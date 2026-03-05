import { PDFLoader } from "@langchain/community/document_loaders/fs/pdf";
import { Document } from "@langchain/core/documents";
import { embeddings, textSplitter } from "../config/models.js";
import {
  PDF_FILE_PATH,
  YOUTUBE_TEST_URL,
  getUserVectorsCollection,
} from "../config/constants.js";
import { DocumentProcessResult } from "../types/index.js";
import { FirestoreVectorStore } from "./firestoreVectorStore.js";
import { Innertube } from "youtubei.js";

/**
 * HTMLエンティティをデコード
 */
function decodeHtmlEntities(text: string): string {
  return text
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&nbsp;/g, " ")
    .replace(/&#(\d+);/g, (_, num) => String.fromCharCode(parseInt(num, 10)));
}

function parsePTagFormat(xml: string): Array<{ text: string }> {
  const segments: Array<{ text: string }> = [];
  const pTagRegex = /<p\s+t="(\d+)"\s+d="(\d+)"[^>]*>([\s\S]*?)<\/p>/g;

  let match = pTagRegex.exec(xml);
  while (match !== null) {
    const [, , , rawText] = match;
    if (rawText) {
      const text = decodeHtmlEntities(rawText.replace(/<[^>]+>/g, "")).trim();
      if (text) segments.push({ text });
    }
    match = pTagRegex.exec(xml);
  }
  return segments;
}

function parseTextTagFormat(xml: string): Array<{ text: string }> {
  const segments: Array<{ text: string }> = [];
  const textTagRegex =
    /<text\s+start="([\d.]+)"\s+dur="([\d.]+)"[^>]*>([\s\S]*?)<\/text>/g;

  let match = textTagRegex.exec(xml);
  while (match !== null) {
    const [, , , rawText] = match;
    if (rawText) {
      const text = decodeHtmlEntities(rawText.replace(/<[^>]+>/g, "")).trim();
      if (text) segments.push({ text });
    }
    match = textTagRegex.exec(xml);
  }
  return segments;
}

function parseTimedTextXml(xml: string): string {
  const pSegments = parsePTagFormat(xml);
  if (pSegments.length > 0) return pSegments.map((s) => s.text).join(" ");
  const textSegments = parseTextTagFormat(xml);
  return textSegments.map((s) => s.text).join(" ");
}

async function fetchCaptionTrack(captionUrl: string): Promise<string> {
  const response = await fetch(captionUrl, {
    headers: {
      "Accept-Language": "en-US,en;q=0.9",
      "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    },
  });

  if (!response.ok) throw new Error(`Failed to fetch caption track: ${response.status}`);
  const xml = await response.text();
  if (!xml || xml.length === 0) throw new Error("Empty caption track response");
  return parseTimedTextXml(xml);
}

export class DocumentService {
  /**
   * PDFファイルを処理してユーザーのベクトルストアに追加
   */
  async processPdfDocument(uid: string): Promise<DocumentProcessResult> {
    const collectionPath = getUserVectorsCollection(uid);
    const store = FirestoreVectorStore.fromExistingCollection(embeddings, collectionPath);

    if (await store.isSourceExists(PDF_FILE_PATH)) {
      console.log(`ソース ${PDF_FILE_PATH} は既に処理済みのため、スキップします`);
      return { message: "指定されたPDFファイルは既に処理済みです", totalChunks: 0 };
    }

    const pdfLoader = new PDFLoader(PDF_FILE_PATH);
    const data = await pdfLoader.load();
    const allSplits = await textSplitter.splitDocuments(data);
    console.log(`Split into ${allSplits.length} chunks.`);

    await store.addDocuments(allSplits);
    console.log(`${allSplits.length}個のチャンクを Firestore に追加しました`);

    return {
      message: "PDFファイルの処理が完了しました",
      totalChunks: allSplits.length,
      totalDocsInCollection: await store.count(),
    };
  }

  /**
   * YouTube動画を処理してユーザーのベクトルストアに追加
   */
  async processYoutubeVideo(
    uid: string,
    videoUrls?: string[]
  ): Promise<DocumentProcessResult> {
    const collectionPath = getUserVectorsCollection(uid);
    const store = FirestoreVectorStore.fromExistingCollection(embeddings, collectionPath);
    const inputUrls = videoUrls && videoUrls.length > 0 ? videoUrls : [YOUTUBE_TEST_URL];
    const urlsToProcess: string[] = [];

    for (const url of inputUrls) {
      if (await store.isSourceExists(url)) {
        console.log(`URL ${url} は既に処理済みのため、スキップします`);
      } else {
        urlsToProcess.push(url);
      }
    }

    if (urlsToProcess.length === 0) {
      return { message: "指定されたYouTube動画はすべて処理済みです", totalChunks: 0 };
    }

    const youtube = await Innertube.create({
      generate_session_locally: true,
      lang: "ja",
      location: "JP",
      retrieve_player: false,
    });

    const allDocs: Document[] = [];
    for (const url of urlsToProcess) {
      console.log(`Processing YouTube URL: ${url}`);

      let videoId: string;
      try {
        const urlObj = new URL(url);
        const vParam = urlObj.searchParams.get("v");
        if (!vParam) throw new Error("動画IDが見つかりません");
        videoId = vParam;
      } catch {
        const splitResult = url.split("v=")[1];
        if (!splitResult) { console.error(`Invalid YouTube URL: ${url}`); continue; }
        videoId = splitResult.split(/[&#]/)[0];
      }

      try {
        const info = await youtube.getBasicInfo(videoId);
        const captionTracks = info.captions?.caption_tracks;

        if (!captionTracks || captionTracks.length === 0) {
          console.error(`No caption tracks found for ${url}. Skipping...`);
          continue;
        }

        const jaTrack =
          captionTracks.find((t) => t.language_code === "ja" && t.kind !== "asr") ||
          captionTracks.find((t) => t.language_code?.startsWith("ja"));

        const enTrack =
          captionTracks.find((t) => t.language_code === "en" && t.kind !== "asr") ||
          captionTracks.find((t) => t.language_code?.startsWith("en"));

        const selectedTrack = jaTrack || enTrack || captionTracks[0];
        if (!selectedTrack?.base_url) {
          console.error(`No valid caption URL found for ${url}. Skipping...`);
          continue;
        }

        const transcriptText = await fetchCaptionTrack(selectedTrack.base_url);
        if (!transcriptText || transcriptText.trim().length === 0) {
          console.error(`Empty transcript for ${url}. Skipping...`);
          continue;
        }

        allDocs.push(new Document({ pageContent: transcriptText, metadata: { source: url } }));
        console.log(`Successfully processed ${url}`);
      } catch (error) {
        console.error(`Error loading YouTube URL ${url}:`, error);
        continue;
      }
    }

    if (allDocs.length === 0) {
      return {
        message: "処理可能なYouTube動画が見つかりませんでした（キャプションが利用できない可能性があります）",
        totalChunks: 0,
      };
    }

    const allSplits = await textSplitter.splitDocuments(allDocs);
    console.log(`Split into ${allSplits.length} chunks.`);

    if (allSplits.length === 0) {
      return { message: "ドキュメントの分割処理後にチャンクが生成されませんでした", totalChunks: 0 };
    }

    await store.addDocuments(allSplits);

    return {
      message: `YouTube動画の処理が完了しました (新規${allDocs.length}件 / 全${inputUrls.length}件)`,
      totalChunks: allSplits.length,
      totalDocsInCollection: await store.count(),
    };
  }

  /**
   * YouTubeプレイリストを処理してユーザーのベクトルストアに追加
   */
  async processYoutubePlaylist(uid: string, playlistUrl: string): Promise<DocumentProcessResult> {
    try {
      const youtube = await Innertube.create({ lang: "ja", retrieve_player: false });

      let playlistId: string;
      try {
        const url = new URL(playlistUrl);
        const listParam = url.searchParams.get("list");
        if (!listParam) throw new Error("プレイリストIDが見つかりません");
        playlistId = listParam;
      } catch {
        const splitResult = playlistUrl.split("list=")[1];
        if (!splitResult) throw new Error("無効なプレイリストURLです");
        playlistId = splitResult.split(/[&#]/)[0];
      }

      if (!playlistId) throw new Error("無効なプレイリストURLです");

      const playlist = await youtube.getPlaylist(playlistId);
      if (!playlist || !playlist.videos) {
        return { message: "プレイリストが見つからないか、動画が含まれていません", totalChunks: 0 };
      }

      const videoUrls = playlist.videos
        .map((video) => {
          const videoId = "id" in video ? (video as { id?: string }).id : undefined;
          return videoId ? `https://www.youtube.com/watch?v=${videoId}` : null;
        })
        .filter((url): url is string => url !== null);

      if (videoUrls.length === 0) {
        return { message: "プレイリストに動画が見つかりませんでした", totalChunks: 0 };
      }

      return await this.processYoutubeVideo(uid, videoUrls);
    } catch (error) {
      console.error("Error processing YouTube playlist:", error);
      throw new Error("YouTubeプレイリストの処理中にエラーが発生しました");
    }
  }
}

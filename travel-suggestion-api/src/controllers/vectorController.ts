import { Request, Response } from "express";
import { VectorStoreService } from "../services/vectorService.js";
import { DocumentService } from "../services/documentService.js";
import { ErrorResponse, YoutubeInputRequest, YoutubePlaylistRequest } from "../types/index.js";

export class VectorController {
  private vectorStoreService: VectorStoreService;
  private documentService: DocumentService;

  constructor() {
    this.vectorStoreService = new VectorStoreService();
    this.documentService = new DocumentService();
  }

  /**
   * ユーザーのベクトルストアを初期化
   */
  async initializeVectorStore(req: Request, res: Response): Promise<void> {
    const uid = req.uid!;
    try {
      const result = await this.vectorStoreService.initializeVectorStore(uid);
      res.json(result);
    } catch (error) {
      console.error("Error in initialize-vector-store endpoint:", error);
      res.status(500).json({
        error: "ベクトルストア初期化中にエラーが発生しました",
        details: error instanceof Error ? error.message : "Unknown error",
      } as ErrorResponse);
    }
  }

  /**
   * PDFドキュメント追加エンドポイント
   */
  async addDocuments(req: Request, res: Response): Promise<void> {
    const uid = req.uid!;
    try {
      const result = await this.documentService.processPdfDocument(uid);
      res.json({
        success: true,
        message: "ドキュメントが正常にベクトルストアに追加されました",
        data: result,
      });
    } catch (error) {
      console.error("Error in add documents endpoint:", error);
      res.status(500).json({
        error: "ドキュメント追加中にエラーが発生しました",
        details: error instanceof Error ? error.message : "Unknown error",
      } as ErrorResponse);
    }
  }

  /**
   * YouTube動画追加エンドポイント
   */
  async addYoutubeVideos(req: Request, res: Response): Promise<void> {
    const uid = req.uid!;
    try {
      const { videoUrls } = req.body as YoutubeInputRequest;

      if (!videoUrls || !Array.isArray(videoUrls) || videoUrls.length === 0) {
        res.status(400).json({
          error: "videoUrlsは空でない配列である必要があります",
        } as ErrorResponse);
        return;
      }

      const invalidUrls = videoUrls.filter(
        (url) =>
          typeof url !== "string" ||
          (!url.includes("youtube.com/watch") && !url.includes("youtu.be/"))
      );

      if (invalidUrls.length > 0) {
        res.status(400).json({
          error: "無効なYouTube URLが含まれています",
          details: `無効なURL: ${invalidUrls.join(", ")}`,
        } as ErrorResponse);
        return;
      }

      const result = await this.documentService.processYoutubeVideo(uid, videoUrls);
      res.json({
        success: true,
        message: "YouTube動画が正常にベクトルストアに追加されました",
        processedVideos: videoUrls.length,
        data: result,
      });
    } catch (error) {
      console.error("Error in add YouTube videos endpoint:", error);
      res.status(500).json({
        error: "YouTube動画追加中にエラーが発生しました",
        details: error instanceof Error ? error.message : "Unknown error",
      } as ErrorResponse);
    }
  }

  /**
   * YouTubeプレイリスト追加エンドポイント
   */
  async addYoutubePlaylist(req: Request, res: Response): Promise<void> {
    const uid = req.uid!;
    try {
      const { playlistUrl } = req.body as YoutubePlaylistRequest;

      if (!playlistUrl || typeof playlistUrl !== "string") {
        res.status(400).json({ error: "playlistUrlは必須です" } as ErrorResponse);
        return;
      }

      const result = await this.documentService.processYoutubePlaylist(uid, playlistUrl);
      res.json({
        success: true,
        message: "YouTubeプレイリストが正常に処理されました",
        data: result,
      });
    } catch (error) {
      console.error("Error in add YouTube playlist endpoint:", error);
      res.status(500).json({
        error: "YouTubeプレイリスト追加中にエラーが発生しました",
        details: error instanceof Error ? error.message : "Unknown error",
      } as ErrorResponse);
    }
  }
}

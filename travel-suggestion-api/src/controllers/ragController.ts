import { Request, Response } from "express";
import { RagService } from "../services/ragService.js";
import {
  SYSTEM_MESSAGES,
  FALLBACK_SOURCES,
  getUserVectorsCollection,
} from "../config/constants.js";
import { ChatRequest, ErrorResponse } from "../types/index.js";

export class RagController {
  private ragService: RagService;

  constructor() {
    this.ragService = new RagService();
  }

  /**
   * 統一RAG検索エンドポイント（本番用）
   */
  async search(req: Request, res: Response): Promise<void> {
    const { question }: ChatRequest = req.body;
    const uid = req.uid!;

    try {
      if (!question) {
        res.status(400).json({
          error: "質問が必要です",
          message: "リクエストボディに 'question' フィールドを含めてください",
        } as ErrorResponse);
        return;
      }

      const config = {
        collectionPath: getUserVectorsCollection(uid),
        systemMessage: SYSTEM_MESSAGES.DEFAULT,
        dataSourceName: "documents",
        logPrefix: "Documents",
        fallbackSource: FALLBACK_SOURCES.DOCUMENTS,
      };

      const result = await this.ragService.processOutputTest(question, config);

      res.json({ success: true, ...result });
    } catch (error) {
      console.error("Error in RAG search endpoint:", error);

      if (error instanceof Error && error.message.includes("ドキュメントが存在しません")) {
        res.status(400).json({
          error: "ドキュメントが存在しません",
          message: "先に /api/v1/documents または /api/v1/youtube-videos でデータを追加してください",
        } as ErrorResponse);
        return;
      }

      res.status(500).json({
        error: "RAG検索中にエラーが発生しました",
        details: error instanceof Error ? error.message : "Unknown error",
      } as ErrorResponse);
    }
  }
}

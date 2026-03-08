import express, { Application } from "express";
import cors from "cors";
import dotenv from "dotenv";
import { initializeRoutes } from "./routes/index.js";
import { initializeDatabase } from "./config/database.js";

// Load environment variables
dotenv.config();

export async function createApp(): Promise<Application> {
  const app: Application = express();

  // CORS（Flutter Web 含む全プラットフォーム対応）
  const corsOrigin =
    process.env.NODE_ENV === "production"
      ? (process.env.CORS_ORIGIN?.split(",") ?? [])
      : true;
  app.use(
    cors({
      origin: corsOrigin,
      allowedHeaders: ["Authorization", "Content-Type"],
      methods: ["GET", "POST", "OPTIONS"],
    })
  );

  // JSON ボディパーサー
  app.use(express.json());

  // Firebase Admin SDK を初期化
  initializeDatabase();

  // ルート設定（/api 配下は authMiddleware が適用される）
  const routes = await initializeRoutes();
  app.use("/", routes);

  return app;
}

export function startServer(app: Application): void {
  const port = process.env.PORT || 8080;

  const server = app.listen(port, () => {
    console.log(`\n🚀 サーバーが起動しました: http://localhost:${port}`);
    console.log(`📝 環境: ${process.env.NODE_ENV || "development"}`);
    console.log(`🔑 Google API Key設定済み: ${!!process.env.GOOGLE_API_KEY}`);
    console.log(`🔥 Firebase Project: ${process.env.FIREBASE_PROJECT_ID || "GCLOUD_PROJECT"}\n`);

    console.log("📋 利用可能なエンドポイント:");
    console.log("  GET  / - API ヘルプ");
    console.log("  GET  /health - ヘルスチェック（認証不要）");
    console.log("  POST /chat - 基本的なチャット（認証不要）");
    console.log("  POST /api/v1/vector-store/init - ベクトルストア初期化 [要認証]");
    console.log("  POST /api/v1/documents - PDFデータ追加 [要認証]");
    console.log("  POST /api/v1/youtube-videos - YouTube動画データ追加 [要認証]");
    console.log("  POST /api/v1/youtube-playlist - YouTubeプレイリスト追加 [要認証]");
    console.log("  POST /api/v1/search - RAG検索・回答 [要認証]");
    console.log("  POST /api/v1/youtube/search - YouTube検索 [要認証]\n");
  });

  const gracefulShutdown = (signal: string) => {
    console.log(`\n${signal} signal received: closing HTTP server gracefully`);
    server.close((err) => {
      if (err) {
        console.error("Error closing server:", err);
        process.exit(1);
      }
      console.log("HTTP server closed");
      process.exit(0);
    });
  };

  process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
  process.on("SIGINT", () => gracefulShutdown("SIGINT"));
  process.on("SIGUSR2", () => gracefulShutdown("SIGUSR2"));

  process.on("uncaughtException", (error) => {
    console.error("Uncaught Exception:", error);
    gracefulShutdown("UNCAUGHT_EXCEPTION");
  });

  process.on("unhandledRejection", (reason, promise) => {
    console.error("Unhandled Rejection at:", promise, "reason:", reason);
    gracefulShutdown("UNHANDLED_REJECTION");
  });
}

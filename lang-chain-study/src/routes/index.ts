import { Router, IRouter } from "express";
import { ChatController } from "../controllers/chatController.js";
import { VectorController } from "../controllers/vectorController.js";
import { RagController } from "../controllers/ragController.js";
import { YoutubeController } from "../controllers/youtubeController.js";
import { authMiddleware } from "../middleware/auth.js";

export const initializeRoutes = async (): Promise<IRouter> => {
  const router: IRouter = Router();

  const chatController = new ChatController();
  const vectorController = new VectorController();
  const ragController = new RagController();
  const youtubeController = await YoutubeController.create();

  // 認証不要なルート
  router.get("/", chatController.getApiInfo.bind(chatController));
  router.get("/health", chatController.healthCheck.bind(chatController));
  router.post("/chat", chatController.chat.bind(chatController));

  // 認証が必要な API エンドポイント（authMiddleware を適用）
  router.post(
    "/api/v1/vector-store/init",
    authMiddleware,
    vectorController.initializeVectorStore.bind(vectorController)
  );
  router.post(
    "/api/v1/documents",
    authMiddleware,
    vectorController.addDocuments.bind(vectorController)
  );
  router.post(
    "/api/v1/youtube-videos",
    authMiddleware,
    vectorController.addYoutubeVideos.bind(vectorController)
  );
  router.post(
    "/api/v1/youtube-playlist",
    authMiddleware,
    vectorController.addYoutubePlaylist.bind(vectorController)
  );
  router.post(
    "/api/v1/search",
    authMiddleware,
    ragController.search.bind(ragController)
  );
  router.post(
    "/api/v1/youtube/search",
    authMiddleware,
    youtubeController.searchVideos.bind(youtubeController)
  );

  return router;
};

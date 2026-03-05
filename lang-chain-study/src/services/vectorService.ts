import { FirestoreVectorStore } from "./firestoreVectorStore.js";
import { getUserVectorsCollection } from "../config/constants.js";

export class VectorStoreService {
  /**
   * ユーザーのベクトルストアを初期化（既存ドキュメントをクリア）
   */
  async initializeVectorStore(uid: string): Promise<{ message: string; nextStep: string }> {
    const collectionPath = getUserVectorsCollection(uid);
    const store = FirestoreVectorStore.fromExistingCollection(
      // embeddings は不要（検索しないため null を渡す）
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      null as any,
      collectionPath
    );

    await store.deleteAll();
    console.log(`ユーザー ${uid} のベクトルストアをクリアしました`);

    return {
      message: "ベクトルストアが初期化されました",
      nextStep: "POST /api/v1/documents または /api/v1/youtube-videos でデータを追加してください",
    };
  }

  /**
   * ユーザーのコレクションにドキュメントが存在するか確認
   */
  async collectionHasData(uid: string): Promise<boolean> {
    const collectionPath = getUserVectorsCollection(uid);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const store = FirestoreVectorStore.fromExistingCollection(null as any, collectionPath);
    const count = await store.count();
    return count > 0;
  }
}

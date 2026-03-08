import { VectorStore } from "@langchain/core/vectorstores";
import { Embeddings } from "@langchain/core/embeddings";
import { Document } from "@langchain/core/documents";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

/**
 * Firestore Vector Search を使ったカスタム VectorStore 実装
 *
 * 前提:
 * - Firestore がネイティブモードで有効になっていること
 * - `embedding` フィールドに対するベクターインデックスが作成済みであること
 *   （Firestore コンソール → インデックス → ベクターインデックスを追加）
 *   次元数: 768 (Gemini embedding-001)
 */
export class FirestoreVectorStore extends VectorStore {
  private collectionPath: string;

  constructor(embeddings: Embeddings, collectionPath: string) {
    super(embeddings, {});
    this.collectionPath = collectionPath;
  }

  _vectorstoreType(): string {
    return "firestore";
  }

  /**
   * VectorStore の抽象メソッド実装
   * 事前に計算済みのベクターを使ってドキュメントを保存する
   */
  async addVectors(
    vectors: number[][],
    documents: Document[]
  ): Promise<string[] | void> {
    const db = getFirestore();
    const col = db.collection(this.collectionPath);
    const ids: string[] = [];
    const batchSize = 499;

    for (let i = 0; i < documents.length; i += batchSize) {
      const batch = db.batch();
      const chunkDocs = documents.slice(i, i + batchSize);
      const chunkVecs = vectors.slice(i, i + batchSize);

      for (let j = 0; j < chunkDocs.length; j++) {
        const ref = col.doc();
        batch.set(ref, {
          content: chunkDocs[j].pageContent,
          embedding: FieldValue.vector(chunkVecs[j]),
          metadata: chunkDocs[j].metadata,
          source: chunkDocs[j].metadata?.source ?? null,
          createdAt: new Date(),
        });
        ids.push(ref.id);
      }
      await batch.commit();
    }

    return ids;
  }

  /**
   * ドキュメントをベクター埋め込みとともに Firestore に保存する
   */
  async addDocuments(documents: Document[]): Promise<string[] | void> {
    const texts = documents.map((d) => d.pageContent);
    const vectors = await this.embeddings.embedDocuments(texts);
    return this.addVectors(vectors, documents);
  }

  /**
   * ベクター類似度検索（Firestore findNearest を使用）
   */
  async similaritySearchVectorWithScore(
    query: number[],
    k: number
  ): Promise<[Document, number][]> {
    const db = getFirestore();
    const col = db.collection(this.collectionPath);

    const snapshot = await col
      .findNearest({
        vectorField: "embedding",
        queryVector: FieldValue.vector(query),
        limit: k,
        distanceMeasure: "COSINE",
        distanceResultField: "vector_distance",
      })
      .get();

    return snapshot.docs.map((doc) => {
      const data = doc.data();
      return [
        new Document({
          pageContent: data.content,
          metadata: data.metadata ?? {},
        }),
        data.vector_distance ?? 0,
      ];
    });
  }

  /**
   * 指定ソースのドキュメントが既に存在するか確認する
   */
  async isSourceExists(source: string): Promise<boolean> {
    const db = getFirestore();
    const snapshot = await db
      .collection(this.collectionPath)
      .where("source", "==", source)
      .limit(1)
      .get();
    return !snapshot.empty;
  }

  /**
   * このコレクションのドキュメント件数を返す
   */
  async count(): Promise<number> {
    const db = getFirestore();
    const snapshot = await db.collection(this.collectionPath).count().get();
    return snapshot.data().count;
  }

  /**
   * コレクション内の全ドキュメントを削除する
   */
  async deleteAll(): Promise<void> {
    const db = getFirestore();
    const col = db.collection(this.collectionPath);

    while (true) {
      const snapshot = await col.limit(499).get();
      if (snapshot.empty) break;
      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }
  }

  /**
   * ドキュメントを追加しながら新しいインスタンスを返す
   * 基底クラスのシグネチャに合わせて dbConfig は Record<string, any> で受け取る
   */
  static async fromDocuments(
    documents: Document[],
    embeddings: Embeddings,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    dbConfig: Record<string, any>
  ): Promise<FirestoreVectorStore> {
    const collectionPath = dbConfig.collectionPath as string;
    const store = new FirestoreVectorStore(embeddings, collectionPath);
    await store.addDocuments(documents);
    return store;
  }

  /**
   * 既存コレクションから検索用インスタンスを作成する
   */
  static fromExistingCollection(
    embeddings: Embeddings,
    collectionPath: string
  ): FirestoreVectorStore {
    return new FirestoreVectorStore(embeddings, collectionPath);
  }
}

import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

export function initializeDatabase(): void {
  if (getApps().length === 0) {
    // Cloud Run 上では Application Default Credentials が自動的に使用される
    // ローカル開発時は GOOGLE_APPLICATION_CREDENTIALS 環境変数でサービスアカウントを指定
    initializeApp();
    console.log("Firebase Admin SDK を初期化しました");
  }
}

export function getFirestoreDb() {
  return getFirestore();
}

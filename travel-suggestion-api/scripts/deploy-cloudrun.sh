#!/bin/bash

# Cloud Run デプロイスクリプト
# 
# 使い方:
#   方法1: .env.cloudrun ファイルを使用（推奨）
#     1. .env.cloudrun.example を .env.cloudrun にコピー
#     2. .env.cloudrun に必要な値を設定
#     3. このスクリプトを実行: bash scripts/deploy-cloudrun.sh
#
#   方法2: 環境変数を直接設定
#     1. export PROJECT_ID=your-project-id
#     2. export GOOGLE_API_KEY=your-api-key
#     3. このスクリプトを実行: bash scripts/deploy-cloudrun.sh

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# .env.cloudrun ファイルが存在する場合は読み込む
if [ -f "$PROJECT_ROOT/.env.cloudrun" ]; then
  echo "📋 .env.cloudrun から設定を読み込んでいます..."
  # コメント行と空行を除外して環境変数として読み込む
  export $(grep -v '^#' "$PROJECT_ROOT/.env.cloudrun" | grep -v '^$' | xargs)
  echo "✅ 設定を読み込みました"
  echo ""
fi

# 環境変数のチェック
if [ -z "$PROJECT_ID" ]; then
  echo "❌ エラー: PROJECT_ID が設定されていません"
  echo "使い方: export PROJECT_ID=your-project-id"
  exit 1
fi

if [ -z "$SERVICE_NAME" ]; then
  echo "⚠️  SERVICE_NAME が設定されていません。デフォルト値 'langchain-tutorial' を使用します"
  SERVICE_NAME="langchain-tutorial"
fi

if [ -z "$REGION" ]; then
  echo "⚠️  REGION が設定されていません。デフォルト値 'asia-northeast1' を使用します"
  REGION="asia-northeast1"
fi

echo "🚀 Cloud Run へのデプロイを開始します..."
echo "プロジェクトID: $PROJECT_ID"
echo "サービス名: $SERVICE_NAME"
echo "リージョン: $REGION"
echo ""

# Google API Keyの確認
if [ -z "$GOOGLE_API_KEY" ]; then
  echo "❌ エラー: GOOGLE_API_KEY が設定されていません"
  echo "使い方: export GOOGLE_API_KEY=your-api-key"
  exit 1
fi

# プロジェクトIDを設定
gcloud config set project $PROJECT_ID

# Cloud Build APIが有効か確認
echo "📦 コンテナイメージをビルドしています..."
gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE_NAME

# Cloud Run にデプロイ
echo "🚢 Cloud Run にデプロイしています..."
gcloud run deploy $SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$SERVICE_NAME \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --set-env-vars "GOOGLE_API_KEY=$GOOGLE_API_KEY,NODE_ENV=production" \
  --memory 512Mi \
  --cpu 1 \
  --max-instances 10

echo ""
echo "✅ デプロイが完了しました！"
echo ""
echo "サービスURL:"
gcloud run services describe $SERVICE_NAME --platform managed --region $REGION --format 'value(status.url)'

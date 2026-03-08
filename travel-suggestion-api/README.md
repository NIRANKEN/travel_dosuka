# LangChain Study

LangChain チュートリアルアプリケーション - TypeScript + Google GenAI

## 概要

このプロジェクトは、LangChain と Google Generative AI (Gemini) を使用したチュートリアルアプリケーションです。
NodeJS + TypeScript で実装されており、ローカル実行と GCP Cloud Run へのデプロイに対応しています。

## 機能

- 🤖 LangChain による質問応答システム
- 🌐 Google Gemini Pro モデルの利用
- 🔄 翻訳機能
- 🌍 REST API（Express ベース）
- 💻 CLI インターフェース
- 🐳 Docker 対応
- ☁️ Google Cloud Run デプロイ可能

## 技術スタック

- **Runtime**: Node.js 24
- **言語**: TypeScript
- **パッケージマネージャー**: pnpm
- **LLMフレームワーク**: LangChain
- **LLMモデル**: Google Gemini Pro
- **Webフレームワーク**: Express
- **Linter**: ESLint with TypeScript support
- **コンテナ**: Docker
- **デプロイ先**: Google Cloud Run

## セットアップ

### 前提条件

- Node.js 24以上
- pnpm
- Google API Key (Gemini Pro用)
- (オプション) Google Cloud SDK (Cloud Runデプロイ時)

### インストール

1. リポジトリをクローン:
```bash
git clone <repository-url>
cd lang-chain-study
```

2. 依存関係をインストール:
```bash
pnpm install
```

3. 環境変数を設定:
```bash
cp .env.example .env
```

`.env` ファイルを編集して、Google API Key を設定:
```
GOOGLE_API_KEY=your_actual_api_key_here
PORT=8080
NODE_ENV=development
```

### Google API Key の取得方法

1. [Google AI Studio](https://makersuite.google.com/app/apikey) にアクセス
2. "Create API Key" をクリック
3. 生成された API Key をコピーして `.env` ファイルに設定

## 使い方

### CLI モードで実行

```bash
pnpm dev:cli
```

サンプルの質問応答、翻訳、チェーン処理の例が実行されます。

### サーバーモードで実行

```bash
pnpm dev
```

サーバーが起動したら、以下のエンドポイントにアクセスできます:

- `GET http://localhost:8080/` - API情報
- `GET http://localhost:8080/health` - ヘルスチェック
- `POST http://localhost:8080/chat` - 質問応答
- `POST http://localhost:8080/translate` - 翻訳

### API の使用例

#### チャット (質問応答)

```bash
curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"question": "LangChainとは何ですか？"}'
```

#### 翻訳

```bash
curl -X POST http://localhost:8080/translate \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello, how are you?", "targetLang": "Japanese"}'
```

## 開発

### Lint の実行

```bash
pnpm lint
```

### Lint の自動修正

```bash
pnpm lint:fix
```

### ビルド

```bash
pnpm build
```

ビルドされたファイルは `dist/` ディレクトリに出力されます。

### 本番環境で実行

```bash
pnpm build
pnpm start
```

## Docker

### Docker イメージのビルド

```bash
docker build -t langchain-tutorial .
```

### Docker コンテナの実行

```bash
docker run -p 8080:8080 \
  -e GOOGLE_API_KEY=your_api_key_here \
  langchain-tutorial
```

## Google Cloud Run へのデプロイ

### 推奨: .env.cloudrun ファイルを使用

1. 環境設定ファイルを作成:
```bash
cp .env.cloudrun.example .env.cloudrun
```

2. `.env.cloudrun` を編集して必要な値を設定:
```bash
PROJECT_ID=your-gcp-project-id
SERVICE_NAME=langchain-tutorial
REGION=asia-northeast1
GOOGLE_API_KEY=your_google_api_key
```

3. デプロイスクリプトを実行:
```bash
bash scripts/deploy-cloudrun.sh
```

デプロイ後のヘルスチェック検証

```
export SERVICE_URL="https://[YOUR_SERVICE_URL]"
# Get the OIDC ID token
export ID_TOKEN=$(gcloud auth print-identity-token)
# Make the GET request with the Authorization header
curl -H "Authorization: Bearer ${ID_TOKEN}" "${SERVICE_URL}"
```

### 代替方法: 環境変数を直接設定

1. 必要な環境変数を設定:
```bash
export PROJECT_ID=your-gcp-project-id
export SERVICE_NAME=langchain-tutorial
export REGION=asia-northeast1
export GOOGLE_API_KEY=your_google_api_key
```

2. デプロイスクリプトを実行:
```bash
bash scripts/deploy-cloudrun.sh
```

### gcloud コマンドで直接デプロイ

```bash
# プロジェクトIDを設定
gcloud config set project YOUR_PROJECT_ID

# コンテナイメージをビルド
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/langchain-tutorial

# Cloud Run にデプロイ
gcloud run deploy langchain-tutorial \
  --image gcr.io/YOUR_PROJECT_ID/langchain-tutorial \
  --platform managed \
  --region asia-northeast1 \
  --allow-unauthenticated \
  --set-env-vars "GOOGLE_API_KEY=YOUR_API_KEY" \
  --memory 512Mi
```

デプロイ後、表示されたURLにアクセスしてアプリケーションを確認できます。

## プロジェクト構成

```
lang-chain-study/
├── src/
│   ├── index.ts          # メインサーバーアプリケーション
│   └── cli.ts            # CLIサンプル
├── scripts/
│   └── deploy-cloudrun.sh # Cloud Runデプロイスクリプト
├── .env.example          # 環境変数のサンプル
├── .dockerignore         # Dockerビルド時の除外ファイル
├── Dockerfile            # Docker設定
├── tsconfig.json         # TypeScript設定
├── eslint.config.mjs     # ESLint設定
├── package.json          # プロジェクト設定
└── README.md             # このファイル
```

## トラブルシューティング

### Google API Key エラー

```
Error: Google API Key is not configured
```

→ `.env` ファイルに `GOOGLE_API_KEY` が正しく設定されているか確認してください。

### pnpm が見つからない

```
bash: pnpm: command not found
```

→ pnpm をインストールしてください:
```bash
npm install -g pnpm
```

### Cloud Run デプロイエラー

必要な API を有効化してください:
```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
```

## ライセンス

ISC

## 参考リンク

- [LangChain Documentation](https://js.langchain.com/)
- [Google Generative AI](https://ai.google.dev/)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)


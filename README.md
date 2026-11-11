# EasyOCR API

EasyOCRを使用した画像・PDFのOCR処理を行うWeb APIサービスです。ファイルのアップロード、OCR処理、結果の取得をシンプルなREST APIで提供します。

## 特徴

- 📝 **多言語対応**: 日本語・英語のOCR処理
- 📄 **PDF対応**: PDFファイルを自動的に画像に変換してOCR処理
- 🔄 **非同期処理**: ファイルアップロード後、バックグラウンドでOCR処理
- 📊 **結果可視化**: テキスト検出位置を矩形で囲んだ画像を生成
- 📈 **構造化データ**: 検出テキスト、位置情報、信頼度をCSV形式で出力
- 🌐 **Web API**: FastAPIベースのRESTful API
- 🔧 **簡単セットアップ**: ワンコマンドでセットアップ・起動

## システム構成

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   File Upload   │───▶│   API Server    │───▶│ OCR Processor   │
│                 │    │  (FastAPI)      │    │  (EasyOCR)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   File Store    │    │    Results      │
                       │ (images/uploads)│    │ (process/result)│
                       └─────────────────┘    └─────────────────┘
```

## クイックスタート

### 1. セットアップ

```bash
# リポジトリをクローン
git clone <repository-url>
cd easyocr-api

# 自動セットアップ（依存関係インストール + 初期化）
./setup.sh setup
```

### 2. サービス起動

```bash
# OCRプロセッサ + APIサーバーを起動
./setup.sh start

# サービス状態確認
./setup.sh status
```

### 3. API使用

```bash
# ファイルアップロード
curl -X POST "http://localhost:8000/upload" \
  -F "file=@sample.jpg" \
  -F "email=user@example.com"

# 処理状況確認
curl "http://localhost:8000/status/20240917_abcd1234_sample.jpg"

# 結果取得
curl "http://localhost:8000/result/20240917_abcd1234_sample.jpg"
```

## ディレクトリ構造

```
easyocr-api/
├── README.md              # このファイル
├── requirements.txt       # Python依存関係
├── setup.sh              # セットアップスクリプト
├── ocr_processor.py       # OCR処理エンジン
├── api_server.py          # Web APIサーバー
├── images/               # OCR処理待ちファイル
├── process/              # 処理済み画像（矩形描画済み）
├── result/               # OCR結果CSV
├── uploads/              # アップロード一時保存
├── logs/                 # ログファイル
└── venv/                 # Python仮想環境
```

## API エンドポイント

### 📤 ファイルアップロード
```http
POST /upload
Content-Type: multipart/form-data

Parameters:
- file: 画像ファイル または PDFファイル
- email: メールアドレス（オプション）
```

### 📊 処理状況確認
```http
GET /status/{filename}

Response:
{
  "filename": "20240917_abcd1234_sample.jpg",
  "status": "completed",
  "has_processed_image": true,
  "has_result_csv": true
}
```

### 📋 結果取得
```http
GET /result/{filename}?result_type=both

Parameters:
- result_type: "image" | "text" | "both"

Response:
{
  "filename": "sample.jpg",
  "processed_image": "processed_sample.jpg",
  "ocr_results": [...],
  "result_csv": "result_sample.csv"
}
```

### 📥 ファイルダウンロード
```http
GET /download/image/{image_filename}  # 処理済み画像
GET /download/csv/{csv_filename}      # 結果CSV
```

## setup.sh コマンド

| コマンド | 説明 |
|---------|------|
| `./setup.sh setup` | 初回セットアップ |
| `./setup.sh start` | サービス起動 |
| `./setup.sh stop` | サービス停止 |
| `./setup.sh restart` | サービス再起動 |
| `./setup.sh status` | サービス状態確認 |
| `./setup.sh test` | テスト画像でOCR実行 |
| `./setup.sh clean` | 一時ファイル削除 |
| `./setup.sh autostart-enable` | OS起動時の自動起動を有効化（systemd ユーザーサービス + linger） |
| `./setup.sh autostart-disable` | 自動起動を無効化してサービス停止 |
| `./setup.sh help` | ヘルプ表示 |

### 自動起動（systemd）

```bash
API_PORT=3000 ./setup.sh autostart-enable    # ポート・待受（API_HOST）・OCR_GPU は有効化時の値でユニットに固定される
systemctl --user status 'easyocr-api*'       # 状態確認
systemctl --user restart easyocr-api.target  # 再起動（自動起動中は ./setup.sh start/stop/restart は使用不可）
```

ユニットは `~/.config/systemd/user/easyocr-api*.{service,target}` に生成され、異常終了時は5秒後に自動再起動されます。
ログは従来どおり `logs/*.log` に追記されます。設定を変える場合は新しい環境変数で `autostart-enable` を再実行してください。

## 個別起動方法

### OCRプロセッサのみ起動
```bash
python ocr_processor.py
```

### APIサーバーのみ起動
```bash
# デフォルト（ポート8000）
python api_server.py

# ポート指定
python api_server.py --port 9000
python api_server.py -p 9000

# ホスト指定
python api_server.py --host 127.0.0.1 --port 9000
```

## 対応ファイル形式

### 画像ファイル
- JPEG (.jpg, .jpeg)
- PNG (.png)
- BMP (.bmp)
- TIFF (.tiff)
- WebP (.webp)

### PDFファイル
- PDF (.pdf) - 自動的に画像に変換してOCR処理

## システム要件

### Python
- Python 3.7 以降
- pip3

### システム依存関係
- **Ubuntu/Debian**: `poppler-utils`, `libgl1-mesa-glx`, `libglib2.0-0`
- **macOS**: `poppler` (Homebrew経由)
- **Windows**: `poppler` バイナリが必要

### Python依存関係
```
easyocr
opencv-python
numpy
fastapi
uvicorn[standard]
python-multipart
pdf2image
pillow
```

## 使用例

### 1. 画像ファイルのOCR

```bash
# 1. 画像をアップロード
curl -X POST "http://localhost:3000/upload" \
  -F "file=@sample.png"

# Response: {"unique_filename": "20240917_abcd1234_document.jpg", ...}

# 2. 処理完了まで待機
curl "http://localhost:3000/status/20250918_141324_38a15bbf_sample.png"

# 3. 結果取得
curl "http://localhost:8000/result/20250918_141324_38a15bbf_sample.png"
```

### 2. PDFファイルのOCR

```bash
# 1. PDFをアップロード（自動的に各ページが画像に変換される）
curl -X POST "http://localhost:8000/upload" \
  -F "file=@report.pdf"

# 2. 各ページの処理状況確認
curl "http://localhost:8000/status/20240917_efgh5678_report_page_001.png"
curl "http://localhost:8000/status/20240917_efgh5678_report_page_002.png"

# 3. 各ページの結果取得
curl "http://localhost:8000/result/20240917_efgh5678_report_page_001.png"
```

### 3. Swagger UIの使用

ブラウザで http://localhost:8000/docs にアクセスして、インタラクティブなAPI文書を使用できます。

## トラブルシューティング

### よくある問題

1. **`poppler-utils`が見つからない**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install poppler-utils
   
   # macOS
   brew install poppler
   ```

2. **OpenCVのエラー**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install libgl1-mesa-glx libglib2.0-0
   ```

3. **ポートが使用中**
   ```bash
   # 別のポートを使用
   python api_server.py --port 9000
   ```

4. **EasyOCRモデルのダウンロードが遅い**
   - 初回起動時にEasyOCRが日本語・英語モデルをダウンロードします
   - インターネット接続が必要です

### ログ確認

```bash
# OCRプロセッサのログ
tail -f logs/ocr_processor.log

# APIサーバーのログ
tail -f logs/api_server.log
```

## ライセンス

MIT License

## 貢献

プルリクエストやイシューは歓迎します。

## 参考

- [EasyOCR](https://github.com/JaidedAI/EasyOCR)
- [FastAPI](https://fastapi.tiangolo.com/)
- [OpenCV](https://opencv.org/)
#!/bin/bash

# EasyOCR API Setup Script
# OCRプロセッサとAPIサーバーを簡単にセットアップ・実行するためのスクリプト

set -e  # エラーが発生した場合はスクリプトを終了

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ出力関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# プロジェクトディレクトリの確認
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

log_info "EasyOCR API セットアップを開始します..."
log_info "プロジェクトディレクトリ: $PROJECT_DIR"

# ヘルプ表示
show_help() {
    echo "EasyOCR API Setup Script"
    echo ""
    echo "使用法:"
    echo "  ./setup.sh [command] [options]"
    echo "  API_PORT=3000 ./setup.sh start    # ポート指定"
    echo ""
    echo "コマンド:"
    echo "  install     - 依存関係をインストール"
    echo "  init        - ディレクトリを初期化"
    echo "  start       - OCRプロセッサとAPIサーバーを起動"
    echo "  stop        - 実行中のサービスを停止"
    echo "  restart     - サービスを再起動"
    echo "  status      - サービスの状態を確認"
    echo "  setup       - インストールと初期化を実行"
    echo "  test        - テスト用画像でOCRを実行"
    echo "  clean       - 一時ファイルを削除"
    echo "  help        - このヘルプを表示"
    echo ""
    echo "例:"
    echo "  ./setup.sh setup              # 初回セットアップ"
    echo "  ./setup.sh start              # サービス起動（ポート8000）"
    echo "  API_PORT=8001 ./setup.sh start  # ポート8001で起動"
    echo "  ./setup.sh test               # テスト実行"
}

# Pythonの確認
check_python() {
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3が見つかりません。Python 3をインストールしてください。"
        exit 1
    fi
    
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
    log_info "Python バージョン: $PYTHON_VERSION"
    
    if ! command -v pip3 &> /dev/null; then
        log_error "pip3が見つかりません。pipをインストールしてください。"
        exit 1
    fi
}

# システム依存関係の確認とインストール
install_system_dependencies() {
    log_info "システム依存関係を確認中..."
    
    # Ubuntu/Debian系の場合
    if command -v apt-get &> /dev/null; then
        # poppler-utilsの確認（PDF変換用）
        if ! dpkg -l | grep -q poppler-utils; then
            log_warning "poppler-utilsが見つかりません。インストールを試行します..."
            sudo apt-get update && sudo apt-get install -y poppler-utils
        fi
        
        # libgl1-mesa-glx（OpenCV用）
        if ! dpkg -l | grep -q libgl1-mesa-glx; then
            log_warning "OpenCV用のライブラリをインストールします..."
            sudo apt-get install -y libgl1-mesa-glx libglib2.0-0
        fi
    
    # macOS（Homebrew）の場合
    elif command -v brew &> /dev/null; then
        if ! brew list poppler &> /dev/null; then
            log_warning "poppler が見つかりません。インストールを試行します..."
            brew install poppler
        fi
    
    else
        log_warning "パッケージマネージャーが見つかりません。手動でpoppler-utilsをインストールしてください。"
    fi
}

# Python依存関係のインストール
install_python_dependencies() {
    log_info "Python依存関係をインストール中..."
    
    # 仮想環境の作成（オプション）
    if [ ! -d "venv" ]; then
        log_info "仮想環境を作成中..."
        python3 -m venv venv
    fi
    
    # 仮想環境のアクティベート
    source venv/bin/activate
    
    # 依存関係のインストール
    pip install --upgrade pip
    pip install -r requirements.txt
    
    log_success "Python依存関係のインストールが完了しました"
}

# ディレクトリの初期化
initialize_directories() {
    log_info "ディレクトリを初期化中..."
    
    # 必要なディレクトリを作成
    directories=("images" "process" "result" "uploads" "logs")
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_info "ディレクトリを作成: $dir"
        fi
    done
    
    # .gitkeepファイルの作成
    for dir in "${directories[@]}"; do
        touch "$dir/.gitkeep"
    done
    
    log_success "ディレクトリの初期化が完了しました"
}

# PIDファイルの管理
PID_DIR="$PROJECT_DIR/logs"
OCR_PID_FILE="$PID_DIR/ocr_processor.pid"
API_PID_FILE="$PID_DIR/api_server.pid"

# デフォルトポート
API_PORT="${API_PORT:-8000}"

# サービスの起動
start_services() {
    log_info "サービスを起動中..."
    
    # 仮想環境のアクティベート
    if [ -d "venv" ]; then
        source venv/bin/activate
    fi
    
    # OCRプロセッサの起動
    if [ ! -f "$OCR_PID_FILE" ] || ! kill -0 $(cat "$OCR_PID_FILE" 2>/dev/null) 2>/dev/null; then
        log_info "OCRプロセッサを起動中..."
        nohup python3 ocr_processor.py > logs/ocr_processor.log 2>&1 &
        echo $! > "$OCR_PID_FILE"
        log_success "OCRプロセッサが起動しました (PID: $(cat $OCR_PID_FILE))"
    else
        log_warning "OCRプロセッサは既に起動しています"
    fi
    
    # APIサーバーの起動
    if [ ! -f "$API_PID_FILE" ] || ! kill -0 $(cat "$API_PID_FILE" 2>/dev/null) 2>/dev/null; then
        log_info "APIサーバーを起動中..."
        nohup python3 api_server.py --host 0.0.0.0 --port $API_PORT > logs/api_server.log 2>&1 &
        #/usr/bin/uvicorn api_server:app --host :: --port $API_PORT > logs/api_server.log 2>&1 &
        echo $! > "$API_PID_FILE"
        log_success "APIサーバーが起動しました (PID: $(cat $API_PID_FILE))"
        log_info "APIサーバー: http://localhost:$API_PORT"
        log_info "Swagger UI: http://localhost:$API_PORT/docs"
    else
        log_warning "APIサーバーは既に起動しています"
    fi
    
    sleep 2
    show_status
}

# サービスの停止
stop_services() {
    log_info "サービスを停止中..."
    
    # OCRプロセッサの停止
    if [ -f "$OCR_PID_FILE" ] && kill -0 $(cat "$OCR_PID_FILE" 2>/dev/null) 2>/dev/null; then
        kill $(cat "$OCR_PID_FILE")
        rm -f "$OCR_PID_FILE"
        log_success "OCRプロセッサを停止しました"
    else
        log_warning "OCRプロセッサは起動していません"
    fi
    
    # APIサーバーの停止
    if [ -f "$API_PID_FILE" ] && kill -0 $(cat "$API_PID_FILE" 2>/dev/null) 2>/dev/null; then
        kill $(cat "$API_PID_FILE")
        rm -f "$API_PID_FILE"
        log_success "APIサーバーを停止しました"
    else
        log_warning "APIサーバーは起動していません"
    fi
}

# サービスの状態確認
show_status() {
    log_info "サービスの状態を確認中..."
    
    # OCRプロセッサの状態
    if [ -f "$OCR_PID_FILE" ] && kill -0 $(cat "$OCR_PID_FILE" 2>/dev/null) 2>/dev/null; then
        log_success "OCRプロセッサ: 起動中 (PID: $(cat $OCR_PID_FILE))"
    else
        log_warning "OCRプロセッサ: 停止中"
    fi
    
    # APIサーバーの状態
    if [ -f "$API_PID_FILE" ] && kill -0 $(cat "$API_PID_FILE" 2>/dev/null) 2>/dev/null; then
        log_success "APIサーバー: 起動中 (PID: $(cat $API_PID_FILE))"
        log_info "URL: http://localhost:$API_PORT"
        
        # APIサーバーの疎通確認
        if command -v curl &> /dev/null; then
            if curl -s http://localhost:$API_PORT/ > /dev/null; then
                log_success "APIサーバーに正常に接続できます"
            else
                log_warning "APIサーバーに接続できません"
            fi
        fi
    else
        log_warning "APIサーバー: 停止中"
    fi
}

# テスト用画像でOCRを実行
run_test() {
    log_info "テスト用画像でOCRを実行中..."
    
    # テスト用の画像を作成（簡単なテキスト画像）
    if command -v convert &> /dev/null; then
        convert -size 400x100 -background white -fill black -font Arial -pointsize 24 -gravity center label:"Hello World テスト" images/test_image.png
        log_info "テスト画像を作成: images/test_image.png"
    else
        log_warning "ImageMagickが見つかりません。手動でテスト画像をimagesフォルダに配置してください。"
        return 1
    fi
    
    # サービスが起動しているか確認
    if [ ! -f "$OCR_PID_FILE" ] || ! kill -0 $(cat "$OCR_PID_FILE" 2>/dev/null) 2>/dev/null; then
        log_warning "OCRプロセッサが起動していません。起動します..."
        start_services
        sleep 3
    fi
    
    # 処理完了まで待機
    log_info "OCR処理の完了を待機中..."
    for i in {1..10}; do
        if [ -f "process/processed_test_image.png" ] && [ -f "result/result_test_image.csv" ]; then
            log_success "OCR処理が完了しました！"
            log_info "処理済み画像: process/processed_test_image.png"
            log_info "結果CSV: result/result_test_image.csv"
            
            # CSVの内容を表示
            if [ -f "result/result_test_image.csv" ]; then
                log_info "検出されたテキスト:"
                cat result/result_test_image.csv
            fi
            return 0
        fi
        sleep 1
    done
    
    log_warning "OCR処理が完了しませんでした。ログを確認してください。"
}

# 一時ファイルの削除
clean_temp_files() {
    log_info "一時ファイルを削除中..."
    
    # 各ディレクトリの内容を削除（.gitkeepは保持）
    for dir in images process result uploads; do
        if [ -d "$dir" ]; then
            find "$dir" -type f ! -name '.gitkeep' -delete
            log_info "$dir ディレクトリをクリーンアップしました"
        fi
    done
    
    # ログファイルをクリーンアップ
    if [ -d "logs" ]; then
        find logs -name "*.log" -delete
        log_info "ログファイルをクリーンアップしました"
    fi
    
    log_success "クリーンアップが完了しました"
}

# メイン処理
case "${1:-help}" in
    "install")
        check_python
        install_system_dependencies
        install_python_dependencies
        ;;
    "init")
        initialize_directories
        ;;
    "start")
        start_services
        ;;
    "stop")
        stop_services
        ;;
    "restart")
        stop_services
        sleep 2
        start_services
        ;;
    "status")
        show_status
        ;;
    "setup")
        check_python
        install_system_dependencies
        install_python_dependencies
        initialize_directories
        log_success "セットアップが完了しました！"
        log_info "サービスを開始するには: ./setup.sh start"
        ;;
    "test")
        run_test
        ;;
    "clean")
        clean_temp_files
        ;;
    "help"|*)
        show_help
        ;;
esac
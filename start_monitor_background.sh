#!/bin/bash
# 背景執行 LINE QR Code 監控腳本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/AutoLINE_scan_qrcode.command"
PID_FILE="$SCRIPT_DIR/qrcode_monitor.pid"

# 解析參數
# 解析參數
CLEAN_LOGS=""
KEEP_LOGS=""
RESTART_INTERVAL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean-logs)
            CLEAN_LOGS="--clean-logs"
            shift
            ;;
        --keep-logs)
            KEEP_LOGS="--keep-logs $2"
            shift 2
            ;;
        --restart-interval)
            RESTART_INTERVAL="$2"
            shift 2
            ;;
        -h|--help)
            echo "使用方式: $0 [選項]"
            echo ""
            echo "選項:"
            echo "  --clean-logs           啟動時清除所有舊日誌檔案"
            echo "  --keep-logs N          啟動時保留最近 N 個日誌檔案,刪除其他"
            echo "  --restart-interval N   每 N 秒自動重啟一次 (例如: 3600 = 1 小時)"
            echo "  -h, --help             顯示此說明訊息"
            echo ""
            echo "範例:"
            echo "  $0                     # 不清除日誌"
            echo "  $0 --clean-logs        # 清除所有舊日誌"
            echo "  $0 --clean-logs --keep-logs 5  # 只保留最近 5 個日誌"
            echo "  $0 --restart-interval 3600     # 每小時重啟一次"
            exit 0
            ;;
        *)
            echo "未知選項: $1"
            echo "使用 -h 或 --help 查看說明"
            exit 1
            ;;
    esac
done

# 檢查是否已經在運行
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "⚠️  監控程式已在運行中 (PID: $OLD_PID)"
        echo "🔄 自動停止舊程序並重新啟動..."
        kill "$OLD_PID" 2>/dev/null
        sleep 1
        # 確認是否已停止
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            echo "⚠️  程式未正常停止,強制終止..."
            kill -9 "$OLD_PID" 2>/dev/null
            sleep 1
        fi
        rm -f "$PID_FILE"
        echo "✅ 舊程序已停止"
    else
        echo "🧹 清理舊的 PID 檔案"
        rm -f "$PID_FILE"
    fi
fi

# 在背景執行
if [ -n "$RESTART_INTERVAL" ]; then
    echo "🚀 啟動 LINE QR Code 監控 (自動重啟模式, 每 ${RESTART_INTERVAL} 秒)..."
    # 使用迴圈進行自動重啟
    nohup bash -c "while true; do \
        echo '🔄 啟動監控程序...'; \
        python3 \"$PYTHON_SCRIPT\" $CLEAN_LOGS $KEEP_LOGS --run-duration $RESTART_INTERVAL; \
        echo '⏳ 等待 1 秒後重啟...'; \
        sleep 1; \
    done" > /dev/null 2>&1 &
    NEW_PID=$!
    echo "Note: PID $NEW_PID 是監控迴圈的 PID"
else
    echo "🚀 啟動 LINE QR Code 監控..."
    nohup python3 "$PYTHON_SCRIPT" $CLEAN_LOGS $KEEP_LOGS > /dev/null 2>&1 &
    NEW_PID=$!
fi

# 儲存 PID
echo $NEW_PID > "$PID_FILE"

echo "✅ 監控已在背景啟動 (PID: $NEW_PID)"
echo "📝 日誌檔案會儲存在: $SCRIPT_DIR/qrcode_monitor_*.log"
echo ""
echo "📋 常用指令:"
echo "  查看最新日誌: tail -f $SCRIPT_DIR/qrcode_monitor_*.log"
echo "  停止監控: kill $NEW_PID"
echo "  或執行: $SCRIPT_DIR/stop_monitor.sh"

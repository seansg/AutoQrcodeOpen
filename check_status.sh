#!/bin/bash
# 檢查 LINE QR Code 監控程式狀態

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/qrcode_monitor.pid"

echo "🔍 檢查 LINE QR Code 監控程式狀態..."
echo ""

if [ ! -f "$PID_FILE" ]; then
    echo "❌ 監控程式未運行"
    echo "   (找不到 PID 檔案)"
    exit 1
fi

PID=$(cat "$PID_FILE")

if ps -p "$PID" > /dev/null 2>&1; then
    echo "✅ 監控程式正在運行"
    echo "   PID: $PID"
    echo ""
    
    # 顯示程序資訊
    echo "📊 程序資訊:"
    ps -p "$PID" -o pid,ppid,etime,command | tail -n +2
    echo ""
    
    # 檢查最新的日誌檔案
    LATEST_LOG=$(ls -t "$SCRIPT_DIR/logs/qrcode_monitor_"*.log 2>/dev/null | head -n 1)
    if [ -n "$LATEST_LOG" ]; then
        echo "📝 最新日誌檔案:"
        echo "   $(basename "$LATEST_LOG")"
        echo ""
        echo "💡 提示: 使用 ./view_logs.sh 查看即時日誌"
    fi
    
    exit 0
else
    echo "⚠️  PID 檔案存在但程式未運行"
    echo "   PID: $PID (已停止)"
    echo ""
    echo "💡 提示: 使用 ./start_monitor_background.sh 啟動監控"
    
    # 清理無效的 PID 檔案
    rm -f "$PID_FILE"
    exit 1
fi

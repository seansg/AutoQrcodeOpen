#!/bin/bash
# 停止 LINE QR Code 監控腳本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/qrcode_monitor.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "❌ 找不到 PID 檔案,監控程式可能未在運行"
    exit 1
fi

PID=$(cat "$PID_FILE")

if ps -p "$PID" > /dev/null 2>&1; then
    echo "🛑 停止監控程式 (PID: $PID)..."
    
    # 嘗試停止子程序 (如果有的話,例如在自動重啟模式下)
    pkill -P "$PID" 2>/dev/null
    
    # 停止主程序
    kill "$PID"
    sleep 1
    
    # 確認是否已停止
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "⚠️  程式未正常停止,強制終止..."
        pkill -9 -P "$PID" 2>/dev/null
        kill -9 "$PID"
    fi
    
    rm -f "$PID_FILE"
    echo "✅ 監控已停止"
else
    echo "⚠️  程式 (PID: $PID) 已不在運行"
    rm -f "$PID_FILE"
fi

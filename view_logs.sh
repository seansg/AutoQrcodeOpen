#!/bin/bash
# 查看 LINE QR Code 監控日誌

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 找到最新的日誌檔案
LATEST_LOG=$(ls -t "$SCRIPT_DIR"/qrcode_monitor_*.log 2>/dev/null | head -n 1)

if [ -z "$LATEST_LOG" ]; then
    echo "❌ 找不到日誌檔案"
    exit 1
fi

echo "📝 查看日誌: $LATEST_LOG"
echo "按 Ctrl+C 退出"
echo ""

tail -f "$LATEST_LOG"

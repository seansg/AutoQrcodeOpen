#!/bin/bash
# 安裝開機自動啟動腳本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_NAME="com.autoline.qrcode.monitor.plist"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME"

# 創建 LaunchAgent plist 檔案
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.autoline.qrcode.monitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/start_monitor_background.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/autoline-monitor.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/autoline-monitor-error.log</string>
</dict>
</plist>
EOF

# 載入 LaunchAgent
launchctl unload "$PLIST_PATH" 2>/dev/null
launchctl load "$PLIST_PATH"

echo "✅ 開機自動啟動已設定"
echo "📝 設定檔位置: $PLIST_PATH"
echo ""
echo "💡 管理指令："
echo "   停用開機啟動: launchctl unload $PLIST_PATH"
echo "   啟用開機啟動: launchctl load $PLIST_PATH"
echo "   移除開機啟動: rm $PLIST_PATH"

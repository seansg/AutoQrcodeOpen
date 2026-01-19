# LINE QR Code 自動偵測監控

自動偵測 LINE 視窗中的 QR code 並開啟連結。

## 功能特色

- ✅ 自動偵測 LINE 視窗中的 QR code
- ✅ 使用 screencapture 命令,避免卡住問題 (v3 改進)
- ✅ 3 秒超時保護機制
- ✅ 支援多種影像前處理方法提高辨識率
- ✅ 自動開啟偵測到的連結
- ✅ 背景執行模式
- ✅ 完整的日誌記錄
- ✅ 靈活的日誌管理

## 使用方式

### 1. 直接執行 (前台模式)

```bash
python3 AutoLINE_scan_qrcode.command
```

### 2. 背景執行模式

#### 基本啟動 (保留所有舊日誌)
```bash
./start_monitor_background.sh
```

**注意:** 如果監控程式已在運行,會自動停止舊程序並重新啟動。

#### 清除所有舊日誌後啟動
```bash
./start_monitor_background.sh --clean-logs
```

#### 保留最近 5 個日誌,刪除其他
```bash
./start_monitor_background.sh --clean-logs --keep-logs 5
```

#### 查看說明
```bash
./start_monitor_background.sh --help
```

### 3. 管理背景程序

#### 查看即時日誌
```bash
./view_logs.sh
```

#### 停止監控
```bash
./stop_monitor.sh
```

## 命令列參數

### Python 腳本參數

```bash
python3 AutoLINE_scan_qrcode.command [選項]

選項:
  --clean-logs           啟動時清除所有舊日誌檔案
  --keep-logs N          保留最近 N 個日誌檔案 (預設: 0 = 保留全部)
  -h, --help             顯示說明訊息
```

### 範例

```bash
# 不清除日誌
python3 AutoLINE_scan_qrcode.command

# 清除所有舊日誌
python3 AutoLINE_scan_qrcode.command --clean-logs

# 只保留最近 3 個日誌
python3 AutoLINE_scan_qrcode.command --clean-logs --keep-logs 3
```

## 日誌檔案

- 日誌檔案格式: `qrcode_monitor_YYYYMMDD_HHMMSS.log`
- 位置: 與腳本相同目錄
- 包含時間戳記的完整執行記錄

### 日誌範例

```
2026-01-18 13:30:00 - INFO - ==================================================
2026-01-18 13:30:00 - INFO - 🚀 LINE QR Code 自動偵測監控已啟動 (v2 增強版)
2026-01-18 13:30:00 - INFO - 📝 日誌檔案: /path/to/qrcode_monitor_20260118_133000.log
2026-01-18 13:30:10 - INFO - ⏱️  運行中... (已檢查 20 次, 已處理 0 個 QR codes)
2026-01-18 13:30:15 - INFO - 🎯 偵測到新連結: https://example.com
```

## 系統需求

- Python 3.x
- macOS (使用 Quartz 框架)
- LINE 應用程式

### 必要套件

腳本會自動安裝以下套件:
- opencv-python
- pyzbar
- pyobjc-framework-Quartz
- numpy

### 系統依賴

```bash
brew install zbar
```

## 注意事項

⚠️ LINE 視窗需在前台才能更新聊天內容
⚠️ 每 0.5 秒檢查一次
⚠️ 已自動處理 Retina 螢幕解析度

## 檔案說明

- `AutoLINE_scan_qrcode.command` - 主程式
- `start_monitor_background.sh` - 背景啟動腳本
- `stop_monitor.sh` - 停止監控腳本
- `view_logs.sh` - 查看日誌腳本
- `qrcode_monitor_*.log` - 日誌檔案
- `qrcode_monitor.pid` - 程序 PID 檔案

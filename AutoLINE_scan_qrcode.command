#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import time
import webbrowser
import subprocess
import logging
import argparse
import glob
from datetime import datetime

# 修正 zbar 系統路徑
os.environ["DYLD_LIBRARY_PATH"] = "/opt/homebrew/lib:" + os.environ.get(
    "DYLD_LIBRARY_PATH", ""
)

# 解析命令列參數
parser = argparse.ArgumentParser(description='LINE QR Code 自動偵測監控')
parser.add_argument('--clean-logs', action='store_true', 
                    help='啟動時清除舊的日誌檔案')
parser.add_argument('--keep-logs', type=int, default=0,
                    help='保留最近 N 個日誌檔案 (預設: 0 = 保留全部)')
args = parser.parse_args()

# 設定 logging
script_dir = os.path.dirname(os.path.abspath(__file__))

# 清理舊日誌檔案 (如果指定)
if args.clean_logs:
    old_logs = glob.glob(os.path.join(script_dir, "qrcode_monitor_*.log"))
    if old_logs:
        old_logs.sort(reverse=True)  # 最新的在前
        
        if args.keep_logs > 0:
            # 保留最近 N 個
            logs_to_delete = old_logs[args.keep_logs:]
            print(f"🧹 保留最近 {args.keep_logs} 個日誌檔案,刪除 {len(logs_to_delete)} 個舊檔案...")
        else:
            # 刪除全部
            logs_to_delete = old_logs
            print(f"🧹 清除 {len(logs_to_delete)} 個舊日誌檔案...")
        
        for log_file in logs_to_delete:
            try:
                os.remove(log_file)
                print(f"   ✓ 已刪除: {os.path.basename(log_file)}")
            except Exception as e:
                print(f"   ✗ 無法刪除 {os.path.basename(log_file)}: {e}")
log_file = os.path.join(script_dir, f"qrcode_monitor_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")

# 建立 logger
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# 建立格式化器
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s', datefmt='%Y-%m-%d %H:%M:%S')

# 檔案處理器
file_handler = logging.FileHandler(log_file, encoding='utf-8')
file_handler.setLevel(logging.INFO)
file_handler.setFormatter(formatter)

# 控制台處理器
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setLevel(logging.INFO)
console_handler.setFormatter(formatter)

# 加入處理器
logger.addHandler(file_handler)
logger.addHandler(console_handler)

# 強制立即輸出
sys.stdout.reconfigure(line_buffering=True)
sys.stderr.reconfigure(line_buffering=True)

try:
    import Quartz
    import cv2
    import numpy as np
    from pyzbar.pyzbar import decode, ZBarSymbol
except ImportError as e:
    logger.info(f"📦 正在安裝必要套件... (錯誤: {e})")
    subprocess.check_call(
        [
            sys.executable,
            "-m",
            "pip",
            "install",
            "opencv-python",
            "pyzbar",
            "pyobjc-framework-Quartz",
            "numpy",
        ]
    )
    logger.info("✅ 安裝完成,重新載入模組...")
    try:
        import Quartz
        import cv2
        import numpy as np
        from pyzbar.pyzbar import decode, ZBarSymbol
        logger.info("✅ 模組載入成功!")
    except ImportError as e2:
        logger.error(f"❌ 模組載入失敗: {e2}")
        logger.error("💡 提示:pyzbar 需要系統安裝 zbar 函式庫")
        logger.error("   請執行: brew install zbar")
        sys.exit(1)


def get_line_window_image():
    """截取 LINE 視窗畫面 (使用 screencapture 避免卡住)"""
    try:
        options = Quartz.kCGWindowListOptionAll
        window_list = Quartz.CGWindowListCopyWindowInfo(options, Quartz.kCGNullWindowID)

        for window in window_list:
            owner = window.get("kCGWindowOwnerName", "")
            if "LINE" in owner:
                window_id = window.get("kCGWindowNumber", 0)
                bounds = window.get("kCGWindowBounds", {})
                if bounds.get("Width", 0) > 300:
                    # 使用 screencapture 命令替代 CGWindowListCreateImage
                    import tempfile
                    with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as tmp:
                        tmp_path = tmp.name
                    
                    try:
                        # 使用 screencapture 截取指定視窗,設定 3 秒超時
                        result = subprocess.run(
                            ['screencapture', '-l', str(window_id), '-o', '-x', tmp_path],
                            timeout=3,
                            capture_output=True,
                            text=True
                        )
                        
                        if result.returncode == 0 and os.path.exists(tmp_path):
                            # 讀取截圖
                            import cv2
                            frame = cv2.imread(tmp_path)
                            os.unlink(tmp_path)  # 刪除臨時檔案
                            
                            if frame is not None:
                                # 轉換為 CGImage 格式以保持相容性
                                # 實際上我們可以直接返回 cv2 影像
                                return frame
                        else:
                            logger.warning(f"screencapture 失敗: {result.stderr}")
                            if os.path.exists(tmp_path):
                                os.unlink(tmp_path)
                    except subprocess.TimeoutExpired:
                        logger.warning("screencapture 超時 (3秒)")
                        if os.path.exists(tmp_path):
                            os.unlink(tmp_path)
                    except Exception as e:
                        logger.error(f"截圖錯誤: {e}")
                        if os.path.exists(tmp_path):
                            os.unlink(tmp_path)
                    
                    return None
    except Exception as e:
        logger.error(f"取得視窗資訊錯誤: {e}")
    
    return None


def preprocess_image(frame):
    """影像前處理以提高 QR code 辨識率"""
    # 轉為灰階
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    
    # 嘗試多種前處理方法
    processed_frames = [
        gray,  # 原始灰階
        cv2.GaussianBlur(gray, (5, 5), 0),  # 高斯模糊
        cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                             cv2.THRESH_BINARY, 11, 2),  # 自適應二值化
    ]
    
    return processed_frames


def detect_qrcodes(frame, save_debug=False):
    """偵測 QR codes,支援多種影像處理方法"""
    all_urls = set()
    
    # 先嘗試原始彩色影像
    decoded_objs = decode(frame, symbols=[ZBarSymbol.QRCODE])
    if decoded_objs:
        logger.info(f"   ✅ 原始影像偵測到 {len(decoded_objs)} 個 QR codes")
        for obj in decoded_objs:
            all_urls.add(obj.data.decode("utf-8"))
    
    # 嘗試前處理後的影像
    processed_frames = preprocess_image(frame)
    for i, processed in enumerate(processed_frames):
        decoded_objs = decode(processed, symbols=[ZBarSymbol.QRCODE])
        if decoded_objs:
            logger.info(f"   ✅ 前處理方法 {i+1} 偵測到 {len(decoded_objs)} 個 QR codes")
            for obj in decoded_objs:
                all_urls.add(obj.data.decode("utf-8"))
    
    # 儲存調試影像
    if save_debug and len(all_urls) == 0:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        debug_dir = os.path.join(os.path.dirname(__file__), "debug_screenshots")
        os.makedirs(debug_dir, exist_ok=True)
        
        cv2.imwrite(os.path.join(debug_dir, f"original_{timestamp}.png"), frame)
        for i, processed in enumerate(processed_frames):
            cv2.imwrite(os.path.join(debug_dir, f"processed_{i}_{timestamp}.png"), processed)
        logger.info(f"   💾 已儲存調試影像至 {debug_dir}")
    
    return all_urls


def start_monitor():
    previous_urls = set()
    processed_urls = set()
    logger.info("\n" + "=" * 50)
    logger.info("🚀 LINE QR Code 自動偵測監控已啟動 (v2 增強版)")
    logger.info(f"� 日誌檔案: {log_file}")
    logger.info("�📍 已自動處理 Retina 螢幕解析度")
    logger.info("🔧 使用多種影像前處理方法提高辨識率")
    logger.info("⚡ 每 0.5 秒檢查一次,快速反應")
    logger.info("⏱️  截圖超時設定: 3 秒")
    logger.info("⚠️  注意:LINE 視窗需在前台才能更新聊天內容")
    logger.info("=" * 50 + "\n")

    check_count = 0
    last_status_time = time.time()
    save_debug_next = True  # 第一次儲存調試影像
    consecutive_failures = 0  # 連續失敗次數
    
    try:
        while True:
            check_count += 1
            current_time = time.time()
            
            # 每 10 秒輸出一次狀態
            if current_time - last_status_time >= 10:
                logger.info(f"⏱️  運行中... (已檢查 {check_count} 次, 已處理 {len(processed_urls)} 個 QR codes)")
                if consecutive_failures > 0:
                    logger.warning(f"⚠️  連續 {consecutive_failures} 次無法截取視窗")
                last_status_time = current_time
            
            cg_image = get_line_window_image()
            if cg_image is not None:
                consecutive_failures = 0  # 重置失敗計數
                # screencapture 直接返回 cv2 影像,不需要轉換
                frame = cg_image

                # 使用增強的 QR code 偵測
                current_urls = detect_qrcodes(frame, save_debug=save_debug_next)
                save_debug_next = False  # 只儲存第一次的調試影像

                # 找出新出現且從未處理過的 QR codes
                new_urls = current_urls - processed_urls
                for url in new_urls:
                    logger.info(f"🎯 偵測到新連結: {url}")
                    os.system('say "Detected"')
                    webbrowser.open(url)
                    processed_urls.add(url)

                previous_urls = current_urls
            else:
                consecutive_failures += 1
                # 只在第一次失敗時記錄,避免日誌過多
                if consecutive_failures == 1:
                    logger.debug("未找到 LINE 視窗或截圖失敗")

            time.sleep(0.5)
    except KeyboardInterrupt:
        logger.info("\n🛑 監控已停止。")
        logger.info(f"📊 總共處理了 {len(processed_urls)} 個 QR codes")
    except Exception as e:
        logger.error(f"❌ 錯誤: {e}")
        import traceback
        logger.error(traceback.format_exc())
        time.sleep(5)


if __name__ == "__main__":
    start_monitor()

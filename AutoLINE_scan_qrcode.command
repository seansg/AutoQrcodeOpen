#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import time
import webbrowser
import subprocess
from datetime import datetime

# 修正 zbar 系統路徑
os.environ["DYLD_LIBRARY_PATH"] = "/opt/homebrew/lib:" + os.environ.get(
    "DYLD_LIBRARY_PATH", ""
)

try:
    import Quartz
    import cv2
    import numpy as np
    from pyzbar.pyzbar import decode, ZBarSymbol
except ImportError as e:
    print(f"📦 正在安裝必要套件... (錯誤: {e})")
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
    print("✅ 安裝完成,重新載入模組...")
    try:
        import Quartz
        import cv2
        import numpy as np
        from pyzbar.pyzbar import decode, ZBarSymbol
        print("✅ 模組載入成功!")
    except ImportError as e2:
        print(f"❌ 模組載入失敗: {e2}")
        print("💡 提示:pyzbar 需要系統安裝 zbar 函式庫")
        print("   請執行: brew install zbar")
        sys.exit(1)


def get_line_window_image():
    """截取 LINE 視窗畫面"""
    options = Quartz.kCGWindowListOptionAll
    window_list = Quartz.CGWindowListCopyWindowInfo(options, Quartz.kCGNullWindowID)

    for window in window_list:
        owner = window.get("kCGWindowOwnerName", "")
        if "LINE" in owner:
            window_id = window.get("kCGWindowNumber", 0)
            bounds = window.get("kCGWindowBounds", {})
            if bounds.get("Width", 0) > 300:
                cg_image = Quartz.CGWindowListCreateImage(
                    Quartz.CGRectNull,
                    Quartz.kCGWindowListOptionIncludingWindow,
                    window_id,
                    Quartz.kCGWindowImageDefault,
                )
                return cg_image
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
        print(f"   ✅ 原始影像偵測到 {len(decoded_objs)} 個 QR codes")
        for obj in decoded_objs:
            all_urls.add(obj.data.decode("utf-8"))
    
    # 嘗試前處理後的影像
    processed_frames = preprocess_image(frame)
    for i, processed in enumerate(processed_frames):
        decoded_objs = decode(processed, symbols=[ZBarSymbol.QRCODE])
        if decoded_objs:
            print(f"   ✅ 前處理方法 {i+1} 偵測到 {len(decoded_objs)} 個 QR codes")
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
        print(f"   💾 已儲存調試影像至 {debug_dir}")
    
    return all_urls


def start_monitor():
    previous_urls = set()
    processed_urls = set()
    print("\n" + "=" * 50)
    print("🚀 LINE QR Code 自動偵測監控已啟動 (v2 增強版)")
    print("📍 已自動處理 Retina 螢幕解析度")
    print("🔧 使用多種影像前處理方法提高辨識率")
    print("⚡ 每 0.5 秒檢查一次,快速反應")
    print("⚠️  注意:LINE 視窗需在前台才能更新聊天內容")
    print("=" * 50 + "\n")

    check_count = 0
    last_status_time = time.time()
    save_debug_next = True  # 第一次儲存調試影像
    
    try:
        while True:
            check_count += 1
            current_time = time.time()
            
            # 每 10 秒輸出一次狀態
            if current_time - last_status_time >= 10:
                print(f"⏱️  運行中... (已檢查 {check_count} 次, 已處理 {len(processed_urls)} 個 QR codes)")
                last_status_time = current_time
            
            cg_image = get_line_window_image()
            if cg_image:
                current_urls = set()

                width = Quartz.CGImageGetWidth(cg_image)
                height = Quartz.CGImageGetHeight(cg_image)
                bpr = Quartz.CGImageGetBytesPerRow(cg_image)

                prov = Quartz.CGImageGetDataProvider(cg_image)
                data = Quartz.CGDataProviderCopyData(prov)

                frame = np.frombuffer(data, dtype=np.uint8)
                frame = frame.reshape((height, bpr // 4, 4))
                frame = frame[:, :width, :]
                frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2BGR)

                # 使用增強的 QR code 偵測
                current_urls = detect_qrcodes(frame, save_debug=save_debug_next)
                save_debug_next = False  # 只儲存第一次的調試影像

                # 找出新出現且從未處理過的 QR codes
                new_urls = current_urls - processed_urls
                for url in new_urls:
                    print(f"🎯 偵測到新連結: {url}")
                    os.system('say "Detected"')
                    webbrowser.open(url)
                    processed_urls.add(url)

                previous_urls = current_urls

            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\n🛑 監控已停止。")
        print(f"📊 總共處理了 {len(processed_urls)} 個 QR codes")
    except Exception as e:
        print(f"❌ 錯誤: {e}")
        import traceback
        traceback.print_exc()
        time.sleep(5)


if __name__ == "__main__":
    start_monitor()

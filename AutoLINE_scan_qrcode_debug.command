#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import time
import webbrowser
import subprocess

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
    # 使用 kCGWindowListOptionAll 以便即使視窗被覆蓋也能截圖
    options = Quartz.kCGWindowListOptionAll
    window_list = Quartz.CGWindowListCopyWindowInfo(options, Quartz.kCGNullWindowID)

    line_windows = []
    for window in window_list:
        owner = window.get("kCGWindowOwnerName", "")
        if "LINE" in owner:
            line_windows.append({
                "owner": owner,
                "id": window.get("kCGWindowNumber", 0),
                "bounds": window.get("kCGWindowBounds", {}),
                "layer": window.get("kCGWindowLayer", 0)
            })
    
    # 調試輸出
    if line_windows:
        print(f"🔍 找到 {len(line_windows)} 個 LINE 視窗")
        for w in line_windows:
            print(f"   - {w['owner']}: {w['bounds'].get('Width', 0)}x{w['bounds'].get('Height', 0)} (Layer: {w['layer']})")
    
    for window in line_windows:
        bounds = window["bounds"]
        if bounds.get("Width", 0) > 300:
            window_id = window["id"]
            cg_image = Quartz.CGWindowListCreateImage(
                Quartz.CGRectNull,
                Quartz.kCGWindowListOptionIncludingWindow,
                window_id,
                Quartz.kCGWindowImageDefault,
            )
            if cg_image:
                print(f"✅ 成功截取視窗: {window['owner']}")
                return cg_image
    
    return None


def start_monitor():
    previous_urls = set()  # 上一次檢查時畫面中的 QR codes
    processed_urls = set()  # 所有已經處理過的 QR codes(歷史記錄)
    print("\n" + "=" * 50)
    print("🚀 LINE QR Code 自動偵測監控已啟動 (調試模式)")
    print("📍 已自動處理 Retina 螢幕解析度")
    print("⚡ 每 0.5 秒檢查一次,快速反應")
    print("⚠️  注意:LINE 視窗需在前台才能更新聊天內容")
    print("=" * 50 + "\n")

    check_count = 0
    last_status_time = time.time()
    
    try:
        while True:
            check_count += 1
            current_time = time.time()
            
            # 每 10 秒輸出一次狀態
            if current_time - last_status_time >= 10:
                print(f"⏱️  運行中... (已檢查 {check_count} 次)")
                last_status_time = current_time
            
            cg_image = get_line_window_image()
            if cg_image:
                current_urls = set()  # 當前畫面中的 QR codes

                width = Quartz.CGImageGetWidth(cg_image)
                height = Quartz.CGImageGetHeight(cg_image)
                bpr = Quartz.CGImageGetBytesPerRow(cg_image)  # 取得每一行的位元組數

                print(f"📸 截圖尺寸: {width}x{height}, BPR: {bpr}")

                prov = Quartz.CGImageGetDataProvider(cg_image)
                data = Quartz.CGDataProviderCopyData(prov)

                # 修正後的數據處理邏輯:根據 bpr (Bytes Per Row) 讀取
                frame = np.frombuffer(data, dtype=np.uint8)
                # 重新排列影像矩陣
                frame = frame.reshape((height, bpr // 4, 4))
                # 裁切掉邊緣可能的多餘數據
                frame = frame[:, :width, :]
                # 轉為 OpenCV 格式 (BGRA -> BGR)
                frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2BGR)

                decoded_objs = decode(frame, symbols=[ZBarSymbol.QRCODE])
                print(f"🔎 偵測到 {len(decoded_objs)} 個 QR codes")
                
                for obj in decoded_objs:
                    url = obj.data.decode("utf-8")
                    current_urls.add(url)
                    print(f"   📋 QR Code: {url[:50]}...")

                # 找出新出現且從未處理過的 QR codes
                new_urls = current_urls - processed_urls
                for url in new_urls:
                    print(f"🎯 偵測到新連結: {url}")
                    os.system('say "Detected"')
                    webbrowser.open(url)
                    processed_urls.add(url)  # 加入歷史記錄

                # 只在成功截取到視窗時才更新狀態
                previous_urls = current_urls
            else:
                print("⚠️  無法找到 LINE 視窗或視窗太小")

            time.sleep(0.5)  # 每 0.5 秒檢查一次,提高反應速度
    except KeyboardInterrupt:
        print("\n🛑 監控已停止。")
    except Exception as e:
        print(f"❌ 錯誤: {e}")
        import traceback
        traceback.print_exc()
        time.sleep(5)


if __name__ == "__main__":
    start_monitor()

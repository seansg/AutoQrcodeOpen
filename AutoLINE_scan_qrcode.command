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
    from pyzbar.pyzbar import decode
except ImportError:
    print("📦 正在安裝必要套件...")
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
    print("✅ 安裝完成，請重新執行。")
    sys.exit()


def get_line_window_image():
    # 使用 kCGWindowListOptionAll 以便即使視窗被覆蓋也能截圖
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


def start_monitor():
    previous_urls = set()  # 上一次檢查時畫面中的 QR codes
    processed_urls = set()  # 所有已經處理過的 QR codes（歷史記錄）
    print("\n" + "=" * 50)
    print("🚀 LINE QR Code 自動偵測監控已啟動")
    print("📍 已自動處理 Retina 螢幕解析度")
    print("⚡ 每 0.5 秒檢查一次，快速反應")
    print("⚠️  注意：LINE 視窗需在前台才能更新聊天內容")
    print("=" * 50 + "\n")

    try:
        while True:
            cg_image = get_line_window_image()
            if cg_image:
                current_urls = set()  # 當前畫面中的 QR codes

                width = Quartz.CGImageGetWidth(cg_image)
                height = Quartz.CGImageGetHeight(cg_image)
                bpr = Quartz.CGImageGetBytesPerRow(cg_image)  # 取得每一行的位元組數

                prov = Quartz.CGImageGetDataProvider(cg_image)
                data = Quartz.CGDataProviderCopyData(prov)

                # 修正後的數據處理邏輯：根據 bpr (Bytes Per Row) 讀取
                frame = np.frombuffer(data, dtype=np.uint8)
                # 重新排列影像矩陣
                frame = frame.reshape((height, bpr // 4, 4))
                # 裁切掉邊緣可能的多餘數據
                frame = frame[:, :width, :]
                # 轉為 OpenCV 格式 (BGRA -> BGR)
                frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2BGR)

                decoded_objs = decode(frame)
                for obj in decoded_objs:
                    url = obj.data.decode("utf-8")
                    current_urls.add(url)

                # 找出新出現且從未處理過的 QR codes
                new_urls = current_urls - processed_urls
                for url in new_urls:
                    print(f"🎯 偵測到新連結: {url}")
                    os.system('say "Detected"')
                    webbrowser.open(url)
                    processed_urls.add(url)  # 加入歷史記錄

                # 只在成功截取到視窗時才更新狀態
                previous_urls = current_urls

            time.sleep(0.5)  # 每 0.5 秒檢查一次，提高反應速度
    except KeyboardInterrupt:
        print("\n🛑 監控已停止。")
    except Exception as e:
        print(f"❌ 錯誤: {e}")
        time.sleep(5)


if __name__ == "__main__":
    start_monitor()

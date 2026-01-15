#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import subprocess
import time
import webbrowser

# 修正 zbar 系統路徑
os.environ["DYLD_LIBRARY_PATH"] = "/opt/homebrew/lib:" + os.environ.get(
    "DYLD_LIBRARY_PATH", ""
)

try:
    import cv2
    import numpy as np
    from pyzbar.pyzbar import decode
    import Quartz
except ImportError:
    print("📦 正在安裝必要的辨識套件...")
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


def get_line_window():
    window_list = Quartz.CGWindowListCopyWindowInfo(
        Quartz.kCGWindowListOptionOnScreenOnly
        | Quartz.kCGWindowListExcludeDesktopElements,
        Quartz.kCGNullWindowID,
    )
    for window in window_list:
        owner = window.get("kCGWindowOwnerName", "")
        if "LINE" in owner:
            bounds = window.get("kCGWindowBounds", {})
            # 寬度大於 300 判定為主聊天視窗
            if bounds.get("Width", 0) > 300:
                return (
                    int(bounds["X"]),
                    int(bounds["Y"]),
                    int(bounds["Width"]),
                    int(bounds["Height"]),
                )
    return None


def start_monitor():
    last_url = ""
    # 截圖暫存檔路徑
    temp_img = "/tmp/line_qr_scan.png"

    print("\n" + "=" * 40)
    print("🚀 LINE QR Code 自動監控 (系統原生截圖版)")
    print("📍 狀態：運行中...")
    print("🛑 停止：按 Ctrl+C")
    print("=" * 40 + "\n")

    try:
        while True:
            rect = get_line_window()
            if rect:
                # 使用 macOS 內建指令截圖: screencapture -R x,y,w,h
                crop_param = f"{rect[0]},{rect[1]},{rect[2]},{rect[3]}"
                subprocess.run(["screencapture", "-R", crop_param, "-x", temp_img])

                if os.path.exists(temp_img):
                    frame = cv2.imread(temp_img)
                    if frame is not None:
                        decoded_objs = decode(frame)
                        for obj in decoded_objs:
                            url = obj.data.decode("utf-8")
                            if url != last_url:
                                print(f"🎯 偵測到: {url}")
                                os.system('say "Got it"')
                                webbrowser.open(url)
                                last_url = url
            time.sleep(2)
    except KeyboardInterrupt:
        print("\n🛑 已停止執行。")


if __name__ == "__main__":
    start_monitor()

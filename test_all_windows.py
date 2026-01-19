#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import subprocess
import tempfile

# 修正 zbar 系統路徑
os.environ["DYLD_LIBRARY_PATH"] = "/opt/homebrew/lib:" + os.environ.get(
    "DYLD_LIBRARY_PATH", ""
)

import Quartz
import cv2
from pyzbar.pyzbar import decode, ZBarSymbol

def get_all_line_windows():
    """取得所有 LINE 視窗"""
    options = Quartz.kCGWindowListOptionAll
    window_list = Quartz.CGWindowListCopyWindowInfo(options, Quartz.kCGNullWindowID)

    line_windows = []
    for window in window_list:
        owner = window.get("kCGWindowOwnerName", "")
        if "LINE" in owner:
            bounds = window.get("kCGWindowBounds", {})
            width = bounds.get("Width", 0)
            height = bounds.get("Height", 0)
            window_id = window.get("kCGWindowNumber", 0)
            layer = window.get("kCGWindowLayer", 0)
            
            # 只選擇夠大的視窗
            if width > 200 and height > 200:
                line_windows.append({
                    "owner": owner,
                    "id": window_id,
                    "width": width,
                    "height": height,
                    "layer": layer
                })
    
    return line_windows

def capture_window(window_id):
    """截取指定視窗"""
    with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as tmp:
        tmp_path = tmp.name
    
    try:
        result = subprocess.run(
            ['screencapture', '-l', str(window_id), '-o', '-x', tmp_path],
            capture_output=True,
            timeout=3
        )
        
        if result.returncode == 0 and os.path.exists(tmp_path):
            frame = cv2.imread(tmp_path)
            os.unlink(tmp_path)
            return frame
        else:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
            return None
    except Exception as e:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        return None

def detect_qr_codes(frame):
    """偵測 QR codes"""
    methods = []
    
    # 原始影像
    objs = decode(frame, symbols=[ZBarSymbol.QRCODE])
    if objs:
        methods.append(("原始", objs))
    
    # 灰階
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    objs = decode(gray, symbols=[ZBarSymbol.QRCODE])
    if objs:
        methods.append(("灰階", objs))
    
    # 增強對比
    enhanced = cv2.equalizeHist(gray)
    objs = decode(enhanced, symbols=[ZBarSymbol.QRCODE])
    if objs:
        methods.append(("增強對比", objs))
    
    # 二值化
    _, binary = cv2.threshold(gray, 127, 255, cv2.THRESH_BINARY)
    objs = decode(binary, symbols=[ZBarSymbol.QRCODE])
    if objs:
        methods.append(("二值化", objs))
    
    return methods

print("=" * 70)
print("掃描所有 LINE 視窗尋找 QR Code")
print("=" * 70)

windows = get_all_line_windows()
print(f"\n🔍 找到 {len(windows)} 個 LINE 視窗:")

found_qr = False
for i, win in enumerate(windows, 1):
    print(f"\n[{i}] {win['owner']}")
    print(f"    尺寸: {win['width']}x{win['height']}, ID: {win['id']}, Layer: {win['layer']}")
    
    # 截取視窗
    print(f"    📸 截取中...")
    frame = capture_window(win['id'])
    
    if frame is not None:
        print(f"    ✅ 截取成功: {frame.shape[1]}x{frame.shape[0]}")
        
        # 儲存截圖
        filename = f"window_{i}_{win['id']}.png"
        cv2.imwrite(filename, frame)
        print(f"    💾 已儲存: {filename}")
        
        # 偵測 QR code
        results = detect_qr_codes(frame)
        if results:
            found_qr = True
            print(f"    🎯 找到 QR Code!")
            for method, objs in results:
                print(f"       方法: {method}")
                for obj in objs:
                    url = obj.data.decode('utf-8')
                    print(f"       📋 {url}")
        else:
            print(f"    ⚠️  未偵測到 QR code")
    else:
        print(f"    ❌ 截取失敗")

print("\n" + "=" * 70)
if found_qr:
    print("✅ 成功找到 QR Code!")
else:
    print("❌ 所有視窗都沒有偵測到 QR Code")
    print("💡 請確認:")
    print("   1. QR code 是否在 LINE 視窗中可見?")
    print("   2. QR code 是否夠大且清晰?")
    print("   3. 請檢查儲存的截圖檔案")
print("=" * 70)

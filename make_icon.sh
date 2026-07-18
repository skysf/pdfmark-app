#!/bin/bash
# 生成应用图标 Resources/AppIcon.icns（仅需在修改图标后运行一次）
set -e
cd "$(dirname "$0")"

swift tools/IconGenerator.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
cp build/AppIcon.iconset/icon_512x512@2x.png build/AppIcon_preview.png

echo "图标已生成: Resources/AppIcon.icns（预览: build/AppIcon_preview.png）"

#!/bin/bash
# 编译并把可执行文件打包成标准的「不跑打印店.app」（ad-hoc 签名，本机可直接运行）
set -e
cd "$(dirname "$0")"

swift build -c release

APP="不跑打印店.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/PDFMark "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

codesign --force --sign - "$APP"

echo "完成：$(pwd)/$APP"

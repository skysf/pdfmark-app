#!/bin/bash
# 制作安装镜像 不跑打印店.dmg（内含 app 和 Applications 快捷方式，拖入即装）
set -e
cd "$(dirname "$0")"

./build_app.sh

DMG="不跑打印店.dmg"
STAGING="build/dmg_staging"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "不跑打印店.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "不跑打印店" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"

echo "完成：$(pwd)/$DMG"

#!/bin/bash
# 웹앱 파일을 Capacitor www 폴더로 복사
# 사용법: app 폴더에서  bash sync-www.sh
set -e
cd "$(dirname "$0")"

mkdir -p www
cp ../index.html          www/index.html
cp ../favicon.ico         www/favicon.ico
cp ../favicon-192.png     www/favicon-192.png
cp ../apple-touch-icon.png www/apple-touch-icon.png
cp ../mascot.png          www/mascot.png
mkdir -p www/icons && cp ../icons/*.png www/icons/

# 앱 아이콘 자동 반영 (Xcode 에셋 카탈로그) — iOS 프로젝트가 있을 때만
ICON_DST="ios/App/App/Assets.xcassets/AppIcon.appiconset"
if [ -d "$ICON_DST" ] && [ -f assets/AppIcon-512@2x.png ]; then
  cp assets/AppIcon-512@2x.png "$ICON_DST/AppIcon-512@2x.png"
  echo "✅ 앱 아이콘 반영 완료"
fi

echo "✅ www 폴더 동기화 완료"

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

echo "✅ www 폴더 동기화 완료"

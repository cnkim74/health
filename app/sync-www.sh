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

# 권한 사용 문구 자동 추가 (없을 때만) — 없으면 앱이 크래시함
PLIST="ios/App/App/Info.plist"
if [ -f "$PLIST" ]; then
  add_perm() {  # $1=키, $2=설명
    if ! /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST" >/dev/null 2>&1; then
      /usr/libexec/PlistBuddy -c "Add :$1 string '$2'" "$PLIST" && echo "  + $1"
    fi
  }
  add_perm NSCameraUsageDescription "식사 사진을 촬영해 칼로리를 분석하기 위해 카메라를 사용합니다."
  add_perm NSPhotoLibraryUsageDescription "식사 사진을 선택해 칼로리를 분석하기 위해 사진에 접근합니다."
  add_perm NSLocationWhenInUseUsageDescription "달리기·걷기 경로와 거리를 기록하기 위해 위치를 사용합니다."
  add_perm NSHealthShareUsageDescription "걸음수, 칼로리, 거리, 혈당 데이터를 읽어 대시보드에 자동으로 기록합니다."
  add_perm NSBluetoothAlwaysUsageDescription "혈당기에서 측정값을 블루투스로 가져오기 위해 사용합니다."
  add_perm NSBluetoothPeripheralUsageDescription "혈당기에서 측정값을 블루투스로 가져오기 위해 사용합니다."
  echo "✅ 권한 문구 확인 완료"
fi

echo "✅ www 폴더 동기화 완료"

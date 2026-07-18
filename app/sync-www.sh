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

# 사용자가 assets/icons 에 넣은 이미지도 웹(../icons)·앱(www/icons) 폴더로 반영
if [ -d assets/icons ]; then
  cp assets/icons/*.png www/icons/ 2>/dev/null || true
  cp assets/icons/*.png ../icons/  2>/dev/null || true
  echo "✅ assets/icons 이미지 반영 완료"
fi

# ── 앱 아이콘: assets/icons/chart_logo.png → 1024 정사각(불투명) 생성 ──
LOGO_SRC="assets/icons/chart_logo.png"
if [ -f "$LOGO_SRC" ] && command -v sips >/dev/null 2>&1; then
  TMP="$(mktemp -d)"
  cp "$LOGO_SRC" "$TMP/icon.png"
  # 투명 배경 → 흰색 평탄화(JPEG 왕복) 후 1024 정사각 리사이즈 + 흰색 패딩
  sips -s format jpeg "$TMP/icon.png" --out "$TMP/icon.jpg" >/dev/null 2>&1
  sips -Z 1024 "$TMP/icon.jpg" >/dev/null 2>&1
  sips -p 1024 1024 --padColor FFFFFF "$TMP/icon.jpg" >/dev/null 2>&1
  sips -s format png "$TMP/icon.jpg" --out assets/AppIcon-512@2x.png >/dev/null 2>&1
  rm -rf "$TMP"
  echo "✅ 앱 아이콘 생성 (chart_logo.png → 1024)"
fi

# 생성된 아이콘을 iOS·애플워치 등 프로젝트 내 모든 AppIcon 에셋에 자동 반영
if [ -f assets/AppIcon-512@2x.png ] && [ -d ios ]; then
  find ios -type d -name "AppIcon.appiconset" 2>/dev/null | while read -r D; do
    for PNG in "$D"/*.png; do
      [ -e "$PNG" ] && cp assets/AppIcon-512@2x.png "$PNG"
    done
    echo "  + 앱 아이콘 반영: $D"
  done
  echo "✅ 앱 아이콘(폰·워치) 반영 완료"
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

  # 구글 로그인 딥링크용 URL 스킴 (carenote://login-callback) — 없을 때만 추가
  if ! /usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes" "$PLIST" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLName string carenote" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string carenote" "$PLIST"
    echo "  + CFBundleURLTypes (carenote)"
  fi
  echo "✅ URL 스킴 확인 완료"
fi

echo "✅ www 폴더 동기화 완료"

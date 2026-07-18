# ⌚ CARENOTE Apple Watch 앱 (v1) 설정 가이드

워치에서 **물 마시기·오늘 복약 완료**를 원터치로 기록합니다.
워치가 폰에 신호를 보내면(WatchConnectivity), 폰이 Supabase에 저장 → 대시보드에 반영됩니다.
(폰이 꺼져 있어도 큐에 쌓였다가 다음 실행 때 전달)

---

## 구성
```
[Apple Watch 앱(SwiftUI)]  → WatchConnectivity →  [iPhone CARENOTE(Capacitor)]  → Supabase
   app/watch/*.swift                                 plugins/watch-bridge (WatchBridge 플러그인)
```

## 0. 코드 받기 & 플러그인 설치 (Mac)
```bash
cd ~/Documents/health && git pull origin main
cd app
npm install                 # carenote-watch-bridge 플러그인 설치
bash sync-www.sh
npx cap sync ios            # WatchBridge 플러그인 → iOS 프로젝트 반영
npx cap open ios
```

## 1. Xcode에서 watchOS 타깃 추가 (최초 1회)
1. Xcode 상단 메뉴 **File → New → Target…**
2. **watchOS** 탭 → **App** 선택 → Next
3. 설정:
   - Product Name: **CarenoteWatch**
   - Interface: **SwiftUI**, Language: **Swift**
   - (있다면) **Companion iOS App: App** (메인 CARENOTE 앱) 선택
4. Finish → "Activate scheme?" 뜨면 **Activate**

## 2. 워치 소스 교체
1. 방금 생성된 `CarenoteWatch` 그룹의 **자동 생성 파일**(예: `CarenoteWatchApp.swift`, `ContentView.swift`)을 열어,
   `app/watch/` 폴더의 아래 3개 내용으로 **교체(또는 드래그해서 추가, target = CarenoteWatch 체크)**:
   - `CarenoteWatchApp.swift`
   - `ContentView.swift`
   - `WatchConn.swift`
2. 세 파일 모두 **Target Membership = CarenoteWatch** 인지 확인 (오른쪽 File Inspector)

> WatchConnectivity 는 별도 Capability 가 필요 없습니다. (자동 동작)

## 3. 번들 ID 확인
- iOS 앱: 예 `com.carenote.app`
- 워치 앱: 보통 `com.carenote.app.watchkitapp` (Xcode가 자동 설정) — 같은 접두어면 OK
- 두 타깃 모두 **같은 Team**(서명) 인지 확인

## 4. 빌드 & 실행
1. Xcode 상단 스킴을 **CarenoteWatch**로 선택 → 페어링된 **Apple Watch**(또는 시뮬레이터) 선택
2. ▶ Run → 워치에 CARENOTE 앱 설치
3. 아이폰 CARENOTE도 한 번 실행해 두기 (수신 측)

## 5. 사용
- 워치 CARENOTE 앱 → **오늘 복약 완료 / 물 +250 / 물 +500** 탭
- 폰 대시보드의 물·복약에 반영됨 (즉시 또는 폰 다음 실행 시)

---

## 참고 / 확장
- **혈당·혈압 등 숫자 입력**은 v2에서 디지털 크라운 + 숫자 피커로 확장 가능
- 폰→워치로 "오늘 복약 진행률" 표시도 `WatchBridge.updateContext` 로 확장 가능
- 문제 시 확인: iOS 앱이 실행/백그라운드 상태인지, 두 기기가 페어링·같은 Apple ID·같은 Team 인지

## 문의
막히는 화면(타깃 추가·서명 등) 캡처해서 물어보면 단계별로 도와드립니다.

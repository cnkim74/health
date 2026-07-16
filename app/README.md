# 📱 CARENOTE iOS 앱 만들기 가이드

웹앱(index.html)을 Capacitor로 감싸 iOS 네이티브 앱으로 만드는 프로젝트입니다.

---

## 0. 준비물

| 항목 | 비고 |
|---|---|
| Mac (iMac) | macOS 13 이상 권장 |
| iPhone + 케이블 | 실기기 테스트용 |
| Apple ID | 무료 — 본인 기기 테스트까지 가능 |
| Apple Developer Program | **$99/년** — App Store 제출 시에만 필요 |

## 1. Xcode 설치 (최초 1회, 30분~1시간)

1. Mac의 **App Store** 앱 → "Xcode" 검색 → 설치 (약 12GB, 오래 걸림)
2. 설치 후 Xcode 한 번 실행 → 라이선스 동의 → 추가 구성요소 설치

## 2. 개발 도구 설치 (최초 1회)

Mac 터미널에 아래 전체를 붙여넣고 Enter:

```bash
# Homebrew (없으면 설치)
which brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Node.js + CocoaPods
brew install node cocoapods
```

## 3. 프로젝트 받기 & iOS 프로젝트 생성

```bash
cd ~/Documents
git clone https://github.com/cnkim74/health.git
cd health/app

npm install          # Capacitor 설치
bash sync-www.sh     # 웹앱 파일을 www/로 복사
npx cap add ios      # iOS Xcode 프로젝트 생성 (최초 1회)
npx cap sync ios     # 웹 파일 → iOS 프로젝트 반영
npx cap open ios     # Xcode 열기
```

## 4. 내 아이폰에서 실행해 보기 (무료)

1. iPhone을 케이블로 Mac에 연결 (신뢰 팝업 → 신뢰)
2. Xcode 상단 기기 선택에서 **본인 iPhone** 선택
3. 왼쪽 파일 트리에서 **App** 클릭 → **Signing & Capabilities** 탭
   - **Team**: 본인 Apple ID 추가 (Xcode → Settings → Accounts에서 로그인)
   - **Automatically manage signing** 체크
4. ▶ (Run) 버튼 클릭 → 아이폰에 앱 설치됨
5. 처음 실행 시 iPhone에서: 설정 → 일반 → VPN 및 기기 관리 → 개발자 앱 신뢰

> 무료 Apple ID 서명은 7일마다 만료 → 다시 Run 하면 갱신됩니다.
> App Store 제출용은 Developer Program($99/년) 가입 후 가능.

## 5. 웹앱 업데이트를 앱에 반영하기

index.html이 바뀔 때마다:

```bash
cd ~/Documents/health && git pull
cd app
bash sync-www.sh && npx cap sync ios && npx cap open ios
```

Xcode에서 다시 Run.

---

## 다음 단계 (로드맵)

- [ ] **Phase 1**: 본인 아이폰에서 실행 확인 ← 지금 여기
- [ ] **Phase 2**: HealthKit 연동 — 걸음수·기초대사량 자동 동기화 (단축어 불필요!)
- [ ] **Phase 3**: 네이티브 복약 알림 (Local Notifications)
- [ ] **Phase 4**: 앱 아이콘·스플래시 스크린 제작
- [ ] **Phase 5**: 개인정보 처리방침 페이지 + App Store 심사 제출

## 알아둘 것

- **이메일 로그인**은 앱 안에서 바로 작동합니다.
- **Google 로그인**은 앱 내에서 추가 설정(딥링크)이 필요 — Phase 2에서 처리 예정. 그 전까지는 이메일 로그인 사용.
- 앱은 인터넷 연결이 필요합니다 (Supabase 클라우드 동기화).

## 문의

김찬년 · cnkim@kakao.com

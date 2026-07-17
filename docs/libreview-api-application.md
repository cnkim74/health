# LibreView(Abbott) 정식 API 연동 신청 준비

CARENOTE가 리브레 혈당을 **공식적으로·자동으로** 연동하기 위한 Abbott/LibreView
파트너 API 신청 가이드입니다. (닥터다이어리 등도 이 방식을 사용)

> 왜 공식 API인가: 소비자 웹 로그인 방식은 **2FA(2단계 인증)로 의도적으로 차단**되어
> 무인 자동화가 불가하고 약관 위반 소지가 있습니다. 공식 파트너 API는 서버용 자격증명을
> 발급받아 **2FA 없이·안정적으로·합법적으로** 환자 데이터를 받습니다.

---

## 1. 신청 경로

정식 창구는 상황에 따라 다르므로, 아래를 병행해 문의하는 것을 권장합니다.

1. **Abbott Korea 당뇨사업부(Abbott Diabetes Care Korea)**
   - 리브레(FreeStyle Libre) 국내 사업 담당. 파트너/기업 연동 문의.
   - 대표 문의처(고객센터)를 통해 "LibreView API / 서드파티 앱 연동 파트너십" 담당 연결 요청.
2. **LibreView 지원(Support)**
   - libreview.com 로그인 후 **도움말/지원(Support)** → API/Integration 문의.
   - HCP(전문가) 계정 지원 채널이 별도일 수 있음.
3. **Abbott 글로벌 개발자/파트너 문의**
   - Abbott의 디지털헬스/파트너십 부서. 영문 문의 병행 시 유리.

> ⚠️ 정확한 포털 주소·담당 이메일은 시점에 따라 바뀌므로, 위 채널로 **현재 유효한 신청
> 경로를 먼저 확인**하세요. 아래 이메일 초안을 그대로 활용해 문의를 시작하면 됩니다.

---

## 2. 미리 준비할 자료 (체크리스트)

| 항목 | 내용 |
|---|---|
| 사업자 정보 | 사업자등록증(또는 개인개발자 정보), 회사/서비스명(CARENOTE) |
| 서비스 소개 | CARENOTE 개요·대상(당뇨/만성질환 관리, 40~50대), 스크린샷 |
| 연동 목적 | 리브레 CGM 혈당을 사용자 대시보드/리포트에 표시 (읽기 전용) |
| 데이터 범위 | 혈당(glucose history) 읽기. 필요한 최소 범위만 요청 |
| 사용자 동의 | 각 사용자가 본인 데이터 공유에 동의하는 구조(연결코드/OAuth) |
| 개인정보·보안 | 저장 위치(Supabase), 암호화·접근통제, 개인정보처리방침 URL |
| 예상 규모 | 초기 사용자 수, 조회 주기(예: 15분~1시간마다) |
| 기술 담당 | 연동 개발/기술 문의 담당자 연락처 |

---

## 3. 문의 이메일 초안 (한국어)

> 제목: [CARENOTE] LibreView API 파트너 연동 문의

안녕하세요.

당뇨·만성질환 관리 앱 **CARENOTE**를 개발·운영 중인 (회사/개발자명) 입니다.
FreeStyle Libre 사용자가 본인 동의하에 **연속 혈당(CGM) 데이터를 CARENOTE에서
자동으로 확인**할 수 있도록, **LibreView 정식 API 연동(파트너십)** 을 문의드립니다.

- 서비스: CARENOTE (iOS 앱, 당뇨/건강 관리)
- 연동 목적: 사용자 동의 기반 혈당 데이터 **읽기 전용** 조회 → 대시보드/리포트 표시
- 데이터 처리: 클라우드(Supabase)에 암호화 저장, 개인정보처리방침 준수
- 현재 상태: LibreView 전문가(클리닉) 계정으로 데이터 공유 구조는 구성 완료,
  정식 API 자격증명 발급을 요청드립니다.

연동 신청 절차, 필요 서류, 기술 규격(API 문서)을 안내해 주시면 감사하겠습니다.

감사합니다.
(이름 / 연락처 / 이메일)

---

## 4. 문의 이메일 초안 (English)

> Subject: [CARENOTE] Inquiry about LibreView API Partnership

Hello,

I am (name/company), developer of **CARENOTE**, an iOS app for diabetes and
chronic-condition management. We would like to integrate **LibreView's official
API** so that FreeStyle Libre users can, **with their consent**, automatically
view their **continuous glucose (CGM) data** inside CARENOTE.

- Product: CARENOTE (iOS app, diabetes/health management)
- Purpose: **Read-only** access to glucose data (with user consent) for dashboard/reports
- Data handling: Encrypted storage on cloud (Supabase), compliant privacy policy
- Current status: We have set up data sharing via a LibreView professional (clinic)
  account; we are requesting official API credentials.

Could you please advise on the application process, required documents, and the
API technical specification? Thank you.

Best regards,
(Name / Phone / Email)

---

## 5. 기술 개요 (Abbott 기술 담당과 논의용 참고)

연동 검증 과정에서 파악한 사항 (공식 API는 규격이 다를 수 있으나, 이해를 돕기 위한 참고):

- 지역(region): 한국 계정은 `ap`(아시아·태평양)
- 데이터 성격: 15분 간격 연속 혈당(historic) + 스캔값
- 공유 구조: 사용자가 리브레 앱 **Data Share 코드**로 CARENOTE 클리닉에 공유 →
  CARENOTE가 조회 (연결 가이드: `docs/libre-connection-guide.md`)
- 소비자 웹 API는 **HCP 계정 2FA 필수**로 무인 자동화 불가 → **공식 파트너 API 필요**

> 공식 API 승인 시, 발급된 자격증명·규격에 맞춰 CARENOTE 서버(Edge Function)에서
> 자동 수집을 구현합니다.

---

## 6. 승인 전 임시 운영

정식 API 승인 전까지는 **CSV 백필**로 운영:
libreview.com 전문가 계정 → **혈당 데이터 다운로드(CSV)** → CARENOTE
**프로필 → 데이터 가져오기 → 리브레뷰** (상세: `docs/libre-connection-guide.md`).

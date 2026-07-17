#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  CARENOTE — 원클릭 GitHub 업로드
#  사용법: 이미지를 app/assets 폴더에 넣은 뒤 이 파일을 더블클릭
# ═══════════════════════════════════════════════════════════
cd "$(dirname "$0")"

echo "📂 폴더: $(pwd)"
echo "🔄 최신 내려받는 중..."
git pull origin main --no-edit 2>/dev/null

echo "📤 변경사항 GitHub에 올리는 중..."
git add -A

if git diff --cached --quiet; then
  echo "ℹ️  올릴 새 파일/변경이 없어요."
else
  git commit -m "update: assets/design $(date '+%Y-%m-%d %H:%M')"
  if git push origin main 2>/tmp/cn_push_err; then
    echo ""
    echo "✅ 업로드 완료! 이 창은 닫으셔도 됩니다."
  else
    echo ""
    echo "⚠️  업로드 실패 — GitHub 로그인이 필요할 수 있어요."
    echo "    (아이디: cnkim74 / 비밀번호 자리에는 GitHub 토큰 입력)"
    echo "───────────────────────────────────────────"
    cat /tmp/cn_push_err
  fi
fi

echo ""
read -p "엔터 키를 누르면 창이 닫힙니다..."

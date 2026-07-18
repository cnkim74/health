-- ============================================================
-- CARENOTE — 광고·제휴 문의 저장 (광고제안 페이지 폼)
-- Supabase SQL Editor 에서 실행.
-- ============================================================
create table if not exists public.cn_ad_inquiries (
  id           uuid primary key default gen_random_uuid(),
  company      text,
  contact_name text,
  email        text,
  phone        text,
  message      text,
  created_at   timestamptz default now()
);

alter table public.cn_ad_inquiries enable row level security;

-- 문의 등록: 누구나(비로그인 포함) 가능
drop policy if exists cn_ad_inq_insert on public.cn_ad_inquiries;
create policy cn_ad_inq_insert on public.cn_ad_inquiries
  for insert with check (true);

-- 조회: 관리자만
drop policy if exists cn_ad_inq_admin on public.cn_ad_inquiries;
create policy cn_ad_inq_admin on public.cn_ad_inquiries
  for select using ((select auth.jwt() ->> 'email') = 'cnkim74@gmail.com');

-- ============================================================
-- CARENOTE — P6 광고/제휴 설정 (쿠팡 파트너스)
-- 관리자만 설정, 사용자는 읽기. Supabase SQL Editor 에서 실행.
-- ============================================================

create table if not exists public.cn_ad_config (
  id              int primary key default 1,
  coupang_enabled boolean not null default false,
  coupang_id      text,                       -- 파트너스 닉네임/ID (고지문 표기용, 선택)
  coupang_note    text,                       -- 커스텀 안내문(선택)
  links           jsonb not null default '[]'::jsonb, -- [{ "title": "...", "url": "..." }]
  updated_at      timestamptz default now(),
  constraint cn_ad_singleton check (id = 1)
);

-- 기본 1행 생성
insert into public.cn_ad_config (id) values (1) on conflict (id) do nothing;

alter table public.cn_ad_config enable row level security;

-- 읽기: 누구나(로그인 사용자 포함)
drop policy if exists cn_ad_read on public.cn_ad_config;
create policy cn_ad_read on public.cn_ad_config
  for select using (true);

-- 쓰기: 관리자 이메일만 (update / insert)
drop policy if exists cn_ad_update on public.cn_ad_config;
create policy cn_ad_update on public.cn_ad_config
  for update using ((select auth.jwt() ->> 'email') = 'cnkim74@gmail.com')
           with check ((select auth.jwt() ->> 'email') = 'cnkim74@gmail.com');

drop policy if exists cn_ad_insert on public.cn_ad_config;
create policy cn_ad_insert on public.cn_ad_config
  for insert with check ((select auth.jwt() ->> 'email') = 'cnkim74@gmail.com');

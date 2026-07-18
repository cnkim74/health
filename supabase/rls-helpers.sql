-- ============================================================
-- CARENOTE — RLS 우회 헬퍼 함수 (SECURITY DEFINER)
-- RLS로 막히지만 꼭 필요한 동작(이메일 중복확인, 조회수 증가)을
-- 안전하게 처리합니다. Supabase SQL Editor 에서 실행하세요.
-- ============================================================

-- 1) 이메일 중복 확인 (회원가입 시, 로그인 전 anon 상태에서 호출)
--    프로필 직접 조회는 RLS로 막히므로 이 함수로만 "존재 여부(true/false)"만 반환.
create or replace function public.email_exists(p_email text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.cn_profiles
    where lower(email) = lower(p_email)
  );
$$;

grant execute on function public.email_exists(text) to anon, authenticated;

-- 2) 커뮤니티 글 조회수 +1 (남의 글도 올려야 하므로 RLS 우회)
create or replace function public.bump_view_count(p_post_id text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.cn_community
     set view_count = coalesce(view_count, 0) + 1
   where id::text = p_post_id;
$$;

grant execute on function public.bump_view_count(text) to anon, authenticated;

-- ============================================================
-- 참고: 관리자 커뮤니티 모니터링/승인이 필요하면, 관리자 이메일에
--       전체 권한을 주는 정책을 추가할 수 있습니다 (선택):
--
-- create policy carenote_comm_admin on public.cn_community
--   for all using ((select auth.jwt() ->> 'email') = 'cnkim74@gmail.com')
--            with check ((select auth.jwt() ->> 'email') = 'cnkim74@gmail.com');
-- ============================================================

-- ============================================================
-- CARENOTE — RLS(행 수준 보안) 정책
-- Supabase Dashboard → SQL Editor 에 붙여넣고 실행하세요.
--
-- 목적: 각 사용자가 "본인 데이터"만 읽고/쓰도록 잠급니다.
-- 타입 안전을 위해 user_id/id 를 ::text 로 캐스팅해 비교합니다
--   (컬럼이 uuid든 text든 모두 동작).
--
-- ⚠️ 적용 순서 권장: 먼저 [A]diabetes_data 만 적용해 앱이 정상인지
--    확인한 뒤, [B][C][D] 를 하나씩 적용하세요.
-- ============================================================


-- ============================================================
-- [A] diabetes_data  — 건강 데이터 (가장 중요, 본인만 접근)
-- ============================================================
-- ⚠️ 사전 확인: 예전 기기 UUID(dm_user_id)로 저장된 "미이관 데이터"가 있다면,
--    RLS 적용 후에는 그 옛 행을 읽지 못합니다(로그인 계정 ID와 다르므로).
--    실제 사용자가 거의 없는 개발 단계면 그대로 진행해도 됩니다.
alter table public.diabetes_data enable row level security;

drop policy if exists carenote_dd_select on public.diabetes_data;
create policy carenote_dd_select on public.diabetes_data
  for select using (user_id::text = (select auth.uid())::text);

drop policy if exists carenote_dd_insert on public.diabetes_data;
create policy carenote_dd_insert on public.diabetes_data
  for insert with check (user_id::text = (select auth.uid())::text);

drop policy if exists carenote_dd_update on public.diabetes_data;
create policy carenote_dd_update on public.diabetes_data
  for update using (user_id::text = (select auth.uid())::text)
          with check (user_id::text = (select auth.uid())::text);

drop policy if exists carenote_dd_delete on public.diabetes_data;
create policy carenote_dd_delete on public.diabetes_data
  for delete using (user_id::text = (select auth.uid())::text);


-- ============================================================
-- [B] cn_profiles  — 프로필 (본인만 읽기/쓰기)
-- ============================================================
-- ⚠️ 주의:
--  1) 커뮤니티에서 "다른 사람 아바타/이름"을 cn_profiles 에서 직접 읽어오면,
--     이 정책 때문에 안 보일 수 있습니다. 그런 경우 게시글에 작성자 이름/아바타를
--     함께 저장(비정규화)하거나, 공개용 뷰(view)를 별도로 만드세요.
--  2) 로그인 전 "이메일 존재 확인" 같은 조회도 막힙니다(세션 없으면 auth.uid()=null).
--     이 기능이 필요하면 서버(Edge Function, service_role)로 처리하세요.
alter table public.cn_profiles enable row level security;

drop policy if exists carenote_prof_select on public.cn_profiles;
create policy carenote_prof_select on public.cn_profiles
  for select using (id::text = (select auth.uid())::text);

drop policy if exists carenote_prof_insert on public.cn_profiles;
create policy carenote_prof_insert on public.cn_profiles
  for insert with check (id::text = (select auth.uid())::text);

drop policy if exists carenote_prof_update on public.cn_profiles;
create policy carenote_prof_update on public.cn_profiles
  for update using (id::text = (select auth.uid())::text)
          with check (id::text = (select auth.uid())::text);


-- ============================================================
-- [C] cn_community / cn_comments — 커뮤니티
--     읽기: 로그인한 사람 모두 / 쓰기·수정·삭제: 본인 글만
-- ============================================================
alter table public.cn_community enable row level security;

drop policy if exists carenote_comm_select on public.cn_community;
create policy carenote_comm_select on public.cn_community
  for select using ((select auth.uid()) is not null);

drop policy if exists carenote_comm_insert on public.cn_community;
create policy carenote_comm_insert on public.cn_community
  for insert with check (user_id::text = (select auth.uid())::text);

drop policy if exists carenote_comm_update on public.cn_community;
create policy carenote_comm_update on public.cn_community
  for update using (user_id::text = (select auth.uid())::text)
          with check (user_id::text = (select auth.uid())::text);

drop policy if exists carenote_comm_delete on public.cn_community;
create policy carenote_comm_delete on public.cn_community
  for delete using (user_id::text = (select auth.uid())::text);

-- 조회수(view_count) 증가처럼 "남의 글 UPDATE"가 필요하면 위 update 정책과 충돌합니다.
-- 그런 경우 조회수 증가는 Edge Function(service_role) 또는 RPC 로 처리하세요.

alter table public.cn_comments enable row level security;

drop policy if exists carenote_cmt_select on public.cn_comments;
create policy carenote_cmt_select on public.cn_comments
  for select using ((select auth.uid()) is not null);

drop policy if exists carenote_cmt_insert on public.cn_comments;
create policy carenote_cmt_insert on public.cn_comments
  for insert with check (user_id::text = (select auth.uid())::text);

drop policy if exists carenote_cmt_delete on public.cn_comments;
create policy carenote_cmt_delete on public.cn_comments
  for delete using (user_id::text = (select auth.uid())::text);


-- ============================================================
-- [D] cn_feedback — 피드백 (아무나 등록 가능 / 조회는 관리자만)
-- ============================================================
-- ⚠️ 관리자 피드백 목록 화면은 이 정책 적용 후 앱(anon 키)으로는 조회가 막힙니다.
--    관리자 조회는 Supabase Dashboard 나 service_role 로 하세요.
alter table public.cn_feedback enable row level security;

drop policy if exists carenote_fb_insert on public.cn_feedback;
create policy carenote_fb_insert on public.cn_feedback
  for insert with check ((select auth.uid()) is not null);

-- (조회 정책 없음 → anon/일반 사용자는 SELECT 불가. 관리자는 대시보드/서버로 조회)


-- ============================================================
-- 적용 후 확인
--  1) 앱에서 로그인 → 오늘 기록 저장/조회 정상인지
--  2) 대시보드·리포트·커뮤니티 정상인지
--  3) 문제가 생기면 해당 섹션만 롤백:
--     alter table public.<테이블> disable row level security;
-- ============================================================

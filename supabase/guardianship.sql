-- ============================================================
-- CARENOTE — P1 가족 연결(보호 관계) : 테이블 · RLS · RPC
-- Supabase SQL Editor 에서 실행하세요.
--   관리자(guardian) = 돌보는 사람 / 피보호자(ward) = 기록하는 본인
-- ============================================================

-- 1) 보호 관계 테이블
create table if not exists public.cn_guardianship (
  id          uuid primary key default gen_random_uuid(),
  guardian_id uuid not null,                 -- 관리자(보호자)
  ward_id     uuid not null,                 -- 피보호자(환자 본인)
  status      text not null default 'pending', -- pending | active | rejected | revoked
  created_at  timestamptz not null default now(),
  unique (guardian_id, ward_id)
);
create index if not exists idx_guardianship_ward     on public.cn_guardianship(ward_id);
create index if not exists idx_guardianship_guardian on public.cn_guardianship(guardian_id);

-- 2) RLS: 본인이 당사자(관리자/피보호자)인 관계만 조회 (쓰기는 아래 RPC로만)
alter table public.cn_guardianship enable row level security;

drop policy if exists cn_guard_select on public.cn_guardianship;
create policy cn_guard_select on public.cn_guardianship
  for select using (
    guardian_id::text = (select auth.uid())::text
    or ward_id::text  = (select auth.uid())::text
  );

-- 3) diabetes_data SELECT 정책 확장: 활성 보호자는 피보호자 데이터 "읽기" 허용
drop policy if exists carenote_dd_select on public.diabetes_data;
create policy carenote_dd_select on public.diabetes_data
  for select using (
    user_id::text = (select auth.uid())::text
    or exists (
      select 1 from public.cn_guardianship g
      where g.ward_id::text = diabetes_data.user_id::text
        and g.guardian_id::text = (select auth.uid())::text
        and g.status = 'active'
    )
  );
-- (쓰기 정책은 그대로 — 보호자는 읽기 전용)

-- ============================================================
-- 4) RPC (SECURITY DEFINER) — 초대/수락/목록/해제
-- ============================================================

-- 4-1) 초대: 관리자(현재 사용자)가 피보호자 이메일로 초대
create or replace function public.cn_guardian_invite(p_ward_email text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_guardian uuid := auth.uid(); v_ward uuid;
begin
  if v_guardian is null then return jsonb_build_object('ok',false,'error','로그인이 필요합니다'); end if;
  select id into v_ward from public.cn_profiles where lower(email) = lower(trim(p_ward_email)) limit 1;
  if v_ward is null then return jsonb_build_object('ok',false,'error','해당 이메일의 CARENOTE 사용자를 찾을 수 없어요'); end if;
  if v_ward = v_guardian then return jsonb_build_object('ok',false,'error','본인은 초대할 수 없어요'); end if;
  insert into public.cn_guardianship (guardian_id, ward_id, status)
    values (v_guardian, v_ward, 'pending')
    on conflict (guardian_id, ward_id)
    do update set status = case when public.cn_guardianship.status = 'active' then 'active' else 'pending' end;
  return jsonb_build_object('ok',true);
end $$;
grant execute on function public.cn_guardian_invite(text) to authenticated;

-- 4-2) 목록: 내가 돌보는 가족(asGuardian) + 나를 돌보는 가족(asWard)
create or replace function public.cn_guardian_list()
returns jsonb language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'asGuardian', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', g.id, 'personId', g.ward_id, 'status', g.status,
        'name', p.name, 'email', p.email) order by g.created_at desc)
      from public.cn_guardianship g
      left join public.cn_profiles p on p.id = g.ward_id
      where g.guardian_id = auth.uid() and g.status <> 'revoked'
    ), '[]'::jsonb),
    'asWard', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', g.id, 'personId', g.guardian_id, 'status', g.status,
        'name', p.name, 'email', p.email) order by g.created_at desc)
      from public.cn_guardianship g
      left join public.cn_profiles p on p.id = g.guardian_id
      where g.ward_id = auth.uid() and g.status <> 'revoked'
    ), '[]'::jsonb)
  );
$$;
grant execute on function public.cn_guardian_list() to authenticated;

-- 4-3) 수락/거절: 피보호자만 자기에게 온 요청을 처리
create or replace function public.cn_guardian_respond(p_id uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update public.cn_guardianship
     set status = case when p_accept then 'active' else 'rejected' end
   where id = p_id and ward_id = auth.uid() and status = 'pending';
  if not found then return jsonb_build_object('ok',false,'error','처리할 요청이 없어요'); end if;
  return jsonb_build_object('ok',true);
end $$;
grant execute on function public.cn_guardian_respond(uuid, boolean) to authenticated;

-- 4-4) 해제: 관리자·피보호자 누구나 연결 해제
create or replace function public.cn_guardian_revoke(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update public.cn_guardianship set status = 'revoked'
   where id = p_id and (guardian_id = auth.uid() or ward_id = auth.uid());
  if not found then return jsonb_build_object('ok',false,'error','해제할 연결이 없어요'); end if;
  return jsonb_build_object('ok',true);
end $$;
grant execute on function public.cn_guardian_revoke(uuid) to authenticated;

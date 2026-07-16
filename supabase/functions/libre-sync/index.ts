// CARENOTE — LibreLinkUp 혈당 자동 수집 프록시
// 리브레 CGM 데이터를 LibreLinkUp API에서 가져와 클라이언트에 전달합니다.
// (LibreLinkUp API는 CORS를 허용하지 않아 브라우저에서 직접 호출 불가 → 이 함수가 중계)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const LLU_VERSION = "4.12.0";

const baseHeaders = (token?: string, accountId?: string): Record<string, string> => ({
  "accept-encoding": "gzip",
  "cache-control": "no-cache",
  "content-type": "application/json",
  "product": "llu.ios",
  "version": LLU_VERSION,
  ...(token ? { "authorization": `Bearer ${token}` } : {}),
  ...(accountId ? { "account-id": accountId } : {}),
});

async function sha256hex(s: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

const apiBase = (region?: string) =>
  region ? `https://api-${region}.libreview.io` : `https://api.libreview.io`;

interface Auth { token: string; accountId: string; region: string; expires: number; }

async function login(email: string, password: string, region?: string, depth = 0): Promise<Auth> {
  if (depth > 2) throw new Error("리전 리디렉션 반복 — 잠시 후 다시 시도해 주세요");
  const res = await fetch(`${apiBase(region)}/llu/auth/login`, {
    method: "POST",
    headers: baseHeaders(),
    body: JSON.stringify({ email, password }),
  });
  const j = await res.json();
  if (j?.data?.redirect && j?.data?.region) return login(email, password, j.data.region, depth + 1);
  if (j?.status === 4) throw new Error("약관 동의 필요 — 아이폰의 LibreLinkUp 앱에서 한 번 로그인해 약관에 동의해 주세요");
  if (j?.status === 2) throw new Error("이메일 또는 비밀번호가 올바르지 않습니다");
  if (j?.status !== 0 || !j?.data?.authTicket?.token) {
    throw new Error(`로그인 실패 (status ${j?.status ?? "?"}) — 이메일/비밀번호를 확인해 주세요`);
  }
  return {
    token: j.data.authTicket.token,
    accountId: await sha256hex(j.data.user.id),
    region: region || "",
    expires: j.data.authTicket.expires || 0,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const reply = (obj: unknown) =>
    new Response(JSON.stringify(obj), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    const body = await req.json().catch(() => ({}));
    const { email, password } = body;

    // 클라이언트가 캐시한 토큰이 유효하면 재로그인 생략
    let auth: Auth | null =
      body.token && body.accountId
        ? { token: body.token, accountId: body.accountId, region: body.region || "", expires: body.expires || 0 }
        : null;

    if (!auth) {
      if (!email || !password) throw new Error("이메일과 비밀번호가 필요합니다");
      auth = await login(email, password);
    }

    // 팔로우 중인 환자 목록
    const fetchConnections = async (a: Auth) => {
      const r = await fetch(`${apiBase(a.region)}/llu/connections`, {
        headers: baseHeaders(a.token, a.accountId),
      });
      return r.json();
    };

    let conn = await fetchConnections(auth);
    // 토큰 만료 → 자격증명 있으면 재로그인 1회
    if (conn?.status !== 0 && email && password) {
      auth = await login(email, password);
      conn = await fetchConnections(auth);
    }
    if (conn?.status !== 0) throw new Error("연결 조회 실패 — 다시 시도해 주세요");

    const patients = conn.data || [];
    if (!patients.length) {
      throw new Error("팔로우 중인 환자가 없습니다 — 리브레 앱 > 공유 > LibreLinkUp에서 이 계정을 초대해 주세요");
    }
    const p = patients[0];

    // 최근 ~12시간 그래프 데이터
    const gr = await fetch(`${apiBase(auth.region)}/llu/connections/${p.patientId}/graph`, {
      headers: baseHeaders(auth.token, auth.accountId),
    });
    const gj = await gr.json();
    if (gj?.status !== 0) throw new Error("혈당 데이터 조회 실패");

    const graph = gj.data?.graphData || [];
    const latestRaw = gj.data?.connection?.glucoseMeasurement || null;

    const readings = graph
      .map((r: any) => ({ ts: r.Timestamp, mgdl: Math.round(r.ValueInMgPerDl ?? r.Value ?? 0) }))
      .filter((r: any) => r.ts && r.mgdl > 0);

    const latest = latestRaw && (latestRaw.ValueInMgPerDl ?? latestRaw.Value) > 0
      ? {
          ts: latestRaw.Timestamp,
          mgdl: Math.round(latestRaw.ValueInMgPerDl ?? latestRaw.Value),
          trend: latestRaw.TrendArrow ?? null,
        }
      : null;
    if (latest) readings.push({ ts: latest.ts, mgdl: latest.mgdl });

    return reply({
      ok: true,
      patient: `${p.firstName || ""} ${p.lastName || ""}`.trim(),
      auth, // 클라이언트가 캐시해서 다음 호출에 재사용 (재로그인 최소화)
      latest,
      readings,
    });
  } catch (e) {
    return reply({ ok: false, error: (e as Error).message || "알 수 없는 오류" });
  }
});

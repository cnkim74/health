// CARENOTE — LibreView 자동수집 진단(probe)
// 전문가(클리닉) 계정으로 LibreView LLU API에 로그인해 어디까지 되는지 단계별로 반환.
// 브라우저에서 GET 호출 가능:  ?email=...&password=...
// (진단용. 비밀번호가 URL/로그에 남을 수 있으니 테스트 후 필요시 비밀번호 변경 권장)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const V = "4.12.0";
const H = (token?: string, acc?: string): Record<string, string> => ({
  "accept-encoding": "gzip",
  "cache-control": "no-cache",
  "content-type": "application/json",
  "product": "llu.ios",
  "version": V,
  ...(token ? { authorization: `Bearer ${token}` } : {}),
  ...(acc ? { "account-id": acc } : {}),
});
async function sha256(s: string) {
  const b = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, "0")).join("");
}
const base = (r?: string) => (r ? `https://api-${r}.libreview.io` : `https://api.libreview.io`);

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const out: any = { steps: [] };
  const reply = () =>
    new Response(JSON.stringify(out, null, 2), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  try {
    const url = new URL(req.url);
    let email = url.searchParams.get("email") || "";
    let password = url.searchParams.get("password") || "";
    if (!email || !password) {
      const body = await req.json().catch(() => ({}));
      email = email || body.email || "";
      password = password || body.password || "";
    }
    if (!email || !password) { out.error = "email/password 필요 (?email=..&password=..)"; return reply(); }

    // 1) 로그인 (리전 리디렉션 최대 2회)
    let region = "";
    let auth: any = null;
    for (let i = 0; i < 3; i++) {
      const r = await fetch(`${base(region)}/llu/auth/login`, {
        method: "POST", headers: H(), body: JSON.stringify({ email, password }),
      });
      const j = await r.json().catch(() => ({}));
      out.steps.push({ step: "login", httpTried: base(region), status: j?.status,
        hasRedirect: !!j?.data?.redirect, region: j?.data?.region ?? null,
        hasToken: !!j?.data?.authTicket?.token });
      if (j?.data?.redirect && j?.data?.region) { region = j.data.region; continue; }
      if (j?.status === 0 && j?.data?.authTicket?.token) {
        auth = { token: j.data.authTicket.token, accountId: await sha256(j.data.user?.id || ""), region };
      } else {
        out.loginFail = { status: j?.status, message: j?.error?.message ?? null };
      }
      break;
    }
    if (!auth) { out.result = "로그인 실패 — status 확인"; return reply(); }
    out.loginOK = true; out.region = auth.region || "(default)";

    // 2) LLU connections (팔로우/환자 목록)
    const rc = await fetch(`${base(auth.region)}/llu/connections`, { headers: H(auth.token, auth.accountId) });
    const jc = await rc.json().catch(() => ({}));
    const patients = jc?.data || [];
    out.steps.push({ step: "connections", status: jc?.status, count: Array.isArray(patients) ? patients.length : 0 });
    out.connectionsCount = Array.isArray(patients) ? patients.length : 0;

    // 3) 첫 환자 그래프 데이터
    if (Array.isArray(patients) && patients.length) {
      const p = patients[0];
      out.firstPatient = { hasId: !!p.patientId, name: `${p.firstName || ""} ${p.lastName || ""}`.trim() || "(이름없음)" };
      const rg = await fetch(`${base(auth.region)}/llu/connections/${p.patientId}/graph`, { headers: H(auth.token, auth.accountId) });
      const jg = await rg.json().catch(() => ({}));
      const graph = jg?.data?.graphData || [];
      const latest = jg?.data?.connection?.glucoseMeasurement || null;
      out.steps.push({ step: "graph", status: jg?.status, graphPoints: graph.length, hasLatest: !!latest });
      out.graphPoints = graph.length;
      out.latest = latest ? { mgdl: Math.round(latest.ValueInMgPerDl ?? latest.Value ?? 0), ts: latest.Timestamp } : null;
      out.verdict = graph.length > 0
        ? "✅ 자동수집 가능 — LLU API로 혈당이 나옵니다"
        : "⚠️ 환자는 보이나 그래프 데이터가 비어있음";
    } else {
      out.verdict = "⚠️ connections에 환자가 없음 — 전문가 계정은 LLU API로 환자가 안 잡힘 (웹/Practice API 필요, cURL 캡처로 진행)";
    }
    return reply();
  } catch (e) {
    out.exception = (e as Error).message || String(e);
    return reply();
  }
});

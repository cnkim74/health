// CARENOTE — LibreView 웹(lv) API 자동로그인 진단 probe2
// 목표: 전문가(hcp) 계정으로 로그인되는 엔드포인트를 찾고, glucoseHistory 응답 구조를 확인.
// 브라우저 GET:  ?email=..&password=..[&patientId=..]
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
// LibreView 웹 헤더 (product: lv)
const H = (token?: string, acc?: string): Record<string, string> => ({
  "accept": "application/json, text/plain, */*",
  "cache-control": "no-cache",
  "content-type": "application/json",
  "product": "lv",
  "newyu-lv-web-version": "3.25.3.0",
  "origin": "https://www.libreview.com",
  "referer": "https://www.libreview.com/",
  ...(token ? { authorization: `Bearer ${token}` } : {}),
  ...(acc ? { "account-id": acc } : {}),
});
async function sha256(s: string) {
  const b = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, "0")).join("");
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const out: any = { loginTries: [] };
  const reply = () =>
    new Response(JSON.stringify(out, null, 2), { headers: { ...cors, "Content-Type": "application/json" } });
  try {
    const url = new URL(req.url);
    let email = url.searchParams.get("email") || "";
    let password = url.searchParams.get("password") || "";
    const patientId = url.searchParams.get("patientId") || "019d5323-5c01-7232-bf27-0f234531cbaf";
    if (!email || !password) {
      const body = await req.json().catch(() => ({}));
      email = email || body.email || ""; password = password || body.password || "";
    }
    if (!email || !password) { out.error = "email/password 필요"; return reply(); }

    // 후보 로그인 엔드포인트 (ap 지역, product lv)
    const candidates = [
      "https://api-ap.libreview.io/auth/login",
      "https://api-ap.libreview.io/lsl/api/auth/login",
      "https://api-ap.libreview.io/llu/auth/login",
      "https://api.libreview.io/auth/login",
    ];
    let auth: { token: string; accountId: string } | null = null;
    for (const ep of candidates) {
      try {
        const r = await fetch(ep, { method: "POST", headers: H(), body: JSON.stringify({ email, password }) });
        const j = await r.json().catch(() => ({}));
        const tok = j?.data?.authTicket?.token || j?.data?.token || j?.ticket?.token || null;
        const uid = j?.data?.user?.id || j?.data?.id || j?.user?.id || null;
        out.loginTries.push({ ep, http: r.status, status: j?.status ?? null, hasToken: !!tok, hasUserId: !!uid,
          keys: Object.keys(j || {}).slice(0, 6) });
        if (tok) { auth = { token: tok, accountId: uid ? await sha256(uid) : "" }; out.loginEndpoint = ep; break; }
      } catch (e) { out.loginTries.push({ ep, error: (e as Error).message }); }
    }
    if (!auth) { out.verdict = "❌ 로그인 엔드포인트 못 찾음 — loginTries 확인 (로그인 요청도 캡처 필요할 수 있음)"; return reply(); }

    out.loginOK = true;
    // glucoseHistory 호출
    const gh = `https://api-ap.libreview.io/patients/${patientId}/glucoseHistory?numPeriods=5&period=14`;
    const rg = await fetch(gh, { headers: H(auth.token, auth.accountId) });
    const jg = await rg.json().catch(() => ({}));
    out.glucoseHTTP = rg.status;
    out.glucoseTopKeys = Object.keys(jg || {}).slice(0, 12);
    // 데이터 구조 탐색
    const d = jg?.data ?? jg;
    out.dataType = Array.isArray(d) ? "array" : typeof d;
    if (Array.isArray(d)) {
      out.dataLen = d.length;
      out.sample = d.slice(0, 2);
    } else if (d && typeof d === "object") {
      out.dataKeys = Object.keys(d).slice(0, 15);
      // 흔한 후보 배열 찾기
      for (const k of Object.keys(d)) {
        if (Array.isArray((d as any)[k])) {
          out[`arr_${k}_len`] = (d as any)[k].length;
          if (!out.firstArraySample) { out.firstArrayKey = k; out.firstArraySample = (d as any)[k].slice(0, 2); }
        }
      }
    }
    out.verdict = out.glucoseHTTP === 200 ? "✅ 웹 API 접근 성공 — 구조 확인됨" : `⚠️ glucoseHistory HTTP ${out.glucoseHTTP}`;
    return reply();
  } catch (e) {
    out.exception = (e as Error).message || String(e);
    return reply();
  }
});

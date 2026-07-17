// CARENOTE — LibreView 웹(lv) API 자동수집 진단 probe2 (v2: JWT에서 id 추출)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
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
function decodeJwt(token: string): any {
  try {
    let b = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    while (b.length % 4) b += "=";
    const bytes = Uint8Array.from(atob(b), (c) => c.charCodeAt(0));
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch { return null; }
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const out: any = {};
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

    // 로그인
    const r = await fetch("https://api-ap.libreview.io/auth/login", {
      method: "POST", headers: H(), body: JSON.stringify({ email, password }),
    });
    const j = await r.json().catch(() => ({}));
    const token = j?.data?.authTicket?.token || j?.data?.token || null;
    out.loginStatus = j?.status;
    out.hasToken = !!token;
    if (!token) { out.verdict = "❌ 토큰 없음"; out.dataKeys = Object.keys(j?.data || {}).slice(0, 10); return reply(); }

    // JWT에서 id 추출 → account-id = sha256(id)
    const claims = decodeJwt(token) || {};
    out.jwt = { id: claims.id ?? null, region: claims.region ?? null, role: claims.role ?? null, country: claims.country ?? null };
    const accountId = claims.id ? await sha256(claims.id) : "";
    out.accountIdComputed = !!accountId;

    // glucoseHistory
    const gh = `https://api-ap.libreview.io/patients/${patientId}/glucoseHistory?numPeriods=5&period=14`;
    const rg = await fetch(gh, { headers: H(token, accountId) });
    const jg = await rg.json().catch(() => ({}));
    out.glucoseHTTP = rg.status;
    out.glucoseTopKeys = Object.keys(jg || {}).slice(0, 12);
    const d = jg?.data ?? jg;
    out.dataType = Array.isArray(d) ? "array" : typeof d;
    if (Array.isArray(d)) {
      out.dataLen = d.length; out.sample = d.slice(0, 2);
    } else if (d && typeof d === "object") {
      out.dataKeys = Object.keys(d).slice(0, 20);
      for (const k of Object.keys(d)) {
        if (Array.isArray((d as any)[k])) {
          out[`arr_${k}_len`] = (d as any)[k].length;
          if (!out.firstArraySample) { out.firstArrayKey = k; out.firstArraySample = (d as any)[k].slice(0, 2); }
        }
      }
    }
    out.verdict = rg.status === 200 ? "✅ 자동수집 가능 — 웹 API 구조 확인됨" : `⚠️ glucoseHistory HTTP ${rg.status}`;
    return reply();
  } catch (e) {
    out.exception = (e as Error).message || String(e);
    return reply();
  }
});

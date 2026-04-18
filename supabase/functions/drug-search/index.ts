import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const DRUG_API_KEY = "12c113eddc12643698f9d49c82bc7ac526c33cc339906c4964299ef4b258ff9d";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const q = url.searchParams.get("q")?.trim() ?? "";

    if (q.length < 2) {
      return new Response(JSON.stringify([]), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const apiUrl =
      `https://apis.data.go.kr/1471000/DrbEasyDrugInfoService/getDrbEasyDrugList` +
      `?serviceKey=${encodeURIComponent(DRUG_API_KEY)}` +
      `&itemName=${encodeURIComponent(q)}&type=json&numOfRows=10&pageNo=1`;

    const res = await fetch(apiUrl);
    if (!res.ok) throw new Error(`API 응답 오류: ${res.status}`);

    const json = await res.json();
    const raw = json?.body?.items?.item;
    const items = raw ? (Array.isArray(raw) ? raw : [raw]) : [];

    // 필요한 필드만 추려서 반환
    const result = items.map((d: any) => ({
      itemName: d.itemName ?? "",
      efcyQesitm: (d.efcyQesitm ?? "").replace(/<[^>]*>/g, ""),
      itemSeq: d.itemSeq ?? "",
    }));

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

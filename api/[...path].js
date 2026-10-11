// Vercel Edge Function: forwards same-origin /api/* requests to the Talorys agent engine
// deployed on Cloudflare Workers (set AGENT_URL, e.g. https://talorys-agent.<account>.workers.dev).
// The engine performs all authentication itself; this function only relays requests.
export const config = { runtime: "edge" };

const STRIP_REQUEST = ["host", "connection", "content-length", "x-forwarded-for", "x-forwarded-host", "x-forwarded-proto", "x-real-ip", "x-vercel-id", "x-vercel-deployment-url", "x-vercel-forwarded-for", "forwarded"];
const STRIP_RESPONSE = ["content-encoding", "content-length", "transfer-encoding", "connection"];

function json(status, code, message) {
  return Response.json({ error: { code, message } }, { status });
}

export default async function handler(request) {
  const base = process.env.AGENT_URL;
  if (!base) return json(503, "NOT_CONFIGURED", "AGENT_URL 환경변수가 설정되지 않았습니다.");

  let target;
  try {
    const agent = new URL(base);
    const incoming = new URL(request.url);
    target = new URL(incoming.pathname + incoming.search, agent.origin);
  } catch {
    return json(503, "NOT_CONFIGURED", "AGENT_URL 형식이 올바르지 않습니다.");
  }

  const headers = new Headers(request.headers);
  for (const name of STRIP_REQUEST) headers.delete(name);
  // The engine only accepts requests whose Origin is its own, so present it as same-origin.
  if (headers.has("origin")) headers.set("origin", target.origin);
  if (headers.has("sec-fetch-site")) headers.set("sec-fetch-site", "same-origin");
  headers.delete("referer");

  const hasBody = request.method !== "GET" && request.method !== "HEAD";
  try {
    const upstream = await fetch(target, {
      method: request.method,
      headers,
      body: hasBody ? request.body : undefined,
      duplex: hasBody ? "half" : undefined,
      redirect: "manual",
    });
    const out = new Headers(upstream.headers);
    for (const name of STRIP_RESPONSE) out.delete(name);
    out.set("cache-control", "no-store");
    return new Response(upstream.body, { status: upstream.status, statusText: upstream.statusText, headers: out });
  } catch (error) {
    console.error("Talorys engine unreachable", error);
    return json(502, "INTERNAL_ERROR", "Talorys 엔진에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요.");
  }
}

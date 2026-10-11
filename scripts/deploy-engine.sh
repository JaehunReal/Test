#!/usr/bin/env bash
# Talorys 에이전트 엔진을 본인 Cloudflare 계정에 배포합니다.
# 필요: Node 20.18+, CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID, OWNER_PASSWORD(앱 로그인 비밀번호)
set -euo pipefail
: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN 이 필요합니다}"
: "${CLOUDFLARE_ACCOUNT_ID:?CLOUDFLARE_ACCOUNT_ID 가 필요합니다}"
: "${OWNER_PASSWORD:?OWNER_PASSWORD 가 필요합니다 (12자 이상 권장)}"
NAME="${WORKER_NAME:-talorys-agent}"
WORK="${WORK_DIR:-$(mktemp -d)}"

git clone --depth 1 https://github.com/rociiu/talorys "$WORK/talorys"
cd "$WORK/talorys"
npm ci --no-audit --no-fund

cd apps/agent
# 운영용 설정: Vercel 프록시가 접근할 수 있도록 workers.dev 주소를 켭니다(인증은 엔진이 직접 수행).
cat > wrangler.prod.jsonc <<JSON
{
  "name": "$NAME",
  "main": "src/index.ts",
  "compatibility_date": "2026-10-01",
  "compatibility_flags": ["nodejs_compat"],
  "workers_dev": true,
  "preview_urls": false,
  "ai": { "binding": "AI" },
  "durable_objects": { "bindings": [{ "name": "TalorysAgent", "class_name": "TalorysAgent" }] },
  "migrations": [{ "tag": "v1", "new_sqlite_classes": ["TalorysAgent"] }],
  "observability": { "enabled": true }
}
JSON
npx wrangler deploy -c wrangler.prod.jsonc

# 비밀번호 해시(PBKDF2)와 세션 비밀키 생성 후 시크릿으로 등록
SECRETS=$(OWNER_PASSWORD="$OWNER_PASSWORD" node --input-type=module -e '
import { webcrypto as c } from "node:crypto";
const b = (x) => Buffer.from(x).toString("base64url");
const salt = c.getRandomValues(new Uint8Array(16));
const key = await c.subtle.importKey("raw", new TextEncoder().encode(process.env.OWNER_PASSWORD.normalize("NFKC")), "PBKDF2", false, ["deriveBits"]);
const bits = await c.subtle.deriveBits({ name: "PBKDF2", hash: "SHA-256", salt, iterations: 100000 }, key, 256);
console.log(JSON.stringify({
  OWNER_PASSWORD_HASH: `pbkdf2-sha256$100000$${b(salt)}$${b(new Uint8Array(bits))}`,
  SESSION_SECRET: b(c.getRandomValues(new Uint8Array(32))),
}));')
echo "$SECRETS" | npx wrangler secret bulk -c wrangler.prod.jsonc

echo
echo "배포 완료. 위 출력의 https://$NAME.<계정>.workers.dev 주소를 Vercel 환경변수 AGENT_URL 로 등록하세요."

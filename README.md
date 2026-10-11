# Talorys on Vercel

## 1. 개요
- 실제 Talorys(https://github.com/rociiu/talorys) 웹앱을 Vercel에서 제공하고, 에이전트 엔진은 Cloudflare Workers에서 구동
- `public/`: Talorys 웹앱 빌드 결과(원본 `apps/web`)
- `api/[...path].js`: Vercel Edge 프록시 (`/api/*` → `AGENT_URL`의 엔진)
- `public/report.html`: 테스트 결과 보고서 (`/report`)

## 2. 배포 절차
- 엔진 배포 (Cloudflare 계정 필요, 무료 플랜 가능)
  - `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `OWNER_PASSWORD` 설정 후 `scripts/deploy-engine.sh` 실행
  - 출력된 `https://talorys-agent.<계정>.workers.dev` 주소 확인
- Vercel 설정
  - 프로젝트 환경변수 `AGENT_URL` 에 위 주소 등록 후 Redeploy
- 접속 후 `OWNER_PASSWORD` 로 로그인

## 3. 유의사항
- 엔진은 workers.dev 공개 주소를 사용하며 인증은 엔진이 직접 수행(비밀번호 12자 이상 권장)
- AI는 Cloudflare Workers AI(무료 한도 내) 사용, 한도 초과 시에도 할 일·메모·기억·알림은 동작
- 로컬 검증: 엔진(wrangler dev, 모의 AI) + 본 프록시 + 실제 웹앱 조합으로 E2E 13건 통과

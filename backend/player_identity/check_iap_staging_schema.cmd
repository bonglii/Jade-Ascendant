@echo off
setlocal
cd /d "%~dp0..\.."
if errorlevel 1 exit /b 1
echo MODE=READ_ONLY_STAGING; PURCHASE=NONE; DEPLOY=NONE
echo Run deploy_iap_gameplay_staging.cmd first. Missing tables mean schema is not deployed.
call npx.cmd --yes wrangler@4 d1 execute jade-iap-ledger-staging --remote --config "backend/monetization/cloudflare/wrangler.gameplay-staging.toml" --file "backend/monetization/cloudflare/staging_readiness_v2.sql"
exit /b %ERRORLEVEL%

param([ValidateSet('all','iap','profile')][string]$Target='all')
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $repo
try {
 & node backend/player_identity/production_release_contract.mjs
 if ($LASTEXITCODE -ne 0) { throw 'Existing live production contract failed; no deployment attempted.' }
 & node --test backend/player_identity/mail.test.mjs backend/player_identity/odyssey.test.mjs backend/monetization/tests/m7e4b_ssv_verifier.test.mjs backend/monetization/cloudflare/tests/odyssey_ssv_documented_wire.test.mjs backend/monetization/cloudflare/tests/odyssey_ad_delivery.test.mjs backend/monetization/cloudflare/tests/odyssey_wire.test.mjs backend/monetization/cloudflare/tests/worker_paid_production_v2.test.mjs
 if ($LASTEXITCODE -ne 0) { throw 'Server validation failed; no deployment attempted.' }
 $iap=Join-Path $repo 'backend/monetization/cloudflare/wrangler.production-live.toml'
 $profile=Join-Path $PSScriptRoot 'wrangler.local.toml'
 $ic=[IO.File]::ReadAllText($iap); $pc=[IO.File]::ReadAllText($profile)
 if ($ic -notmatch '(?m)^name\s*=\s*"jade-ascendant-iap"\s*$' -or $ic -notmatch 'f0e59ec4-effb-4002-b9a5-d246965b5b83') { throw 'Unexpected IAP target.' }
 if ($pc -notmatch '(?m)^name\s*=\s*"jade-ascendant-player"\s*$' -or $pc -notmatch '1089de95-8cdc-447d-a9e3-9e743d200cba') { throw 'Unexpected profile target.' }
 if ($Target -in @('all','profile')) {
 & node backend/player_identity/build_mail_assets.mjs
 if ($LASTEXITCODE -ne 0) { throw 'Existing dashboard assets could not be prepared.' }
 }
 if ($Target -in @('all','iap')) {
 & npx.cmd --yes wrangler@4.151.0 deploy --keep-vars --config $iap
 if ($LASTEXITCODE -ne 0) { throw 'IAP event deployment failed; retry the same launcher.' }
 }
 if ($Target -in @('all','profile')) {
 & npx.cmd --yes wrangler@4.151.0 deploy --keep-vars --config $profile
 if ($LASTEXITCODE -ne 0) { throw 'Profile mail deployment failed; completed IAP deployment is retained.' }
 }
 Write-Host 'PREMIUM_RELIABILITY_DEPLOY=PASS; SCHEMA=UNCHANGED; LIVE_PAYMENT_GATES=UNCHANGED; EVENT_SCHEDULE=UNCHANGED; BROADCAST=NONE'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }

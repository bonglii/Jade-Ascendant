$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $repo
try {
    & node backend/player_identity/production_release_contract.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Existing production release contract failed. No deploy attempted.' }
    & node --test backend/monetization/cloudflare/tests/odyssey_flow.test.mjs backend/monetization/cloudflare/tests/odyssey_purchase_bonus.test.mjs backend/monetization/cloudflare/tests/worker_paid_production_v2.test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Event server validation failed. No deploy attempted.' }
    $iap=Join-Path $repo 'backend/monetization/cloudflare/wrangler.production-live.toml'
    $ic=[IO.File]::ReadAllText($iap)
    if ($ic -notmatch '(?m)^name\s*=\s*"jade-ascendant-iap"\s*$' -or $ic -notmatch 'f0e59ec4-effb-4002-b9a5-d246965b5b83') { throw 'Unexpected production IAP target.' }
    # Existing JSON state storage; no schema, secret, Firebase or event schedule changes.
    & npx.cmd --yes wrangler@4.151.0 deploy --config $iap --keep-vars
    if ($LASTEXITCODE -ne 0) { throw 'Event worker deploy failed. Retry the same batch launcher.' }
    Write-Host 'ODYSSEY_FLOW_DEPLOY=PASS; SCHEMA=UNCHANGED; EVENT_SCHEDULE=UNCHANGED; PAYMENT_GATES=UNCHANGED; BROADCAST=NONE'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }

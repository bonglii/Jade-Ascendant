$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $repo
try {
    & node backend/player_identity/production_release_contract.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Existing production contract failed; no deploy attempted.' }
    & node --test backend/player_identity/heavenly_trials.test.mjs backend/monetization/cloudflare/heavenly_trials.test.mjs backend/monetization/cloudflare/tests/paid_gameplay_v2.test.mjs backend/monetization/cloudflare/tests/worker_paid_production_v2.test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Weekly server validation failed; no deploy attempted.' }
    $iap=Join-Path $repo 'backend/monetization/cloudflare/wrangler.production-live.toml'
    $profile=Join-Path $PSScriptRoot 'wrangler.local.toml'
    $ic=[IO.File]::ReadAllText($iap);$pc=[IO.File]::ReadAllText($profile)
    if ($ic -notmatch '(?m)^name\s*=\s*"jade-ascendant-iap"\s*$' -or $ic -notmatch 'f0e59ec4-effb-4002-b9a5-d246965b5b83') { throw 'Unexpected IAP target.' }
    if ($pc -notmatch '(?m)^name\s*=\s*"jade-ascendant-player"\s*$' -or $pc -notmatch '1089de95-8cdc-447d-a9e3-9e743d200cba') { throw 'Unexpected profile target.' }
    $stateDir=Join-Path $repo '.local/heavenly_trials_deploy'
    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    $schema=Join-Path $repo 'backend/monetization/cloudflare/migrations/0016_heavenly_trials.sql'
    $schemaHash=(Get-FileHash -LiteralPath $schema -Algorithm SHA256).Hash.ToLowerInvariant()
    $schemaDone=Join-Path $stateDir ($schemaHash+'.schema')
    if (-not (Test-Path -LiteralPath $schemaDone)) {
        & npx.cmd --yes wrangler@4.151.0 d1 execute jade-iap-ledger --remote --config $iap --file $schema --yes
        if ($LASTEXITCODE -ne 0) { throw 'Weekly additive schema failed. No Worker deployment attempted; existing records preserved.' }
        [IO.File]::WriteAllText($schemaDone,'confirmed')
    } else { Write-Host 'TRIALS_DEPLOY_RESUME_SKIP=schema' }
    & node backend/player_identity/build_mail_assets.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Dashboard assets failed.' }
    & npx.cmd --yes wrangler@4.151.0 deploy --config $iap --keep-vars
    if ($LASTEXITCODE -ne 0) { throw 'IAP worker deploy failed. Completed schema retained.' }
    & npx.cmd --yes wrangler@4.151.0 deploy --config $profile --keep-vars
    if ($LASTEXITCODE -ne 0) { throw 'Dashboard deploy failed. Retry this same launcher.' }
    Write-Host 'HEAVENLY_TRIALS_DEPLOY=PASS; NOT_AUTOSTARTED; PAYMENT_GATES_UNCHANGED; BROADCAST=NONE'
    Write-Host 'Dashboard: https://jade-ascendant-player.jade-ascendant-studio.workers.dev/admin/trials'
    Write-Host 'Optional SSV: https://jade-ascendant-iap.jade-ascendant-studio.workers.dev/v1/heavenly-trials/ssv'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }

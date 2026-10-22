param([ValidateSet('profile','iap','all')][string]$Target='all')
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $repo
try {
    & node backend/player_identity/production_release_contract.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Existing production contract failed. No deploy attempted.' }
    $changes=@(& git diff --name-only HEAD -- backend/player_identity/*.mjs backend/monetization/cloudflare/src/*.mjs)
    if ($LASTEXITCODE -ne 0 -or $changes.Count -gt 0) { throw 'Publish reviewed backend source before deploying. Local changes preserved.' }
    $profile=Join-Path $PSScriptRoot 'wrangler.local.toml'
    $iap=Join-Path $repo 'backend/monetization/cloudflare/wrangler.production-live.toml'
    if ($Target -in @('profile','all')) {
        if (-not (Test-Path -LiteralPath $profile)) { throw 'Existing profile wrangler.local.toml is missing. Restore the established local configuration.' }
        $text=[IO.File]::ReadAllText($profile)
        if ($text -notmatch '(?m)^name\s*=\s*"jade-ascendant-player"\s*$' -or $text -notmatch '1089de95-8cdc-447d-a9e3-9e743d200cba') { throw 'Unexpected profile production resource.' }
        & node backend/player_identity/build_mail_assets.mjs
        if ($LASTEXITCODE -ne 0) { throw 'Dashboard asset bundle failed; no Profile deploy attempted.' }
        & npx.cmd --yes wrangler@4.151.0 deploy --config $profile --keep-vars
        if ($LASTEXITCODE -ne 0) { throw 'Profile grant-verification deployment failed. Resume the same batch launcher.' }
        Write-Host 'PLAYER_JOURNEY_PROFILE_DEPLOY=PASS; SCHEMA=UNCHANGED; GRANT_WRITES=NONE'
    }
    if ($Target -in @('iap','all')) {
        $text=[IO.File]::ReadAllText($iap)
        if ($text -notmatch '(?m)^name\s*=\s*"jade-ascendant-iap"\s*$' -or $text -notmatch 'f0e59ec4-effb-4002-b9a5-d246965b5b83') { throw 'Unexpected IAP production resource.' }
        & npx.cmd --yes wrangler@4.151.0 deploy --config $iap --keep-vars
        if ($LASTEXITCODE -ne 0) { throw 'IAP Compass-verification deployment failed. Completed Profile stage is retained by the batch launcher.' }
        Write-Host 'PLAYER_JOURNEY_IAP_DEPLOY=PASS; PAYMENT_GATES=UNCHANGED; SCHEMA=UNCHANGED'
    }
    Write-Host 'PLAYER_JOURNEY_DEPLOY=PASS; CAMPAIGN_ACTIVATION=NONE; BROADCAST=NONE'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }

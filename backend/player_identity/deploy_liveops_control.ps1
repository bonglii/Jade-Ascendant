param([ValidateSet('indexes','iap','profile','all')][string]$Target='all')
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $repo
try {
    & node backend/player_identity/production_release_contract.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Existing production contract failed. Nothing deployed.' }
    $sourceChanges=@(& git diff --name-only HEAD -- backend/player_identity/*.mjs backend/monetization/cloudflare/src/*.mjs backend/monetization/src/*.mjs)
    if ($LASTEXITCODE -ne 0 -or $sourceChanges.Count -gt 0) { throw 'Publish reviewed backend source before deployment. Local differences were preserved.' }
    $iap=Join-Path $repo 'backend/monetization/cloudflare/wrangler.production-live.toml'
    $profile=Join-Path $PSScriptRoot 'wrangler.local.toml'
    $iapConfig=[IO.File]::ReadAllText($iap)
    if ($iapConfig -notmatch '(?m)^name\s*=\s*"jade-ascendant-iap"\s*$' -or $iapConfig -notmatch 'f0e59ec4-effb-4002-b9a5-d246965b5b83') { throw 'Unexpected production IAP resource.' }
    if ($Target -in @('indexes','all')) {
        $migration=Join-Path $repo 'backend/monetization/cloudflare/migrations/0017_liveops_operations_indexes.sql'
        $hash=(Get-FileHash -LiteralPath $migration -Algorithm SHA256).Hash.ToLowerInvariant()
        $state=Join-Path $repo '.local/liveops_control_deploy'
        New-Item -ItemType Directory -Force -Path $state | Out-Null
        $marker=Join-Path $state ($hash+'.indexes')
        if (-not (Test-Path -LiteralPath $marker)) {
            & npx.cmd --yes wrangler@4.151.0 d1 execute jade-iap-ledger --remote --config $iap --file $migration --yes
            if ($LASTEXITCODE -ne 0) { throw 'Additive operations index migration failed. No Worker deployment attempted; retry the same launcher.' }
            [IO.File]::WriteAllText($marker,'confirmed')
        } else { Write-Host 'LIVEOPS_RESUME_SKIP=indexes' }
    }
    if ($Target -in @('iap','all')) {
        $config=[IO.File]::ReadAllText($iap)
        if ($config -notmatch '(?m)^name\s*=\s*"jade-ascendant-iap"\s*$' -or $config -notmatch 'f0e59ec4-effb-4002-b9a5-d246965b5b83') { throw 'Unexpected IAP resource. Nothing deployed.' }
        & npx.cmd --yes wrangler@4.151.0 deploy --config $iap --keep-vars
        if ($LASTEXITCODE -ne 0) { throw 'IAP deployment failed; rerun the same batch launcher.' }
        Write-Host 'LIVEOPS_IAP_DEPLOY=PASS; INDEXES=ADDITIVE_ONLY; EVENT_ACTIVATION=NONE'
    }
    if ($Target -in @('profile','all')) {
        if (-not (Test-Path -LiteralPath $profile)) { throw 'Existing wrangler.local.toml is missing. Restore the established local profile configuration; do not create a new service/database.' }
        $config=[IO.File]::ReadAllText($profile)
        if ($config -notmatch '(?m)^name\s*=\s*"jade-ascendant-player"\s*$' -or $config -notmatch '1089de95-8cdc-447d-a9e3-9e743d200cba') { throw 'Unexpected profile resource. Nothing deployed.' }
        & node backend/player_identity/build_mail_assets.mjs
        if ($LASTEXITCODE -ne 0) { throw 'Existing dashboard icon bundle failed; completed IAP stage retained.' }
        & npx.cmd --yes wrangler@4.151.0 deploy --config $profile --keep-vars
        if ($LASTEXITCODE -ne 0) { throw 'Profile deployment failed; the batch retains completed IAP deployment.' }
        Write-Host 'LIVEOPS_PROFILE_DEPLOY=PASS; ADMIN_AUTH=UNCHANGED'
    }
    Write-Host 'LIVEOPS_CONTROL_DEPLOY=PASS; CLIENT_NATIVE_AAB=UNCHANGED; BROADCAST=NONE'
    Write-Host 'Open the established dashboard launcher, then Heavenly Trials (/admin/trials).'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }

param([Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{40}$')][string]$ExpectedCommit,[switch]$ValidateOnly)
$ErrorActionPreference='Stop'
$project=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $project
try {
    $head=(& git rev-parse HEAD).Trim()
    $branch=(& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or $head -ne $ExpectedCommit -or $branch -ne 'checkpoint/iap-fasttrack-20261010') { throw 'Exact reviewed checkpoint required. No deployment attempted.' }
    $dirty=@(& git diff HEAD --name-only -- backend | Where-Object { $_ -ne 'backend/monetization/cloudflare/wrangler.production-live.toml' })
    if ($LASTEXITCODE -ne 0 -or $dirty.Count) { throw 'Local backend edits preserved. No deployment attempted.' }
    & node backend/player_identity/production_release_contract.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Existing nine production gates changed.' }
    $config=Join-Path $PSScriptRoot 'wrangler.local.toml'
    $text=[IO.File]::ReadAllText($config)
    if ([regex]::Matches($text,'(?m)^database_id\s*=').Count -ne 1 -or $text -notmatch '(?m)^name\s*=\s*"jade-ascendant-player"\s*$' -or $text -notmatch '(?m)^database_id\s*=\s*"1089de95-8cdc-447d-a9e3-9e743d200cba"\s*$' -or $text -notmatch '(?m)^binding\s*=\s*"PROFILE_DB"\s*$' -or $text -notmatch '(?m)^main\s*=\s*"(?:\./)?worker\.mjs"\s*$') { throw 'Existing Profile service/database/main required. Config is never overwritten.' }
    if ($ValidateOnly) { Write-Host 'RELEASE_POLICY_PREFLIGHT=PASS; DEPLOY=NONE; SCHEMA=UNCHANGED'; exit 0 }
    $folder=Join-Path $project ('.local/release_policy_deploy/'+$ExpectedCommit)
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    $receiptPath=Join-Path $folder 'profile.json'
    if (Test-Path -LiteralPath $receiptPath) {
        $receipt=[IO.File]::ReadAllText($receiptPath) | ConvertFrom-Json
        if ($receipt.commit -ne $ExpectedCommit -or $receipt.worker -ne 'jade-ascendant-player' -or -not $receipt.version_id) { throw 'Deployment receipt differs; preserved for review.' }
        Write-Host ('RELEASE_POLICY_RESUME_SKIP=profile; VERSION='+$receipt.version_id)
    } else {
        & node backend/player_identity/build_mail_assets.mjs
        if ($LASTEXITCODE -ne 0) { throw 'Existing dashboard assets could not be prepared.' }
        # Wrangler writes harmless diagnostics to stderr on Windows PowerShell.
        # Preserve them while checking its actual exit code; do not treat a warning as failure.
        $previous=$ErrorActionPreference
        try {
            $ErrorActionPreference='Continue'
            $lines=@(& npx.cmd --yes wrangler@4.151.0 deploy --keep-vars --config $config 2>&1)
            $code=$LASTEXITCODE
        } finally { $ErrorActionPreference=$previous }
        $output=($lines | ForEach-Object { $_.ToString() }) -join "`n"
        [IO.File]::WriteAllText((Join-Path $folder 'deploy.log'),$output,(New-Object Text.UTF8Encoding($false)))
        $lines | ForEach-Object { Write-Host $_ }
        if ($code -ne 0) { throw ('Profile deploy failed (exit '+$code+'); log and completed stages retained.') }
        $version=[regex]::Match($output,'Current Version ID:\s*([a-f0-9-]{36})')
        if (-not $version.Success) { throw 'No deployment version receipt. Inspect deploy.log; no success is asserted.' }
        $receipt=@{commit=$ExpectedCommit;worker='jade-ascendant-player';version_id=$version.Groups[1].Value;deployed_at_utc=[DateTime]::UtcNow.ToString('o');schema='unchanged';iap_worker='unchanged';notifications_sent=$false} | ConvertTo-Json
        [IO.File]::WriteAllText(($receiptPath+'.tmp'),$receipt,(New-Object Text.UTF8Encoding($false)))
        Move-Item -LiteralPath ($receiptPath+'.tmp') -Destination $receiptPath -Force
    }
    $previousOptions=$env:NODE_OPTIONS
    try {
        $env:NODE_OPTIONS=$null
        & node backend/player_identity/check_player_trust_public.cjs
        if ($LASTEXITCODE -ne 0) { throw 'Exact public policy/deletion content not yet verified. Profile receipt retained; rerun without redeploying.' }
    } finally { $env:NODE_OPTIONS=$previousOptions }
    Write-Host 'RELEASE_POLICY_DEPLOY=PASS; PUBLIC_CONTENT=VERIFIED; PROFILE_ONLY; VARS=RETAINED; SCHEMA=UNCHANGED; IAP_WORKER=UNCHANGED; NO_PUSH_SENT'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }

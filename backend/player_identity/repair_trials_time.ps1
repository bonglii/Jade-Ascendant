param([string]$CampaignId = '')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $repo
try {
    & node.exe backend/player_identity/production_release_contract.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Production contract failed. No data changed.' }
    $config = Join-Path $repo 'backend/monetization/cloudflare/wrangler.production-live.toml'
    $configText = [IO.File]::ReadAllText($config)
    if ($configText -notmatch 'f0e59ec4-effb-4002-b9a5-d246965b5b83') { throw 'Unexpected database. Nothing changed.' }
    $folder = Join-Path $repo '.local/trials_time_repair'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $encoding = New-Object Text.UTF8Encoding($false)
    function Read-Remote([string]$Sql, [string]$Output) {
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { $lines = @(& npx.cmd --yes wrangler@4.151.0 d1 execute jade-iap-ledger --remote --config $config --command $Sql --json 2> (Join-Path $folder 'query-error.log')); $code = $LASTEXITCODE }
        finally { $ErrorActionPreference = $previous }
        if ($code -ne 0) { throw ('D1 read failed; inspect ' + (Join-Path $folder 'query-error.log')) }
        [IO.File]::WriteAllText($Output, ($lines -join "`n"), $encoding)
    }
    $plan = Join-Path $folder 'plan.json'
    if (-not (Test-Path -LiteralPath $plan)) {
        $snapshot = Join-Path $folder 'before.json'
        if (Test-Path -LiteralPath $snapshot) { Copy-Item -LiteralPath $snapshot -Destination (Join-Path $folder ('before-' + [Guid]::NewGuid().ToString('N') + '.json')) }
        $snapshotSql = @(& node.exe backend/player_identity/repair_trials_time.mjs snapshot-query)
        if ($LASTEXITCODE -ne 0) { throw 'Snapshot query preparation failed. No data changed.' }
        Read-Remote ($snapshotSql -join "`n") $snapshot
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { $planOutput = @(& node.exe backend/player_identity/repair_trials_time.mjs prepare $snapshot $folder $CampaignId 2>&1); $planCode = $LASTEXITCODE }
        finally { $ErrorActionPreference = $previous }
        $planText = ($planOutput | ForEach-Object { $_.ToString() }) -join "`n"
        [IO.File]::WriteAllText((Join-Path $folder 'plan-output.log'), $planText, $encoding)
        if ($planCode -ne 0) { throw ('Schedule preparation failed: ' + $planText + '. No data changed.') }
        Write-Output $planText
    }
    $verify = Join-Path $folder 'verify.sql'
    $planData = [IO.File]::ReadAllText($plan) | ConvertFrom-Json
    if ($planData.kind -eq 'skip' -and (Test-Path -LiteralPath (Join-Path $folder 'done.json'))) {
        Write-Output 'TRIALS_TIME_SKIPPED=NO_CAMPAIGNS_AT_PREVIOUS_CHECK; DATABASE_WRITE=NONE; NEW_CONFIG=UNCHANGED'
        return
    }
    if ($planData.kind -ne 'skip' -and -not (Test-Path -LiteralPath (Join-Path $folder 'done.json'))) {
        & npx.cmd --yes wrangler@4.151.0 d1 execute jade-iap-ledger --remote --config $config --file (Join-Path $folder 'repair.sql') --yes
        if ($LASTEXITCODE -ne 0) { throw 'Schedule write failed. Backups and plan retained; existing player progress is unchanged.' }
    }
    $after = Join-Path $folder 'after.json'
    Read-Remote ([IO.File]::ReadAllText($verify)) $after
    & node.exe backend/player_identity/repair_trials_time.mjs verify $after $folder
    if ($LASTEXITCODE -ne 0) { throw 'Schedule verification failed. Backup retained; no automatic overwrite of newer edits.' }
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }

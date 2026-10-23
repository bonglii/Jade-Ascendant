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
        Read-Remote "SELECT c.id,c.document,c.created_at,(SELECT COUNT(*) FROM ht_weeks w WHERE w.campaign=c.id) AS materialized_weeks,unixepoch('now') AS server_now FROM ht_campaigns c ORDER BY created_at DESC" $snapshot
        & node.exe backend/player_identity/repair_trials_time.mjs prepare $snapshot $folder $CampaignId
        if ($LASTEXITCODE -ne 0) { throw 'Schedule plan could not be prepared. No data changed.' }
    }
    $verify = Join-Path $folder 'verify.sql'
    if (-not (Test-Path -LiteralPath (Join-Path $folder 'done.json'))) {
        & npx.cmd --yes wrangler@4.151.0 d1 execute jade-iap-ledger --remote --config $config --file (Join-Path $folder 'repair.sql') --yes
        if ($LASTEXITCODE -ne 0) { throw 'Schedule write failed. Backups and plan retained; existing player progress is unchanged.' }
    }
    $after = Join-Path $folder 'after.json'
    Read-Remote ([IO.File]::ReadAllText($verify)) $after
    & node.exe backend/player_identity/repair_trials_time.mjs verify $after $folder
    if ($LASTEXITCODE -ne 0) { throw 'Schedule verification failed. Backup retained; no automatic overwrite of newer edits.' }
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }

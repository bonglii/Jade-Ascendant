$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$config=Join-Path $repo 'backend/monetization/cloudflare/wrangler.gameplay-staging.toml'
try {
    $text=[IO.File]::ReadAllText($config)
    if ($text -notmatch '(?m)^name\s*=\s*"jade-ascendant-iap-staging"\s*$' -or
        $text -notmatch 'c7c9841f-cbd3-4563-b13f-21ed90d45120' -or
        $text -notmatch '(?m)^JADE_STAGING_ACCOUNT_GUARD\s*=\s*"true"\s*$' -or
        $text -notmatch '(?m)^main\s*=\s*"src/worker_staging_tester_r1.mjs"\s*$') { throw 'Unexpected staging target. No remote command was run.' }
    $migrations=@(Get-ChildItem -LiteralPath (Join-Path $repo 'backend/monetization/cloudflare/migrations') -Filter '*.sql' | Sort-Object Name)
    if ($migrations.Count -ne 12 -or $migrations[-1].Name -ne '0012_paid_runs_v2.sql') { throw 'Unexpected migration set. Nothing deployed.' }
    $commands=@()
    foreach ($file in $migrations) {
        $sql=([regex]::Replace([IO.File]::ReadAllText($file.FullName),'(?m)^\s*--[^\r\n]*','')).Trim()
        if ($sql -match '(?i)\b(DROP|DELETE|ALTER|ATTACH|DETACH|REPLACE)\b' -or $sql -match '(?i)\b(INSERT|UPDATE)\s+(?:INTO\s+)?iap_') { throw ('Non-additive migration refused: '+$file.Name) }
        $commands+=@{Name=$file.Name;Sql=$sql}
    }
    $npx=(Get-Command npx.cmd -ErrorAction Stop).Source
    foreach ($migration in $commands) {
        Write-Host ('STAGING_SCHEMA='+$migration.Name)
        & $npx --yes wrangler@4 d1 execute jade-iap-ledger-staging --remote --config $config --command $migration.Sql
        if ($LASTEXITCODE -ne 0) { throw 'Staging schema failed. Worker was not deployed; existing player data is preserved.' }
    }
    & $npx --yes wrangler@4 deploy --config $config
    if ($LASTEXITCODE -ne 0) { throw 'Staging deployment failed. No production configuration was used.' }
    Write-Host 'IAP_GAMEPLAY_STAGING_DEPLOY=PASS; PRODUCTION=UNCHANGED'
    Write-Host 'Wait for the next successful refund cron (up to 15 minutes). No fake readiness watermark is written.'
} catch {Write-Error $_ -ErrorAction Continue;exit 1}

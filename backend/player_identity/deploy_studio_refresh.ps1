param([Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{40}$')][string]$ExpectedCommit,[switch]$ValidateOnly)
$ErrorActionPreference='Stop'
$project=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $project
try {
    $branch=(& git branch --show-current).Trim()
    $source=(& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $branch -ne 'checkpoint/iap-fasttrack-20261010' -or $source -ne $ExpectedCommit) { throw 'Source commit/branch differs. No deployment attempted.' }
    $backendEdits=@(& git diff HEAD --name-only -- backend)
    $unknownBackendEdits=@($backendEdits | Where-Object { $_ -ne 'backend/monetization/cloudflare/wrangler.production-live.toml' })
    if ($LASTEXITCODE -ne 0 -or $unknownBackendEdits.Count -gt 0) { throw 'Local server edits are preserved. Deploy only the exact reviewed backend commit.' }
    # The owner may retain equivalent local IAP configuration. Validate its nine
    # gates; never copy, overwrite or deploy that separate Worker here.
    & node backend/player_identity/production_release_contract.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Existing nine production gates changed; deployment stopped.' }
    $receiptPath=Join-Path $project '.local/studio_refresh_deploy/receipt.json'
    if (Test-Path -LiteralPath $receiptPath) {
        $receipt=Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
        if ($receipt.commit -eq $source -and $receipt.worker -eq 'jade-ascendant-player' -and $receipt.version_id) {
            Write-Host ('STUDIO_DEPLOY_RESUME_SKIP=profile; VERSION='+$receipt.version_id)
            exit 0
        }
    }
    $config=Join-Path $PSScriptRoot 'wrangler.local.toml'
    if (-not (Test-Path -LiteralPath $config)) { throw 'Existing Profile wrangler.local.toml is missing. No config was created.' }
    $text=[IO.File]::ReadAllText($config)
    if ($text -notmatch '(?m)^name\s*=\s*"jade-ascendant-player"\s*$' -or $text -notmatch '1089de95-8cdc-447d-a9e3-9e743d200cba' -or $text -notmatch '(?m)^main\s*=\s*"(?:\./)?worker\.mjs"\s*$') { throw 'Unexpected Profile Worker/database/main. No deployment attempted.' }
    if ($ValidateOnly) { Write-Host 'STUDIO_DEPLOY_PREFLIGHT=PASS; DEPLOY=NONE; SCHEMA=UNCHANGED'; exit 0 }
    $tests=@(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.test.mjs' | ForEach-Object { $_.FullName })
    & node --test --test-concurrency=1 @tests
    if ($LASTEXITCODE -ne 0) { throw 'Profile regression failed; no deployment attempted.' }
    & node backend/player_identity/build_mail_assets.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Existing icon preparation failed; no deployment attempted.' }
    $lines=@(& npx.cmd --yes wrangler@4.151.0 deploy --keep-vars --config $config 2>&1)
    $code=$LASTEXITCODE
    $logDir=Join-Path $project '.local/studio_refresh_deploy'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $output=$lines -join [Environment]::NewLine
    [IO.File]::WriteAllText((Join-Path $logDir 'deploy.log'),$output)
    $lines | ForEach-Object { Write-Host $_ }
    if ($code -ne 0) { throw 'Profile deployment failed. Completed install/publish stages retained.' }
    $match=[regex]::Match($output,'Current Version ID:\s*([a-f0-9-]{36})')
    if (-not $match.Success) { throw 'Wrangler returned success but no version receipt. Inspect the saved log; deployment is not asserted.' }
    $body=@{commit=$source;worker='jade-ascendant-player';version_id=$match.Groups[1].Value;deployed_at_utc=[DateTime]::UtcNow.ToString('o');schema='unchanged';iap_worker='unchanged';events_started=$false;notifications_sent=$false} | ConvertTo-Json
    $temp=$receiptPath+'.tmp'
    [IO.File]::WriteAllText($temp,$body)
    Move-Item -LiteralPath $temp -Destination $receiptPath -Force
    Write-Host 'STUDIO_PROFILE_DEPLOY=PASS; TIMEZONE=WIB; VARS=RETAINED; SCHEMA=UNCHANGED; IAP_WORKER=UNCHANGED; EVENTS_NOT_STARTED; NOTIFICATIONS_NOT_SENT'
    Write-Host 'Dashboard: https://jade-ascendant-player.jade-ascendant-studio.workers.dev/admin'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }

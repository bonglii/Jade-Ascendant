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
    $receiptPath=Join-Path $project '.local/release_comfort_deploy/receipt.json'
    if (Test-Path -LiteralPath $receiptPath) {
        $receipt=Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
        if ($receipt.commit -eq $source -and $receipt.worker -eq 'jade-ascendant-player' -and $receipt.version_id) {
            Write-Host ('COMFORT_DEPLOY_RESUME_SKIP=profile; VERSION='+$receipt.version_id)
            exit 0
        }
    }
    $config=Join-Path $PSScriptRoot 'wrangler.local.toml'
    if (-not (Test-Path -LiteralPath $config)) { throw 'Existing Profile wrangler.local.toml is missing. No config was created.' }
    $text=[IO.File]::ReadAllText($config)
    if ($text -notmatch '(?m)^name\s*=\s*"jade-ascendant-player"\s*$' -or $text -notmatch '1089de95-8cdc-447d-a9e3-9e743d200cba' -or $text -notmatch '(?m)^main\s*=\s*"(?:\./)?worker\.mjs"\s*$') { throw 'Unexpected Profile Worker/database/main. No deployment attempted.' }
    if ($ValidateOnly) { Write-Host 'COMFORT_DEPLOY_PREFLIGHT=PASS; DEPLOY=NONE; SCHEMA=ADDITIVE_NOT_APPLIED'; exit 0 }
    # The publisher/CI validate source before deployment. This additive schema
    # is safely repeatable after interruption and preserves all existing records.
    $schema=Join-Path $PSScriptRoot 'announcement_schema.sql'
    $schemaLines=@(& npx.cmd --yes wrangler@4.151.0 d1 execute jade-player-identities --remote --config $config --file $schema --yes 2>&1)
    $schemaCode=$LASTEXITCODE
    $schemaLines | ForEach-Object { Write-Host $_ }
    if ($schemaCode -ne 0) { throw 'Announcement presentation schema failed; no Worker deployment attempted. Rerun this same launcher.' }
    Write-Host 'COMFORT_ANNOUNCEMENT_SCHEMA=PASS; EXISTING_MAIL_AND_READS=PRESERVED'
    & node backend/player_identity/build_mail_assets.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Existing icon preparation failed; no deployment attempted.' }
    $lines=@(& npx.cmd --yes wrangler@4.151.0 deploy --keep-vars --config $config 2>&1)
    $code=$LASTEXITCODE
    $logDir=Join-Path $project '.local/release_comfort_deploy'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $output=$lines -join [Environment]::NewLine
    [IO.File]::WriteAllText((Join-Path $logDir 'deploy.log'),$output)
    $lines | ForEach-Object { Write-Host $_ }
    if ($code -ne 0) { throw 'Profile deployment failed. Completed install/publish stages retained.' }
    $match=[regex]::Match($output,'Current Version ID:\s*([a-f0-9-]{36})')
    if (-not $match.Success) { throw 'Wrangler returned success but no version receipt. Inspect the saved log; deployment is not asserted.' }
    $body=@{commit=$source;worker='jade-ascendant-player';version_id=$match.Groups[1].Value;deployed_at_utc=[DateTime]::UtcNow.ToString('o');schema='announcement_presentation_additive';iap_worker='unchanged';events_started=$false;notifications_sent=$false} | ConvertTo-Json
    $temp=$receiptPath+'.tmp'
    [IO.File]::WriteAllText($temp,$body)
    Move-Item -LiteralPath $temp -Destination $receiptPath -Force
    Write-Host 'COMFORT_PROFILE_DEPLOY=PASS; TIMEZONE=WIB; VARS=RETAINED; SCHEMA=ADDITIVE; IAP_WORKER=UNCHANGED; EVENTS_NOT_STARTED; NOTIFICATIONS_NOT_SENT'
    Write-Host 'Dashboard: https://jade-ascendant-player.jade-ascendant-studio.workers.dev/admin'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }

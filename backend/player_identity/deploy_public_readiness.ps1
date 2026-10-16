$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $repo
try {
    $node = (Get-Command node.exe -ErrorAction Stop).Source
    $npx = (Get-Command npx.cmd -ErrorAction Stop).Source
    $profileConfig = Join-Path $PSScriptRoot 'wrangler.local.toml'
    if (-not (Test-Path -LiteralPath $profileConfig)) { throw 'Existing profile wrangler.local.toml is required. No replacement database/account is created.' }
    $profile = [IO.File]::ReadAllText($profileConfig)
    if ([regex]::Matches($profile,'(?m)^database_id\s*=').Count -ne 1) { throw 'Exactly the existing profile database binding is required.' }
    foreach ($required in @('(?m)^name\s*=\s*"jade-ascendant-player"\s*$','(?m)^database_id\s*=\s*"1089de95-8cdc-447d-a9e3-9e743d200cba"\s*$','(?m)^binding\s*=\s*"PROFILE_DB"\s*$','(?m)^\[vars\]\s*$','(?m)^binding\s*=\s*"ASSETS"\s*$')) {
        if ($profile -notmatch $required) { throw 'Unexpected profile configuration. Nothing deployed.' }
    }
    $liveConfig = Join-Path $repo 'backend/monetization/cloudflare/wrangler.production-live.toml'
    $contract = Join-Path $PSScriptRoot 'production_release_contract.mjs'
    & $node $contract
    if ($LASTEXITCODE -ne 0) { throw 'Reviewed production configuration is required.' }
    $sql = @(& $node $contract sql) -join ''
    if ($LASTEXITCODE -ne 0) { throw 'Cannot generate read-only readiness query.' }
    $readiness = @(& $npx --yes wrangler@4.151.0 d1 execute jade-iap-ledger --remote --config $liveConfig --command $sql --json)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read production schema/refund state. No deployment was started.' }
    $work = Join-Path $repo ('.local/public_readiness_deploy/' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    $report = Join-Path $work 'readiness.json'
    [IO.File]::WriteAllText($report,($readiness -join "`n"),(New-Object Text.UTF8Encoding($false)))
    & $node $contract readiness $report
    if ($LASTEXITCODE -ne 0) { throw 'Fresh real refund polling and existing schema are required. No fake watermark or migration is written.' }
    $secretsRaw = @(& $npx --yes wrangler@4.151.0 secret list --config $liveConfig)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect production secret names.' }
    $secrets = ($secretsRaw -join "`n") | ConvertFrom-Json
    if (@($secrets | Where-Object { $_.name -eq 'PLAY_SERVICE_ACCOUNT_JSON' }).Count -ne 1) { throw 'Existing production Play secret is required. This launcher does not replace credentials.' }
    & $node (Join-Path $PSScriptRoot 'build_mail_assets.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'Existing profile/dashboard assets could not be prepared.' }
    $schema = [regex]::Replace([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'progress_backup_schema.sql')),'\s+',' ').Trim()
    & $npx --yes wrangler@4.151.0 d1 execute PROFILE_DB --remote --config $profileConfig --command $schema
    if ($LASTEXITCODE -ne 0) { throw 'Progress backup schema failed. No Worker was deployed; existing tables are preserved.' }
    Copy-Item -LiteralPath $profileConfig -Destination (Join-Path $work 'profile-config-before.toml')
    if ($profile -match '(?m)^JADE_PROGRESS_BACKUP_ENABLED\s*=') {
        $profile = [regex]::Replace($profile,'(?m)^JADE_PROGRESS_BACKUP_ENABLED\s*=\s*"(?:true|false)"\s*$','JADE_PROGRESS_BACKUP_ENABLED = "true"')
    } else { $profile = [regex]::Replace($profile,'(?m)^\[vars\]\s*$',('[vars]' + "`n" + 'JADE_PROGRESS_BACKUP_ENABLED = "true"')) }
    if ($profile -notmatch '(?m)^JADE_PROGRESS_BACKUP_ENABLED\s*=\s*"true"\s*$') { throw 'Cannot configure the backup flag safely.' }
    [IO.File]::WriteAllText($profileConfig,$profile,(New-Object Text.UTF8Encoding($false)))
    & $npx --yes wrangler@4.151.0 deploy --config $profileConfig
    if ($LASTEXITCODE -ne 0) { throw 'Profile Worker deployment failed. Existing config backup is retained; no IAP deployment started.' }
    & $npx --yes wrangler@4.151.0 deploy --config $liveConfig
    if ($LASTEXITCODE -ne 0) { throw 'IAP deployment failed. Reviewed live config is retained; never retry using the locked candidate config.' }
    $oldOptions = $env:NODE_OPTIONS
    try {
        $env:NODE_OPTIONS = $null
        & $node (Join-Path $PSScriptRoot 'check_production_backend.cjs')
        if ($LASTEXITCODE -ne 0) { throw 'Production health verification failed. No automatic redeploy or rollback was attempted.' }
    } finally { $env:NODE_OPTIONS = $oldOptions }
    Write-Host 'PUBLIC_READINESS_DEPLOY=PASS; IAP=PRODUCTION_V2; PROGRESS_BACKUP=PROFILE_SERVICE; PURCHASE=NONE'
    Write-Host 'Next: export with backend\player_identity\export_production.cmd. Version/AAB/signing settings remain yours.'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }

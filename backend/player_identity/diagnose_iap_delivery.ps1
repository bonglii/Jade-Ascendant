$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Push-Location $repo
try {
    $config = 'backend/monetization/cloudflare/wrangler.wallet-recovery.toml'
    $configuration = [IO.File]::ReadAllText((Join-Path $repo $config))
    if ($configuration -notmatch 'name = "jade-ascendant-iap-staging"' -or $configuration -notmatch 'database_id = "c7c9841f-cbd3-4563-b13f-21ed90d45120"') { throw 'Unexpected staging service/database. No query executed.' }
    $sql = [IO.File]::ReadAllText((Join-Path $repo 'backend/monetization/cloudflare/delivery_diagnose.sql'))
    if ($sql -notmatch '^WITH records AS' -or $sql -match '(?i)\b(INSERT|UPDATE|DELETE|DROP|ALTER|PRAGMA|ATTACH|REPLACE|CREATE)\b') { throw 'Diagnosis must contain only the approved read query.' }
    $oneLineSql = [regex]::Replace($sql,'\s+',' ').Trim()
    Write-Host 'JADE_IAP_DELIVERY_DIAGNOSIS; MODE=READ_ONLY; STAGING_ONLY; PURCHASE=NONE; DEPLOY=NONE'
    $stderrFile = [IO.Path]::GetTempFileName()
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $raw = @(& npx.cmd --yes wrangler@4 d1 execute jade-iap-ledger-staging --remote --config $config --command $oneLineSql --json 2> $stderrFile)
        $queryExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    try {
        if ($queryExit -ne 0) {
            if (Test-Path -LiteralPath $stderrFile) { Get-Content -LiteralPath $stderrFile | Write-Host }
            $raw | Write-Host
            throw 'Staging ledger query failed. No data changed. See the Wrangler error above.'
        }
    } finally { Remove-Item -LiteralPath $stderrFile -Force -ErrorAction SilentlyContinue }
    $decoded = ($raw -join "`n") | ConvertFrom-Json
    if ($null -eq $decoded) { throw 'D1 returned no structured query result. No zero-balance inference made.' }
    $rows = @()
    foreach ($reply in $decoded) {
        if ($reply.success -ne $true -or $null -eq $reply.PSObject.Properties['results']) { throw 'D1 did not confirm a successful query result.' }
        foreach ($row in $reply.results) {
            if ($null -eq $row.PSObject.Properties['account_ref'] -or $null -eq $row.PSObject.Properties['refund_monitor']) { throw 'D1 returned a summary instead of account rows. No zero-balance inference made.' }
        }
        foreach ($row in $reply.results) { $rows += $row }
    }
    if ($rows.Count -eq 0) { Write-Host 'STAGING_ACCOUNT_ROWS=0; this is not proof that Play checkout did not happen.' }
    else { $rows | Format-Table account_ref,server_balance,verified_purchases,credited_purchases,verified_not_credited,voided_purchases,account_held,refund_monitor -AutoSize }
    $reportDirectory = Join-Path $repo '.local\iap_delivery'
    New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
    $report = Join-Path $reportDirectory 'diagnosis-latest.json'
    $result = @{ mode='read_only_staging'; scope='all_staging_accounts'; utc=[DateTime]::UtcNow.ToString('o'); account_rows=@($rows); purchased_gameplay_ready=$false }
    [IO.File]::WriteAllText($report,($result | ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding($false)))
    Write-Host ('REPORT=' + $report)
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }

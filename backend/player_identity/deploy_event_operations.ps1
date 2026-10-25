param([Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{40}$')][string]$ExpectedCommit,[switch]$ValidateOnly)
$ErrorActionPreference='Stop'
$project=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$encoding=New-Object Text.UTF8Encoding($false)
Push-Location $project
try {
    $head=(& git rev-parse HEAD).Trim()
    $branch=(& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or $head -ne $ExpectedCommit -or $branch -ne 'checkpoint/iap-fasttrack-20261010') { throw 'Exact reviewed commit/branch required. No deploy attempted.' }
    $dirty=@(& git diff HEAD --name-only -- backend | Where-Object { $_ -ne 'backend/monetization/cloudflare/wrangler.production-live.toml' })
    if ($LASTEXITCODE -ne 0 -or $dirty.Count) { throw 'Unreviewed backend edits preserved. No deploy attempted.' }
    & node backend/player_identity/production_release_contract.mjs
    if ($LASTEXITCODE -ne 0) { throw 'The nine existing live payment gates differ.' }
    $iapConfig=Join-Path $project 'backend/monetization/cloudflare/wrangler.production-live.toml'
    $profileConfig=Join-Path $PSScriptRoot 'wrangler.local.toml'
    $iapConfigText=[IO.File]::ReadAllText($iapConfig)
    $profileConfigText=[IO.File]::ReadAllText($profileConfig)
    if ($iapConfigText -notmatch '(?m)^name\s*=\s*"jade-ascendant-iap"\s*$' -or $iapConfigText -notmatch 'f0e59ec4-effb-4002-b9a5-d246965b5b83' -or $iapConfigText -notmatch 'main\s*=\s*"src/worker_paid_production_v2.mjs"') { throw 'Unexpected IAP resource or entry point.' }
    if ($profileConfigText -notmatch '(?m)^name\s*=\s*"jade-ascendant-player"\s*$' -or $profileConfigText -notmatch '1089de95-8cdc-447d-a9e3-9e743d200cba' -or $profileConfigText -notmatch 'main\s*=\s*"(?:\./)?worker.mjs"') { throw 'Unexpected Profile resource or entry point.' }
    if ($ValidateOnly) { Write-Host 'EVENT_OPERATIONS_PREFLIGHT=PASS; DEPLOY=NONE; SCHEDULE_WRITE=NONE'; exit 0 }
    $folder=Join-Path $project ('.local/event_operations_deploy/'+$ExpectedCommit)
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    function Invoke-Captured([string]$Executable,[string[]]$NativeArgs,[string]$Name,[switch]$Json) {
        Write-Host ('EVENT_OPERATIONS_STAGE='+$Name)
        $previous=$ErrorActionPreference
        try {
            $ErrorActionPreference='Continue'
            if ($Json) { $lines=@(& $Executable @NativeArgs 2> (Join-Path $folder ($Name+'.stderr.log'))) }
            else { $lines=@(& $Executable @NativeArgs 2>&1) }
            $code=$LASTEXITCODE
        } finally { $ErrorActionPreference=$previous }
        $output=($lines | ForEach-Object { $_.ToString() }) -join "`n"
        [IO.File]::WriteAllText((Join-Path $folder ($Name+'.log')),$output,$encoding)
        if (-not $Json) { $lines | ForEach-Object { Write-Host $_ } }
        if ($code -ne 0) { throw ($Name+' failed (exit '+$code+'). Logs and completed stages retained: '+$folder) }
        return $output
    }
    foreach ($target in @(@{name='iap';worker='jade-ascendant-iap';config=$iapConfig},@{name='profile';worker='jade-ascendant-player';config=$profileConfig})) {
        $receiptPath=Join-Path $folder ($target.name+'.json')
        if (Test-Path -LiteralPath $receiptPath) {
            $receipt=[IO.File]::ReadAllText($receiptPath) | ConvertFrom-Json
            if ($receipt.commit -ne $ExpectedCommit -or $receipt.worker -ne $target.worker -or -not $receipt.version_id) { throw 'Deployment receipt differs. Existing receipt preserved.' }
            Write-Host ('EVENT_OPERATIONS_RESUME_SKIP='+$target.name+'; VERSION='+$receipt.version_id)
            continue
        }
        if ($target.name -eq 'profile') { Invoke-Captured 'node.exe' @('backend/player_identity/build_mail_assets.mjs') 'profile-assets' | Out-Null }
        $output=Invoke-Captured 'npx.cmd' @('--yes','wrangler@4.151.0','deploy','--keep-vars','--config',$target.config) ('deploy-'+$target.name)
        $version=[regex]::Match($output,'Current Version ID:\s*([a-f0-9-]{36})')
        if (-not $version.Success) { throw 'Wrangler success without a version receipt; deployment is not asserted.' }
        $body=@{commit=$ExpectedCommit;worker=$target.worker;version_id=$version.Groups[1].Value;deployed_at_utc=[DateTime]::UtcNow.ToString('o');vars='retained';schema='unchanged'} | ConvertTo-Json
        [IO.File]::WriteAllText(($receiptPath+'.tmp'),$body,$encoding)
        Move-Item -LiteralPath ($receiptPath+'.tmp') -Destination $receiptPath -Force
    }
    # Always read the live calendar again. An old no-op receipt is not evidence
    # that an admin has not changed a schedule since the previous invocation.
    $query=Invoke-Captured 'node.exe' @('backend/player_identity/repair_event_calendar.mjs','snapshot-query') 'calendar-query' -Json
    $before=Invoke-Captured 'npx.cmd' @('--yes','wrangler@4.151.0','d1','execute','jade-iap-ledger','--remote','--config',$iapConfig,'--command',$query,'--json') 'calendar-before' -Json
    $snapshotPath=Join-Path $folder ('before-'+[Guid]::NewGuid().ToString('N')+'.json')
    [IO.File]::WriteAllText($snapshotPath,$before,$encoding)
    Invoke-Captured 'node.exe' @('backend/player_identity/repair_event_calendar.mjs','prepare',$snapshotPath,$folder) 'calendar-plan' | Out-Null
    $plan=[IO.File]::ReadAllText((Join-Path $folder 'plan.json')) | ConvertFrom-Json
    if ($plan.kind -eq 'repair') {
        Invoke-Captured 'npx.cmd' @('--yes','wrangler@4.151.0','d1','execute','jade-iap-ledger','--remote','--config',$iapConfig,'--file',(Join-Path $folder 'repair.sql'),'--yes') 'calendar-time-only-repair' | Out-Null
    }
    $after=Invoke-Captured 'npx.cmd' @('--yes','wrangler@4.151.0','d1','execute','jade-iap-ledger','--remote','--config',$iapConfig,'--command',$query,'--json') 'calendar-after' -Json
    $afterPath=Join-Path $folder 'after.json'
    [IO.File]::WriteAllText($afterPath,$after,$encoding)
    Invoke-Captured 'node.exe' @('backend/player_identity/repair_event_calendar.mjs','verify',$afterPath,$folder) 'calendar-verified' | Out-Null
    Write-Host 'EVENT_OPERATIONS_DEPLOY=PASS; PROFILE_AND_IAP=UPDATED; SCHEMA=UNCHANGED; PAYMENT_GATES=UNCHANGED; NO_EVENT_CREATED; NO_PUSH_SENT'
    Write-Host 'Dashboard: https://jade-ascendant-player.jade-ascendant-studio.workers.dev/admin'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }

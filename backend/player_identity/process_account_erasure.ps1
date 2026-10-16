param([switch]$Apply,[string]$PlanPath='')
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $repo
try {
 $node=(Get-Command node.exe -ErrorAction Stop).Source
 $npx=(Get-Command npx.cmd -ErrorAction Stop).Source
 if(-not $PlanPath){
  Write-Host 'This tool processes an ALREADY VERIFIED support request. It never deletes Firebase Auth or verifies ownership for you.'
  if((Read-Host 'Have you verified the requester owns this Firebase game account? Type VERIFIED') -cne 'VERIFIED'){throw 'Ownership not verified.'}
  $privateUid=Read-Host 'Private Firebase UID from Firebase Auth (NOT the public JA UID)'
  $deletedAt=Read-Host 'When did you delete that exact Firebase Auth user? UTC ISO time, at least 65 minutes ago'
  $inputJson=@{firebase_uid=$privateUid;firebase_deleted_at=$deletedAt;ownership_verified=$true;request_verified=$true}|ConvertTo-Json -Compress
  $previousOutputEncoding=$OutputEncoding
  try{$OutputEncoding=New-Object Text.UTF8Encoding($false);$output=@($inputJson | & $node (Join-Path $PSScriptRoot 'account_erasure.mjs') prepare);$prepareResult=$LASTEXITCODE}finally{$OutputEncoding=$previousOutputEncoding}
  $privateUid=$null; $inputJson=$null
  if($prepareResult -ne 0 -or $output.Count -ne 1){throw 'Cannot prepare verified erasure plan.'}
  $PlanPath=Join-Path ([string]$output[0]) 'plan.json'
 }
 $PlanPath=(Resolve-Path -LiteralPath $PlanPath).Path
 $ownedRoot=[IO.Path]::GetFullPath((Join-Path $repo '.local/account_erasure')).TrimEnd('\')+'\'
 if(-not $PlanPath.StartsWith($ownedRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Only local owned case plans are accepted.'}
 & $node (Join-Path $PSScriptRoot 'account_erasure.mjs') validate $PlanPath
 if($LASTEXITCODE -ne 0){throw 'Erasure plan validation failed.'}
 $plan=[IO.File]::ReadAllText($PlanPath)|ConvertFrom-Json
 if(([DateTime]::UtcNow-[DateTime]::Parse($plan.firebase_deleted_at).ToUniversalTime()).TotalMinutes -lt 65){throw 'Wait 65 minutes after Firebase Auth deletion.'}
 $profile=Join-Path $PSScriptRoot 'wrangler.local.toml'
 $iap=Join-Path $repo 'backend/monetization/cloudflare/wrangler.production-live.toml'
 $profileText=[IO.File]::ReadAllText($profile);$iapText=[IO.File]::ReadAllText($iap)
 if($profileText -notmatch '(?m)^name\s*=\s*"jade-ascendant-player"\s*$' -or $profileText -notmatch '(?m)^database_id\s*=\s*"1089de95-8cdc-447d-a9e3-9e743d200cba"\s*$' -or [regex]::Matches($profileText,'(?m)^database_id\s*=').Count -ne 1){throw 'Unexpected profile database configuration.'}
 & $node (Join-Path $PSScriptRoot 'production_release_contract.mjs')
 if($LASTEXITCODE -ne 0){throw 'Unexpected production IAP configuration.'}
 function Read-AccountCounts([string]$Config,[string]$Database,[string]$Sql){
  $raw=@(& $npx --yes wrangler@4.151.0 d1 execute $Database --remote --config $Config --command $Sql --json)
  if($LASTEXITCODE -ne 0){throw 'Read-only account check failed.'}
  $decoded=($raw -join "`n")|ConvertFrom-Json
  if(@($decoded).Count -ne 1 -or $decoded[0].success -ne $true -or @($decoded[0].results).Count -ne 1){throw 'Unexpected account check response.'}
  return $decoded[0].results[0]
 }
 $beforeProfile=Read-AccountCounts $profile 'PROFILE_DB' $plan.profile_check
 $beforeIap=Read-AccountCounts $iap 'jade-iap-ledger' $plan.iap_check
 Write-Host ('CASE='+$plan.case_id+'; PROFILE_ROWS='+$beforeProfile.remaining_account_rows+'; PUBLIC_UID='+$beforeProfile.public_uid+'; GAMEPLAY_ROWS='+$beforeIap.remaining_gameplay_rows)
 if(-not $Apply){Write-Host ('MODE=READ_ONLY; No D1 data changed. Review case ownership/retention, then rerun with -Apply -PlanPath "'+$PlanPath+'"');exit 0}
 if((Read-Host ('Irreversible removal for this verified case only. Type ERASE '+$plan.case_id)) -cne ('ERASE '+$plan.case_id)){throw 'Erasure cancelled. No D1 data changed.'}
 $caseDir=Split-Path -Parent $PlanPath
 foreach($target in @('iap','profile')){
  $sqlPath=Join-Path $caseDir ($target+'.sql')
  $sql=[string]$plan.($target+'_sql')
  [IO.File]::WriteAllText($sqlPath,$sql,(New-Object Text.UTF8Encoding($false)))
  $config=$iap;$db='jade-iap-ledger';if($target -eq 'profile'){$config=$profile;$db='PROFILE_DB'}
  & $npx --yes wrangler@4.151.0 d1 execute $db --remote --config $config --file $sqlPath
  if($LASTEXITCODE -ne 0){throw ('Erasure stopped at '+$target+'. The two services are not one atomic transaction; retain this case and rerun after resolving the error. Do not mark complete.')}
 }
 $afterProfile=Read-AccountCounts $profile 'PROFILE_DB' $plan.profile_check
 $afterIap=Read-AccountCounts $iap 'jade-iap-ledger' $plan.iap_check
 if($afterProfile.remaining_account_rows -ne 0 -or $afterIap.remaining_gameplay_rows -ne 0){throw 'Remaining account rows found. Do not mark the request complete.'}
 [IO.File]::WriteAllText((Join-Path $caseDir 'completion.json'),(@{case_id=$plan.case_id;completed_at=[DateTime]::UtcNow.ToString('o');profile_rows=0;gameplay_rows=0;firebase_deletion_evidence='operator_attested';retained='limited financial/refund/security evidence, subject to case retention review'}|ConvertTo-Json),(New-Object Text.UTF8Encoding($false)))
 Write-Host 'D1_ACCOUNT_ERASURE=VERIFIED; FIREBASE_AUTH_DELETION=OPERATOR_ATTESTED; FINANCIAL_LEDGER=NOT_MODIFIED; OTHER_PLAYERS=OUTSIDE_SCOPE'
} catch {Write-Error $_ -ErrorAction Continue;exit 1} finally {Pop-Location}

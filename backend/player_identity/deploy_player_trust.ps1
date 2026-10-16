$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $repo
try {
 $node=(Get-Command node.exe -ErrorAction Stop).Source
 $npx=(Get-Command npx.cmd -ErrorAction Stop).Source
 $config=Join-Path $PSScriptRoot 'wrangler.local.toml'
 $text=[IO.File]::ReadAllText($config)
 foreach($pattern in @('(?m)^name\s*=\s*"jade-ascendant-player"\s*$','(?m)^database_id\s*=\s*"1089de95-8cdc-447d-a9e3-9e743d200cba"\s*$','(?m)^binding\s*=\s*"PROFILE_DB"\s*$','(?m)^binding\s*=\s*"ASSETS"\s*$','(?m)^JADE_PROGRESS_BACKUP_ENABLED\s*=\s*"true"\s*$')){
  if($text -notmatch $pattern){throw 'Expected existing profile/mail/backup configuration is required. No config, schema or IAP service changed.'}
 }
 if([regex]::Matches($text,'(?m)^database_id\s*=').Count -ne 1){throw 'Unexpected profile database inventory.'}
 & $node (Join-Path $PSScriptRoot 'build_trust_pages.mjs')
 if($LASTEXITCODE -ne 0){throw 'Policy generation failed.'}
 & $node (Join-Path $PSScriptRoot 'build_mail_assets.mjs')
 if($LASTEXITCODE -ne 0){throw 'Existing dashboard assets could not be prepared.'}
 & $npx --yes wrangler@4.151.0 deploy --config $config
 if($LASTEXITCODE -ne 0){throw 'Profile Worker deployment failed. No IAP deployment/schema/erasure was attempted.'}
 $previousOptions=$env:NODE_OPTIONS
 try{
  $env:NODE_OPTIONS=$null
  & $node (Join-Path $PSScriptRoot 'check_player_trust_public.cjs')
  if($LASTEXITCODE -ne 0){throw 'Public policy/deletion verification failed. Do not submit these URLs in Console until they verify.'}
 }finally{$env:NODE_OPTIONS=$previousOptions}
 Write-Host 'PLAYER_TRUST_DEPLOY=PASS; PUBLIC_POLICY=VERIFIED; ACCOUNT_DELETION=SUPPORT_REQUEST; ERASURE=NONE; IAP_DEPLOY=NONE; SCHEMA=UNCHANGED'
 Write-Host 'Next: export the combined Android release using backend\player_identity\export_production.cmd. No repeat purchase is required.'
} catch {Write-Error $_ -ErrorAction Continue;exit 1} finally {Pop-Location}

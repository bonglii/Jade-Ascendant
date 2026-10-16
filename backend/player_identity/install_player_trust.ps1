param([string]$Project='D:\Godot\project\jade-ascendant',[string]$PackageRoot=$PSScriptRoot,[switch]$ValidateOnly)
$ErrorActionPreference='Stop'
$allowedPathsHash='b918daae4776de31b96e8a20c5f96d2b7e77481261b7ca1583e9eb67edf10a6b'
function Hash-Path([string]$Path,[string]$Mode){
 if($Mode -eq 'binary'){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
 if($Mode -ne 'text'){throw 'Unknown checksum mode.'}
 $sha=[Security.Cryptography.SHA256]::Create()
 try{return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($Path).Replace("`r`n","`n"))))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
$pushed=$false
try{
 $PackageRoot=(Resolve-Path -LiteralPath $PackageRoot).Path
 $pathFile=Join-Path $PackageRoot 'payload/backend/player_identity/player_trust_paths.json'
 if((Hash-Path $pathFile 'text') -ne $allowedPathsHash){throw 'Unexpected package path inventory.'}
 $decodedPaths=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($pathFile))
 $allowed=@();foreach($path in $decodedPaths){$allowed+=$path}
 $decoded=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $PackageRoot 'files.json')))
 $entries=@();foreach($item in $decoded){$entries+=$item}
 if($entries.Count -ne $allowed.Count){throw ('Invalid package manifest: expected '+$allowed.Count+', read '+$entries.Count+'. No project files changed.')}
 $seen=@{}
 foreach($entry in $entries){
  if($entry.path -notmatch '^[A-Za-z0-9_./-]+$' -or $entry.path -match '(^|/)\.\.(/|$)' -or $allowed -notcontains $entry.path -or $seen.ContainsKey($entry.path)){throw 'Unexpected package path.'}
  $seen[$entry.path]=$true
  $mode='text';if($entry.path.EndsWith('.aar')){$mode='binary'}
  if($entry.mode -ne $mode -or $entry.after -notmatch '^[a-f0-9]{64}$' -or ($null -ne $entry.before -and $entry.before -notmatch '^[a-f0-9]{64}$')){throw 'Invalid package checksums.'}
  if((Hash-Path (Join-Path (Join-Path $PackageRoot 'payload') $entry.path) $mode) -ne $entry.after){throw ('Payload differs: '+$entry.path)}
 }
 Write-Host ('PLAYER_TRUST_PACKAGE_PATHS='+$entries.Count+'; CHECKSUMS=PASS')
 if($ValidateOnly){Write-Host 'PACKAGE_VALIDATION=PASS; INSTALL=PUBLISH=DEPLOY=ERASURE=NONE';exit 0}
 $repo=(Resolve-Path -LiteralPath $Project).Path
 Push-Location $repo;$pushed=$true
 $branch=(& git branch --show-current)
 if($LASTEXITCODE -ne 0 -or ([string]$branch).Trim() -ne 'checkpoint/iap-fasttrack-20261010'){throw 'Unexpected branch. No project files changed.'}
 $origin=(& git remote get-url origin)
 if($LASTEXITCODE -ne 0 -or ([string]$origin).Trim() -notmatch '^https://github\.com/bonglii/Jade-Ascendant(?:\.git)?$|^git@github\.com:bonglii/Jade-Ascendant(?:\.git)?$'){throw 'Unexpected repository.'}
 $lock=(& git rev-parse --git-path index.lock)
 if($LASTEXITCODE -ne 0 -or (Test-Path -LiteralPath ([string]$lock).Trim())){throw 'Git lock is present or cannot be inspected. Close its owning process; no lock is deleted.'}
 if(@(Get-Process | Where-Object { $_.ProcessName -match '^(godot|Godot_v)' }).Count -gt 0){throw 'Close Godot before installing. No files changed.'}
 if(Test-Path -LiteralPath (Join-Path $repo '.local/production_native_export/active.json')){throw 'Recover the old export first: backend\player_identity\recover_production_export.cmd. No files changed.'}
 $lessonPath='docs/checkpoints/LESSONS.md';$lessonMarker='Player trust and ad privacy'
 $lesson=[IO.File]::ReadAllText((Join-Path $PackageRoot 'LESSON.txt'))
 if(-not $lesson.Contains($lessonMarker)){throw 'Invalid lesson appendix.'}
 $mergeLessons=$false;$observed=@{}
 foreach($entry in $entries){
  $target=Join-Path $repo $entry.path;$current=$null
  if(Test-Path -LiteralPath $target){
   $current=Hash-Path $target $entry.mode
   if($current -ne $entry.before -and $current -ne $entry.after){
    if($entry.path -eq $lessonPath){$mergeLessons=$true}else{throw ('Local file differs: '+$entry.path+'; no project files overwritten.')}
   }
  }elseif($null -ne $entry.before){throw ('Missing existing file: '+$entry.path)}
  $observed[$entry.path]=$current
 }
 $ps=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
 & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'backend/player_identity/export_production.ps1') -VerifyOnly
 if($LASTEXITCODE -ne 0){throw 'Existing verified native/export preflight failed. No project files changed.'}
 $backup=Join-Path $repo ('.local/player_trust_install/'+[Guid]::NewGuid().ToString('N'))
 New-Item -ItemType Directory -Path $backup -Force | Out-Null
 $preparedHashes=@{}
 foreach($entry in $entries){
  $target=Join-Path $repo $entry.path
  if(Test-Path -LiteralPath $target){
   $copy=Join-Path $backup ('before/'+$entry.path)
   New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($copy)) -Force | Out-Null
   Copy-Item -LiteralPath $target -Destination $copy
  }
  $prepared=Join-Path $backup ('prepared/'+$entry.path)
  New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($prepared)) -Force | Out-Null
  if($entry.path -eq $lessonPath -and $mergeLessons){
   $text=[IO.File]::ReadAllText($target);if(-not $text.Contains($lessonMarker)){$text+=$lesson}
   [IO.File]::WriteAllText($prepared,$text,(New-Object Text.UTF8Encoding($false)))
  }else{Copy-Item -LiteralPath (Join-Path (Join-Path $PackageRoot 'payload') $entry.path) -Destination $prepared}
  $preparedHashes[$entry.path]=Hash-Path $prepared $entry.mode
  if(-not ($entry.path -eq $lessonPath -and $mergeLessons) -and $preparedHashes[$entry.path] -ne $entry.after){throw 'Prepared checksum failed.'}
 }
 # Detect edits between initial inspection and replacement before mutating any target.
 foreach($entry in $entries){$target=Join-Path $repo $entry.path;$current=$null;if(Test-Path -LiteralPath $target){$current=Hash-Path $target $entry.mode};if($current -ne $observed[$entry.path]){throw ('File changed during preflight: '+$entry.path+'; originals retained.')}}
 foreach($entry in $entries){
  $target=[IO.Path]::GetFullPath((Join-Path $repo $entry.path));$prepared=[IO.Path]::GetFullPath((Join-Path $backup ('prepared/'+$entry.path)))
  New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($target)) -Force | Out-Null
  if([IO.File]::Exists($target)){
   $swap=[IO.Path]::GetFullPath((Join-Path $backup ('replaced/'+$entry.path)))
   New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($swap)) -Force | Out-Null
   [IO.File]::Replace($prepared,$target,$swap)
  }else{[IO.File]::Move($prepared,$target)}
  if((Hash-Path $target $entry.mode) -ne $preparedHashes[$entry.path]){throw ('Installed checksum failed: '+$entry.path+'; backups retained.')}
 }
 Write-Host ('PLAYER_TRUST_APPLIED=PASS; BACKUP='+$backup)
 & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'backend/player_identity/publish_player_trust.ps1')
 if($LASTEXITCODE -ne 0){throw 'Publisher stopped. Installed files/backups retained. No deployment or erasure attempted.'}
 Write-Host 'PLAYER_TRUST_PACKAGE=PASS; DEPLOY=ERASURE=PURCHASE=NONE'
 Write-Host 'After CI: backend\player_identity\deploy_player_trust.cmd, then backend\player_identity\export_production.cmd'
}catch{Write-Error $_ -ErrorAction Continue;exit 1}finally{if($pushed){Pop-Location}}

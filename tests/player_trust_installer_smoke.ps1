$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$qa=Join-Path ([IO.Path]::GetTempPath()) ('jade-trust-manifest-'+[Guid]::NewGuid().ToString('N'))
try{
 New-Item -ItemType Directory -Path $qa -Force|Out-Null
 $decoded=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $repo 'backend/player_identity/player_trust_paths.json')))
 $paths=@();foreach($path in $decoded){$paths+=$path}
 $entries=@()
 function TextHash([string]$Path){$sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($Path).Replace("`r`n","`n"))))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}}
 foreach($path in $paths){
  $source=Join-Path $repo $path;$target=Join-Path $qa ('payload/'+$path)
  New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($target)) -Force|Out-Null
  Copy-Item -LiteralPath $source -Destination $target
  $entries+=@{path=$path;mode='text';before=$null;after=(TextHash $target)}
 }
 [IO.File]::WriteAllText((Join-Path $qa 'files.json'),($entries|ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding($false)))
 $ps=(Get-Process -Id $PID).Path
 & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'backend/player_identity/install_player_trust.ps1') -PackageRoot $qa -ValidateOnly
 if($LASTEXITCODE -ne 0){throw 'Actual PowerShell package validation failed.'}
 # A singleton pipeline containing a decoded array must still enumerate all paths.
 $wrapped=Write-Output -NoEnumerate $decoded
 $flat=@();foreach($path in $wrapped){$flat+=$path}
 if($flat.Count -ne $paths.Count){throw 'Non-enumerating JSON regression.'}
 [IO.File]::AppendAllText((Join-Path $qa ('payload/'+$paths[0])),'tampered')
 $previous=$ErrorActionPreference
 try{$ErrorActionPreference='Continue';$failure=@(& $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'backend/player_identity/install_player_trust.ps1') -PackageRoot $qa -ValidateOnly 2>&1);$code=$LASTEXITCODE}finally{$ErrorActionPreference=$previous}
 if($code -eq 0 -or ($failure -join "`n") -notmatch 'Payload differs'){throw 'Tampered payload was not rejected.'}
 Write-Host ('TRUST_INSTALLER_QA=PASS; PATHS='+$paths.Count+'; NORMAL_AND_NONENUMERATING_JSON=PASS; TAMPER_REJECTED=PASS; INSTALL=NONE')
}finally{if(Test-Path -LiteralPath $qa){Remove-Item -LiteralPath $qa -Recurse -Force}}

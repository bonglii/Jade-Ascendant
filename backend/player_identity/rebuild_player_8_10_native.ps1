param([string]$SdkRoot='D:\SDK',[string]$GradlePath='')
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
# Rebuild only. No deployment, purchase, AAB export or installed plugin mutation.
$output=@(& (Join-Path $PSScriptRoot 'build_iap_production_candidate.ps1') -SdkRoot $SdkRoot -GradlePath $GradlePath 6>&1)
$output | ForEach-Object { Write-Host $_ }
if($LASTEXITCODE -ne 0){throw 'Native build failed; existing candidate pins unchanged.'}
$line=@($output | Where-Object { $_ -match 'PRODUCTION_CANDIDATE_BUILD=PASS;.*OUTPUT=(.+)$' } | Select-Object -Last 1)
if($line.Count -ne 1){throw 'Native build receipt missing.'}
$null=$line[0] -match 'OUTPUT=(.+)$';$work=$Matches[1].Trim()
$python=(Get-Command python.exe -ErrorAction Stop).Source
& $python (Join-Path $PSScriptRoot 'collect_player_8_10_native.py') --repo $repo --dependencies (Join-Path $work 'release-dependencies.txt') --java-home $env:JAVA_HOME
if($LASTEXITCODE -ne 0){throw 'Candidate validation failed. Do not export.'}
Write-Host 'PLAYER_8_10_NATIVE=PASS; INSTALLED=NONE; DEPLOY=NONE; EXPORT=NONE'

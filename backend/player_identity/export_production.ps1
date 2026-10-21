param(
    [string]$Project = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [string]$GodotPath = '',
    [switch]$RecoverOnly,
    [switch]$VerifyOnly
)
$ErrorActionPreference = 'Stop'
$candidateHash = '74c737b46bf2b9de1b8bdb2f29747f8f11cd6da1d5d402f9002ead048d055df5'
$lockedHash = '8f466fb8738413f95813b1aa0bd11d102716cf26a84298ea7d12af8a4adb60b8'
$lockStream = $null
$markerWritten = $false
$nodeOptions = $env:NODE_OPTIONS
$sourceRevision = $env:JADE_BUILD_SOURCE_REVISION
$resultCode = 1
function HashFile([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function TextHash([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($Path).Replace("`r`n","`n"))
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()
    } finally { $sha.Dispose() }
}
function AssertEditorClosed {
    $running = @(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -match '^(godot|Godot_v)' })
    if ($running.Count -gt 0) { throw 'Close all Godot editor/game windows, then retry this launcher. No running process is terminated.' }
}
function RestoreRelease([string]$MarkerPath) {
    $state = [IO.File]::ReadAllText($MarkerPath) | ConvertFrom-Json
    if ($state.original_hash -ne $lockedHash -or $state.candidate_hash -ne $candidateHash) { throw 'Unrecognized recovery receipt. Backup retained.' }
    if ($state.project -ne $repo -or $state.release_path -ne $release) { throw 'Recovery project mismatch. Backup retained.' }
    $allowedBackupRoot = $sessionRoot.TrimEnd('\') + '\'
    $backupPath = [IO.Path]::GetFullPath([string]$state.backup_path)
    if (-not $backupPath.StartsWith($allowedBackupRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Recovery backup outside session directory.' }
    if ((HashFile $backupPath) -ne $lockedHash) { throw 'Recovery backup hash mismatch. Nothing overwritten.' }
    $current = HashFile $release
    if ($current -ne $candidateHash -and $current -ne $lockedHash) { throw 'Release AAR changed outside this session. Nothing overwritten; backup retained.' }
    if ($current -ne $lockedHash) { Copy-Item -LiteralPath $backupPath -Destination $release -Force }
    if ((HashFile $release) -ne $lockedHash) { throw 'Release restore verification failed. Backup retained.' }
    Remove-Item -LiteralPath $MarkerPath
    Write-Host 'ORIGINAL_RELEASE_RESTORED=PASS; DEBUG_AAR_AND_NATIVE_RECEIPTS=UNCHANGED'
}
try {
    $repo = (Resolve-Path -LiteralPath $Project).Path
    if (-not (Test-Path -LiteralPath (Join-Path $repo 'project.godot'))) { throw 'Godot project not found.' }
    $release = Join-Path $repo 'addons/JadeMonetizationNativeBridge/bin/release/JadeMonetizationNativeBridge-release.aar'
    $sessionRoot = [IO.Path]::GetFullPath((Join-Path $repo '.local/production_native_export'))
    New-Item -ItemType Directory -Path $sessionRoot -Force | Out-Null
    $lockStream = [IO.File]::Open((Join-Path $sessionRoot 'session.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $marker = Join-Path $sessionRoot 'active.json'
    AssertEditorClosed
    if ($RecoverOnly) {
        if (Test-Path -LiteralPath $marker) { RestoreRelease $marker }
        elseif ((HashFile $release) -eq $lockedHash) { Write-Host 'RECOVERY_NOT_NEEDED; ORIGINAL_RELEASE_ALREADY_INSTALLED' }
        else { throw 'Release differs and there is no owned recovery receipt. Nothing overwritten.' }
        $resultCode = 0
    } else {
        if (Test-Path -LiteralPath $marker) { throw 'An interrupted export session exists. Run recover_production_export.cmd first.' }
        $proofPath = Join-Path $repo 'docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json'
        if ((TextHash $proofPath) -ne '140f91f58a1335991f9603c022666956171aa94d52b284e3261dc969e3cd61f7') { throw 'Candidate provenance changed.' }
        $proof = [IO.File]::ReadAllText($proofPath) | ConvertFrom-Json
        $candidate = Join-Path $repo 'release/native/JadeMonetizationNativeBridge-production-candidate.aar'
        if ($proof.target -ne 'production-candidate' -or $proof.aar_sha256 -ne $candidateHash -or (HashFile $candidate) -ne $candidateHash) { throw 'Candidate AAR hash/target mismatch.' }
        $inputs = @($proof.inputs.PSObject.Properties)
        if ($inputs.Count -ne 48) { throw 'Candidate source inventory incomplete.' }
        foreach ($inputFile in $inputs) {
            $sourcePath = Join-Path $repo $inputFile.Name
            if (-not (Test-Path -LiteralPath $sourcePath) -or (TextHash $sourcePath) -ne $inputFile.Value) { throw ('Candidate source differs: ' + $inputFile.Name + '. Nothing installed.') }
        }
        if ((HashFile $release) -ne $lockedHash) { throw 'Installed release is not the expected verified locked AAR. Nothing overwritten.' }
        if (-not [IO.File]::ReadAllText((Join-Path $repo 'project.godot')).Contains('res://addons/JadeReleaseMetadata/plugin.cfg')) { throw 'Release metadata export plugin is not enabled in project.godot.' }
        Write-Host 'CANDIDATE_SOURCE_AND_BINARY=PASS; INPUTS=48; APP_CHECK=PLAY_INTEGRITY; TARGET=PRODUCTION'
        if ($VerifyOnly) {
            Write-Host 'PRODUCTION_EXPORT_PREFLIGHT=PASS; INSTALLED=NONE; NETWORK=NONE'
            $resultCode = 0
        } else {
        if (-not $GodotPath) {
            $remembered = Join-Path $sessionRoot 'godot-path.local.txt'
            if (Test-Path -LiteralPath $remembered) { $GodotPath = [IO.File]::ReadAllText($remembered).Trim() }
            if (-not $GodotPath) {
                $root = Split-Path (Split-Path $repo -Parent) -Parent
                $possible = @(Get-ChildItem -LiteralPath $root -Filter '*console.exe' -File | Where-Object { $_.Name -match '^Godot' })
                if ($possible.Count -eq 1) { $GodotPath = $possible[0].FullName }
            }
            if (-not $GodotPath) { $GodotPath = (Read-Host 'Full path to your Godot console EXE').Trim().Trim('"') }
        }
        $GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
        if ([IO.Path]::GetExtension($GodotPath) -ne '.exe') { throw 'Select your Godot Windows EXE.' }
        $version = @(& $GodotPath --version) -join ' '
        if ($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.') { throw 'Godot 4 version check failed.' }
        [IO.File]::WriteAllText((Join-Path $sessionRoot 'godot-path.local.txt'),$GodotPath)
        $node = (Get-Command node.exe -ErrorAction Stop).Source
        $env:NODE_OPTIONS = $null
        & $node (Join-Path $PSScriptRoot 'check_production_backend.cjs')
        if ($LASTEXITCODE -ne 0) { throw 'Production backend check failed. No AAR was changed.' }
        $env:NODE_OPTIONS = $nodeOptions
        AssertEditorClosed
        $session = Join-Path $sessionRoot ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $session -Force | Out-Null
        $backup = Join-Path $session 'original-release.aar'
        Copy-Item -LiteralPath $release -Destination $backup
        if ((HashFile $backup) -ne $lockedHash) { throw 'Backup verification failed.' }
        $state = @{ project=$repo; release_path=$release; backup_path=$backup; original_hash=$lockedHash; candidate_hash=$candidateHash; started_utc=[DateTime]::UtcNow.ToString('o') }
        [IO.File]::WriteAllText($marker,($state | ConvertTo-Json),(New-Object Text.UTF8Encoding($false)))
        $markerWritten = $true
        Copy-Item -LiteralPath $candidate -Destination $release -Force
        if ((HashFile $release) -ne $candidateHash) { throw 'Candidate installation verification failed.' }
        Write-Host 'PRODUCTION_EXPORT_SESSION=READY'
        Write-Host 'In this editor: export Android RELEASE, with Export With Debug unchecked.'
        Write-Host 'Use your normal AAB/version settings. Upload via your Play internal test track.'
        Write-Host 'Keep this terminal open. Close Godot after exporting; the original AAR will be restored.'
        Write-Host 'Do not commit/push or run another exporter while this session is open.'
        $env:JADE_BUILD_SOURCE_REVISION = (& git -C $repo rev-parse --verify HEAD).Trim()
        if ($LASTEXITCODE -ne 0 -or $env:JADE_BUILD_SOURCE_REVISION -notmatch '^[a-f0-9]{40}$') { throw 'Cannot stamp source revision.' }
        $arguments = '--editor --path "' + $repo + '"'
        $editor = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WorkingDirectory $repo -Wait -PassThru
        if ($editor.ExitCode -ne 0) { throw ('Godot exited with code ' + $editor.ExitCode + '. Original AAR will be restored.') }
        Write-Host 'EDITOR_SESSION_CLOSED; EXPORTED_PACKAGE_MUST_BE_VERIFIED_IN_PLAY'
        $resultCode = 0
        }
    }
} catch {
    Write-Error $_ -ErrorAction Continue
    $resultCode = 1
} finally {
    $env:JADE_BUILD_SOURCE_REVISION = $sourceRevision
    $env:NODE_OPTIONS = $nodeOptions
    if ($markerWritten) {
        try { AssertEditorClosed; RestoreRelease $marker }
        catch { Write-Error ('Restore pending: ' + $_.Exception.Message + '. Close Godot and run recover_production_export.cmd.') -ErrorAction Continue; $resultCode = 1 }
    }
    if ($null -ne $lockStream) { $lockStream.Dispose() }
}
exit $resultCode

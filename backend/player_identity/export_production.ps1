param(
    [string]$Project = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [string]$GodotPath = '',
    [switch]$RecoverOnly,
    [switch]$VerifyOnly
)
$ErrorActionPreference = 'Stop'
$candidateHash = '2171f13f36cf8d90988fd20248f879653104625c8481b91d3fb0a4303fb098ea'
$previousCandidateHash = '11de7b6d70d27f7bc7df277fadc07afe03e166d7b4a95b6351f1575a72e8b557'
$priorConnectionCandidateHash = 'a4db0c183df6bdb3c0deac64b10916c1b15d2db1f420d12b1011f37283d4bc21'
$historicalCandidateHash = '74c737b46bf2b9de1b8bdb2f29747f8f11cd6da1d5d402f9002ead048d055df5'
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
    Restore-JadeNativeOverlay -Project $repo -Release $release -SessionRoot $sessionRoot -Marker $MarkerPath -CandidateHashes @($candidateHash,$previousCandidateHash,$priorConnectionCandidateHash,$historicalCandidateHash)
}

try {
    $repo = (Resolve-Path -LiteralPath $Project).Path
    if (-not (Test-Path -LiteralPath (Join-Path $repo 'project.godot'))) { throw 'Godot project not found.' }
    $release = Join-Path $repo 'addons/JadeMonetizationNativeBridge/bin/release/JadeMonetizationNativeBridge-release.aar'
    $sessionRoot = [IO.Path]::GetFullPath((Join-Path $repo '.local/production_native_export'))
    New-Item -ItemType Directory -Path $sessionRoot -Force | Out-Null
    $lockStream = [IO.File]::Open((Join-Path $sessionRoot 'session.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $marker = Join-Path $sessionRoot 'active.json'
    $overlayHelper = Join-Path $PSScriptRoot 'production_native_overlay.ps1'
    if ((TextHash $overlayHelper) -ne 'ddebc683ae50ef49191e8935bef80a159a2dad1a878d1da03ad544fad6173b6a') { throw 'Native overlay helper changed.' }
    . $overlayHelper
    AssertEditorClosed
    if ($RecoverOnly) {
        if (Test-Path -LiteralPath $marker) { RestoreRelease $marker }
        else { Write-Host ('RECOVERY_NOT_NEEDED; EXISTING_RELEASE_UNCHANGED; SHA256=' + (HashFile $release)) }
        $resultCode = 0
    } else {
        if (Test-Path -LiteralPath $marker) { throw 'An interrupted export session exists. Run recover_production_export.cmd first.' }
        $proofPath = Join-Path $repo 'docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json'
        if ((TextHash $proofPath) -ne 'ff0dadb7aee521fbc5d71d5de62ca948c12567b0cc68d1aa4211ac389c0f9596') { throw 'Candidate provenance changed.' }
        $proof = [IO.File]::ReadAllText($proofPath) | ConvertFrom-Json
        $candidate = Join-Path $repo 'release/native/JadeMonetizationNativeBridge-production-candidate.aar'
        if ($proof.target -ne 'production-candidate' -or $proof.aar_sha256 -ne $candidateHash -or (HashFile $candidate) -ne $candidateHash) { throw 'Candidate AAR hash/target mismatch.' }
        $inputs = @($proof.inputs.PSObject.Properties)
        if ($inputs.Count -ne 52) { throw 'Candidate source inventory incomplete.' }
        foreach ($inputFile in $inputs) {
            $sourcePath = Join-Path $repo $inputFile.Name
            if (-not (Test-Path -LiteralPath $sourcePath) -or (TextHash $sourcePath) -ne $inputFile.Value) { throw ('Candidate source differs: ' + $inputFile.Name + '. Nothing installed.') }
        }
        # The existing bridge is not an input to the new AAB. Snapshot it for exact restoration.
        $originalHash = HashFile $release
        if (-not [IO.File]::ReadAllText((Join-Path $repo 'project.godot')).Contains('res://addons/JadeReleaseMetadata/plugin.cfg')) { throw 'Release metadata export plugin is not enabled in project.godot.' }
        Write-Host 'CANDIDATE_SOURCE_AND_BINARY=PASS; INPUTS=52; APP_CHECK=PLAY_INTEGRITY; TARGET=PRODUCTION'
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
        $markerWritten = $true
        $state = Start-JadeNativeOverlay -Project $repo -Release $release -Candidate $candidate -SessionRoot $sessionRoot -Marker $marker -OriginalHash $originalHash -CandidateHash $candidateHash
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
    if ($markerWritten -and (Test-Path -LiteralPath $marker)) {
        try { AssertEditorClosed; RestoreRelease $marker }
        catch { Write-Error ('Restore pending: ' + $_.Exception.Message + '. Close Godot and run recover_production_export.cmd.') -ErrorAction Continue; $resultCode = 1 }
    }
    if ($null -ne $lockStream) { $lockStream.Dispose() }
}
exit $resultCode

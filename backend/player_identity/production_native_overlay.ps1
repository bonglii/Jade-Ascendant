# Reversible export overlay. The candidate is trusted separately; the original is
# an opaque owner file and is always restored byte-for-byte, whatever its build.
function Get-JadeNativeHash([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Assert-JadeNativePlainPath([string]$Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if ((Test-Path -LiteralPath $current) -and (([IO.File]::GetAttributes($current) -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
            throw ('Native path is a link/reparse point: ' + $Path)
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if ($parent -eq $current) { break }
        $current = $parent
    }
}
function Write-JadeVerifiedNativeFile([string]$Source,[string]$Destination,[string]$SourceHash,[string]$DestinationHash) {
    Assert-JadeNativePlainPath $Source
    Assert-JadeNativePlainPath $Destination
    if ((Get-JadeNativeHash $Source) -ne $SourceHash -or (Get-JadeNativeHash $Destination) -ne $DestinationHash) {
        throw 'Native file changed before replacement. Nothing overwritten.'
    }
    $temporary = $Destination + '.jade-' + [Guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::Copy($Source,$temporary,$false)
        if ((Get-JadeNativeHash $temporary) -ne $SourceHash -or (Get-JadeNativeHash $Destination) -ne $DestinationHash) {
            throw 'Native file changed while preparing replacement. Nothing overwritten.'
        }
        # Replace only after the full new file exists and its bytes are verified.
        [IO.File]::Replace($temporary,$Destination,[NullString]::Value)
        if ((Get-JadeNativeHash $Destination) -ne $SourceHash) { throw 'Native replacement verification failed.' }
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
    }
}
function Start-JadeNativeOverlay(
    [string]$Project,[string]$Release,[string]$Candidate,[string]$SessionRoot,[string]$Marker,
    [string]$OriginalHash,[string]$CandidateHash
) {
    if (Test-Path -LiteralPath $Marker) { throw 'An export recovery receipt already exists. Nothing overwritten.' }
    foreach ($path in @($Release,$Candidate,$SessionRoot,$Marker)) { Assert-JadeNativePlainPath $path }
    if ($OriginalHash -notmatch '^[a-f0-9]{64}$' -or $CandidateHash -notmatch '^[a-f0-9]{64}$' -or
        (Get-JadeNativeHash $Release) -ne $OriginalHash -or (Get-JadeNativeHash $Candidate) -ne $CandidateHash) {
        throw 'Native original/candidate changed before export. Nothing overwritten.'
    }
    $session = Join-Path $SessionRoot ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $session -Force | Out-Null
    $backup = Join-Path $session 'original-release.aar'
    [IO.File]::Copy($Release,$backup,$false)
    if ((Get-JadeNativeHash $backup) -ne $OriginalHash) { throw 'Original native backup verification failed.' }
    $state = @{version=2;project=[IO.Path]::GetFullPath($Project);release_path=[IO.Path]::GetFullPath($Release);
        backup_path=$backup;original_hash=$OriginalHash;candidate_hash=$CandidateHash;started_utc=[DateTime]::UtcNow.ToString('o')}
    $pending = $Marker + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($pending,($state | ConvertTo-Json),(New-Object Text.UTF8Encoding($false)))
        [IO.File]::Move($pending,$Marker)
    } finally {
        if (Test-Path -LiteralPath $pending) { Remove-Item -LiteralPath $pending }
    }
    Write-JadeVerifiedNativeFile $Candidate $Release $CandidateHash $OriginalHash
    return $state
}
function Restore-JadeNativeOverlay(
    [string]$Project,[string]$Release,[string]$SessionRoot,[string]$Marker,[string[]]$CandidateHashes
) {
    foreach ($path in @($Release,$SessionRoot,$Marker)) { Assert-JadeNativePlainPath $path }
    $state = [IO.File]::ReadAllText($Marker) | ConvertFrom-Json
    if ($state.original_hash -notmatch '^[a-f0-9]{64}$' -or $state.candidate_hash -notin $CandidateHashes) {
        throw 'Unrecognized export receipt. Backup retained.'
    }
    $comparison = [StringComparison]::Ordinal
    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { $comparison = [StringComparison]::OrdinalIgnoreCase }
    if (-not [string]::Equals([IO.Path]::GetFullPath([string]$state.project),[IO.Path]::GetFullPath($Project),$comparison) -or
        -not [string]::Equals([IO.Path]::GetFullPath([string]$state.release_path),[IO.Path]::GetFullPath($Release),$comparison)) {
        throw 'Recovery project mismatch. Backup retained.'
    }
    $rootPath = [IO.Path]::GetFullPath($SessionRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $backup = [IO.Path]::GetFullPath([string]$state.backup_path)
    if (-not $backup.StartsWith($rootPath,$comparison) -or [IO.Path]::GetFileName($backup) -ne 'original-release.aar') {
        throw 'Recovery backup outside owned session directory. Nothing overwritten.'
    }
    Assert-JadeNativePlainPath $backup
    if ((Get-JadeNativeHash $backup) -ne $state.original_hash) { throw 'Recovery backup hash mismatch. Nothing overwritten.' }
    $current = Get-JadeNativeHash $Release
    if ($current -ne $state.candidate_hash -and $current -ne $state.original_hash) {
        throw 'Release AAR changed outside this export. Nothing overwritten; backup retained.'
    }
    if ($current -ne $state.original_hash) {
        Write-JadeVerifiedNativeFile $backup $Release $state.original_hash $current
    }
    if ((Get-JadeNativeHash $Release) -ne $state.original_hash) { throw 'Original native restore verification failed.' }
    Remove-Item -LiteralPath $Marker
    Write-Host ('ORIGINAL_RELEASE_RESTORED=PASS; SHA256=' + $state.original_hash + '; DEBUG_AAR_AND_NATIVE_RECEIPTS=UNCHANGED')
}

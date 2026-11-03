param(
    [string]$ProjectPath = 'D:\Godot\project\jade-ascendant',
    [string]$GodotPath = '',
    [string]$PackageRoot = $PSScriptRoot,
    [switch]$QaOnly,
    [switch]$ApplyOnly
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false, $true)
function Hash-Bytes([byte[]]$Bytes) {
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() } finally { $hasher.Dispose() }
}
function Read-Text([string]$Path) {
    $value = $utf8.GetString([IO.File]::ReadAllBytes($Path))
    if ($value.Length -gt 0 -and $value[0] -eq [char]0xFEFF) { $value = $value.Substring(1) }
    if ($value.Contains([string][char]0)) { throw ('Non-text source: ' + $Path) }
    return $value.Replace("`r`n", "`n")
}
function Text-Hash([string]$Text) { return Hash-Bytes ($utf8.GetBytes($Text)) }
function Plain-Path([string]$Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if ((Test-Path -LiteralPath $cursor) -and (([IO.File]::GetAttributes($cursor) -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw ('Link/reparse point refused: ' + $Path) }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}
function Quote-Argument([string]$Value) {
    # CommandLineToArgvW quoting; also valid for these literal arguments on Unix.
    $result = '"'; $slashes = 0
    foreach ($letter in $Value.ToCharArray()) {
        if ($letter -eq [char]92) { $slashes++; continue }
        if ($letter -eq [char]34) { $result += ('\' * ($slashes * 2 + 1)) + '"'; $slashes = 0; continue }
        $result += ('\' * $slashes) + $letter; $slashes = 0
    }
    return $result + ('\' * ($slashes * 2)) + '"'
}
function Run-Child([string]$Executable, [string[]]$Arguments, [string]$WorkingDirectory) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $Executable; $info.WorkingDirectory = $WorkingDirectory
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = $utf8; $info.StandardErrorEncoding = $utf8
    $info.Arguments = (($Arguments | ForEach-Object { Quote-Argument $_ }) -join ' ')
    $process = [Diagnostics.Process]::Start($info)
    $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit(); $answer = @{ Code = $process.ExitCode; Out = $stdout.Result; Error = $stderr.Result }
    $process.Dispose(); return $answer
}
function Write-Atomic([string]$Path, [byte[]]$Bytes) {
    Plain-Path $Path
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    $temporary = $Path + '.jade-content-' + [Guid]::NewGuid().ToString('N') + '.tmp'
    $prior = $Path + '.jade-prior-' + [Guid]::NewGuid().ToString('N') + '.bak'
    $replaced = $false
    try {
        [IO.File]::WriteAllBytes($temporary, $Bytes)
        if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($temporary, $Path, $prior); $replaced = $true }
        else { [IO.File]::Move($temporary, $Path) }
    } finally {
        if (Test-Path -LiteralPath $temporary) { [IO.File]::Delete($temporary) }
        if ($replaced -and (Test-Path -LiteralPath $prior)) { [IO.File]::Delete($prior) }
    }
}
$sourceApplied = $false
$written = New-Object Collections.Generic.List[object]
try {
    $project = (Resolve-Path -LiteralPath $ProjectPath).Path
    $package = (Resolve-Path -LiteralPath $PackageRoot).Path
    Plain-Path $project; Plain-Path $package
    $git = (Get-Command git -ErrorAction Stop).Source
    $psBinary = (Get-Process -Id $PID).Path
    $top = Run-Child $git @('rev-parse', '--show-toplevel') $project
    if ($top.Code -ne 0 -or [IO.Path]::GetFullPath($top.Out.Trim()).TrimEnd([char]92,[char]47) -ne [IO.Path]::GetFullPath($project).TrimEnd([char]92,[char]47)) { throw 'Project must be the actual Git repository root.' }
    $head = Run-Child $git @('rev-parse','HEAD') $project
    if ($head.Code -ne 0) { throw 'Committed project baseline is required.' }
    $branch = Run-Child $git @('branch','--show-current') $project
    if ($branch.Code -ne 0 -or $branch.Out.Trim() -in @('main','master','production')) { throw 'Use the existing authorized work branch. Main/production is protected.' }
    $exporter = Join-Path $project 'backend/player_identity/export_production.ps1'
    $native = Run-Child $psBinary @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$exporter,'-Project',$project,'-VerifyOnly') $project
    if ($native.Code -ne 0 -or $native.Out -notmatch 'PRODUCTION_EXPORT_PREFLIGHT=PASS') { throw ('Native/recovery preflight refused; no source writes. ' + $native.Error + $native.Out) }
    Write-Host 'NATIVE_SOURCE_BINARY_MATCH=PASS; INPUTS=52; EXPORT=NOT_RUN'
    if (-not $QaOnly) {
        $manifest = (Read-Text (Join-Path $package 'manifest.json')) | ConvertFrom-Json
        if ($manifest.batch -ne 'MENU_PLAYER_EXPERIENCE_20261103' -or $manifest.files.Count -lt 1) { throw 'Invalid package manifest.' }
        $session = Join-Path $package ('backups/' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($session) | Out-Null
        $plan = New-Object Collections.Generic.List[object]
        foreach ($entry in $manifest.files) {
            $relative = [string]$entry.path
            if (-not $relative -or $relative.StartsWith('/') -or $relative.Contains('\') -or $relative.Contains(':') -or @($relative.Split('/') | Where-Object { $_ -eq '..' -or $_ -eq '.' }).Count) { throw 'Unsafe package path.' }
            $target = Join-Path $project $relative; $incomingPath = Join-Path $package ('payload/' + $relative)
            Plain-Path $target; Plain-Path $incomingPath
            $incoming = Read-Text $incomingPath
            if ((Text-Hash $incoming) -ne [string]$entry.sha256) { throw ('Payload hash mismatch: ' + $relative) }
            $exists = Test-Path -LiteralPath $target -PathType Leaf
            $beforeBytes = if ($exists) { [IO.File]::ReadAllBytes($target) } else { $null }
            $before = if ($exists) { Read-Text $target } else { '' }
            $after = $incoming; $merged = $false
            if ($exists -and (Text-Hash $before) -ne [string]$entry.sha256) {
                $recognized = $false
                foreach ($base in $entry.bases) { if ((Text-Hash $before) -eq [string]$base.sha256) { $recognized = $true; break } }
                if (-not $recognized) {
                    $committed = Run-Child $git @('show',($head.Out.Trim() + ':' + $relative)) $project
                    $committedHash = if ($committed.Code -eq 0) { Text-Hash ($committed.Out.TrimStart([char]0xFEFF).Replace("`r`n","`n")) } else { '' }
                    $ancestors = @($entry.bases | Where-Object { $_.sha256 -eq $committedHash })
                    if ($ancestors.Count -ne 1) { throw ('Unrecognized committed ancestor; zero source writes: ' + $relative + '. Retain local changes for review.') }
                    $mergedOk = $false
                    foreach ($base in $ancestors) {
                        $basePath = Join-Path $package ([string]$base.file)
                        $baseText = Read-Text $basePath
                        if ((Text-Hash $baseText) -ne [string]$base.sha256) { throw ('Baseline hash mismatch: ' + $relative) }
                        $attempt = Join-Path $session ('merge-' + [Guid]::NewGuid().ToString('N'))
                        [IO.Directory]::CreateDirectory($attempt) | Out-Null
                        $ours = Join-Path $attempt 'ours.txt'; $ancestor = Join-Path $attempt 'base.txt'; $theirs = Join-Path $attempt 'incoming.txt'
                        [IO.File]::WriteAllText($ours,$before,$utf8); [IO.File]::WriteAllText($ancestor,$baseText,$utf8); [IO.File]::WriteAllText($theirs,$incoming,$utf8)
                        $result = Run-Child $git @('merge-file','--stdout','--',$ours,$ancestor,$theirs) $attempt
                        if ($result.Code -eq 0) { $after = $result.Out; $mergedOk = $true; $merged = $true; break }
                        [IO.File]::WriteAllText((Join-Path $attempt 'conflict.txt'),$result.Out,$utf8)
                    }
                    if (-not $mergedOk) { throw ('Source conflict; zero source writes: ' + $relative + '. Review the retained preflight files in ' + $session) }
                }
            } elseif (-not $exists) {
                $tracked = Run-Child $git @('ls-files','--error-unmatch','--',$relative) $project
                if ($tracked.Code -eq 0) { throw ('Tracked source is missing; zero source writes: ' + $relative) }
            }
            $after = $after.Replace("`r`n","`n")
            $outputText = $after
            if ($exists) {
                $originalText = $utf8.GetString($beforeBytes)
                if ($originalText.Contains("`r`n")) { $outputText = $outputText.Replace("`n","`r`n") }
                if ($originalText.Length -gt 0 -and $originalText[0] -eq [char]0xFEFF) { $outputText = ([string][char]0xFEFF) + $outputText }
            }
            $afterBytes = $utf8.GetBytes($outputText)
            $change = -not $exists -or (Hash-Bytes $beforeBytes) -ne (Hash-Bytes $afterBytes)
            $plan.Add(@{ Path=$relative; Target=$target; Existed=$exists; Before=$beforeBytes; BeforeHash=$(if($exists){Hash-Bytes $beforeBytes}else{''}); Bytes=$afterBytes; TextHash=(Text-Hash $after); Changed=$change; Merged=$merged })
        }
        # Every merge/hash/link/recovery check completes before the first project write.
        foreach ($row in $plan) {
            Plain-Path $row.Target
            if ($row.Existed) {
                if (-not (Test-Path -LiteralPath $row.Target -PathType Leaf) -or (Hash-Bytes ([IO.File]::ReadAllBytes($row.Target))) -ne $row.BeforeHash) { throw ('Source changed during preflight: ' + $row.Path) }
            } elseif (Test-Path -LiteralPath $row.Target) { throw ('A new file appeared during preflight: ' + $row.Path) }
            if ($row.Changed -and $row.Existed) {
                $backup = Join-Path $session ('original/' + $row.Path)
                [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($backup)) | Out-Null
                [IO.File]::WriteAllBytes($backup,$row.Before)
            }
        }
        foreach ($row in $plan) {
            if (-not $row.Changed) { continue }
            if ($row.Existed -and (Hash-Bytes ([IO.File]::ReadAllBytes($row.Target))) -ne $row.BeforeHash) { throw ('Source changed before replacement: ' + $row.Path) }
            if (-not $row.Existed -and (Test-Path -LiteralPath $row.Target)) { throw ('A new file appeared before replacement: ' + $row.Path) }
            Write-Atomic $row.Target $row.Bytes; $written.Add($row)
            if ((Text-Hash (Read-Text $row.Target)) -ne $row.TextHash) { throw ('Write verification failed: ' + $row.Path) }
        }
        $receipt = @{ batch=$manifest.batch; project=$project; source_commit=$manifest.source_commit; source_writes=$written.Count; independent_merges=@($plan | Where-Object { $_.Merged }).Count; qa='NOT_RUN'; deploy='NOT_RUN'; aab='NOT_EXPORTED'; phone='UNCONFIRMED'; files=@($plan | ForEach-Object { @{path=$_.Path;hash=$_.TextHash;merged=$_.Merged} }) }
        [IO.File]::WriteAllText((Join-Path $session 'APPLY_RECEIPT.json'),($receipt | ConvertTo-Json -Depth 8),$utf8)
        $sourceApplied = $true
        Write-Host ('MENU_EXPERIENCE_APPLY=PASS; SOURCE_WRITES=' + $written.Count + '; INDEPENDENT_MERGES=' + $receipt.independent_merges)
        Write-Host ('BACKUP_AND_RECEIPT=' + $session)
    }
    if ($ApplyOnly) { Write-Host 'MENU_EXPERIENCE_WINDOWS_QA=NOT_RUN'; exit 0 }
    $qa = Join-Path $project 'backend/player_identity/check_menu_experience.ps1'
    if (-not (Test-Path -LiteralPath $qa -PathType Leaf)) { throw 'The batch QA runner is missing. Source is retained; use the cumulative package.' }
    $qaArgs = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$qa,'-Project',$project)
    if ($GodotPath) { $qaArgs += @('-GodotPath',$GodotPath) }
    $result = Run-Child $psBinary $qaArgs $project
    Write-Host $result.Out
    if ($result.Code -ne 0) { throw ('Source remains installed; QA must be resumed with qa_only.cmd. ' + $result.Error) }
    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { Write-Host 'MENU_EXPERIENCE_WINDOWS_QA=PASS; DEPLOY=NOT_RUN; AAB=NOT_EXPORTED; PHONE=UNCONFIRMED' }
    else { Write-Host 'MENU_EXPERIENCE_AUTHOR_QA=PASS; WINDOWS=UNCONFIRMED; AAB=NOT_EXPORTED; PHONE=UNCONFIRMED' }
    exit 0
} catch {
    # Roll back only an interrupted write transaction; a QA failure retains the installed source.
    if ($written.Count -gt 0 -and -not $sourceApplied) {
        foreach ($row in @($written.ToArray())[-1..-($written.Count)]) {
            try {
                if ((Test-Path -LiteralPath $row.Target) -and (Hash-Bytes ([IO.File]::ReadAllBytes($row.Target))) -ne (Hash-Bytes $row.Bytes)) { throw 'A concurrent edit is retained for review.' }
                if ($row.Existed) { Write-Atomic $row.Target $row.Before }
                elseif (Test-Path -LiteralPath $row.Target) { [IO.File]::Delete($row.Target) }
            } catch { Write-Host ('ROLLBACK_REQUIRES_REVIEW=' + $row.Path) }
        }
    }
    Write-Error $_ -ErrorAction Continue
    Write-Host 'MENU_EXPERIENCE_RESULT=STOPPED; NO_DEPLOY_OR_EXPORT_PERFORMED'
    exit 1
}

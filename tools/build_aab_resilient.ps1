$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Artifacts = Join-Path $ProjectRoot 'artifacts'
$WindowsScript = Join-Path $PSScriptRoot 'windows.ps1'
$Utf8 = New-Object System.Text.UTF8Encoding($false)

New-Item -ItemType Directory -Force $Artifacts | Out-Null

function Write-Utf8([string]$Path, [string]$Value) {
    [System.IO.File]::WriteAllText($Path, $Value, $Utf8)
}

function Write-MonitorState(
    [string]$Path,
    [string]$State,
    [hashtable]$Extra
) {
    $record = [ordered]@{
        timestamp = (Get-Date).ToString('o')
        state = $State
    }

    if ($Extra) {
        foreach ($key in $Extra.Keys) {
            $record[$key] = $Extra[$key]
        }
    }

    Write-Utf8 $Path ($record | ConvertTo-Json -Depth 6)
}

function Get-GodotEditorSetting([string]$Key) {
    if (-not $env:APPDATA) {
        return ''
    }

    $folder = Join-Path $env:APPDATA 'Godot'
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        return ''
    }

    $files = @(
        Get-ChildItem `
            -LiteralPath $folder `
            -Filter 'editor_settings-4*.tres' `
            -File `
            -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending
    )

    foreach ($file in $files) {
        $text = [System.IO.File]::ReadAllText($file.FullName)
        $pattern = '(?m)^' + [regex]::Escape($Key) + '\s*=\s*"(?<value>(?:\\.|[^"])*)"\s*$'
        $match = [regex]::Match($text, $pattern)

        if ($match.Success) {
            $value = $match.Groups['value'].Value.Replace('\\', '\')
            if ($value) {
                return $value
            }
        }
    }

    return ''
}

function Find-JavaTool([string]$Name) {
    $roots = @(
        $env:JAVA_HOME,
        (Get-GodotEditorSetting 'export/android/java_sdk_path')
    )

    foreach ($root in $roots) {
        if (-not $root) {
            continue
        }

        $candidate = Join-Path $root ('bin/' + $Name + '.exe')
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    $command = Get-Command ($Name + '.exe') -CommandType Application -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw "$Name belum ditemukan. Pastikan JDK 17 masih terpasang dan terdaftar di Godot."
}

function Get-DescendantProcesses([int]$RootProcessId) {
    $all = @(
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Select-Object ProcessId, ParentProcessId, Name, CommandLine
    )

    $result = @()
    $frontier = @($RootProcessId)

    while ($frontier.Count -gt 0) {
        $next = @()

        foreach ($parentId in $frontier) {
            $children = @(
                $all |
                    Where-Object {
                        [int]$_.ParentProcessId -eq [int]$parentId
                    }
            )

            foreach ($child in $children) {
                $result += $child
                $next += [int]$child.ProcessId
            }
        }

        $frontier = @($next)
    }

    return @($result)
}

function Get-BuildExporter(
    [int]$BuildProcessId,
    [string]$BundleFileName
) {
    $matches = @(
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object {
                [int]$_.ParentProcessId -eq $BuildProcessId -and
                $_.Name -match '(?i)^Godot.*_console\.exe$' -and
                $_.CommandLine -and
                $_.CommandLine -like '*--export-release*' -and
                $_.CommandLine -like ('*' + $BundleFileName + '*')
            }
    )

    return ($matches | Select-Object -First 1)
}

function Stop-StaleExporterIfSafe(
    [string]$BundleFileName,
    [string]$MonitorPath
) {
    $projectNeedle = $ProjectRoot.Replace('\', '/')
    $matches = @(
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -match '(?i)^Godot.*_console\.exe$' -and
                $_.CommandLine -and
                $_.CommandLine -like '*--export-release*' -and
                $_.CommandLine -like ('*' + $BundleFileName + '*') -and
                (
                    $_.CommandLine.Replace('\', '/') -like ('*' + $projectNeedle + '*')
                )
            }
    )

    foreach ($process in $matches) {
        $descendants = @(
            Get-DescendantProcesses -RootProcessId ([int]$process.ProcessId)
        )

        if ($descendants.Count -gt 0) {
            throw (
                "Masih ada export lama aktif (PID $($process.ProcessId)) " +
                "dan child build process masih hidup. Tutup build lama lalu jalankan lagi."
            )
        }

        Write-Host (
            "Membersihkan exporter lama yang sudah tidak punya child build process: " +
            "PID $($process.ProcessId)"
        ) -ForegroundColor Yellow

        Write-MonitorState $MonitorPath 'CLEANING_STALE_EXPORTER' @{
            exporter_process_id = [int]$process.ProcessId
        }

        Stop-Process `
            -Id ([int]$process.ProcessId) `
            -Force `
            -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 1
    }
}

function Assert-AabContainer([string]$Bundle) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $archive = [System.IO.Compression.ZipFile]::OpenRead($Bundle)
    try {
        if ($archive.Entries.Count -le 0) {
            throw 'AAB tidak memiliki ZIP entries.'
        }

        $manifest = @(
            $archive.Entries |
                Where-Object {
                    $_.FullName -eq 'base/manifest/AndroidManifest.xml'
                }
        )

        if ($manifest.Count -ne 1) {
            throw 'AAB tidak memiliki base/manifest/AndroidManifest.xml.'
        }

        $arm64 = @(
            $archive.Entries |
                Where-Object {
                    $_.FullName -match '^base/lib/arm64-v8a/[^/]+\.so$'
                }
        )

        if ($arm64.Count -le 0) {
            throw 'AAB tidak memiliki native library ARM64.'
        }

        return $arm64.Count
    }
    finally {
        $archive.Dispose()
    }
}

function Assert-AabNativeAlignment([string]$Bundle) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $archive = [System.IO.Compression.ZipFile]::OpenRead($Bundle)
    $checked = 0

    try {
        $libraries = @(
            $archive.Entries |
                Where-Object {
                    $_.FullName -match '^base/lib/arm64-v8a/[^/]+\.so$'
                }
        )

        if ($libraries.Count -eq 0) {
            throw 'AAB tidak berisi native library ARM64.'
        }

        foreach ($entry in $libraries) {
            $stream = $entry.Open()
            $buffer = New-Object System.IO.MemoryStream

            try {
                $stream.CopyTo($buffer)
                $bytes = $buffer.ToArray()
            }
            finally {
                $stream.Dispose()
                $buffer.Dispose()
            }

            if (
                $bytes.Length -lt 64 -or
                $bytes[0] -ne 127 -or
                $bytes[1] -ne 69 -or
                $bytes[2] -ne 76 -or
                $bytes[3] -ne 70 -or
                $bytes[4] -ne 2 -or
                $bytes[5] -ne 1
            ) {
                throw "ELF ARM64 tidak valid: $($entry.FullName)"
            }

            $offset = [BitConverter]::ToUInt64($bytes, 32)
            $size = [BitConverter]::ToUInt16($bytes, 54)
            $count = [BitConverter]::ToUInt16($bytes, 56)

            if (
                $size -lt 56 -or
                $offset + [long]$size * $count -gt $bytes.Length
            ) {
                throw "Program header ELF tidak valid: $($entry.FullName)"
            }

            $loads = 0

            for ($index = 0; $index -lt $count; $index++) {
                $position = [int]($offset + $size * $index)

                if ([BitConverter]::ToUInt32($bytes, $position) -ne 1) {
                    continue
                }

                $loads++
                $alignment = [BitConverter]::ToUInt64($bytes, $position + 48)

                if ($alignment -lt 16384) {
                    throw "Alignment 16 KB belum terpenuhi: $($entry.FullName)."
                }
            }

            if ($loads -eq 0) {
                throw "ELF tidak berisi segmen LOAD: $($entry.FullName)"
            }

            $checked++
        }
    }
    finally {
        $archive.Dispose()
    }

    return $checked
}

function Invoke-RecoveredAabValidation(
    [string]$Bundle,
    [string]$ExportLog,
    [string]$ReportPath,
    [string]$SignaturePath,
    [object]$Config,
    [int]$ExporterPid
) {
    if (-not (Test-Path -LiteralPath $Bundle -PathType Leaf)) {
        throw 'AAB tidak ditemukan setelah exporter dihentikan.'
    }

    $bundleItem = Get-Item -LiteralPath $Bundle

    if ($bundleItem.Length -le 0) {
        throw 'AAB kosong setelah exporter dihentikan.'
    }

    $exportLogStatus = 'NOT_AVAILABLE'
    $exportLogDoneMarker = $false
    $exportLogFatal = $false

    if (Test-Path -LiteralPath $ExportLog -PathType Leaf) {
        try {
            $exportText = [System.IO.File]::ReadAllText($ExportLog)
            $exportLogStatus = 'READABLE'
            $exportLogDoneMarker = (
                $exportText -match '(?m)^\[\s*DONE\s*\]\s+export\s*$'
            )

            $fatalPattern = (
                '(?im)^\s*(SCRIPT ERROR:|USER ERROR:|ERROR:|' +
                'Parse Error:|Parser Error:)|leaked at exit|' +
                'still in use at exit'
            )

            $exportLogFatal = ($exportText -match $fatalPattern)

            if ($exportLogFatal) {
                throw 'Log export mengandung error fatal. Artifact tidak dipromosikan.'
            }
        }
        catch {
            if ($_.Exception.Message -eq 'Log export mengandung error fatal. Artifact tidak dipromosikan.') {
                throw
            }

            $exportLogStatus = 'UNREADABLE_AFTER_RECOVERY'
        }
    }

    Write-Host (
        'Exporter sudah dihentikan. Exit child build dapat bernilai non-zero karena ' +
        'proses Godot dihentikan setelah AAB stabil; sekarang artifact diverifikasi langsung.'
    ) -ForegroundColor Yellow

    Write-Host 'Memverifikasi struktur AAB...' -ForegroundColor Cyan
    $null = Assert-AabContainer $Bundle

    Write-Host 'Memverifikasi native ARM64 dan alignment 16 KB...' -ForegroundColor Cyan
    $nativeCount = Assert-AabNativeAlignment $Bundle

    Write-Host 'Memverifikasi signature AAB...' -ForegroundColor Cyan
    $jarsigner = Find-JavaTool 'jarsigner'

    $verification = (
        & $jarsigner `
            '-J-Duser.language=en' `
            '-J-Duser.country=US' `
            -verify `
            $Bundle `
            2>&1 |
            Out-String
    )

    if (
        $LASTEXITCODE -ne 0 -or
        $verification -notmatch '(?i)jar verified'
    ) {
        throw 'Tanda tangan AAB belum terverifikasi.'
    }

    Write-Utf8 $SignaturePath $verification

    $record = [ordered]@{
        bundle = $Bundle
        sha256 = (Get-FileHash -LiteralPath $Bundle -Algorithm SHA256).Hash
        version_name = [string]$Config.version_name
        version_code = [long]$Config.version_code
        package_name = [string]$Config.package_name
        signature = 'PASS'
        elf_16kb = 'PASS'
        arm64_libraries = $nativeCount
        export_shutdown = 'GODOT_4_7_2_POST_EXPORT_RECOVERED'
        recovered_exporter_pid = $ExporterPid
        export_log_status = $exportLogStatus
        export_log_done_marker = [bool]$exportLogDoneMarker
        export_log_fatal = [bool]$exportLogFatal
        recovery_evidence = 'AAB_STABLE_30S_NO_WRITES_30S_NO_CHILDREN_15S_ZIP_ELF_SIGNATURE_PASS'
        apk_zip_alignment = 'NOT_RUN'
        device_16kb = 'NOT_RUN'
        target_manifest = 'VERIFY_IN_PLAY_CONSOLE'
        play_review = 'NOT_SUBMITTED'
    }

    Write-Utf8 $ReportPath ($record | ConvertTo-Json -Depth 6)

    Write-Host (
        "AAB bertanda tangan dibuat dan diverifikasi: $Bundle"
    ) -ForegroundColor Green

    Write-Host (
        'RECOVERY PASS: ZIP PASS | ARM64/16 KB PASS | SIGNATURE PASS'
    ) -ForegroundColor Green
}

$buildProcess = $null
$monitorPath = Join-Path $Artifacts 'aab-export-monitor.json'

try {
    if (-not (Test-Path -LiteralPath $WindowsScript -PathType Leaf)) {
        throw 'tools/windows.ps1 tidak ditemukan.'
    }

    $configPath = Join-Path $ProjectRoot 'release/release_config.json'

    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        throw 'release/release_config.json belum ada. Jalankan SIAPKAN_RILIS.bat.'
    }

    $config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json

    if (-not $config.version_name -or -not $config.package_name) {
        throw 'release/release_config.json belum lengkap.'
    }

    $bundle = Join-Path $Artifacts (
        'JadeAscendant-' + [string]$config.version_name + '.aab'
    )

    $bundleFileName = [System.IO.Path]::GetFileName($bundle)
    $exportLog = Join-Path $Artifacts 'android-export.log'
    $reportPath = Join-Path $Artifacts 'aab-build-report.json'
    $signaturePath = Join-Path $Artifacts 'aab-signature.log'

    Write-MonitorState $monitorPath 'PREPARING_BUILD' @{
        bundle = $bundle
    }

    Stop-StaleExporterIfSafe `
        -BundleFileName $bundleFileName `
        -MonitorPath $monitorPath

    foreach ($path in @(
        $bundle,
        $exportLog,
        $reportPath,
        $signaturePath
    )) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }

    $childArgs = @(
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        ('"' + $WindowsScript + '"'),
        '-Mode',
        'Build'
    )

    $buildProcess = Start-Process `
        -FilePath 'powershell.exe' `
        -ArgumentList $childArgs `
        -NoNewWindow `
        -PassThru

    Write-MonitorState $monitorPath 'BUILD_PROCESS_STARTED' @{
        build_process_id = $buildProcess.Id
        bundle = $bundle
    }

    $deadline = (Get-Date).AddMinutes(30)
    $stableSince = $null
    $noDescendantsSince = $null
    $lastSize = -1L
    $forcedExporterPid = 0
    $forced = $false
    $aabSeen = $false

    while (-not $buildProcess.HasExited) {
        if ((Get-Date) -ge $deadline) {
            throw 'Build melewati batas waktu 30 menit.'
        }

        $bundleExists = Test-Path -LiteralPath $bundle -PathType Leaf

        if ($bundleExists) {
            $item = Get-Item -LiteralPath $bundle
            $size = [long]$item.Length

            if (-not $aabSeen) {
                $aabSeen = $true

                Write-MonitorState $monitorPath 'AAB_FILE_SEEN' @{
                    build_process_id = $buildProcess.Id
                    bundle = $bundle
                    bundle_size = $size
                }
            }

            if ($size -gt 0 -and $size -eq $lastSize) {
                if ($null -eq $stableSince) {
                    $stableSince = Get-Date
                }
            }
            else {
                $stableSince = $null
                $noDescendantsSince = $null
            }

            $lastSize = $size

            $stableSeconds = 0

            if ($null -ne $stableSince) {
                $stableSeconds = (
                    (Get-Date) - $stableSince
                ).TotalSeconds
            }

            $fileQuietSeconds = (
                (Get-Date) - $item.LastWriteTime
            ).TotalSeconds

            $exporter = Get-BuildExporter `
                -BuildProcessId $buildProcess.Id `
                -BundleFileName $bundleFileName

            if ($null -ne $exporter) {
                $descendants = @(
                    Get-DescendantProcesses `
                        -RootProcessId ([int]$exporter.ProcessId)
                )

                if ($descendants.Count -eq 0) {
                    if ($null -eq $noDescendantsSince) {
                        $noDescendantsSince = Get-Date
                    }
                }
                else {
                    $noDescendantsSince = $null
                }

                $noDescendantsSeconds = 0

                if ($null -ne $noDescendantsSince) {
                    $noDescendantsSeconds = (
                        (Get-Date) - $noDescendantsSince
                    ).TotalSeconds
                }

                if (
                    $size -gt 0 -and
                    $stableSeconds -ge 30 -and
                    $fileQuietSeconds -ge 30 -and
                    $noDescendantsSeconds -ge 15
                ) {
                    $forcedExporterPid = [int]$exporter.ProcessId

                    Write-MonitorState $monitorPath 'FORCING_STUCK_EXPORTER' @{
                        build_process_id = $buildProcess.Id
                        exporter_process_id = $forcedExporterPid
                        bundle = $bundle
                        bundle_size = $size
                        stable_seconds = [math]::Round($stableSeconds, 1)
                        file_quiet_seconds = [math]::Round($fileQuietSeconds, 1)
                        no_descendants_seconds = [math]::Round(
                            $noDescendantsSeconds,
                            1
                        )
                    }

                    Write-Host ''
                    Write-Host (
                        "AAB sudah stabil >=30 detik dan exporter tidak punya " +
                        "child build process >=15 detik. " +
                        "Menghentikan hanya Godot exporter PID $forcedExporterPid..."
                    ) -ForegroundColor Yellow

                    Stop-Process `
                        -Id $forcedExporterPid `
                        -Force `
                        -ErrorAction Stop

                    $forced = $true
                    break
                }
            }
        }

        Start-Sleep -Seconds 1
        $buildProcess.Refresh()
    }

    if ($forced) {
        if (-not $buildProcess.WaitForExit(60000)) {
            Write-MonitorState $monitorPath 'BUILD_WRAPPER_DID_NOT_EXIT' @{
                build_process_id = $buildProcess.Id
                exporter_process_id = $forcedExporterPid
            }

            Stop-Process `
                -Id $buildProcess.Id `
                -Force `
                -ErrorAction SilentlyContinue

            Start-Sleep -Seconds 1
        }
    }
    else {
        $buildProcess.WaitForExit()
    }

    $buildProcess.Refresh()
    $buildExit = $buildProcess.ExitCode

    if ($buildExit -eq 0) {
        if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
            throw 'Build melaporkan sukses tetapi aab-build-report.json tidak dibuat.'
        }

        Write-MonitorState $monitorPath 'NORMAL_BUILD_PASS' @{
            build_process_id = $buildProcess.Id
            exit_code = $buildExit
            bundle = $bundle
        }

        Write-Host 'Build AAB selesai normal tanpa recovery.' -ForegroundColor Green
        exit 0
    }

    if (-not $forced) {
        Write-MonitorState $monitorPath 'BUILD_FAILED_WITHOUT_RECOVERY' @{
            build_process_id = $buildProcess.Id
            exit_code = $buildExit
        }

        throw "Build gagal dengan exit code $buildExit sebelum recovery gate terpenuhi."
    }

    Invoke-RecoveredAabValidation `
        -Bundle $bundle `
        -ExportLog $exportLog `
        -ReportPath $reportPath `
        -SignaturePath $signaturePath `
        -Config $config `
        -ExporterPid $forcedExporterPid

    Write-MonitorState $monitorPath 'RECOVERY_PASS' @{
        build_process_id = $buildProcess.Id
        exporter_process_id = $forcedExporterPid
        child_exit_code = $buildExit
        bundle = $bundle
    }

    exit 0
}
catch {
    $message = $_.Exception.Message

    try {
        Write-MonitorState $monitorPath 'WRAPPER_FAIL' @{
            message = $message
        }
    }
    catch {
    }

    if ($null -ne $buildProcess) {
        try {
            $buildProcess.Refresh()

            if (-not $buildProcess.HasExited) {
                $exporters = @(
                    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
                        Where-Object {
                            [int]$_.ParentProcessId -eq [int]$buildProcess.Id -and
                            $_.Name -match '(?i)^Godot.*_console\.exe$' -and
                            $_.CommandLine -and
                            $_.CommandLine -like '*--export-release*'
                        }
                )

                foreach ($exporter in $exporters) {
                    Stop-Process `
                        -Id ([int]$exporter.ProcessId) `
                        -Force `
                        -ErrorAction SilentlyContinue
                }

                Start-Sleep -Milliseconds 500

                Stop-Process `
                    -Id $buildProcess.Id `
                    -Force `
                    -ErrorAction SilentlyContinue
            }
        }
        catch {
        }
    }

    Write-Host $message -ForegroundColor Red
    exit 1
}

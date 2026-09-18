param(
    [ValidateSet('Run','Check','Android','Configure','Key','Build','Capture')][string]$Mode = 'Run',
    [string]$GodotPath = ''
)
Write-Host "Jade Ascendant launcher aktif. Mode: $Mode" -ForegroundColor Cyan
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LocalFolder = Join-Path $ProjectRoot '.local'
$Artifacts = Join-Path $ProjectRoot 'artifacts'
$Utf8 = New-Object System.Text.UTF8Encoding($false)
New-Item -ItemType Directory -Force $LocalFolder,$Artifacts | Out-Null

function Write-Utf8([string]$Path,[string]$Value) {
    [System.IO.File]::WriteAllText($Path,$Value,$Utf8)
}
function Read-GodotVersion([string]$Executable) {
    Write-Host 'Memeriksa versi Godot (batas tunggu 20 detik)...'
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo.FileName = $Executable
    $process.StartInfo.Arguments = '--version'
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    try {
        if (-not $process.Start()) { throw 'Executable Godot tidak dapat dimulai.' }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(20000)) {
            $process.Kill()
            throw 'Godot tidak menjawab pemeriksaan versi dalam 20 detik. Coba executable Godot yang berakhiran _console.exe.'
        }
        $version = $stdout.Result.Trim()
        if ($process.ExitCode -ne 0) { throw ("Pemeriksaan versi Godot gagal. " + $stderr.Result) }
        return $version
    }
    finally { $process.Dispose() }
}
function Get-Godot {
    Write-Host 'Mencari lokasi Godot...'
    $cache = Join-Path $LocalFolder 'godot-path.txt'
    $candidate = $GodotPath.Trim().Trim('"')
    if (-not $candidate -and (Test-Path $cache)) { $candidate = (Get-Content -Raw $cache).Trim() }
    if (-not $candidate -or -not (Test-Path -LiteralPath $candidate -PathType Leaf -ErrorAction SilentlyContinue)) {
        foreach ($name in @('godot4.exe','godot.exe','Godot_v4.7.2-stable_win64_console.exe')) {
            $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue
            if ($command) { $candidate = $command.Source; break }
        }
    }
    # Console input keeps the request visible in the same window; no hidden picker.
    while (-not $candidate -or -not (Test-Path -LiteralPath $candidate -PathType Leaf) -or [System.IO.Path]::GetExtension($candidate) -ine '.exe') {
        Write-Host 'Buka folder Godot di Explorer. Seret file Godot .exe ke jendela ini, lalu tekan Enter.' -ForegroundColor Yellow
        Write-Host 'Atau Shift + klik kanan file .exe > Copy as path, lalu tempel lokasinya di sini.'
        $candidate = (Read-Host 'Lokasi Godot .exe (Enter kosong untuk batal)').Trim().Trim('"')
        if (-not $candidate) { throw 'Pemilihan Godot dibatalkan.' }
    }
    if (-not $candidate.EndsWith('_console.exe',[StringComparison]::OrdinalIgnoreCase)) {
        $console = $candidate.Substring(0,$candidate.Length - 4) + '_console.exe'
        if (Test-Path -LiteralPath $console) { $candidate = $console }
    }
    Write-Host "Godot yang dipakai: $candidate"
    $version = Read-GodotVersion $candidate
    if ($version -notmatch '^4\.7\.2\.') {
        throw "Paket ini membutuhkan Godot 4.7.2. Versi terbaca: $version. Untuk memilih ulang, seret executable Godot yang benar ke PERIKSA_GAME.bat."
    }
    Write-Utf8 $cache $candidate
    Write-Host "Godot: $version"
    return $candidate
}
function Set-GodotValue([string]$Path,[string]$Section,[string]$Key,[string]$Value) {
    $text = if (Test-Path $Path) { [System.IO.File]::ReadAllText($Path) } else { '' }
    $header = [regex]::Match($text,'(?m)^\['+[regex]::Escape($Section)+'\]\s*$')
    if (-not $header.Success) { $text += "`n[$Section]`n$Key=$Value`n" }
    else {
        $tail = $text.Substring($header.Index+$header.Length)
        $next = [regex]::Match($tail,'(?m)^\[')
        $length = if ($next.Success) { $next.Index } else { $tail.Length }
        $block = $tail.Substring(0,$length)
        $block = [regex]::Replace($block,'(?m)^'+[regex]::Escape($Key)+'=.*(?:\r?\n|$)','')
        $text = $text.Substring(0,$header.Index+$header.Length)+$block.TrimEnd()+"`n$Key=$Value`n`n"+$tail.Substring($length)
    }
    Write-Utf8 $Path $text
}
function Quote-Godot([string]$Value) {
    if ($Value -match '[\r\n\x00]') { throw 'Nilai konfigurasi harus satu baris.' }
    return '"'+$Value.Replace('\','\\').Replace('"','\"')+'"'
}
function New-QACopy {
    $token = 'jade_phase0_' + [guid]::NewGuid().ToString('N')
    $copy = Join-Path ([System.IO.Path]::GetTempPath()) $token
    New-Item -ItemType Directory -Force $copy | Out-Null
    Get-ChildItem -LiteralPath $ProjectRoot -File -Recurse -Force | ForEach-Object {
        $relative = $_.FullName.Substring($ProjectRoot.Length+1)
        if (
            $relative -match '(^|[\\/])(\.godot|\.git|\.local|artifacts|__pycache__)([\\/]|$)' -or
            $relative -match '^android([\\/]|$)' -or
            $relative -match '^addons[\\/]admob[\\/](csharp|gdscript)[\\/]sample([\\/]|$)' -or
            $relative -match '\.(jks|keystore|p12|pem|zip)$'
        ) { return }
        $target = Join-Path $copy $relative
        New-Item -ItemType Directory -Force (Split-Path -Parent $target) | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $target
    }
    foreach ($name in @('project.godot','override.cfg')) {
        $configPath = Join-Path $copy $name
        Set-GodotValue $configPath 'application' 'config/use_custom_user_dir' 'true'
        Set-GodotValue $configPath 'application' 'config/custom_user_dir_name' (Quote-Godot $token)
    }
    Set-GodotValue (Join-Path $copy 'override.cfg') 'jade_phase0' 'token' (Quote-Godot $token)
    return @{ Path=$copy; Token=$token }
}
function Invoke-GodotStep([string]$Executable,[string[]]$Arguments,[string]$Log,[bool]$Strict=$true) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $Executable @Arguments 2>&1 | ForEach-Object { "$($_)" } | Tee-Object -FilePath $Log | Out-Host
    $code = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    $output = [System.IO.File]::ReadAllText($Log)
    $errorPattern = '(?im)^\s*(SCRIPT ERROR:|USER ERROR:|ERROR:|Parse Error:|Parser Error:)|leaked at exit|still in use at exit'
    if ($Strict) { $errorPattern += '|(?im)^\s*(WARNING:|USER WARNING:)' }
    if ($code -ne 0 -or $output -match $errorPattern) { throw "Pemeriksaan gagal. Baca $Log" }
    return $output
}
function Invoke-GameCheck([string]$Executable) {
    Write-Host 'Menyiapkan salinan proyek untuk pemeriksaan. Tunggu hingga proses salin selesai...'
    $qa = New-QACopy
    $report = Join-Path $Artifacts ('check-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Force $report | Out-Null
    $result = [ordered]@{ engine_status='FAIL'; device_status='NOT_RUN'; namespace=$qa.Token; report=$report }
    try {
        Write-Host 'Mengimpor salinan uji. Progres permainan pribadi tidak dipakai sebagai data uji.'
        $null = Invoke-GodotStep $Executable @('--headless','--path',$qa.Path,'--import') (Join-Path $report 'import.log')
        $log = Invoke-GodotStep $Executable @('--verbose','--headless','--path',$qa.Path,'--script','res://tests/phase0_smoke.gd','--','--phase0-token',$qa.Token) (Join-Path $report 'smoke.log')
        if ($log -notmatch 'JADE_PHASE0_PASS') { throw 'Uji berhenti tanpa penanda PASS. Baca smoke.log.' }
        $result.engine_status = 'PASS'
        Write-Host "Pemeriksaan Godot PASS. Laporan: $report" -ForegroundColor Green
    }
    finally {
        Write-Utf8 (Join-Path $report 'summary.json') ($result | ConvertTo-Json -Depth 5)
        # Delete only the unique disposable project created by this invocation.
        if ((Split-Path -Leaf $qa.Path) -eq $qa.Token) { Remove-Item -LiteralPath $qa.Path -Recurse -Force }
        $saveCopy = Join-Path $env:APPDATA $qa.Token
        if (Test-Path -LiteralPath $saveCopy) { Remove-Item -LiteralPath $saveCopy -Recurse -Force }
    }
}
function Read-PublisherConfig {
    $path = Join-Path $ProjectRoot 'release/release_config.json'
    if (-not (Test-Path $path)) { throw 'Jalankan SIAPKAN_RILIS.bat terlebih dahulu.' }
    $config = Get-Content -Raw $path | ConvertFrom-Json
    if ($config.package_name -notmatch '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*){2,}$' -or $config.package_name -match '(^|\.)(example|placeholder|yourcompany|test)(\.|$)') { throw 'Package name harus ID penerbit yang valid dan bukan contoh.' }
    if (-not $config.publisher_name -or $config.publisher_name -match '[\r\n]') { throw 'Nama penerbit belum valid.' }
    if ($config.support_email -notmatch '^[A-Za-z0-9.!#$%&''*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') { throw 'Alamat dukungan belum valid.' }
    $url = $null
    if (-not [Uri]::TryCreate($config.privacy_url,[UriKind]::Absolute,[ref]$url) -or $url.Scheme -ne 'https' -or $url.Host -in @('example.com','example.org','localhost') -or $url.UserInfo) { throw 'URL privasi harus HTTPS publik milik penerbit.' }
    if ($config.version_name -notmatch '^\d+\.\d+\.\d+$' -or [long]$config.version_code -lt 1 -or [long]$config.version_code -gt 2100000000) { throw 'Versi rilis tidak valid.' }
    return $config
}
function Configure-Publisher {
    $path = Join-Path $ProjectRoot 'release/release_config.json'
    if (Test-Path $path) {
        Write-Host "Konfigurasi sudah ada: $path"
        Write-Host 'Edit file ini untuk mengubah identitas atau menaikkan versi. Perubahan diterapkan saat BUAT_AAB.'
        Start-Process notepad.exe -ArgumentList ('"'+$path+'"') -Wait
    }
    else {
        $config = [ordered]@{
            package_name=(Read-Host 'Package name final milikmu (format: domain.penerbit.game)')
            publisher_name=(Read-Host 'Nama penerbit yang akan tampil di kebijakan privasi')
            support_email=(Read-Host 'Email dukungan milikmu')
            privacy_url=(Read-Host 'URL HTTPS kebijakan privasi yang akan kamu terbitkan')
            version_name='1.0.0'
            version_code=1
        }
        Write-Utf8 $path ($config | ConvertTo-Json)
    }
    $config = Read-PublisherConfig
    Apply-Publisher $config
    Write-Host 'Identitas tersimpan. Terbitkan release/privacy-policy.html pada URL yang kamu isi, lalu periksa isinya.'
}
function Apply-Publisher($Config) {
    $preset = Join-Path $ProjectRoot 'export_presets.cfg'
    Set-GodotValue $preset 'preset.0.options' 'package/unique_name' (Quote-Godot $Config.package_name)
    Set-GodotValue $preset 'preset.0.options' 'version/name' (Quote-Godot $Config.version_name)
    Set-GodotValue $preset 'preset.0.options' 'version/code' ([string]$Config.version_code)
    Set-GodotValue $preset 'preset.0' 'export_path' (Quote-Godot ('artifacts/JadeAscendant-'+$Config.version_name+'.aab'))
    $info = Join-Path $ProjectRoot 'release/publisher_info.cfg'
    Set-GodotValue $info 'publisher' 'name' (Quote-Godot $Config.publisher_name)
    Set-GodotValue $info 'publisher' 'support_email' (Quote-Godot $Config.support_email)
    Set-GodotValue $info 'publisher' 'privacy_url' (Quote-Godot $Config.privacy_url)
    $html = [System.IO.File]::ReadAllText((Join-Path $ProjectRoot 'release/privacy-policy.template.html'))
    $html = $html.Replace('{{PUBLISHER_NAME}}',[System.Net.WebUtility]::HtmlEncode($Config.publisher_name)).Replace('{{SUPPORT_EMAIL}}',[System.Net.WebUtility]::HtmlEncode($Config.support_email)).Replace('{{EFFECTIVE_DATE}}',(Get-Date -Format 'yyyy-MM-dd'))
    Write-Utf8 (Join-Path $ProjectRoot 'release/privacy-policy.html') $html
}
function Find-JavaTool([string]$Name) {
    foreach ($root in @($env:JAVA_HOME,(Get-GodotEditorSetting 'export/android/java_sdk_path'))) {
        if (-not $root) { continue }
        $candidate = Join-Path $root ('bin/'+$Name+'.exe')
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    $command = Get-Command ($Name+'.exe') -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw "$Name belum ditemukan. Pasang JDK 17 dan arahkan JAVA_HOME atau Java SDK Path Godot ke folder JDK."
}

function Read-JavaVersionText([string]$Executable) {
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo.FileName = $Executable
    $process.StartInfo.Arguments = '-version'
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    try {
        if (-not $process.Start()) { throw 'Executable Java tidak dapat dimulai.' }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(10000)) {
            $process.Kill()
            throw 'Java tidak menjawab pemeriksaan versi dalam 10 detik.'
        }
        $text = (($stderr.Result + "`n" + $stdout.Result).Trim())
        if ($process.ExitCode -ne 0) { throw ("Pemeriksaan versi Java gagal. " + $text) }
        if (-not $text) { throw 'Java tidak mengembalikan informasi versi.' }
        return $text
    }
    finally { $process.Dispose() }
}

function Get-GodotEditorSetting([string]$Key) {
    if (-not $env:APPDATA) { return '' }
    $folder = Join-Path $env:APPDATA 'Godot'
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) { return '' }
    $files = @(Get-ChildItem -LiteralPath $folder -Filter 'editor_settings-4*.tres' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    foreach ($file in $files) {
        $text = [System.IO.File]::ReadAllText($file.FullName)
        $match = [regex]::Match($text,'(?m)^'+[regex]::Escape($Key)+'\s*=\s*"(?<value>(?:\\.|[^"])*)"\s*$')
        if ($match.Success) {
            $value = $match.Groups['value'].Value.Replace('\\','\')
            if ($value) { return $value }
        }
    }
    return ''
}

function Get-AndroidSdkPath {
    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($value in @($env:ANDROID_HOME,$env:ANDROID_SDK_ROOT,(Get-GodotEditorSetting 'export/android/android_sdk_path'))) {
        if ($value -and -not $candidates.Contains($value)) { $candidates.Add($value) }
    }
    if ($env:LOCALAPPDATA) {
        $defaultSdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
        if (-not $candidates.Contains($defaultSdk)) { $candidates.Add($defaultSdk) }
    }
    foreach ($candidate in $candidates) {
        if (-not $candidate) { continue }
        $clean = $candidate.Trim().Trim('"')
        if (Test-Path -LiteralPath (Join-Path $clean 'platform-tools\adb.exe') -PathType Leaf) { return $clean }
    }
    throw 'Android SDK belum ditemukan. Pasang Android SDK lalu pastikan platform-tools\adb.exe tersedia. Lokasi Windows yang umum: %LOCALAPPDATA%\Android\Sdk.'
}
function Get-VersionFromFolderName([string]$Name) {
    try { return [Version]$Name }
    catch { return $null }
}
function Assert-AndroidEnvironment([string]$Executable,[bool]$RequirePublisher=$false) {
    Write-Host 'Memeriksa Android build environment...' -ForegroundColor Cyan
    $checks = New-Object System.Collections.Generic.List[object]
    function Add-AndroidCheck([string]$Name,[bool]$Passed,[string]$Details) {
        $checkStatus = if ($Passed) { 'PASS' } else { 'FAIL' }
        $checks.Add([ordered]@{ name=$Name; status=$checkStatus; details=$Details }) | Out-Null
        if ($Passed) { Write-Host "[PASS] $Name - $Details" -ForegroundColor Green }
        else { Write-Host "[FAIL] $Name - $Details" -ForegroundColor Red }
    }

    $java = $null; $javaVersionText = ''; $javaMajor = 0
    try {
        $java = Find-JavaTool 'java'
        $javaVersionText = Read-JavaVersionText $java
        $versionLine = (($javaVersionText -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -First 1).Trim()
        # Accept the standard Java/OpenJDK version forms, including four-part Temurin builds such as 17.0.20.1.
        $match = [regex]::Match($versionLine,'(?i)(?:openjdk|java)\s+version\s+"(?<major>\d+)(?:\.(?<minor>\d+))?')
        if (-not $match.Success) {
            $match = [regex]::Match($versionLine,'(?i)^openjdk\s+(?<major>\d+)(?:\.(?<minor>\d+))?')
        }
        if ($match.Success) {
            $javaMajor = [int]$match.Groups['major'].Value
            if ($javaMajor -eq 1 -and $match.Groups['minor'].Success) { $javaMajor = [int]$match.Groups['minor'].Value }
        }
        $javaPass = ($javaMajor -eq 17)
        $javaDetails = "$java | $versionLine"
        if ($javaMajor -gt 0 -and -not $javaPass) { $javaDetails += ' | Jade Ascendant release baseline dikunci ke JDK 17.' }
        if ($javaMajor -eq 0) { $javaDetails += ' | Versi Java tidak dapat diparse.' }
        Add-AndroidCheck 'Java/JDK 17' $javaPass $javaDetails
    }
    catch { Add-AndroidCheck 'Java/JDK 17' $false $_.Exception.Message }

    $sdk = $null
    try {
        $sdk = Get-AndroidSdkPath
        Add-AndroidCheck 'Android SDK root' $true $sdk
        Add-AndroidCheck 'Platform Tools / adb' (Test-Path -LiteralPath (Join-Path $sdk 'platform-tools\adb.exe') -PathType Leaf) (Join-Path $sdk 'platform-tools\adb.exe')
        $platform36 = Join-Path $sdk 'platforms\android-36\android.jar'
        Add-AndroidCheck 'Android Platform API 36' (Test-Path -LiteralPath $platform36 -PathType Leaf) $platform36

        $buildToolsRoot = Join-Path $sdk 'build-tools'
        $best = $null; $bestName = ''
        if (Test-Path -LiteralPath $buildToolsRoot -PathType Container) {
            Get-ChildItem -LiteralPath $buildToolsRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $parsed = Get-VersionFromFolderName $_.Name
                if ($parsed -and (($null -eq $best) -or $parsed -gt $best)) { $best=$parsed; $bestName=$_.Name }
            }
        }
        $buildToolsOk = ($null -ne $best -and $best -ge [Version]'35.0.1')
        $buildToolsDetails = if ($bestName) { "$bestName at $buildToolsRoot" } else { "Tidak ada versi di $buildToolsRoot" }
        Add-AndroidCheck 'Android Build-Tools >= 35.0.1' $buildToolsOk $buildToolsDetails

        $sdkManagerCandidates = @(
            (Join-Path $sdk 'cmdline-tools\latest\bin\sdkmanager.bat'),
            (Join-Path $sdk 'tools\bin\sdkmanager.bat')
        )
        $sdkManager = $sdkManagerCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
        $sdkManagerDetails = if ($sdkManager) { [string]$sdkManager } else { 'sdkmanager.bat tidak ditemukan; pasang Command-line Tools (latest).' }
        Add-AndroidCheck 'Android Command-line Tools' ([bool]$sdkManager) $sdkManagerDetails
    }
    catch { Add-AndroidCheck 'Android SDK root' $false $_.Exception.Message }

    $templatesRoot = if ($env:APPDATA) { Join-Path $env:APPDATA 'Godot\export_templates' } else { '' }
    $templateFolder = $null
    if ($templatesRoot -and (Test-Path -LiteralPath $templatesRoot -PathType Container)) {
        $templateFolder = Get-ChildItem -LiteralPath $templatesRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '4.7.2*' } | Sort-Object Name -Descending | Select-Object -First 1
    }
    $androidSource = if ($templateFolder) { Join-Path $templateFolder.FullName 'android_source.zip' } else { '' }
    $templateDetails = if ($templateFolder) { $templateFolder.FullName } else { "Tidak ditemukan di $templatesRoot" }
    Add-AndroidCheck 'Godot 4.7.2 export templates' ([bool]($templateFolder -and (Test-Path -LiteralPath $androidSource -PathType Leaf))) $templateDetails

    $preset = Join-Path $ProjectRoot 'export_presets.cfg'
    $presetText = if (Test-Path $preset) { [System.IO.File]::ReadAllText($preset) } else { '' }
    Add-AndroidCheck 'Preset AAB / API 36 / ARM64' (($presetText -match '(?m)^gradle_build/export_format=1$') -and ($presetText -match '(?m)^gradle_build/target_sdk="36"$') -and ($presetText -match '(?m)^architectures/arm64-v8a=true$')) 'Android preset harus AAB, target API 36, ARM64 aktif.'

    $publisherReady = $true; $publisherDetails = 'Tidak diwajibkan untuk environment-only preflight.'
    if ($RequirePublisher) {
        try { $config = Read-PublisherConfig; $publisherDetails = "$($config.package_name) | v$($config.version_name) ($($config.version_code))" }
        catch { $publisherReady = $false; $publisherDetails = $_.Exception.Message }
        Add-AndroidCheck 'Publisher/package configuration' $publisherReady $publisherDetails
    }

    $failed = @($checks | Where-Object { $_.status -eq 'FAIL' })
    $overallStatus = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }
    $report = [ordered]@{
        timestamp=(Get-Date).ToString('o')
        status=$overallStatus
        require_publisher=$RequirePublisher
        godot=$Executable
        java_major=$javaMajor
        android_sdk=$sdk
        checks=$checks
    }
    $reportPath = Join-Path $Artifacts 'android-preflight.json'
    Write-Utf8 $reportPath ($report | ConvertTo-Json -Depth 6)
    if ($failed.Count -gt 0) {
        Write-Host "Android preflight FAIL. Laporan: $reportPath" -ForegroundColor Red
        Write-Host 'Jika Build-Tools/API 36 belum ada, install lewat Android Studio SDK Manager atau sdkmanager. Setelah itu set Java SDK Path dan Android SDK Path pada Editor > Editor Settings > Export > Android.' -ForegroundColor Yellow
        throw 'Android environment belum siap. Baca daftar FAIL di atas.'
    }
    Write-Host "Android preflight PASS. Laporan: $reportPath" -ForegroundColor Green
    return $report
}

function New-UploadKey {
    $keytool = Find-JavaTool 'keytool'
    $folder = Join-Path $LocalFolder 'keys'
    New-Item -ItemType Directory -Force $folder | Out-Null
    $path = Join-Path $folder 'JadeAscendant-upload.jks'
    if (Test-Path -LiteralPath $path) { throw 'Kunci upload sudah ada. Kunci lama tidak ditimpa.' }
    Write-Host 'Keytool akan meminta password dan identitasmu. Gunakan password kunci yang sama dengan password keystore.'
    & $keytool -genkeypair -keystore $path -alias jade_upload -keyalg RSA -keysize 4096 -validity 10000 -storetype JKS
    if ($LASTEXITCODE -ne 0) { throw 'Pembuatan kunci belum selesai.' }
    Write-Host "Kunci dibuat: $path. Simpan cadangan pribadi beserta password; jangan kirim dalam ZIP proyek."
}
function Assert-AabNativeAlignment([string]$Bundle) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Bundle)
    $checked = 0
    try {
        $libraries = @($archive.Entries | Where-Object { $_.FullName -match '/lib/arm64-v8a/[^/]+\.so$' })
        if ($libraries.Count -eq 0) { throw 'AAB tidak berisi native library ARM64.' }
        foreach ($entry in $libraries) {
            $stream = $entry.Open(); $buffer = New-Object System.IO.MemoryStream
            try { $stream.CopyTo($buffer); $bytes = $buffer.ToArray() } finally { $stream.Dispose(); $buffer.Dispose() }
            if ($bytes.Length -lt 64 -or $bytes[0] -ne 127 -or $bytes[1] -ne 69 -or $bytes[2] -ne 76 -or $bytes[3] -ne 70 -or $bytes[4] -ne 2 -or $bytes[5] -ne 1) { throw "ELF ARM64 tidak valid: $($entry.FullName)" }
            $offset = [BitConverter]::ToUInt64($bytes,32)
            $size = [BitConverter]::ToUInt16($bytes,54)
            $count = [BitConverter]::ToUInt16($bytes,56)
            if ($size -lt 56 -or $offset + [long]$size*$count -gt $bytes.Length) { throw 'Program header ELF tidak valid.' }
            $loads = 0
            for ($index=0; $index -lt $count; $index++) {
                $position = [int]($offset + $size*$index)
                if ([BitConverter]::ToUInt32($bytes,$position) -ne 1) { continue }
                $loads++
                $alignment = [BitConverter]::ToUInt64($bytes,$position+48)
                if ($alignment -lt 16384) { throw "Alignment 16 KB belum terpenuhi: $($entry.FullName). Perbarui export template/plugin native." }
            }
            if ($loads -eq 0) { throw 'ELF tidak berisi segmen LOAD.' }
            $checked++
        }
    }
    finally { $archive.Dispose() }
    return $checked
}
function Build-Bundle([string]$Executable) {
    $null = Assert-AndroidEnvironment $Executable $true
    $config = Read-PublisherConfig
    Apply-Publisher $config
    # A fresh engine check is a build gate, never a cached PASS from another revision.
    Invoke-GameCheck $Executable
    $jarsigner = Find-JavaTool 'jarsigner'
    $keystore = Join-Path $LocalFolder 'keys/JadeAscendant-upload.jks'
    $alias = 'jade_upload'
    if (-not (Test-Path -LiteralPath $keystore)) {
        Add-Type -AssemblyName System.Windows.Forms
        $picker = New-Object System.Windows.Forms.OpenFileDialog
        $picker.Title = 'Pilih kunci upload milikmu; buat dengan BUAT_KUNCI_UPLOAD bila belum ada'
        $picker.Filter = 'Keystore (*.jks;*.keystore)|*.jks;*.keystore|All files (*.*)|*.*'
        if ($picker.ShowDialog() -ne 'OK') { throw 'Kunci upload belum dipilih.' }
        $keystore=$picker.FileName; $picker.Dispose()
        $alias=Read-Host 'Alias kunci di dalam keystore'
    }
    $password = Read-Host 'Password keystore upload (tidak disimpan ke proyek)' -AsSecureString
    $pointer = [IntPtr]::Zero
    $environmentNames=@('GODOT_ANDROID_KEYSTORE_RELEASE_PATH','GODOT_ANDROID_KEYSTORE_RELEASE_USER','GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD')
    $previousEnvironment=@{}
    foreach($name in $environmentNames) { $previousEnvironment[$name]=[Environment]::GetEnvironmentVariable($name,'Process') }
    $bundle = Join-Path $Artifacts ('JadeAscendant-'+$config.version_name+'.aab')
    $log = Join-Path $Artifacts 'android-export.log'
    try {
        $pointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
        $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$keystore
        $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER=$alias
        $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        $null=Invoke-GodotStep $Executable @('--headless','--path',$ProjectRoot,'--install-android-build-template','--export-release','Android',$bundle) $log $false
    }
    finally {
        # Redact if an external build tool unexpectedly echoed the password.
        $secret=[Environment]::GetEnvironmentVariable('GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD','Process')
        if ($secret -and (Test-Path $log)) { Write-Utf8 $log ([System.IO.File]::ReadAllText($log).Replace($secret,'[REDACTED]')) }
        foreach($name in $environmentNames) { [Environment]::SetEnvironmentVariable($name,$previousEnvironment[$name],'Process') }
        if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
        $password.Dispose()
    }
    if (-not (Test-Path $bundle) -or (Get-Item $bundle).Length -eq 0) { throw 'Export tidak menghasilkan AAB.' }
    $nativeCount=Assert-AabNativeAlignment $bundle
    $verification = (& $jarsigner '-J-Duser.language=en' '-J-Duser.country=US' -verify $bundle 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -or $verification -notmatch 'jar verified') { throw 'Tanda tangan AAB belum terverifikasi.' }
    Write-Utf8 (Join-Path $Artifacts 'aab-signature.log') $verification
    $record=[ordered]@{ bundle=$bundle; sha256=(Get-FileHash $bundle -Algorithm SHA256).Hash; version_name=$config.version_name; version_code=$config.version_code; package_name=$config.package_name; signature='PASS'; elf_16kb='PASS'; arm64_libraries=$nativeCount; apk_zip_alignment='NOT_RUN'; device_16kb='NOT_RUN'; target_manifest='VERIFY_IN_PLAY_CONSOLE'; play_review='NOT_SUBMITTED' }
    Write-Utf8 (Join-Path $Artifacts 'aab-build-report.json') ($record | ConvertTo-Json)
    Write-Host "AAB bertanda tangan dibuat: $bundle" -ForegroundColor Green
    Write-Host 'Lanjutkan uji internal di Play Console dan pemeriksaan perangkat pada docs/release/PLAYSTORE.md.'
}

try {
    if (-not (Test-Path (Join-Path $ProjectRoot 'scenes/system/boot.tscn'))) { throw 'Ini paket file pengganti. Ekstrak ke folder proyek lama yang berisi project.godot, lalu pilih Replace.' }
    Set-Location -LiteralPath $ProjectRoot
    switch ($Mode) {
        'Configure' { Configure-Publisher }
        'Key' { New-UploadKey }
        'Run' {
            $engine=Get-Godot
            $null=Invoke-GodotStep $engine @('--headless','--path',$ProjectRoot,'--import') (Join-Path $Artifacts 'run-import.log') $false
            & $engine --path $ProjectRoot
            if ($LASTEXITCODE -ne 0) { throw 'Game berhenti dengan error. Jalankan PERIKSA_GAME.bat.' }
        }
        'Check' { $engine=Get-Godot; Invoke-GameCheck $engine }
        'Android' { $engine=Get-Godot; $null=Assert-AndroidEnvironment $engine $false }
        'Build' { $engine=Get-Godot; Build-Bundle $engine }
        'Capture' {
            $engine=Get-Godot; $qa=New-QACopy
            $captures=Join-Path $Artifacts 'screenshots'
            New-Item -ItemType Directory -Force $captures | Out-Null
            try {
                Set-GodotValue (Join-Path $qa.Path 'override.cfg') 'jade_phase0' 'capture_path' (Quote-Godot $captures.Replace('\','/'))
                $null=Invoke-GodotStep $engine @('--headless','--path',$qa.Path,'--import') (Join-Path $Artifacts 'capture-import.log')
                Write-Host 'Mainkan salinan uji. Tekan F12 pada jendela game untuk menyimpan screenshot asli. Tutup game untuk selesai.'
                & $engine --path $qa.Path --resolution 1080x1920 --script res://tools/capture_session.gd
                if ($LASTEXITCODE -ne 0) { throw 'Capture berhenti dengan error.' }
            }
            finally {
                if ((Split-Path -Leaf $qa.Path) -eq $qa.Token) { Remove-Item -LiteralPath $qa.Path -Recurse -Force }
                $saveCopy=Join-Path $env:APPDATA $qa.Token
                if (Test-Path -LiteralPath $saveCopy) { Remove-Item -LiteralPath $saveCopy -Recurse -Force }
            }
            Write-Host "Screenshot: $captures"
        }
    }
    exit 0
}
catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }

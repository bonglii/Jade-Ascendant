# Gradle 8.13 bin SHA-256, independently checked against Gradle's two official
# checksum endpoints. No HTML/body cast.
function Get-JadeGradle813Hash { return '20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78' }
function Test-JadeGradle813Zip([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() -eq (Get-JadeGradle813Hash)
}
function Test-JadeGradle813Home([string]$Path) {
    return (Test-Path -LiteralPath (Join-Path $Path 'bin/gradle.bat') -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $Path 'lib/gradle-launcher-8.13.jar') -PathType Leaf)
}
function Get-JadeGradle813([string]$GradlePath='', [string]$CacheRoot='') {
    if ($GradlePath) {
        if (-not (Test-Path -LiteralPath $GradlePath -PathType Leaf)) { throw 'Explicit Gradle launcher does not exist.' }
        return (Resolve-Path -LiteralPath $GradlePath).Path
    }
    if (-not $CacheRoot) { $CacheRoot=Join-Path $env:LOCALAPPDATA 'JadeAscendant/BuildTools' }
    $gradleHome=Join-Path $CacheRoot 'gradle-8.13'
    if (Test-JadeGradle813Home $gradleHome) { Write-Host 'GRADLE_813=EXISTING_JADE_CACHE'; return (Join-Path $gradleHome 'bin/gradle.bat') }
    $installed=Get-Command gradle.bat -ErrorAction SilentlyContinue
    if ($installed) {
        $installedHome=Split-Path (Split-Path $installed.Source -Parent) -Parent
        if (Test-JadeGradle813Home $installedHome) { Write-Host 'GRADLE_813=EXISTING_PATH'; return $installed.Source }
    }
    $roots=@()
    if ($env:GRADLE_USER_HOME) { $roots+=$env:GRADLE_USER_HOME }
    if ($env:USERPROFILE) { $roots+=(Join-Path $env:USERPROFILE '.gradle') }
    foreach ($root in $roots) {
        foreach ($kind in @('bin','all')) {
            $pattern=Join-Path $root ('wrapper/dists/gradle-8.13-' + $kind + '/*/gradle-8.13')
            foreach ($candidate in @(Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue)) {
                if (Test-JadeGradle813Home $candidate.FullName) { Write-Host 'GRADLE_813=EXISTING_WRAPPER_CACHE'; return (Join-Path $candidate.FullName 'bin/gradle.bat') }
            }
        }
    }
    New-Item -ItemType Directory -Force -Path $CacheRoot | Out-Null
    $zip=Join-Path $CacheRoot 'gradle-8.13-bin.zip'
    if (-not (Test-JadeGradle813Zip $zip)) {
        $verified=$false
        foreach ($url in @('https://downloads.gradle.org/distributions/gradle-8.13-bin.zip','https://services.gradle.org/distributions/gradle-8.13-bin.zip')) {
            $part=Join-Path $CacheRoot ('gradle-8.13.' + [Guid]::NewGuid().ToString('N') + '.download')
            try {
                Write-Host ('GRADLE_813_DOWNLOAD=' + $url)
                [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $part -TimeoutSec 180
                if (-not (Test-JadeGradle813Zip $part)) {
                    $actual=(Get-FileHash -LiteralPath $part -Algorithm SHA256).Hash.ToLowerInvariant()
                    Write-Host ('GRADLE_813_REJECTED; BYTES=' + (Get-Item -LiteralPath $part).Length + '; SHA256=' + $actual)
                    continue
                }
                if (Test-Path -LiteralPath $zip) { Move-Item -LiteralPath $zip -Destination ($zip + '.previous-' + [Guid]::NewGuid().ToString('N')) }
                Move-Item -LiteralPath $part -Destination $zip
                $verified=$true; break
            } catch { Write-Host ('GRADLE_813_DOWNLOAD_FAILED=' + $_.Exception.GetType().Name) }
            finally { if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part -Force } }
        }
        if (-not $verified) { throw 'Neither official Gradle download matched the pinned SHA-256. No archive was extracted.' }
    }
    Write-Host 'GRADLE_813_ZIP_SHA256=PASS'
    $unpack=Join-Path $CacheRoot ('gradle-unpack-' + [Guid]::NewGuid().ToString('N'))
    try {
        Expand-Archive -LiteralPath $zip -DestinationPath $unpack
        $expanded=Join-Path $unpack 'gradle-8.13'
        if (-not (Test-JadeGradle813Home $expanded)) { throw 'Verified Gradle archive has an unexpected layout.' }
        if (Test-Path -LiteralPath $gradleHome) { Move-Item -LiteralPath $gradleHome -Destination ($gradleHome + '.previous-' + [Guid]::NewGuid().ToString('N')) }
        Move-Item -LiteralPath $expanded -Destination $gradleHome
    } finally { if (Test-Path -LiteralPath $unpack) { Remove-Item -LiteralPath $unpack -Recurse -Force } }
    return (Join-Path $gradleHome 'bin/gradle.bat')
}

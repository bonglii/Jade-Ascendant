param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path, [switch]$Setup)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$client = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'scripts\managers\player_identity_server_client.gd'))
$match = [regex]::Match($client, 'const ENDPOINT: String = "(https://[^"\r\n]+)/v1/player/register"')
if (-not $match.Success) { throw 'Client endpoint not found.' }
$origin = $match.Groups[1].Value
$originFile = Join-Path $PSScriptRoot 'admin-origin.local.txt'
if (Test-Path -LiteralPath $originFile) {
    $candidate = [IO.File]::ReadAllText($originFile).Trim()
    $adminUri = $null
    if (-not [Uri]::TryCreate($candidate, [UriKind]::Absolute, [ref]$adminUri) -or $adminUri.Scheme -ne 'https' -or $adminUri.UserInfo -or $adminUri.Query -or $adminUri.Fragment -or $adminUri.AbsolutePath -ne '/' -or -not $adminUri.IsDefaultPort) { throw 'Custom admin origin must be an HTTPS hostname without path or credentials.' }
    $origin = $adminUri.GetLeftPart([UriPartial]::Authority)
}
if ($Setup) {
    Add-Type -AssemblyName System.Security
    $keyFile = Join-Path $PSScriptRoot '.mail-admin-key.dpapi'
    if (-not (Test-Path -LiteralPath $keyFile)) { throw 'Initial setup key is missing. Existing admins can open without -Setup and use username/password.' }
    $bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($keyFile), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    $setupKey = [Text.Encoding]::UTF8.GetString($bytes)
    if ($setupKey -notmatch '^[a-f0-9]{64}$') { throw 'Invalid protected setup key.' }
    Set-Clipboard -Value $setupKey
    $setupKey = $null
}
$hostName = ([Uri]$origin).DnsSafeHost
$addresses = @()
foreach ($resolver in @('https://dns.google/resolve?name=', 'https://cloudflare-dns.com/dns-query?name=')) {
    try {
        $dns = Invoke-RestMethod -Uri ($resolver + [Uri]::EscapeDataString($hostName) + '&type=A') -Headers @{ Accept = 'application/dns-json' } -TimeoutSec 8
        $addresses = @($dns.Answer | Where-Object { $_.type -eq 1 -and $_.data -match '^\d{1,3}(\.\d{1,3}){3}$' } | ForEach-Object { $_.data } | Select-Object -Unique)
        if ($dns.Status -eq 0 -and $addresses.Count -gt 0) { break }
    } catch { $addresses = @() }
}
if ($addresses.Count -eq 0) { throw 'Encrypted DNS is unavailable. Retry the desktop shortcut; Windows DNS was not changed.' }
$browsers = @()
foreach ($folder in @([Environment]::GetFolderPath('ProgramFilesX86'),[Environment]::GetFolderPath('ProgramFiles'),$env:LOCALAPPDATA)) {
    if ($folder) {
        $browsers += (Join-Path $folder 'Microsoft\Edge\Application\msedge.exe')
        $browsers += (Join-Path $folder 'Google\Chrome\Application\chrome.exe')
    }
}
$browserExecutable = @($browsers | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1)
if ($browserExecutable.Count -eq 0) { throw 'Chrome or Edge is required for this dashboard shortcut.' }
$browserProfile = Join-Path $env:LOCALAPPDATA 'JadeAscendant\MailAdminBrowser'
$arguments = @(('--user-data-dir="' + $browserProfile + '"'), ('--host-resolver-rules="MAP ' + $hostName + ' ' + $addresses[0] + '"'), '--no-first-run', ($origin + '/admin'))
Start-Process -FilePath $browserExecutable[0] -ArgumentList $arguments
Write-Host 'Dashboard opened. Sign in with the existing admin username and password.'
Write-Host 'Encrypted DNS applies only to this dashboard browser profile. Windows DNS and TLS verification are unchanged.'

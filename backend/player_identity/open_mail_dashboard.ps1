param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
$keyFile = Join-Path $PSScriptRoot '.mail-admin-key.dpapi'
if (-not (Test-Path -LiteralPath $keyFile)) { throw 'Run deploy_mail.ps1 first on this Windows account.' }
$bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($keyFile), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
$adminKey = [Text.Encoding]::UTF8.GetString($bytes)
if ($adminKey -notmatch '^[a-f0-9]{64}$') { throw 'Invalid protected admin key.' }
$client = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'scripts\managers\player_identity_server_client.gd'))
$match = [regex]::Match($client, 'const ENDPOINT: String = "(https://[^"\r\n]+)/v1/player/register"')
if (-not $match.Success) { throw 'Client endpoint not found.' }
Set-Clipboard -Value $adminKey
$adminKey = $null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$origin = $match.Groups[1].Value
$hostName = ([Uri]$origin).DnsSafeHost
$dns = Invoke-RestMethod -Uri ('https://dns.google/resolve?name=' + [Uri]::EscapeDataString($hostName) + '&type=A') -TimeoutSec 10
$addresses = @($dns.Answer | Where-Object { $_.type -eq 1 -and $_.data -match '^\d{1,3}(\.\d{1,3}){3}$' } | ForEach-Object { $_.data })
if ($dns.Status -ne 0 -or $addresses.Count -eq 0) { throw 'Unable to resolve the dashboard through HTTPS DNS.' }
$browsers = @()
foreach ($folder in @([Environment]::GetFolderPath('ProgramFilesX86'),[Environment]::GetFolderPath('ProgramFiles'),$env:LOCALAPPDATA)) {
    if ($folder) {
        $browsers += (Join-Path $folder 'Microsoft\Edge\Application\msedge.exe')
        $browsers += (Join-Path $folder 'Google\Chrome\Application\chrome.exe')
    }
}
$browserExecutable = @($browsers | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1)
if ($browserExecutable.Count -eq 0) { throw 'Chrome or Edge is required for the isolated dashboard launcher.' }
$browserProfile = Join-Path $env:LOCALAPPDATA 'JadeAscendant\MailAdminBrowser'
$arguments = @(('--user-data-dir="' + $browserProfile + '"'), ('--host-resolver-rules="MAP ' + $hostName + ' ' + $addresses[0] + '"'), '--no-first-run', ($origin + '/admin'))
Start-Process -FilePath $browserExecutable[0] -ArgumentList $arguments
Write-Host 'Dashboard opened. First setup: paste the copied deployment key. After account setup: use your username and password; the old key cannot log in.'
Write-Host 'Dashboard uses its own browser profile and DNS route; your normal browser and Windows DNS settings are unchanged.'

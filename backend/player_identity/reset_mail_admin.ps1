$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
$sqlFile = $null
$adminKey = $null
$password = $null
$confirmation = $null
$resetFailed = $false
$previousOutputEncoding = $OutputEncoding
try {
    $OutputEncoding = New-Object Text.UTF8Encoding($false)
    & node --test identity.test.mjs mail.test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Backend tests failed; reset stopped.' }
    $config = Join-Path $PSScriptRoot 'wrangler.local.toml'
    $keyFile = Join-Path $PSScriptRoot '.mail-admin-key.dpapi'
    if (-not (Test-Path -LiteralPath $config) -or -not (Test-Path -LiteralPath $keyFile)) { throw 'Use the original deployment laptop and Windows account; config and protected key are required.' }
    Add-Type -AssemblyName System.Security
    $adminKey = [Text.Encoding]::UTF8.GetString([Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($keyFile), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))
    $username = Read-Host 'Admin username (choose the username you will use)'
    $securePassword = Read-Host 'New password (12-128 characters)' -AsSecureString
    $secureConfirmation = Read-Host 'Repeat new password' -AsSecureString
    $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    try { $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer) }
    $confirmationPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureConfirmation)
    try { $confirmation = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($confirmationPointer) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($confirmationPointer) }
    if ($username -notmatch '^[a-zA-Z0-9_.-]{3,40}$') { throw 'Username must contain 3-40 letters, numbers, dots, underscores or hyphens. Nothing changed.' }
    if ($password.Length -lt 12 -or $password.Length -gt 128) { throw 'Password must contain 12-128 characters. Nothing changed.' }
    if ($password -cne $confirmation) { throw 'Passwords do not match. Nothing changed.' }
    $sqlFile = [IO.Path]::GetTempFileName()
    @{ username=$username; password=$password; key=$adminKey } | ConvertTo-Json -Compress | & node reset_mail_admin.mjs $sqlFile
    if ($LASTEXITCODE -ne 0) { throw 'Password preparation failed. Nothing changed.' }
    $adminKey = $null
    $password = $null
    $confirmation = $null
    & npx.cmd --yes wrangler@4 d1 execute PROFILE_DB --config $config --remote --file $sqlFile --yes
    if ($LASTEXITCODE -ne 0) { throw 'Admin reset failed; check the Wrangler error before retrying.' }
    Write-Host 'MAIL_ADMIN_RESET=PASS; old sessions revoked. Log in with your chosen username and new password.'
    Write-Host 'Player identities, mail, rewards and delivery history are preserved.'
} catch {
    $resetFailed = $true
    Write-Host ('MAIL_ADMIN_RESET=FAIL; ' + $_.Exception.Message)
} finally {
    $OutputEncoding = $previousOutputEncoding
    $adminKey = $null
    $password = $null
    $confirmation = $null
    if ($sqlFile -and (Test-Path -LiteralPath $sqlFile)) { Remove-Item -LiteralPath $sqlFile -Force }
    Pop-Location
}

if ($resetFailed) { exit 1 }
exit 0

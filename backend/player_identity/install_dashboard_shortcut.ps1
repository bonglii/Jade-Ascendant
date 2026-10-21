$ErrorActionPreference = 'Stop'
$target = Join-Path $PSScriptRoot 'open_mail_dashboard.cmd'
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw 'Dashboard launcher missing.' }
$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'Jade Ascendant Studio.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $target
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.Description = 'Jade Ascendant admin dashboard; isolated browser DNS, existing account login.'
$shortcut.Save()
Write-Host ('DASHBOARD_SHORTCUT=PASS; ' + $shortcutPath)

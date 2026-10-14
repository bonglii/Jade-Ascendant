param([string]$ProjectPath = 'D:\Godot\project\jade-ascendant')
$ErrorActionPreference = 'Stop'
try {
    if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) { throw 'Project folder was not found.' }
    $project = (Resolve-Path -LiteralPath $ProjectPath).Path
    $git = (Get-Command git -ErrorAction Stop).Source
    function Invoke-ProjectGit([string]$Arguments) {
        $info = New-Object System.Diagnostics.ProcessStartInfo
        $info.FileName = $git
        $info.Arguments = $Arguments
        $info.WorkingDirectory = $project
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $process = [System.Diagnostics.Process]::Start($info)
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $result = @{ Code = $process.ExitCode; Text = $stdout.Result + $stderr.Result }
        $process.Dispose()
        return $result
    }
    $root = Invoke-ProjectGit 'rev-parse --show-toplevel'
    if ($root.Code -ne 0 -or [IO.Path]::GetFullPath($root.Text.Trim()) -ne [IO.Path]::GetFullPath($project)) { throw 'Project path must be the repository root.' }
    $branch = Invoke-ProjectGit 'branch --show-current'
    if ($branch.Code -ne 0 -or $branch.Text.Trim() -ne 'checkpoint/iap-fasttrack-20261010') { throw 'Use the authorized checkpoint branch. Main is protected.' }
    $names = @('Jade-Ascendant-Celestial-Gate-Auto-Mail.patch','Jade-Ascendant-Arsenal-Gate-Combined.patch')
    foreach ($name in $names) {
        $patch = Join-Path $PSScriptRoot $name
        if (-not (Test-Path -LiteralPath $patch -PathType Leaf)) { continue }
        $reverse = Invoke-ProjectGit ('apply --reverse --check -- "' + $patch + '"')
        if ($reverse.Code -eq 0) { Write-Host 'GATE_AUTO_MAIL_APPLY=ALREADY_INSTALLED'; exit 0 }
    }
    Write-Host 'Checking the package against your actual project files...'
    foreach ($name in $names) {
        $patch = Join-Path $PSScriptRoot $name
        if (-not (Test-Path -LiteralPath $patch -PathType Leaf)) { continue }
        $check = Invoke-ProjectGit ('apply --check --whitespace=error-all -- "' + $patch + '"')
        if ($check.Code -ne 0) { continue }
        $applied = Invoke-ProjectGit ('apply --whitespace=error-all -- "' + $patch + '"')
        if ($applied.Code -ne 0) { throw ('Apply failed: ' + $applied.Text) }
        Write-Host ('GATE_AUTO_MAIL_APPLY=PASS; PACKAGE=' + $name)
        Write-Host 'Open Godot, finish asset import, then re-export Android.'
        Write-Host 'Publish: backend\player_identity\publish_gate_auto_mail.cmd'
        exit 0
    }
    throw 'Neither package matches the current files. Nothing was applied. Keep your local edits and report git status --short; do not force or partially apply the patch.'
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}

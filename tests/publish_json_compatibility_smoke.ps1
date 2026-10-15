$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$checks = 0
function Assert-Json([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }; $script:checks++
}
Push-Location $repo
try {
    foreach ($legacy in @($false, $true)) {
        if ($legacy) {
            function global:ConvertFrom-Json {
                param([Parameter(ValueFromPipeline = $true)][string]$InputObject)
                process {
                    $decoded = Microsoft.PowerShell.Utility\ConvertFrom-Json -InputObject $InputObject
                    Write-Output -NoEnumerate $decoded
                }
            }
            $old = @('["one","two"]' | ConvertFrom-Json)
            Assert-Json ($old.Count -eq 1 -and $old[0] -is [array]) 'Legacy simulation did not reproduce the nested-array failure.'
        }
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repo 'backend/player_identity') -Filter 'publish*.ps1') {
            $tokens = $null; $errors = $null
            $ast = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
            Assert-Json ($errors.Count -eq 0) ('Parse failure: ' + $file.Name)
            $assignment = $ast.Find({param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and $node.Left.VariablePath.UserPath -eq 'paths'}, $true)
            if ($null -eq $assignment -or $assignment.Extent.Text -notmatch 'ConvertFrom-Json') { continue }
            & {
                param($directory, $statement, $name)
                $PSScriptRoot = $directory
                $literalRoot = "'" + $directory.Replace("'", "''") + "'"
                Invoke-Expression ($statement.Replace('$PSScriptRoot', $literalRoot))
                Assert-Json ($paths.Count -gt 1) ('Missing path list: ' + $name)
                foreach ($entry in $paths) {
                    if ($entry -isnot [string] -or [string]::IsNullOrWhiteSpace($entry)) { throw ('Nested/invalid path: ' + $name) }
                }
            } $file.DirectoryName $assignment.Extent.Text $file.Name
            if (-not $?) { throw ('Initializer execution failed: ' + $file.Name) }
        }
        if ($legacy) { Remove-Item Function:\ConvertFrom-Json }
    }
    Write-Host ('PUBLISH_JSON_COMPATIBILITY=PASS; CHECKS=' + $checks)
} finally {
    if (Test-Path Function:\ConvertFrom-Json) { Remove-Item Function:\ConvertFrom-Json }
    Pop-Location
}

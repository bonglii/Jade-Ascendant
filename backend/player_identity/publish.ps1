param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'
Push-Location $RepositoryRoot
try {
    $branch = (& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or $branch -ne 'checkpoint/iap-fasttrack-20261010') { throw 'Use the authorized checkpoint branch; main/production are protected.' }
    $origin = (& git remote get-url origin).Trim()
    if ($LASTEXITCODE -ne 0 -or $origin -notmatch 'github\.com[:/]bonglii/Jade-Ascendant(?:\.git)?$') { throw 'Unexpected repository remote.' }
    $paths = @(Get-Content -Raw -LiteralPath 'backend/player_identity/publish_paths.json' | ConvertFrom-Json)
    $staged = @(& git diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect existing staging area.' }
    foreach ($path in $staged) { if ($paths -notcontains $path) { throw ('Unrelated staged file; preserve it before publishing: ' + $path) } }
    & node --test backend/player_identity/identity.test.mjs backend/player_identity/mail.test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Identity and mail server tests failed.' }
    $availablePaths = @()
    foreach ($path in $paths) {
        if ($path -match 'node_modules|\.env|\.keystore|\.jks|firestore-debug|backend/monetization/|backend/cloud_save/') { throw ('Protected or unsafe publish path: ' + $path) }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            if ($path -like 'docs/checkpoints/*' -or $path -in @('tools/Jade-Server-Network-Diagnose.ps1','tools/Jade-Wrangler-Tail-DNS.cjs')) { continue }
            throw ('Expected patch file missing: ' + $path)
        }
        $availablePaths += $path
    }
    & git add -- $availablePaths
    if ($LASTEXITCODE -ne 0) { throw 'Unable to stage reviewed patch files.' }
    & git diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw 'Staged whitespace check failed.' }
    & git diff --cached --stat
    & git diff --cached --quiet
    if ($LASTEXITCODE -eq 1) {
        & git commit -m 'feat(liveops): upgrade mail studio operations and admin access'
        if ($LASTEXITCODE -ne 0) { throw 'Checkpoint commit failed.' }
    } elseif ($LASTEXITCODE -ne 0) { throw 'Unable to inspect staged changes.' }
    & git push origin $branch
    if ($LASTEXITCODE -ne 0) { throw 'GitHub push failed; local commit exists but has not been published. Do not force-push.' }
    $sha = (& git rev-parse HEAD).Trim()
    $remote = @(& git ls-remote origin ('refs/heads/' + $branch))
    if ($LASTEXITCODE -ne 0 -or $remote.Count -ne 1 -or ($remote[0] -split '\s+')[0] -ne $sha) { throw 'Remote checkpoint verification failed.' }
    Write-Host ('GITHUB_COMMIT_URL=https://github.com/bonglii/Jade-Ascendant/commit/' + $sha)
    Write-Host ('GITHUB_BRANCH_URL=https://github.com/bonglii/Jade-Ascendant/tree/' + $branch)
} finally { Pop-Location }

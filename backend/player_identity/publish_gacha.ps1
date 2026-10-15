param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'
Push-Location $RepositoryRoot
try {
    $branch = (& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or $branch -ne 'checkpoint/iap-fasttrack-20261010') { throw 'Use the authorized checkpoint branch; main/production are protected.' }
    $origin = (& git remote get-url origin).Trim()
    if ($LASTEXITCODE -ne 0 -or $origin -notmatch 'github\.com[:/]bonglii/Jade-Ascendant(?:\.git)?$') { throw 'Unexpected repository remote.' }
    $paths = Get-Content -Raw -LiteralPath 'backend/player_identity/publish_paths.json' | ConvertFrom-Json
    $gachaPaths = @(
        'assets/ui/pavilion/sanctum_premium/pavilion_unified.png',
        'assets/ui/pavilion/sanctum_premium/pavilion_unified.png.import',
        'tests/pavilion_secrecy_render_smoke.gd',
        'docs/checkpoints/PAVILION_UNIFIED_REVEAL_2026-10-13.md',
        'assets/ui/pavilion/sanctum_premium/celestial_dragon.png',
        'assets/ui/pavilion/sanctum_premium/celestial_seal.png',
        'assets/ui/pavilion/sanctum_premium/celestial_seal.png.import',
        'assets/ui/pavilion/sanctum_premium/asset_sources.json',
        'assets/ui/pavilion/sanctum_premium/celestial_dragon.png.import',
        'assets/ui/pavilion/sanctum_premium/celestial_gate.png.import',
        'assets/ui/pavilion/sanctum_premium/celestial_gate.png',
        'scripts/ui/idle_cultivation_presenter_premium.gd',
        'scripts/managers/daily_quest_manager.gd',
        'scripts/managers/live_ops_manager.gd',
        'scripts/managers/pavilion_manager.gd',
        'scripts/managers/save_manager.gd',
        'scripts/managers/server_mail_manager.gd',
        'scripts/monetization/google_play_billing_provider.gd',
        'tests/idle_modal_lifetime_smoke.gd',
        'docs/checkpoints/GACHA_PREMIUM_POLISH_2026-10-13.md',
        'scripts/ui/pavilion_sanctum_screen.gd',
        'scripts/ui/pavilion_sanctum_screen.gd.uid',
        'scripts/ui/pavilion_sanctum_stage.gd',
        'scripts/ui/pavilion_sanctum_stage.gd.uid',
        'scenes/ui/pavilion_screen.tscn',
        'scripts/managers/localization_manager.gd',
        'tests/pavilion_sanctum_smoke.gd',
        'docs/checkpoints/GACHA_SANCTUM_2026-10-13.md',
        'docs/previews/gacha-ritual-v3.html',
        'backend/player_identity/publish_gacha.ps1',
        'backend/player_identity/publish_gacha.cmd'
    )
    foreach ($path in $gachaPaths) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw ('Required gacha patch file missing: ' + $path) } }
    $paths = @($paths + $gachaPaths | Select-Object -Unique)
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
        & git commit -m 'feat(ui): unify Pavilion and conceal summon identity until reveal'
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

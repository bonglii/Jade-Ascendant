param([string]$Project=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path)
$ErrorActionPreference='Stop'
try {
    $receiptPath=Join-Path $Project '.local/odyssey_export/last.json'
    if (-not (Test-Path -LiteralPath $receiptPath)) { throw 'No Odyssey export receipt. Export a RELEASE AAB from the editor opened by export_production.cmd.' }
    $receipt=[IO.File]::ReadAllText($receiptPath) | ConvertFrom-Json
    $aab=[IO.Path]::GetFullPath([string]$receipt.path)
    if ([IO.Path]::GetExtension($aab) -ne '.aab' -or -not (Test-Path -LiteralPath $aab)) { throw 'The last export was not an existing AAB.' }
    $started=[DateTimeOffset]::FromUnixTimeMilliseconds([long]$receipt.started_ms).UtcDateTime
    if ((Get-Item -LiteralPath $aab).LastWriteTimeUtc -lt $started.AddSeconds(-2)) { throw 'AAB predates this export attempt. Do not upload the previous artifact.' }
    if ([string]$receipt.source_revision -notmatch '^[a-f0-9]{40}$') { throw 'Export source revision is missing. Use the production export launcher.' }
     $currentHead=(& git -C $Project rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $currentHead -ne [string]$receipt.source_revision) { throw 'Export receipt is from an older commit. Export the current source.' }
    $proof=[IO.File]::ReadAllText((Join-Path $Project 'docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json')) | ConvertFrom-Json
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip=[IO.Compression.ZipFile]::OpenRead($aab)
    try {
        $manifestEntry=$zip.GetEntry('base/manifest/AndroidManifest.xml')
        if ($null -eq $manifestEntry -or $manifestEntry.Length -gt 4194304) { throw 'Base Android manifest missing or unexpectedly large.' }
        $manifestStream=$manifestEntry.Open(); $manifestMemory=New-Object IO.MemoryStream
        try { $manifestStream.CopyTo($manifestMemory); $manifestText=[Text.Encoding]::UTF8.GetString($manifestMemory.ToArray()) } finally { $manifestMemory.Dispose(); $manifestStream.Dispose() }
        foreach ($marker in @('POST_NOTIFICATIONS','JadeUpdateMessagingService','JadeNotificationPermissionActivity')) { if (-not $manifestText.Contains($marker)) { throw ('AAB manifest lacks update notification component: '+$marker) } }
        $entries=@($zip.Entries | Where-Object { $_.FullName -match '(^|/)release/build_metadata\.json$' })
        if ($entries.Count -ne 1 -or $entries[0].Length -gt 16384) { throw 'Unique release metadata not found in AAB.' }
        $reader=New-Object IO.StreamReader($entries[0].Open())
        try { $meta=$reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
        if ($meta.debug -ne $false -or $meta.iap_target -ne 'production' -or $meta.odyssey_presentation -ne 3 -or $meta.update_notifications -ne 1 -or $meta.odyssey_shop_protocol -ne 4 -or $meta.odyssey_flow_revision -ne 4 -or $meta.odyssey_reliability_revision -ne 1 -or $meta.odyssey_ad_feedback_revision -ne 1 -or $meta.premium_reliability_revision -ne 1 -or $meta.native_sha256 -ne $proof.aar_sha256 -or $meta.source_revision -ne $receipt.source_revision) { throw 'AAB metadata does not match this verified Odyssey release candidate.' }
        $found=$false; $pushService=$false; $pushTopic=$false
        foreach ($entry in @($zip.Entries | Where-Object { $_.FullName -match '(^|/)classes[0-9]*\.dex$' })) {
            if ($entry.Length -gt 134217728) { throw 'Unexpectedly large DEX entry.' }
            $stream=$entry.Open(); $memory=New-Object IO.MemoryStream
            try { $stream.CopyTo($memory); $text=[Text.Encoding]::UTF8.GetString($memory.ToArray()); if ($text.Contains('JadeUpdateMessagingService')) { $pushService=$true }; if ($text.Contains('jade_release_updates_v1')) { $pushTopic=$true }; if ($text.Contains('/v4/odyssey') -and $text.Contains('requestOdysseyV1')) { $found=$true } } finally { $memory.Dispose(); $stream.Dispose() }
        }
        if (-not $pushService -or -not $pushTopic) { throw 'AAB lacks the compiled update notification service/topic.' }
        if (-not $found) { throw 'AAB DEX lacks the expected Odyssey native method/economy route. Do not upload this artifact.' }
    } finally { $zip.Dispose() }
    $hash=(Get-FileHash -LiteralPath $aab -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Host ('ODYSSEY_FINAL_AAB=PASS; RELEASE_METADATA=VERIFIED; NATIVE_FLOW_PROTOCOL_V4=VERIFIED; SHA256='+$hash)
    Write-Host ('SOURCE='+$meta.source_revision)
    Write-Host ('AAB='+$aab)
    Write-Host 'Upload this verified AAB to internal test using a new version code. Event/player records were not reset.'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }

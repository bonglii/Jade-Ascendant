$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $repo
try {
 $query=@'
SELECT substr(i.owner,1,12) AS account_ref,datetime(i.created_at,'unixepoch') AS intent_created_utc,CASE WHEN i.consumed_at>0 THEN 'credited' WHEN i.expires_at<unixepoch() THEN 'expired_unconfirmed' ELSE 'awaiting_google_ssv' END AS receipt_stage,(SELECT COUNT(*) FROM odyssey_ad_receipts r WHERE r.intent_id=i.id) AS verified_receipts,json_extract(p.state,'$.daily_ads') AS confirmed_daily_rewards,json_extract(p.state,'$.tickets') AS server_dice FROM odyssey_ad_intents i LEFT JOIN odyssey_players p ON p.event_id=i.event_id AND p.owner=i.owner ORDER BY i.created_at DESC,i.id DESC LIMIT 8
'@
 Write-Host 'ODYSSEY_AD_DIAGNOSIS=READ_ONLY; RAW_NONCES_UIDS_TOKENS=OMITTED; PURCHASE=NONE'
 & npx.cmd --yes wrangler@4.151.0 d1 execute jade-iap-ledger --remote --config backend/monetization/cloudflare/wrangler.production-live.toml --command $query --json
 if ($LASTEXITCODE -ne 0) { throw 'Ad receipt query failed. No data was changed.' }
 Write-Host 'NOTE: A pending intent is not proof that a video completed. Credit requires the signed Google callback; daily reward cap is 2.'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }

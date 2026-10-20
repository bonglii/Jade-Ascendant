# Premium combat and reliable rewards — 2026-10-20

Base: d4ba9617348693930c613c24298765e5240cde13, checkpoint/iap-fasttrack-20261010.
User scope: all twelve 2026-10-20 fixes plus previously agreed direct Play pricing/checkout in Odyssey. Production purchases already work and remain live.

## Changed

1. Victory/Defeat now use two new portrait painted xianxia sanctuary backgrounds. Existing damage/skill reports, rewards, retry, revive and return remain owned by their original managers.
2. Boss warning geometry is prepared before visibility; removed the second presenter replaying the same arrival fade. Labels have bounded wrapping. Boss HP panel shrinks with its content after layout. No fullscreen black scrim is inserted by these notices.
3. Combat HUD has engraved gradient frame/fill assets, readable separated status rows, a compact boss frame and a centered temporary encounter ribbon. Health/phase/time/attack rules do not change.
4. Odyssey route, mission, shop and milestone sheets use bounded scrolling and compact illustrated cards. Text padding respects the existing floral atlas. Route choices have immediate readable rewards. Arena HUD shares combat styling.
5. Mail Claim All groups up to eight independent claims and eight acknowledgements into two HTTPS requests. Token reuse is transient (45s), owner-fenced, cleared on account change/401. Local reward receipts remain individually journaled; retry/restart does not double grant. One inbox refresh per frame replaces repeated rebuilds during a burst. Delete All removes completed/expired letters; unclaimed rewards and unacknowledged leases are retained. Campaign/audit/claim records stay intact.
6. Repeating seven active login days add 100 earned Jade and one Seal total. Existing stones are retained. Old claim IDs are preserved; claimed days do not replay.
7. Trials displays the existing complete-all bonus (20 Jade, or 180 Jade +4 Seals on seventh completed daily set) before claim and includes its actual committed amounts in the unified result.
8. Twenty-one permanent achievement milestones add 685 Jade and seven Seals over the full catalog. Claims atomically save currencies with achievement markers. No automatic retroactive grants to already claimed milestones.
9. Bursts merge into the queued or currently visible summary, rather than a chain of claim modals. Exact applied amounts are accumulated; no grant is performed by the presenter. Read-only saves reject early in daily/achievement authorities.
10. Repeated Spirit Stone mail comes from earned Odyssey tile/route/guardian/mission rewards. The receiver previously gave every such letter the same generic title/body. New deliveries explain the event source and action. The fixed welcome letter is one-time, not a daily allowance. Rewards are not deleted to hide the symptom.
11. Event shop displays localized positive Google ProductDetails prices and delegates to existing purchase_iap directly. A held/loading wallet still shows known prices but cannot buy; absent prices never become guessed rupiah values. A consumed seasonal dice bonus changes the displayed pack to Jade-only. Compass remains the 72-journey milestone.
12. Signed AdMob callback accepts the documented numeric unit ID when it is the exact suffix of the configured SDK unit. Full publisher IDs still must match exactly. Decode signature padding only; never rewrite signed query bytes. Amount, label, nonce, key, timestamp, owner, daily cap and atomic one-receipt checks remain mandatory. Logs distinguish mismatched binding fields without raw tokens/nonces. Actual credited receipt triggers the existing Reward Granted +1 die notice after ad dismissal.

## Economy

One pull costs 100 Jade; ten cost 900; one Seal is one pull. Existing daily cadence is 300 Jade +4 Seals per seven completed daily sets. Added login is 100 Jade +1 Seal per seven active dates: together 400 Jade +5 Seals, about 9.44 single-pull equivalents/week before existing optional ads/events. Existing rewarded Pavilion allowance can add at most seven Seals/cycle. Achievement premium is 685 Jade +7 Seals once across progression (about 13.85 single pulls). Existing starter ten Seals and chapter milestones are unchanged. This is a bounded catalog audit, not a claim that long-term retention/LTV has been measured.

## Validation / delivery

Evidence and actual source/render logs accompany the package. Tests use temporary user profiles and explicit network/native doubles where noted. Live Google-signed playback on the new backend is still a device confirmation; an SDK completed callback alone never proves credit. No live transaction or historical ad was fabricated.

The installer validates every target before writing, backs up changed files, preserves unrelated work and appends lessons safely. Publisher stages only package/verified-native files, preserves unrelated index entries and locks, fetches FETCH_HEAD, never force pushes, and prints a real GitHub commit URL only after successful push. Deployment uses existing production targets and retains vars; no migration, event schedule reset or broadcast. IAP and profile deployments have separate resumable stages. New AAB metadata premium_reliability_revision=1 plus current commit check rejects the previous bundle. Existing verified native candidate is reused because its inputs did not change.

Not performed in this environment: Windows install, GitHub push, live Workers deploy, release AAB export, Play upload, actual fresh Google ad callback. The same launcher performs the authorized workstation stages and records completion for retry.

# Mail gifts + Studio upgrade — 2026-10-12

Scope agreed: polish the admin website and add mail Celestial Jade, summon items and equipment. Gacha/event art, new weapons, balance/HP/damage/economy/VFX and ads remain next, after dashboard acceptance. No EquipmentScreen redesign or combat catalog modification in this patch.

Inspected existing equipment/economy/visual catalogs, inventory duplicate rules, local pavilion currency state, shared claim feedback, actual Jade/equipment bitmap assets and current Studio. Exported 40 equipment identities/icons from the real Godot catalog into the reviewed mail_reward_catalog.json. Existing source images remain unchanged and generate 44 static web icons at deployment.

Backend: bounded allowlisted gift schema; exact receipt snapshot; UID/owner isolation and claim/ACK idempotency retained; old-client capability gate filters new gifts from their inbox and denies unsupported claims before reservation. Expanded gifts use existing JSON columns. Same Worker, PROFILE_DB, administrator username/password and cron. ASSETS binding serves only authenticated admin icon paths; generated assets are ignored by Git and Godot.

Client: validated gift fields, free/local Celestial Jade and Pavilion Seals plus inventory/receipt in the existing atomic save batch. Existing duplicate conversion and ascension state preserved; no auto-equip or summon. RewardManager's bonus allowance is scoped to the server-mail source and requires the matching atomic pavilion target. Mixed and pure-currency gifts show actual reward feedback. Mailbox reward grids and scroll placement support up to nine attachment types while actions stay within parchment. Server-paid IAP wallet and parked monetization modules remain untouched.

Studio: tab navigation, stronger green/gold hierarchy, currency icons, 40-item equipment picker, rarity/slot/search, five-item selected tray, image-backed attachment preview, desktop sticky preview, phone layout, incremental equipment image loading. Catalog filters do not invalidate an unchanged confirmed reward; selections do.

Validation: 40 Node tests; Godot gift/catalog 60 checks + restart six; legacy mailbox 531 and expanded maximum-attachment 657 checks across nine sizes, English/Indonesian; existing mailbox/Skill Book 153 checks. Browser verified full mail/draft/jobs/archive/account paths and gift picker with authenticated source icons, no CSP/JS errors or mobile overflow. Native Cloudflare workerd + real local D1/static assets verified expanded sends and actual cron dispatch. Fixtures isolated, no real players/credentials or production mail touched. Windows scripts reviewed and retain parser preflight; live deployment/Android acceptance is user-side.

Delivery: apply patch, deploy_mail.cmd, export Android once, open_mail_dashboard.cmd (required on current hotspot DNS), send a small gift to own UID and verify counters/inventory/one claim after restart. Publish with publish.cmd for a verified GitHub commit URL.

Limits: free/local gift wallet is not server-global economy authority; this does not repair parked IAP. Up to 10,000 Jade, 100 seals, five distinct equipment (one each) per campaign. Gift item IDs are catalog-owned; future catalog additions require review/export update. Old APKs deliberately hide unsupported gift letters until upgraded.

# Mailbox reader consistency fix — 2026-10-12

Trigger: server mail arrives successfully but its variable-length text and viewport geometry can clip the letter UI. Existing selected title had a three-line cap, sender a fixed-height displaced slot, and short-screen minimum footer sizes could reduce body height to zero or push actions outside the parchment. Every authority refresh also reset the reader to the top.

Asset review: inspected real spirit_messages_parchment.png, background_frame_fitted.png, jade frame, production scene and native Godot captures. Reused the approved assets without image edits.

Changed: title, sender and body form one full scroll document; selected title has no line cap and sender wraps naturally. Claim/delete actions stay within the parchment. On short letter panes attachments move into the scroll document to preserve reading space; taller panes retain pinned attachments. Popup margins scale with the artwork/viewport and short screens use more vertical space. A scroll/end-of-letter hint explains navigation. The shorter localized SYNC MAIL label fits the inbox; duplicate server status is removed. Inbox preview truncation remains deliberate; selecting a letter reveals its complete title and body.

Reader scroll persists across status/read refresh and returning to a selected letter. Text only changes when its document signature changes. Restore waits for container layout, checks the current selection and stops if the screen left the tree, preventing callbacks from using a destroyed viewport.

Validation: 531 layout checks over nine logical viewports (320x568, 360x640, 390x844, 540x960, 648x960, 648x1152, 720x1280, 800x1200, 896x504), English and Indonesian. Server-valid fixtures exercise long titles/senders, exactly 4000 body characters, literal BBCode, 100000 Stone/500 Shard quantities, notices, full-document end reachability, card containment, action bounds, selection and refresh scroll retention. Existing mailbox/Skill Book transaction/delete regression: 153 checks passed. Native OpenGL software-rendered captures inspected. No actual player mail sent or real account/wallet modified during QA.

Delivery: client UI/localization + tests + publishing allowlist. Apply on top of the latest server/dashboard patches and re-export Android once. No Worker/database/dashboard deployment and no reward/identity/IAP authority changes. Live Android acceptance is still required on the user's device.

Lessons: selected remote text must not inherit local-catalog length assumptions; fixed-height footer/header sums are unsafe on short panes; restore scroll only after the new document is laid out, and guard deferred callbacks when the popup closes.

# Mailbox printable-region redesign — 2026-10-13

## Result
- Phones use one full-width letter reader; Inbox button opens the full list and selecting a mail returns to reading. Large logical viewports retain two columns only with enough width (760-pixel body threshold).
- Sync button and bounded, high-contrast server status now live in a persistent toolbar, available in both reader and inbox. Sync eligibility follows the existing server manager.
- Inspected and reused approved background, jade/gold outer frame and parchment. The previous 16/26-pixel letter margins treated decorative frame pixels as printable content. The new printable region uses proportional insets: 12% sides, 18.5% top, 8.5% bottom, plus clipping and responsive attachment columns. Inbox cards also reserve proportional side room so the outer ribbons do not cover their first/last characters.
- Header is in container flow below the outer crown; close button is above the frame in its top-right orb. Ink text has no inherited glow/shadow on pale paper.
- Full title, full sender and complete body remain one vertical document. Attachments scroll after the body; claim/delete remain pinned in a responsive action grid. Short viewports retain reading space rather than letting gifts consume it.
- Server text remains literal (no BBCode parsing), including long unbroken strings. Exact amounts remain unwrapped. Recovery and read-only action text wraps within bounded buttons; failed claim uses a compact Retry label.
- Text/reward containers pass touch input to ScrollContainer. Reader drag/release guards prevent accidental claim/delete. Authority, network endpoints, reward transactions and save schemas are unchanged.

## Verification
Godot 4.7.2 final runs:
- Existing expanded mailbox layout suite: 657 checks, zero failures.
- Printable-region / touch suite: 629 checks, zero failures. EN/ID, portrait, landscape and 1280-wide tablet; all text retained, exact geometry, document end, reader offset preservation, sync placement, literal URL and actual local-reward swipe guards.
- Server claim/receipt suite: 26 checks, zero failures.
- Mixed gifts/identical duplicate suite: 62 checks, zero failures.
- Separate gift restart: six checks, zero failures.
Total: 1380 checks, zero failures. Native previews at 648x1152 and 320x568 inspected; no script errors in final native run. Android export/device QA remains necessary.

Two old regression assertions were stale: permanent-domain count before approved Mastery, and equipment restart expected one copy before the identical-duplicate change. Assertions now verify all nine exact permanent IDs and saved duplicate counts; no reward behavior was changed to satisfy them.

## Windows
Apply after the Menu Performance/Touch patch:

```bat
git apply --check "D:\Godot\tools\Jade-Ascendant-Mailbox-Paper-Reader.patch" && git apply "D:\Godot\tools\Jade-Ascendant-Mailbox-Paper-Reader.patch"
backend\player_identity\publish_mailbox_reader.cmd
```

Open Godot/import and re-export Android. No Worker/database deployment. The protected publisher includes authorized pending prerequisites, rejects unrelated staged/outbound changes, never force-pushes, and prints a real commit link after verifying the remote SHA. GitHub connector write access remains unavailable in this session; no remote publication is claimed.
This checkpoint completes the mailbox portion of prioritized backlog package 2, pending device confirmation. Boss notice presentation is the next open portion.

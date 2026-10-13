# Mail direct tap — 2026-10-13

A tap on any letter card opens the reader directly, including a card already selected. READ remains an optional toolbar shortcut. Compact selection previously used a stale 450px width threshold, while the approved reader/inbox layout switched at 760px. Thus phones using larger logical widths selected a letter but remained in the inbox. Both now use WIDE_READER_THRESHOLD.

Existing scroll offset, active scroll and post-scroll guard still cancel accidental opens. Selection updates existing cards without rebuilding the inbox. Letter scroll restoration, rewards, claims, deletes, backend and assets are unchanged.

QA covers 5 viewport sizes and 2 locales, full paper/long body/attachment layout, actual card signals, scroll cancellation and reopening an already selected card. See test output for check counts. Apply incremental patch after the paper reader patch, reimport and re-export Android; no server deployment. Publish through backend/player_identity/publish_mail_directtap.cmd on the authorized checkpoint branch.

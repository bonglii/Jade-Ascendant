# Rewarded warning correction — 2026-10-20

Screenshot shows SHADOWED_VARIABLE_BASE_CLASS: local ready hides Node.ready signal. Fixed local identifiers in AdMob status, Odyssey ad control and mission row status. Dictionary/API key ready stays unchanged; no gameplay, reward, currency, quota, unit ID, callback protocol or native input changes.

Isolated Godot QA treats base-class shadow warnings as errors. An intentionally bad var-ready control must fail; corrected full-source import and relevant interaction/provider tests must pass. This policy is confined to QA profiles; user project settings are not weakened or overwritten.

Supersedes Jade-Rewarded-Units.zip with a new revision, accepting its prior source checksums. Updated dependency list avoids rejecting the newly corrected Odyssey client on retry. Previously completed worker deployment stages may be reused only with matching deployed backend source digests and matching recorded workflow package identity. All 63 earlier payload changes included, plus the corrected client and this note.

Close the owned Godot editor before rerunning the updated apply_and_publish.cmd. The same checkpoint publisher prints a real GitHub commit URL after success. No GitHub commit, Windows installation, remote deployment or AAB export was performed in the agent environment.

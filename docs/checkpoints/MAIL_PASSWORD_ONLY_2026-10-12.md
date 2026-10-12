# Admin password-only access — 2026-10-12

User forgot their admin password and explicitly requested removing 2FA. Updated login, account setup and password changes to username/password only. Legacy TOTP data no longer participates in authentication; no deployment-key fallback is permitted for an existing account.

Added reset_mail_admin.cmd/.ps1/.mjs. The original deployment Windows account decrypts its existing DPAPI key, enters the desired username/password locally, hashes it with the existing server password pepper and a new salt, and updates only administrator credentials through the authenticated Cloudflare D1 CLI. Sessions are revoked by revision rotation; legacy recovery records are cleared. SQL contains no plaintext password or master key. UTF-8 stdin and hidden confirmation prompts preserve non-ASCII passwords. Temporary SQL is removed in finally. No browser-accessible forgotten-password bypass endpoint.

Acceptance: 38 backend tests, including legacy account login without 2FA, password-change session revocation, reset credential replacement, Unicode password hashing, no plaintext in SQL, unchanged mail/identity records and invalid username rejection. Browser setup/login and existing mail/draft/archive/schedule flows passed. Native Cloudflare workerd/D1 password-only setup/login/change and scheduler checked. Windows prompt, DPAPI and live D1 reset require execution on the user's machine; no production credentials changed here. No Android re-export required.

Apply on top of Mail Studio Upgrade, deploy first, reset second, then reopen dashboard. User chooses their own password (12–128 characters); never request it in chat. Preserve the DPAPI master key and local Wrangler configuration.

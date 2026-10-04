# Jade Ascendant Monetization Backend — M1A

State: **PREDEPLOY CONTRACT ONLY**.

This directory is intentionally separate from `backend/cloud_save/`. M1A adds no
Firebase project target, credentials, deployment command, live Google Play API
client, Firestore ledger, or client integration.

## Secure purchase contract

The planned production flow is server-authoritative for verification and
consumption:

1. Android launches Play Billing with `obfuscatedAccountId = SHA256(firebase_uid)`.
2. The authenticated + App Check protected backend receives **only** the opaque
   purchase token.
3. The backend queries Google Play `purchases.productsv2.getproductpurchasev2`.
4. It requires `PURCHASED`, one supported product line item, quantity 1, not yet
   consumed, fully refundable quantity 1, and the expected obfuscated account
   binding.
5. A persistent transactional server ledger records one deterministic grant ID
   per globally unique purchase token. The raw purchase token is not stored in
   the ledger record.
6. Before any grant is returned to the client, the backend consumes the verified
   Google Play consumable. The durable ledger makes consume-before-client-save
   recoverable: a crash after consume can be repaired from Google Play state.
7. Only after Google Play consumption is confirmed does the backend expose the
   stable `grant_ready` authorization containing the server-derived product and
   Celestial Jade amount.
8. The client atomically applies that authorization to the local Pavilion save
   using the grant ID for local replay protection. If the local save fails, the
   same purchase token returns the same durable grant for retry; the client has
   no consume/finalization authority.

This ordering avoids a client-controlled window where local premium currency is
saved while the Play purchase remains unconsumed/unacknowledged.

M1A implements only the pure policy and executable tests with injected fake Play
and ledger adapters. Production runtime wiring is a later subphase and remains
blocked by `production_approval_boundary.json`.

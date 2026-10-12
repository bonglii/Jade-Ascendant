CREATE TABLE IF NOT EXISTS player_identities (
  owner_binding TEXT PRIMARY KEY NOT NULL CHECK(length(owner_binding) = 64),
  public_uid TEXT UNIQUE NOT NULL CHECK(length(public_uid) = 12),
  created_at INTEGER NOT NULL
);

-- Append-only banner revisions. Never touches player currency, pity or receipts.
CREATE TABLE IF NOT EXISTS pavilion_control (id INTEGER PRIMARY KEY CHECK(id=1), revision INTEGER NOT NULL DEFAULT 0, operation_id TEXT NOT NULL DEFAULT '');
INSERT OR IGNORE INTO pavilion_control(id) VALUES(1);
CREATE TABLE IF NOT EXISTS pavilion_revisions (revision INTEGER PRIMARY KEY, request_id TEXT NOT NULL UNIQUE, fingerprint TEXT NOT NULL, document_json TEXT NOT NULL, created_at INTEGER NOT NULL);

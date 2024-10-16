\connect elysium;

CREATE TABLE IF NOT EXISTS "elysium" (
    PrimaryKey TEXT PRIMARY KEY,
    KeyString TEXT NOT NULL,
    Value JSONB NOT NULL
);

CREATE TABLE IF NOT EXISTS "foreignKeys" (
    id SERIAL PRIMARY KEY,
    ForeignKey TEXT,
    KeyString TEXT NOT NULL,
    PrimaryKey TEXT REFERENCES "elysium"(PrimaryKey) ON DELETE CASCADE,
    CONSTRAINT unique_ForeignKey_PrimaryKey UNIQUE (ForeignKey, PrimaryKey)
);

CREATE INDEX IF NOT EXISTS idx_foreign_key
ON "foreignKeys"(ForeignKey);

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO elysium;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO elysium;

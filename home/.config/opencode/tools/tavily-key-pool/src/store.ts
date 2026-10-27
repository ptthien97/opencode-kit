import Database from "better-sqlite3";
import type { PoolConfig } from "./config.js";
import { redactKey } from "./redact.js";

export type KeyRecord = {
  account_id: string;
  email: string | null;
  api_key: string | null;
  last_fetched_at: string | null;
  status: "active" | "invalid" | "pending" | "cooldown";
  failure_count: number;
  last_used_at: string | null;
  cooldown_until: string | null;
};

function compareAccountIds(a: KeyRecord, b: KeyRecord): number {
  const aMatch = /^acc(\d+)$/.exec(a.account_id);
  const bMatch = /^acc(\d+)$/.exec(b.account_id);
  if (aMatch && bMatch) return Number(aMatch[1]) - Number(bMatch[1]);
  if (aMatch) return -1;
  if (bMatch) return 1;
  return a.account_id.localeCompare(b.account_id);
}

export class KeyStore {
  private db: Database.Database;

  constructor(cfg: PoolConfig) {
    this.db = new Database(cfg.pool.db_path);
    this.db.pragma("journal_mode = WAL");
    this.db.pragma("busy_timeout = 5000");
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS keys (
        account_id TEXT PRIMARY KEY,
        email TEXT,
        api_key TEXT,
        last_fetched_at TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        failure_count INTEGER NOT NULL DEFAULT 0,
        last_used_at TEXT,
        cooldown_until TEXT
      );
      CREATE TABLE IF NOT EXISTS rotation_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        last_index INTEGER NOT NULL DEFAULT -1
      );
      INSERT OR IGNORE INTO rotation_state (id, last_index) VALUES (1, -1);
      CREATE TABLE IF NOT EXISTS session_affinity (
        session_id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        last_seen_at TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_session_affinity_account
        ON session_affinity (account_id);
      CREATE TABLE IF NOT EXISTS schema_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    `);
    this.migrateLegacyConfiguredPlaceholders(cfg);
  }

  private migrateLegacyConfiguredPlaceholders(cfg: PoolConfig) {
    const migrationKey = "dynamic_accounts_v1";
    const completed = this.db
      .prepare(`SELECT value FROM schema_meta WHERE key = ?`)
      .get(migrationKey) as { value: string } | undefined;
    if (completed) return;

    const legacyIds = (cfg.accounts ?? []).map((account) => account.id);
    const transaction = this.db.transaction(() => {
      if (legacyIds.length > 0) {
        const placeholders = legacyIds.filter((accountId) => {
          const row = this.get(accountId);
          return Boolean(
            row &&
            row.api_key === null &&
            row.status === "pending" &&
            row.email === null &&
            row.last_fetched_at === null &&
            row.failure_count === 0 &&
            row.last_used_at === null &&
            row.cooldown_until === null,
          );
        });
        for (const accountId of placeholders) {
          this.deleteAffinitiesForAccount(accountId);
          this.db.prepare(`DELETE FROM keys WHERE account_id = ?`).run(accountId);
        }
        if (placeholders.length > 0) {
          console.log(`[store] removed ${placeholders.length} legacy empty account placeholder(s)`);
        }
      }
      this.db
        .prepare(`INSERT INTO schema_meta (key, value) VALUES (?, ?)`)
        .run(migrationKey, new Date().toISOString());
    });
    transaction();
  }

  upsertKey(accountId: string, apiKey: string, email?: string | null) {
    const now = new Date().toISOString();
    this.db
      .prepare(
        `INSERT INTO keys (
           account_id, email, api_key, last_fetched_at, status, failure_count, last_used_at, cooldown_until
         ) VALUES (?, ?, ?, ?, 'active', 0, NULL, NULL)
         ON CONFLICT(account_id) DO UPDATE SET
           api_key = excluded.api_key,
           email = COALESCE(excluded.email, keys.email),
           last_fetched_at = excluded.last_fetched_at,
           status = 'active',
           failure_count = 0,
           cooldown_until = NULL`,
      )
      .run(accountId, email ?? null, apiKey, now);
    console.log(`[store] ${accountId} key saved ${redactKey(apiKey)}`);
  }

  importKey(accountId: string, apiKey: string, email?: string) {
    this.upsertKey(accountId, apiKey, email ?? null);
  }

  deleteAccount(accountId: string): boolean {
    const row = this.get(accountId);
    if (!row) return false;
    const transaction = this.db.transaction(() => {
      this.deleteAffinitiesForAccount(accountId);
      this.db.prepare(`DELETE FROM keys WHERE account_id = ?`).run(accountId);
    });
    transaction();
    console.log(`[store] ${accountId} local account removed`);
    return true;
  }

  nextAccountId(): string {
    let max = 0;
    for (const row of this.list()) {
      const match = /^acc(\d+)$/.exec(row.account_id);
      if (match) max = Math.max(max, Number(match[1]));
    }
    return `acc${String(max + 1).padStart(2, "0")}`;
  }

  markFailure(accountId: string, cfg: PoolConfig) {
    const row = this.get(accountId);
    if (!row) return;
    const failures = row.failure_count + 1;
    if (failures >= cfg.rotation.max_failures_before_skip) {
      this.markInvalid(accountId, failures);
      return;
    }
    this.markCooldown(accountId, cfg.rotation.cooldown_seconds, failures);
  }

  markAuthFailure(accountId: string) {
    const row = this.get(accountId);
    if (!row) return;
    this.markInvalid(accountId, row.failure_count + 1);
  }

  markRateLimited(accountId: string, cooldownSeconds: number, until?: string | null) {
    const row = this.get(accountId);
    if (!row) return;
    this.markCooldown(accountId, cooldownSeconds, row.failure_count + 1, until);
  }

  markSuccess(accountId: string) {
    this.db
      .prepare(
        `UPDATE keys SET status = 'active', failure_count = 0, cooldown_until = NULL WHERE account_id = ? AND api_key IS NOT NULL`,
      )
      .run(accountId);
  }

  private markInvalid(accountId: string, failures: number) {
    this.db
      .prepare(
        `UPDATE keys SET failure_count = ?, status = 'invalid', cooldown_until = NULL WHERE account_id = ?`,
      )
      .run(failures, accountId);
    this.deleteAffinitiesForAccount(accountId);
    console.log(`[store] ${accountId} failure #${failures} status=invalid`);
  }

  private markCooldown(
    accountId: string,
    cooldownSeconds: number,
    failures: number,
    until?: string | null,
  ) {
    const seconds = Math.max(1, Math.floor(cooldownSeconds));
    const cooldownUntil = until ?? new Date(Date.now() + seconds * 1000).toISOString();
    this.db
      .prepare(
        `UPDATE keys SET failure_count = ?, status = 'cooldown', cooldown_until = ? WHERE account_id = ?`,
      )
      .run(failures, cooldownUntil, accountId);
    this.deleteAffinitiesForAccount(accountId);
    console.log(`[store] ${accountId} failure #${failures} status=cooldown until=${cooldownUntil}`);
  }

  clearCooldowns() {
    const now = new Date().toISOString();
    this.db
      .prepare(
        `UPDATE keys SET status = 'active', cooldown_until = NULL WHERE status = 'cooldown' AND (cooldown_until IS NULL OR cooldown_until <= ?)`,
      )
      .run(now);
  }

  get(accountId: string): KeyRecord | undefined {
    return this.db
      .prepare(`SELECT * FROM keys WHERE account_id = ?`)
      .get(accountId) as KeyRecord | undefined;
  }

  list(): KeyRecord[] {
    const rows = this.db.prepare(`SELECT * FROM keys`).all() as KeyRecord[];
    return rows.sort(compareAccountIds);
  }

  getRotationIndex(): number {
    const r = this.db
      .prepare(`SELECT last_index FROM rotation_state WHERE id = 1`)
      .get() as { last_index: number };
    return r.last_index;
  }

  setRotationIndex(i: number) {
    this.db.prepare(`UPDATE rotation_state SET last_index = ? WHERE id = 1`).run(i);
  }

  markUsed(accountId: string) {
    this.db
      .prepare(`UPDATE keys SET last_used_at = ? WHERE account_id = ?`)
      .run(new Date().toISOString(), accountId);
  }

  getAffinity(sessionId: string, ttlSeconds: number): string | undefined {
    const row = this.db
      .prepare(`SELECT account_id, last_seen_at FROM session_affinity WHERE session_id = ?`)
      .get(sessionId) as { account_id: string; last_seen_at: string } | undefined;
    if (!row) return undefined;
    const lastSeen = Date.parse(row.last_seen_at);
    if (!Number.isFinite(lastSeen) || Date.now() - lastSeen > ttlSeconds * 1000) {
      this.deleteAffinity(sessionId);
      return undefined;
    }
    return row.account_id;
  }

  setAffinity(sessionId: string, accountId: string) {
    this.db
      .prepare(
        `INSERT INTO session_affinity (session_id, account_id, last_seen_at)
         VALUES (?, ?, ?)
         ON CONFLICT(session_id) DO UPDATE SET account_id = excluded.account_id, last_seen_at = excluded.last_seen_at`,
      )
      .run(sessionId, accountId, new Date().toISOString());
  }

  touchAffinity(sessionId: string) {
    this.db
      .prepare(`UPDATE session_affinity SET last_seen_at = ? WHERE session_id = ?`)
      .run(new Date().toISOString(), sessionId);
  }

  deleteAffinity(sessionId: string) {
    this.db.prepare(`DELETE FROM session_affinity WHERE session_id = ?`).run(sessionId);
  }

  deleteAffinitiesForAccount(accountId: string) {
    this.db.prepare(`DELETE FROM session_affinity WHERE account_id = ?`).run(accountId);
  }

  close() {
    this.db.close();
  }
}
import { readFileSync, existsSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join, dirname } from "node:path";
import { parse } from "yaml";

export type AccountConfig = { id: string; label?: string; email_hint?: string };

export type PoolConfig = {
  pool: { db_path: string; profiles_dir: string; debug_screenshots: string };
  tavily: {
    dashboard_url: string;
    selectors: { api_key_input: string; api_key_text: string; copy_button: string };
    key_regex: string;
  };
  rotation: {
    mode: "round_robin" | "weighted";
    cooldown_seconds: number;
    max_failures_before_skip: number;
    weights?: Record<string, number>;
    /** Day of month (1-31) when plan credits reset. When set, quota-exhausted
     *  keys stay in cooldown until the next reset boundary instead of the
     *  fixed proxy.quota_cooldown_seconds timer. */
    quota_reset_day?: number;
  };
  /** Legacy migration seed only. SQLite is the live account registry. */
  accounts?: AccountConfig[];
  fetch: { delay_between_accounts_ms: number; navigation_timeout_ms: number; headed_login: boolean };
  proxy: {
    bind: string;
    port: number;
    upstream_mcp_base: string;
    auth_mode: "bearer" | "query" | "both";
    max_failover_attempts: number;
    max_request_body_bytes: number;
    session_affinity_ttl_seconds: number;
    quota_cooldown_seconds: number;
  };
};

function expandHome(p: string): string {
  return p.startsWith("~/") ? join(homedir(), p.slice(2)) : p;
}

export function configPath(): string {
  if (process.env.TAVILY_POOL_CONFIG) {
    return expandHome(process.env.TAVILY_POOL_CONFIG);
  }
  return join(homedir(), ".tavily-key-pool", "config.yaml");
}

export function loadConfig(): PoolConfig {
  const path = configPath();
  if (!existsSync(path)) {
    throw new Error(`Missing ${path}. Copy config.example.yaml and configure the pool.`);
  }
  const raw = parse(readFileSync(path, "utf8")) as PoolConfig;
  raw.pool.db_path = expandHome(raw.pool.db_path);
  raw.pool.profiles_dir = expandHome(raw.pool.profiles_dir);
  raw.pool.debug_screenshots = expandHome(raw.pool.debug_screenshots);
  raw.proxy = {
    ...raw.proxy,
    auth_mode: raw.proxy.auth_mode ?? "query",
    max_failover_attempts: raw.proxy.max_failover_attempts ?? 3,
    max_request_body_bytes: raw.proxy.max_request_body_bytes ?? 1_048_576,
    session_affinity_ttl_seconds: raw.proxy.session_affinity_ttl_seconds ?? 86_400,
    quota_cooldown_seconds: raw.proxy.quota_cooldown_seconds ?? 3_600,
  };
  for (const d of [dirname(raw.pool.db_path), raw.pool.profiles_dir, raw.pool.debug_screenshots]) {
    mkdirSync(d, { recursive: true });
  }
  return raw;
}
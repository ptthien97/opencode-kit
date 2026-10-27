import type { PoolConfig } from "./config.js";
import { KeyStore } from "./store.js";

export type NextKeyResult =
  | { ok: true; account_id: string; api_key: string }
  | { ok: false; reason: string };

export type KeySelectionOptions = {
  preferredAccountId?: string;
  excludeAccountIds?: ReadonlySet<string>;
};

export function getNextApiKey(
  store: KeyStore,
  cfg: PoolConfig,
  options: KeySelectionOptions = {},
): NextKeyResult {
  store.clearCooldowns();
  const excluded = options.excludeAccountIds ?? new Set<string>();
  const rows = store
    .list()
    .filter(
      (r) =>
        r.status === "active" &&
        r.api_key &&
        r.api_key.length > 10 &&
        !excluded.has(r.account_id),
    );

  if (rows.length === 0) {
    return { ok: false, reason: "no active keys — run fetch-all or import-key" };
  }

  const activeSet = new Set(rows.map((r) => r.account_id));
  const ordered = rows.map((row) => row.account_id);

  if (options.preferredAccountId && activeSet.has(options.preferredAccountId)) {
    const row = store.get(options.preferredAccountId);
    if (row?.api_key) {
      store.markUsed(options.preferredAccountId);
      return {
        ok: true,
        account_id: options.preferredAccountId,
        api_key: row.api_key,
      };
    }
  }

  if (cfg.rotation.mode === "weighted" && cfg.rotation.weights) {
    const expanded: string[] = [];
    for (const id of ordered) {
      const w = cfg.rotation.weights[id] ?? 1;
      for (let i = 0; i < w; i++) expanded.push(id);
    }
    const idx = (store.getRotationIndex() + 1) % expanded.length;
    store.setRotationIndex(idx);
    const accountId = expanded[idx]!;
    const row = store.get(accountId)!;
    store.markUsed(accountId);
    return { ok: true, account_id: accountId, api_key: row.api_key! };
  }

  const last = store.getRotationIndex();
  let idx = (last + 1) % ordered.length;
  for (let n = 0; n < ordered.length; n++) {
    const accountId = ordered[idx]!;
    const row = store.get(accountId)!;
    if (row.api_key) {
      store.setRotationIndex(idx);
      store.markUsed(accountId);
      return { ok: true, account_id: accountId, api_key: row.api_key };
    }
    idx = (idx + 1) % ordered.length;
  }

  return { ok: false, reason: "rotation exhausted" };
}
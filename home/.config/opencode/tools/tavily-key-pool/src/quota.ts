import { redactKey } from "./redact.js";
import type { KeyRecord } from "./store.js";

export type TavilyUsagePayload = {
  key?: UsageBucket;
  account?: AccountUsageBucket;
};

type UsageBucket = {
  usage?: number;
  limit?: number | null;
  search_usage?: number;
  crawl_usage?: number;
  extract_usage?: number;
  map_usage?: number;
  research_usage?: number;
};

type AccountUsageBucket = UsageBucket & {
  current_plan?: string;
  plan_usage?: number;
  plan_limit?: number | null;
  paygo_usage?: number;
  paygo_limit?: number | null;
};

export type QuotaResult =
  | { ok: true; row: KeyRecord; payload: TavilyUsagePayload }
  | { ok: false; row: KeyRecord; status?: number; error: string; retryAfter?: string };

export type QuotaOptions = {
  endpoint?: string;
  timeoutMs?: number;
  concurrency?: number;
  fetchImpl?: typeof fetch;
};

export async function printQuota(
  rows: KeyRecord[],
  options: QuotaOptions = {},
): Promise<QuotaResult[]> {
  const keyedRows = rows.filter((row) => Boolean(row.api_key));
  if (keyedRows.length === 0) {
    console.log("No Tavily accounts with local keys.");
    return [];
  }

  const results = await mapConcurrent(
    keyedRows,
    Math.max(1, options.concurrency ?? 3),
    (row) => fetchQuota(row, options),
  );
  renderQuotaTable(results);
  return results;
}

export async function fetchQuota(
  row: KeyRecord,
  options: QuotaOptions = {},
): Promise<QuotaResult> {
  if (!row.api_key) return { ok: false, row, error: "no local key" };
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), options.timeoutMs ?? 15_000);
  try {
    const response = await (options.fetchImpl ?? fetch)(
      options.endpoint ?? "https://api.tavily.com/usage",
      {
        headers: { Authorization: `Bearer ${row.api_key}` },
        signal: controller.signal,
      },
    );
    if (!response.ok) {
      return {
        ok: false,
        row,
        status: response.status,
        error: statusLabel(response.status),
        retryAfter: response.headers.get("retry-after") ?? undefined,
      };
    }
    const payload = await response.json() as TavilyUsagePayload;
    return { ok: true, row, payload };
  } catch (error) {
    return {
      ok: false,
      row,
      error: error instanceof Error && error.name === "AbortError"
        ? "timeout"
        : "network error",
    };
  } finally {
    clearTimeout(timeout);
  }
}

function renderQuotaTable(results: QuotaResult[]): void {
  console.log("ACCOUNT  KEY               STATE     PLAN          USED   LIMIT  REMAIN   USED%");
  for (const result of results) {
    const account = result.row.account_id.padEnd(8);
    const key = redactKey(result.row.api_key).padEnd(17);
    if (result.ok === false) {
      const detail = result.retryAfter ? `${result.error} retry=${result.retryAfter}` : result.error;
      console.log(`${account} ${key} ${result.row.status.padEnd(9)} ${detail}`);
      continue;
    }
    const usage = result.payload.account;
    const used = numberOr(usage?.plan_usage, usage?.usage);
    const limit = nullableNumberOr(usage?.plan_limit, usage?.limit);
    const remaining = limit === null || used === null ? null : Math.max(0, limit - used);
    const percent = limit && used !== null ? `${Math.round((used / limit) * 100)}%` : "-";
    console.log(
      `${account} ${key} ${result.row.status.padEnd(9)} ${(usage?.current_plan ?? "-").padEnd(13)} ${formatNumber(used, 6)} ${formatNumber(limit, 6)} ${formatNumber(remaining, 7)} ${percent}`,
    );
    console.log(
      `         breakdown search=${usage?.search_usage ?? 0} extract=${usage?.extract_usage ?? 0} crawl=${usage?.crawl_usage ?? 0} map=${usage?.map_usage ?? 0} research=${usage?.research_usage ?? 0} paygo=${usage?.paygo_usage ?? 0}`,
    );
  }
}

function statusLabel(status: number): string {
  if (status === 401 || status === 403) return "unauthorized";
  if (status === 429) return "rate limited";
  return `HTTP ${status}`;
}

function numberOr(...values: Array<number | undefined>): number | null {
  return values.find((value): value is number => typeof value === "number") ?? null;
}

function nullableNumberOr(...values: Array<number | null | undefined>): number | null {
  for (const value of values) {
    if (typeof value === "number") return value;
    if (value === null) return null;
  }
  return null;
}

function formatNumber(value: number | null, width: number): string {
  return (value === null ? "-" : String(value)).padStart(width);
}

async function mapConcurrent<T, R>(
  items: T[],
  concurrency: number,
  worker: (item: T) => Promise<R>,
): Promise<R[]> {
  const results = new Array<R>(items.length);
  let nextIndex = 0;
  const workers = Array.from({ length: Math.min(concurrency, items.length) }, async () => {
    while (true) {
      const index = nextIndex++;
      if (index >= items.length) return;
      results[index] = await worker(items[index]!);
    }
  });
  await Promise.all(workers);
  return results;
}

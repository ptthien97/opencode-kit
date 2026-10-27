import http from "node:http";
import { Readable } from "node:stream";
import { URL } from "node:url";
import type { PoolConfig } from "./config.js";
import { KeyStore } from "./store.js";
import { getNextApiKey } from "./rotate.js";
import { quotaResetUntil } from "./quota-reset.js";
import { maskForLog, redactKey } from "./redact.js";

const CLIENT_SESSION_HEADERS = ["mcp-session-id", "x-session-id", "x-human-id"];
const HOP_BY_HOP_HEADERS = new Set([
  "connection",
  "keep-alive",
  "proxy-authenticate",
  "proxy-authorization",
  "te",
  "trailer",
  "transfer-encoding",
  "upgrade",
]);
const FAILOVER_STATUSES = new Set([401, 403, 429, 432]);

/**
 * Reverse proxy for Tavily's Streamable HTTP MCP endpoint.
 * Requests are pinned to a key by MCP/session headers and fail over only after
 * explicit upstream rejection (401/403/429/432), never after ambiguous network or 5xx errors.
 */
export function startMcpProxy(cfg: PoolConfig, store: KeyStore): http.Server {
  const server = http.createServer(async (req, res) => {
    if (!req.url?.startsWith("/tavily/")) {
      writeJson(res, 404, { error: "use /tavily/mcp/" });
      return;
    }

    const targetUrl = buildTargetUrl(req.url, cfg.proxy.upstream_mcp_base);
    const incomingSessionId = getClientSessionId(req.headers);
    const bodyResult = await readReplayableBody(req, cfg.proxy.max_request_body_bytes);
    if (bodyResult.ok === false) {
      writeJson(res, bodyResult.status, { error: bodyResult.error });
      return;
    }

    const attemptedAccounts = new Set<string>();
    let preferredAccountId = incomingSessionId
      ? store.getAffinity(incomingSessionId, cfg.proxy.session_affinity_ttl_seconds)
      : undefined;
    let lastRejectedStatus: number | undefined;
    let lastRejectedBody: Buffer | undefined;
    let lastRejectedHeaders: Headers | undefined;
    const maxAttempts = Math.max(1, cfg.proxy.max_failover_attempts);

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      const next = getNextApiKey(store, cfg, {
        preferredAccountId,
        excludeAccountIds: attemptedAccounts,
      });
      if (next.ok === false) {
        if (lastRejectedStatus && lastRejectedHeaders) {
          writeBufferedResponse(
            res,
            lastRejectedStatus,
            lastRejectedHeaders,
            lastRejectedBody ?? Buffer.alloc(0),
          );
        } else {
          writeJson(res, 503, { error: next.reason });
        }
        return;
      }

      attemptedAccounts.add(next.account_id);
      const headers = buildUpstreamHeaders(req.headers, next.api_key, cfg.proxy.auth_mode);
      const keyedTargetUrl = withApiKey(targetUrl, next.api_key, cfg.proxy.auth_mode);
      console.log(
        `[proxy] ${req.method} ${targetUrl.pathname} attempt=${attempt}/${maxAttempts} account=${next.account_id} key=${redactKey(next.api_key)} session=${redactSession(incomingSessionId)}`,
      );

      let upstreamRes: Response;
      try {
        upstreamRes = await fetch(keyedTargetUrl, {
          method: req.method,
          headers,
          body: bodyResult.body as BodyInit | undefined,
          redirect: "manual",
        });
      } catch (error) {
        const message = maskForLog(
          error instanceof Error ? error.message : String(error),
          store.list().flatMap((row) => (row.api_key ? [row.api_key] : [])),
        );
        console.error(`[proxy] upstream network error account=${next.account_id}: ${message}`);
        writeJson(res, 502, { error: "upstream network error; request was not replayed" });
        return;
      }

      if (FAILOVER_STATUSES.has(upstreamRes.status)) {
        const rejectedBody = Buffer.from(await upstreamRes.arrayBuffer());
        lastRejectedStatus = upstreamRes.status;
        lastRejectedBody = rejectedBody;
        lastRejectedHeaders = upstreamRes.headers;
        handleRejectedKey(store, cfg, next.account_id, upstreamRes, rejectedBody);
        if (incomingSessionId) store.deleteAffinity(incomingSessionId);
        preferredAccountId = undefined;
        continue;
      }

      store.markSuccess(next.account_id);
      bindAffinity(store, incomingSessionId, upstreamRes, next.account_id);
      await streamResponse(res, upstreamRes);
      return;
    }

    if (lastRejectedStatus && lastRejectedHeaders) {
      writeBufferedResponse(
        res,
        lastRejectedStatus,
        lastRejectedHeaders,
        lastRejectedBody ?? Buffer.alloc(0),
      );
      return;
    }
    writeJson(res, 503, { error: "failover attempts exhausted" });
  });

  server.listen(cfg.proxy.port, cfg.proxy.bind, () => {
    console.log(
      `[proxy] http://${cfg.proxy.bind}:${cfg.proxy.port}/tavily/mcp/ → ${cfg.proxy.upstream_mcp_base} (sticky keys + bounded failover)`,
    );
  });

  return server;
}

function buildTargetUrl(requestUrl: string, upstreamBase: string): URL {
  const incoming = new URL(requestUrl, "http://localhost");
  const suffix = incoming.pathname.replace(/^\/tavily/, "") || "/mcp/";
  const upstream = new URL(upstreamBase);
  const target = new URL(suffix.startsWith("/") ? suffix : `/${suffix}`, upstream.origin);
  target.search = incoming.search || upstream.search;
  return target;
}

function withApiKey(targetUrl: URL, apiKey: string, authMode: PoolConfig["proxy"]["auth_mode"]): URL {
  const out = new URL(targetUrl);
  if (authMode === "query" || authMode === "both") {
    out.searchParams.set("tavilyApiKey", apiKey);
  } else {
    out.searchParams.delete("tavilyApiKey");
  }
  return out;
}

function buildUpstreamHeaders(
  incoming: http.IncomingHttpHeaders,
  apiKey: string,
  authMode: PoolConfig["proxy"]["auth_mode"],
): Headers {
  const headers = new Headers();
  for (const [name, value] of Object.entries(incoming)) {
    const lower = name.toLowerCase();
    if (!value || lower === "host" || lower === "authorization" || HOP_BY_HOP_HEADERS.has(lower)) {
      continue;
    }
    headers.set(name, Array.isArray(value) ? value.join(",") : value);
  }
  if (authMode === "bearer" || authMode === "both") {
    headers.set("Authorization", `Bearer ${apiKey}`);
  }
  if (!headers.has("accept")) {
    headers.set("Accept", "application/json, text/event-stream");
  }
  return headers;
}

function getClientSessionId(headers: http.IncomingHttpHeaders): string | undefined {
  for (const name of CLIENT_SESSION_HEADERS) {
    const value = firstHeader(headers[name]);
    if (value) return `${name}:${value}`;
  }
  return undefined;
}

function bindAffinity(
  store: KeyStore,
  incomingSessionId: string | undefined,
  upstreamRes: Response,
  accountId: string,
) {
  if (incomingSessionId) store.setAffinity(incomingSessionId, accountId);
  const upstreamSessionId = upstreamRes.headers.get("mcp-session-id");
  if (upstreamSessionId) store.setAffinity(`mcp-session-id:${upstreamSessionId}`, accountId);
}

function handleRejectedKey(
  store: KeyStore,
  cfg: PoolConfig,
  accountId: string,
  response: Response,
  body: Buffer,
) {
  if (response.status === 401 || response.status === 403) {
    store.markAuthFailure(accountId);
    return;
  }
  const retryAfterSeconds = parseRetryAfter(response.headers.get("retry-after"));
  const bodyText = body.toString("utf8").toLowerCase();
  const quotaLimited = /quota|credit|usage limit|plan limit|exhausted/.test(bodyText);
  const cooldownSeconds = retryAfterSeconds ??
    (quotaLimited ? cfg.proxy.quota_cooldown_seconds : cfg.rotation.cooldown_seconds);
  const quotaResetUntil = quotaLimited ? quotaResetUntilAt(cfg, response.status) : null;
  store.markRateLimited(accountId, cooldownSeconds, quotaResetUntil);
}

function quotaResetUntilAt(cfg: PoolConfig, status: number): string | null {
  if (status !== 432) return null;
  return quotaResetUntil(cfg.rotation.quota_reset_day);
}

function parseRetryAfter(value: string | null, now = Date.now()): number | undefined {
  if (!value) return undefined;
  const seconds = Number(value);
  if (Number.isFinite(seconds) && seconds >= 0) return Math.max(1, Math.ceil(seconds));
  const dateMs = Date.parse(value);
  if (!Number.isFinite(dateMs)) return undefined;
  return Math.max(1, Math.ceil((dateMs - now) / 1000));
}

async function readReplayableBody(
  req: http.IncomingMessage,
  maxBytes: number,
): Promise<
  | { ok: true; body: Uint8Array | undefined }
  | { ok: false; status: number; error: string }
> {
  if (req.method === "GET" || req.method === "HEAD" || req.method === "DELETE") {
    return { ok: true, body: undefined };
  }
  return new Promise((resolve) => {
    const chunks: Buffer[] = [];
    let size = 0;
    let settled = false;
    req.on("data", (chunk: Buffer) => {
      if (settled) return;
      size += chunk.length;
      if (size > maxBytes) {
        settled = true;
        resolve({
          ok: false,
          status: 413,
          error: `request body exceeds replay limit (${maxBytes} bytes)`,
        });
        req.resume();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      if (!settled) resolve({ ok: true, body: new Uint8Array(Buffer.concat(chunks)) });
    });
    req.on("error", () => {
      if (!settled) resolve({ ok: false, status: 400, error: "failed to read request body" });
    });
  });
}

async function streamResponse(res: http.ServerResponse, upstreamRes: Response) {
  writeResponseHead(res, upstreamRes.status, upstreamRes.headers);
  if (!upstreamRes.body) {
    res.end();
    return;
  }
  await new Promise<void>((resolve, reject) => {
    Readable.fromWeb(upstreamRes.body as never)
      .on("error", reject)
      .on("end", resolve)
      .pipe(res);
  }).catch((error) => {
    console.error(`[proxy] response stream error: ${error instanceof Error ? error.message : String(error)}`);
    if (!res.writableEnded) res.destroy(error instanceof Error ? error : undefined);
  });
}

function writeBufferedResponse(
  res: http.ServerResponse,
  status: number,
  headers: Headers,
  body: Buffer,
) {
  writeResponseHead(res, status, headers);
  res.end(body);
}

function writeResponseHead(res: http.ServerResponse, status: number, headers: Headers) {
  const outgoing: Record<string, string | string[]> = {};
  headers.forEach((value, name) => {
    if (!HOP_BY_HOP_HEADERS.has(name.toLowerCase())) outgoing[name] = value;
  });
  res.writeHead(status, outgoing);
}

function writeJson(res: http.ServerResponse, status: number, payload: object) {
  res.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(payload));
}

function firstHeader(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

function redactSession(value: string | undefined): string {
  if (!value) return "(none)";
  if (value.length <= 12) return "****";
  return `${value.slice(0, 6)}…${value.slice(-4)}`;
}

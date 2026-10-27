import { join } from "node:path";
import { chromium, type BrowserContext } from "playwright";
import type { PoolConfig } from "./config.js";
import { KeyStore } from "./store.js";
import { redactKey } from "./redact.js";

const TVLY_RE = /tvly-[A-Za-z0-9_-]+/;

async function extractKeyFromPage(
  cfg: PoolConfig,
  page: import("playwright").Page,
): Promise<string | null> {
  const body = await page.content();
  const m =
    body.match(new RegExp(cfg.tavily.key_regex)) ?? body.match(TVLY_RE);
  if (m) return m[0];

  for (const sel of [
    cfg.tavily.selectors.api_key_input,
    cfg.tavily.selectors.api_key_text,
  ]) {
    try {
      const loc = page.locator(sel).first();
      if ((await loc.count()) > 0) {
        const val = await loc.inputValue().catch(() => loc.innerText());
        const km = String(val).match(TVLY_RE);
        if (km) return km[0];
      }
    } catch {
      /* try next */
    }
  }

  try {
    const copy = page.locator(cfg.tavily.selectors.copy_button).first();
    if ((await copy.count()) > 0) {
      await copy.click();
      // Clipboard not always available headless — rely on DOM after click if UI reveals key
    }
  } catch {
    /* ignore */
  }

  return null;
}

export async function openLoginSession(
  accountId: string,
  cfg: PoolConfig,
  store?: KeyStore,
): Promise<void> {
  if (store && !store.get(accountId)) {
    throw new Error(`Unknown account ${accountId}. Add it first with tavilylogin.`);
  }
  const profileDir = join(cfg.pool.profiles_dir, accountId);
  const context = await chromium.launchPersistentContext(profileDir, {
    headless: false,
    viewport: { width: 1280, height: 800 },
  });
  const page = context.pages()[0] ?? (await context.newPage());
  await page.goto(cfg.tavily.dashboard_url, { waitUntil: "domcontentloaded" });
  console.log(
    `[login] Complete Google + Tavily sign-in for ${accountId}, then close the browser window.`,
  );
  await page.waitForEvent("close", { timeout: 0 }).catch(() => {});
  await context.close();
}

export async function fetchKeyForAccount(
  accountId: string,
  cfg: PoolConfig,
  store: KeyStore,
  headed = false,
): Promise<boolean> {
  if (!store.get(accountId)) {
    throw new Error(`Unknown account ${accountId}. Add it first with tavilylogin.`);
  }
  const profileDir = join(cfg.pool.profiles_dir, accountId);
  let context: BrowserContext | null = null;
  try {
    context = await chromium.launchPersistentContext(profileDir, {
      headless: !headed,
      viewport: { width: 1280, height: 800 },
    });
    const page = context.pages()[0] ?? (await context.newPage());
    await page.goto(cfg.tavily.dashboard_url, {
      waitUntil: "domcontentloaded",
      timeout: cfg.fetch.navigation_timeout_ms,
    });
    await page.waitForTimeout(3000);

    if (page.url().includes("accounts.google") || page.url().includes("login")) {
      console.warn(`[fetch] ${accountId} not logged in — run: pnpm login ${accountId}`);
      store.get(accountId);
      await context.close();
      return false;
    }

    const key = await extractKeyFromPage(cfg, page);
    if (!key) {
      const shot = join(cfg.pool.debug_screenshots, `${accountId}-${Date.now()}.png`);
      await page.screenshot({ path: shot, fullPage: true });
      console.error(`[fetch] ${accountId} key not found — screenshot ${shot}`);
      await context.close();
      return false;
    }

    const email =
      (await page.locator('[data-email], [class*="email"]').first().innerText().catch(() => null)) ??
      store.get(accountId)?.email ??
      null;

    store.upsertKey(accountId, key, email);
    console.log(`[fetch] ${accountId} OK ${redactKey(key)}`);
    await context.close();
    return true;
  } catch (e) {
    console.error(`[fetch] ${accountId} error:`, e instanceof Error ? e.message : e);
    if (context) await context.close().catch(() => {});
    return false;
  }
}

export async function fetchAll(cfg: PoolConfig, store: KeyStore): Promise<void> {
  for (const account of store.list()) {
    await fetchKeyForAccount(account.account_id, cfg, store, false);
    await new Promise((r) => setTimeout(r, cfg.fetch.delay_between_accounts_ms));
  }
}
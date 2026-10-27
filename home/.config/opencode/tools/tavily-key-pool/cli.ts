#!/usr/bin/env node
import { loadConfig } from "./src/config.js";
import { KeyStore } from "./src/store.js";
import { fetchAll, fetchKeyForAccount, openLoginSession } from "./src/fetch.js";
import { getNextApiKey } from "./src/rotate.js";
import { startMcpProxy } from "./src/proxy.js";
import { redactKey } from "./src/redact.js";
import { interactiveLogin, interactiveLogout } from "./src/interactive.js";
import { printQuota } from "./src/quota.js";

const [cmd, arg, arg2] = process.argv.slice(2);

async function main() {
  const cfg = loadConfig();
  const store = new KeyStore(cfg);

  try {
    switch (cmd) {
      case "login":
        if (!arg) throw new Error("usage: login <account_id>");
        await openLoginSession(arg, cfg, store);
        break;

      case "fetch":
        if (!arg) throw new Error("usage: fetch <account_id>");
        await fetchKeyForAccount(arg, cfg, store, false);
        break;

      case "fetch-all":
        await fetchAll(cfg, store);
        break;

      case "interactive-login":
        await interactiveLogin(cfg, store);
        break;

      case "interactive-logout":
        await interactiveLogout(cfg, store);
        break;

      case "import-key":
        if (!arg || !arg2?.startsWith("tvly-")) {
          throw new Error("usage: import-key <account_id> <tvly-...>");
        }
        store.importKey(arg, arg2);
        break;

      case "next":
        console.log(JSON.stringify(getNextApiKey(store, cfg), null, 2));
        break;

      case "quota":
        await printQuota(store.list());
        break;

      case "status": {
        for (const row of store.list()) {
          console.log(
            `${row.account_id}\t${row.status}\t${redactKey(row.api_key)}\t${row.last_fetched_at ?? "-"}`,
          );
        }
        break;
      }

      case "serve-proxy":
        startMcpProxy(cfg, store);
        break;

      default:
        console.log(`Commands:
  login <acc>           Headed Chromium — Google + Tavily once per profile
  fetch <acc>           Scrape key for one account
  fetch-all             All accounts (with delay)
  interactive-login     Select a slot and securely enter a key
  interactive-logout    Select a slot and remove its local key
  import-key <acc> <key> Legacy manual import (key is visible in argv)
  status                Redacted table
  quota                 Credit quota for every local account
  next                  JSON get_next_api_key()
  serve-proxy           Local MCP rotator on :8765

Setup: mkdir -p ~/.tavily-key-pool && cp config.example.yaml ~/.tavily-key-pool/config.yaml
`);
    }
  } finally {
    if (cmd !== "serve-proxy") store.close();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
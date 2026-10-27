import { createInterface } from "node:readline/promises";
import type { PoolConfig } from "./config.js";
import { redactKey } from "./redact.js";
import { KeyStore, type KeyRecord } from "./store.js";

export async function interactiveLogin(cfg: PoolConfig, store: KeyStore): Promise<void> {
  const accounts = store.list();
  printAccounts(accounts, true);
  const selection = await selectAccount(accounts, true);
  if (selection.kind === "cancel") {
    console.log("Cancelled.");
    return;
  }

  const isNew = selection.kind === "add";
  const accountId = isNew ? store.nextAccountId() : selection.accountId;
  const key = (await readSecret(`Tavily API key for ${accountId}: `)).trim();
  if (!key) throw new Error("API key cannot be empty");
  if (!matchesConfiguredKey(key, cfg.tavily.key_regex)) {
    throw new Error("Invalid Tavily API key format");
  }

  store.importKey(accountId, key);
  console.log(`${isNew ? "Created" : "Updated"} ${accountId} with ${redactKey(key)}.`);
}

export async function interactiveLogout(_cfg: PoolConfig, store: KeyStore): Promise<void> {
  const accounts = store.list();
  if (accounts.length === 0) {
    console.log("No Tavily accounts exist.");
    return;
  }
  printAccounts(accounts, false);
  const selection = await selectAccount(accounts, false);
  if (selection.kind === "cancel") {
    console.log("Cancelled.");
    return;
  }
  if (selection.kind !== "account") return;

  const current = store.get(selection.accountId);
  if (!current) {
    console.log(`${selection.accountId} no longer exists; nothing changed.`);
    return;
  }

  const confirmed = await confirm(
    `Delete local account ${selection.accountId} (${redactKey(current.api_key)})? [y/N]: `,
  );
  if (!confirmed) {
    console.log("Cancelled; account was not removed.");
    return;
  }

  store.deleteAccount(selection.accountId);
  console.log(
    `${selection.accountId} was removed locally. Its key was not revoked at Tavily.`,
  );
}

export function printAccounts(accounts: KeyRecord[], allowAdd: boolean): void {
  console.log("Tavily accounts:");
  accounts.forEach((account, index) => {
    console.log(
      `${String(index + 1).padStart(2, " ")}) ${account.account_id.padEnd(7)} ${account.status.padEnd(8)} ${redactKey(account.api_key)}`,
    );
  });
  if (allowAdd) console.log(`${String(accounts.length + 1).padStart(2, " ")}) Add new account`);
  console.log(" 0) Cancel");
}

type AccountSelection =
  | { kind: "account"; accountId: string }
  | { kind: "add" }
  | { kind: "cancel" };

async function selectAccount(accounts: KeyRecord[], allowAdd: boolean): Promise<AccountSelection> {
  const answer = (await readLine("Account number or id: ")).trim();
  if (!answer || answer === "0" || /^q(uit)?$/i.test(answer)) return { kind: "cancel" };
  if (allowAdd && /^(a|add|new)$/i.test(answer)) return { kind: "add" };
  if (/^\d+$/.test(answer)) {
    const index = Number(answer) - 1;
    if (accounts[index]) return { kind: "account", accountId: accounts[index].account_id };
    if (allowAdd && index === accounts.length) return { kind: "add" };
  }
  const account = accounts.find((candidate) => candidate.account_id === answer);
  if (account) return { kind: "account", accountId: account.account_id };
  throw new Error(`Unknown account selection: ${answer}`);
}

async function confirm(prompt: string): Promise<boolean> {
  const answer = (await readLine(prompt)).trim().toLowerCase();
  return answer === "y" || answer === "yes";
}

let pipedLines: string[] | undefined;
let pipedLineIndex = 0;

async function readLine(prompt: string): Promise<string> {
  if (!process.stdin.isTTY) {
    process.stdout.write(prompt);
    if (!pipedLines) {
      let input = "";
      for await (const chunk of process.stdin) input += String(chunk);
      pipedLines = input.split(/\r?\n/);
    }
    return pipedLines[pipedLineIndex++] ?? "";
  }

  const rl = createInterface({ input: process.stdin, output: process.stdout, terminal: true });
  try {
    return await rl.question(prompt);
  } finally {
    rl.close();
  }
}

async function readSecret(prompt: string): Promise<string> {
  if (!process.stdin.isTTY || !process.stdin.setRawMode) {
    return readLine(prompt);
  }

  process.stdout.write(prompt);
  process.stdin.setRawMode(true);
  process.stdin.resume();
  process.stdin.setEncoding("utf8");

  return new Promise<string>((resolve, reject) => {
    let value = "";
    const cleanup = () => {
      process.stdin.off("data", onData);
      process.stdin.setRawMode?.(false);
      process.stdin.pause();
      process.stdout.write("\n");
    };
    const finish = () => {
      cleanup();
      resolve(value);
    };
    const onData = (chunk: string | Buffer) => {
      const text = String(chunk);
      for (const char of text) {
        if (char === "\r" || char === "\n") {
          finish();
          return;
        }
        if (char === "\u0003") {
          cleanup();
          reject(new Error("Cancelled"));
          return;
        }
        if (char === "\u007f" || char === "\b") {
          value = value.slice(0, -1);
          continue;
        }
        if (char >= " ") value += char;
      }
    };
    process.stdin.on("data", onData);
  });
}

function matchesConfiguredKey(key: string, pattern: string): boolean {
  const re = new RegExp(pattern);
  const match = key.match(re);
  return match?.[0] === key;
}

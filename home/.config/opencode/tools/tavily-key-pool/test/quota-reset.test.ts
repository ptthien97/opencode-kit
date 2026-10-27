import { nextQuotaResetAt, quotaResetUntil } from "../src/quota-reset.js";

let failed = 0;
let passed = 0;

function check(name: string, actual: string, expected: string) {
  const ok = actual === expected;
  if (ok) passed++;
  else {
    failed++;
    console.error(`FAIL ${name}\n  actual:   ${actual}\n  expected: ${expected}`);
  }
}

const at = (iso: string) => new Date(iso);

// Reset day later in the same month -> that day.
check(
  "reset day 15, now Aug 8 -> Aug 15",
  nextQuotaResetAt(15, at("2026-08-08T13:53:00+07:00")).toISOString(),
  "2026-08-14T17:00:00.000Z",
);

// Reset day already passed this month -> first day of next month.
check(
  "reset day 5, now Aug 8 -> Sep 5",
  nextQuotaResetAt(5, at("2026-08-08T13:53:00+07:00")).toISOString(),
  "2026-09-04T17:00:00.000Z",
);

// Exactly on reset day -> next month (boundary must be strictly after now).
check(
  "reset day 8, now Aug 8 00:00 local -> Sep 8",
  nextQuotaResetAt(8, at("2026-08-07T17:00:00.000Z")).toISOString(),
  "2026-09-07T17:00:00.000Z",
);

// Reset day beyond month length -> clamps to last day of month.
check(
  "reset day 31, Feb -> Feb 28",
  nextQuotaResetAt(31, at("2026-02-10T00:00:00+07:00")).toISOString(),
  "2026-02-27T17:00:00.000Z",
);

// December -> January of next year.
check(
  "reset day 1, Dec 31 -> Jan 1 next year",
  nextQuotaResetAt(1, at("2026-12-31T12:00:00+07:00")).toISOString(),
  "2026-12-31T17:00:00.000Z",
);

// No configured reset day -> null (keep fixed cooldown behavior).
const noResetDay = quotaResetUntil(undefined);
if (noResetDay === null) passed++;
else {
  failed++;
  console.error(`FAIL no reset day -> null\n  actual: ${noResetDay}`);
}

console.log(`\nquota-reset tests: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);

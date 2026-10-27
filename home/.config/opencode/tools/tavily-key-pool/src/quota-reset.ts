/**
 * Quota reset scheduling for plan-exhausted keys.
 *
 * Tavily plan credits reset on a monthly billing cycle. The /usage endpoint
 * does not expose the reset timestamp, so we approximate it with a configured
 * "reset day of month" (rotation.quota_reset_day). Keys flagged quota-limited
 * stay in cooldown until the next reset boundary instead of a fixed timer.
 */

/**
 * Returns the next reset boundary strictly after `now` for a given day of
 * month (1-31). Days beyond the month length clamp to the last day of the
 * month (e.g. resetDay 31 in February -> Feb 28/29).
 */
export function nextQuotaResetAt(resetDay: number, now: Date = new Date()): Date {
  const clamped = Math.max(1, Math.min(31, Math.floor(resetDay)));
  const year = now.getFullYear();
  const month = now.getMonth();

  const daysThisMonth = new Date(year, month + 1, 0).getDate();
  const candidate = new Date(
    year,
    month,
    Math.min(clamped, daysThisMonth),
    0,
    0,
    0,
    0,
  );

  if (candidate > now) return candidate;

  const daysNextMonth = new Date(year, month + 2, 0).getDate();
  return new Date(year, month + 1, Math.min(clamped, daysNextMonth), 0, 0, 0, 0);
}

/**
 * Optional reset boundary for a quota-limited key.
 * Returns null when the pool does not configure a reset day, so callers keep
 * their existing fixed cooldown behavior.
 */
export function quotaResetUntil(
  quotaResetDay: number | undefined,
  now: Date = new Date(),
): string | null {
  if (!quotaResetDay) return null;
  return nextQuotaResetAt(quotaResetDay, now).toISOString();
}

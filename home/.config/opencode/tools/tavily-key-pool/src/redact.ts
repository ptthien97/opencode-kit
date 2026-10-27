export function redactKey(key: string | null | undefined): string {
  if (!key) return "(none)";
  if (key.length <= 8) return "****";
  return `${key.slice(0, 8)}…${key.slice(-4)}`;
}

export function maskForLog(message: string, keys: string[]): string {
  let out = message;
  for (const k of keys) {
    if (k.length > 12) {
      out = out.split(k).join(redactKey(k));
    }
  }
  return out;
}
export function normaliseBoolean(value: unknown): boolean | null {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    if (value === 1) return true;
    if (value === 0) return false;
  }
  if (typeof value === "string") {
    const trimmed = value.trim().toLowerCase();
    if (["1", "true", "evet", "yes"].includes(trimmed)) return true;
    if (["0", "false", "hayir", "hayır", "no"].includes(trimmed)) return false;
  }
  return null;
}

export function normaliseNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null;
  }
  if (typeof value === "string") {
    const normalised = value.trim().replace(",", ".");
    if (!normalised) {
      return null;
    }
    const parsed = Number(normalised);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

// Age and place checks before any money goes in. Rules come from settings so
// a lawyer's list can change them without a release:
//   BLOCKED_REGIONS  comma list of ISO codes: whole countries (CZ) or states (US-AZ).
//                    "none" means nothing is blocked. Unset in production is an
//                    error, so a missing setting can never open every state.
//   AGE_RULES        comma list of code:age where the minimum is above 18
//                    (e.g. US-AL:19,US-MS:21).
// Cash-outs never call this: money already in the Vault always goes home.
import { HttpError } from "./common.ts";

export const DEFAULT_MIN_AGE = 18;
// Countries whose rules differ by state: a state is required before money.
export const NEEDS_REGION = new Set(["US", "CA", "AU"]);

export type Place = { country: string | null; region: string | null };
export type Rules = { blocked: Set<string>; ages: Map<string, number> };

export function normCountry(c: unknown): string | null {
  const s = String(c ?? "").trim().toUpperCase();
  return /^[A-Z]{2}$/.test(s) ? s : null;
}

/** "AZ" or "US-AZ" -> "US-AZ". Anything else -> null. */
export function normRegion(country: string | null, r: unknown): string | null {
  if (!country) return null;
  let s = String(r ?? "").trim().toUpperCase();
  if (!s) return null;
  if (!s.includes("-")) s = `${country}-${s}`;
  return new RegExp(`^${country}-[A-Z0-9]{1,3}$`).test(s) ? s : null;
}

export function readRules(env: (k: string) => string | undefined = (k) => Deno.env.get(k)): Rules {
  const raw = env("BLOCKED_REGIONS");
  if (raw === undefined && env("WHOP_ENVIRONMENT") === "production") {
    throw new HttpError(503, "Paid races are paused while we set up region rules.");
  }
  const blocked = new Set(
    (raw ?? "").split(",").map((s) => s.trim().toUpperCase()).filter((s) => s && s !== "NONE"),
  );
  const ages = new Map<string, number>();
  for (const part of (env("AGE_RULES") ?? "").split(",")) {
    const [code, age] = part.split(":").map((s) => s.trim().toUpperCase());
    const n = Number(age);
    if (code && Number.isInteger(n) && n >= DEFAULT_MIN_AGE && n <= 25) ages.set(code, n);
  }
  return { blocked, ages };
}

export function isBlocked(p: Place, rules: Rules): boolean {
  return (!!p.country && rules.blocked.has(p.country)) || (!!p.region && rules.blocked.has(p.region));
}

export function minAge(p: Place, rules: Rules): number {
  return Math.max(
    DEFAULT_MIN_AGE,
    (p.country && rules.ages.get(p.country)) || 0,
    (p.region && rules.ages.get(p.region)) || 0,
  );
}

/**
 * Age in whole years on `today` (YYYY-MM-DD). With only a birth year we can't
 * know if the birthday has passed, so we assume it hasn't: never too young by mistake.
 */
export function ageOn(today: string, birthDate: string | null, birthYear: number | null): number | null {
  const [ty, tm, td] = today.split("-").map(Number);
  if (birthDate && /^\d{4}-\d{2}-\d{2}$/.test(birthDate)) {
    const [y, m, d] = birthDate.split("-").map(Number);
    return ty - y - (tm < m || (tm === m && td < d) ? 1 : 0);
  }
  if (birthYear) return ty - birthYear - 1;
  return null;
}

type Profile = {
  id: string;
  birth_year: number | null;
  birth_date?: string | null;
  country?: string | null;
  region?: string | null;
};
export type Declared = { birth_date?: string | null; birth_year?: number | null; country?: string | null; region?: string | null };

/**
 * What to store from the request: only fields the profile doesn't have yet.
 * A stored birth date or place is never overwritten from the app, so nobody
 * can switch state or age one tap before paying. Moving is a support request.
 */
export function fillFromBody(p: Profile, body: Declared): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  if (!p.birth_date && body.birth_date && /^\d{4}-\d{2}-\d{2}$/.test(body.birth_date)) {
    out.birth_date = body.birth_date;
    out.birth_year = Number(body.birth_date.slice(0, 4));
  } else if (!p.birth_year && !p.birth_date && Number.isInteger(body.birth_year)) {
    out.birth_year = body.birth_year;
  }
  if (!p.country) {
    const c = normCountry(body.country);
    if (c) {
      out.country = c;
      const r = normRegion(c, body.region);
      if (r) out.region = r;
      out.place_set_at = new Date().toISOString();
    }
  } else if (!p.region) {
    const r = normRegion(p.country, body.region);
    if (r) out.region = r;
  }
  return out;
}

/** Throws a 403 with a plain reason when this person may not put money in. */
export function checkEligible(p: Profile, today: string, rules: Rules): void {
  const place: Place = { country: p.country ?? null, region: p.region ?? null };
  if (!place.country) throw new HttpError(403, "Tell us where you live before your first paid race.");
  if (NEEDS_REGION.has(place.country) && !place.region) {
    throw new HttpError(403, "Tell us which state or province you live in before your first paid race.");
  }
  if (isBlocked(place, rules)) {
    throw new HttpError(403, "Paid races aren't available where you live. Free races and your Vault still work.");
  }
  const age = ageOn(today, p.birth_date ?? null, p.birth_year ?? null);
  const need = minAge(place, rules);
  if (age === null) throw new HttpError(403, "Add your date of birth before your first paid race.");
  if (age < need) throw new HttpError(403, `Paid races are for adults ${need} and over where you live.`);
}

/** Loads nothing: the caller passes the profile it already has, gets back the merged one. */
export async function ensureEligible<P extends Profile>(
  // deno-lint-ignore no-explicit-any
  db: any,
  profile: P,
  body: Declared,
  today: string,
  rules: Rules = readRules(),
): Promise<P> {
  const fill = fillFromBody(profile, body);
  if (Object.keys(fill).length) {
    const { error } = await db.from("profiles").update(fill).eq("id", profile.id);
    if (error) throw new HttpError(400, "That place or date doesn't look right.");
  }
  const merged = { ...profile, ...fill } as P;
  checkEligible(merged, today, rules);
  return merged;
}

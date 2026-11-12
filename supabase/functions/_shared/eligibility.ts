// Age and place checks before any money goes in. The lists below are the
// defaults; a lawyer's list replaces them through settings, without a release:
//   BLOCKED_REGIONS  comma list of ISO codes: whole countries (CZ) or states (US-AZ).
//                    "none" blocks nothing. Unset or empty uses DEFAULT_BLOCKED.
//   AGE_RULES        comma list of code:age where the minimum is above 18
//                    (e.g. US-AL:19,US-MS:21). "none" clears it. Unset or empty
//                    uses DEFAULT_AGES.
// Cash-outs never call this: money already in the Vault always goes home.
import { HttpError } from "./common.ts";

export const DEFAULT_MIN_AGE = 18;

// Steppa (the same pay-to-enter, finishers-split model) blocks paid play in
// some US states but doesn't publish which. This is the list Skillz-powered
// cash-tournament apps publish on the App Store (Solitaire Tour, Jewel Blitz,
// checked 2026-11-12): states whose laws catch paid contests with any element
// of chance. Steppa's Terms add nothing country-wide.
export const DEFAULT_BLOCKED = "US-AZ,US-AR,US-CT,US-DE,US-LA,US-MT,US-SC,US-SD,US-TN";

// Steppa's Terms: 18, "or 19 or 21 where a higher minimum age is required by the
// law of Your jurisdiction of residence". That is the age of majority: 19 in
// Alabama, Nebraska and seven Canadian provinces and territories, 21 in
// Mississippi and Puerto Rico.
export const DEFAULT_AGES =
  "US-AL:19,US-NE:19,US-MS:21,PR:21,CA-BC:19,CA-NB:19,CA-NL:19,CA-NS:19,CA-NT:19,CA-NU:19,CA-YT:19";
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
  const setting = (k: string, fallback: string) => {
    const v = (env(k) ?? "").trim();
    return v === "" ? fallback : v.toUpperCase() === "NONE" ? "" : v;
  };
  const blocked = new Set(
    setting("BLOCKED_REGIONS", DEFAULT_BLOCKED).split(",").map((s) => s.trim().toUpperCase()).filter(Boolean),
  );
  const ages = new Map<string, number>();
  for (const part of setting("AGE_RULES", DEFAULT_AGES).split(",")) {
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

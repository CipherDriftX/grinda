import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { ageOn, checkEligible, fillFromBody, isBlocked, minAge, normRegion, readRules } from "./eligibility.ts";
import { HttpError } from "./common.ts";

const env = (m: Record<string, string>) => (k: string) => m[k];

Deno.test("rules: unset or empty uses the defaults, 'none' clears, a list replaces", () => {
  for (const d of [readRules(env({})), readRules(env({ BLOCKED_REGIONS: " ", AGE_RULES: "" }))]) {
    assertEquals(d.blocked.size, 9);
    assertEquals(d.blocked.has("US-AZ") && d.blocked.has("US-TN"), true);
    assertEquals(d.blocked.has("US-TX"), false);
    assertEquals(d.ages.get("US-MS"), 21);
    assertEquals(d.ages.get("US-AL"), 19);
    assertEquals(d.ages.get("CA-BC"), 19);
    assertEquals(d.ages.has("CA-ON"), false);
  }
  const none = readRules(env({ BLOCKED_REGIONS: "none", AGE_RULES: "NONE" }));
  assertEquals(none.blocked.size + none.ages.size, 0);
  const r = readRules(env({ BLOCKED_REGIONS: " us-az, CZ ,", AGE_RULES: "US-AL:19,US-MS:21,XX:abc,US-NE:12" }));
  assertEquals([...r.blocked].sort(), ["CZ", "US-AZ"]);
  assertEquals(r.ages.get("US-MS"), 21);
  assertEquals(r.ages.has("XX"), false);
  assertEquals(r.ages.has("US-NE"), false); // below 18 is ignored
});

Deno.test("default rules: Arizona blocked, Texas open, 20 is too young in Mississippi", () => {
  const d = readRules(env({}));
  const tx = { id: "u", birth_year: 2006, birth_date: "2006-01-01", country: "US", region: "US-TX" };
  checkEligible(tx, "2026-11-12", d);
  assertThrows(() => checkEligible({ ...tx, region: "US-AZ" }, "2026-11-12", d), HttpError, "aren't available");
  assertThrows(() => checkEligible({ ...tx, region: "US-MS" }, "2026-11-12", d), HttpError, "21 and over");
  assertThrows(() => checkEligible({ ...tx, country: "CA", region: "CA-BC", birth_date: "2008-01-01" }, "2026-11-12", d), HttpError, "19 and over");
  checkEligible({ ...tx, country: "CA", region: "CA-ON", birth_date: "2008-01-01" }, "2026-11-12", d);
  checkEligible({ ...tx, country: "DE", region: null }, "2026-11-12", d);
});

Deno.test("blocked by country or by state", () => {
  const r = readRules(env({ BLOCKED_REGIONS: "CZ,US-AZ" }));
  assertEquals(isBlocked({ country: "CZ", region: null }, r), true);
  assertEquals(isBlocked({ country: "US", region: "US-AZ" }, r), true);
  assertEquals(isBlocked({ country: "US", region: "US-TX" }, r), false);
  assertEquals(minAge({ country: "US", region: "US-MS" }, readRules(env({ AGE_RULES: "US-MS:21" }))), 21);
  assertEquals(minAge({ country: "DE", region: null }, r), 18);
});

Deno.test("age: exact with a date, careful with only a year", () => {
  assertEquals(ageOn("2026-11-12", "2008-11-12", null), 18);
  assertEquals(ageOn("2026-11-11", "2008-11-12", null), 17);
  assertEquals(ageOn("2026-11-12", null, 2008), 17); // birthday may not have come yet
  assertEquals(ageOn("2026-11-12", null, null), null);
});

Deno.test("region codes", () => {
  assertEquals(normRegion("US", "az"), "US-AZ");
  assertEquals(normRegion("US", "US-AZ"), "US-AZ");
  assertEquals(normRegion("US", "DE-BY"), null);
  assertEquals(normRegion(null, "AZ"), null);
});

Deno.test("the app can fill a profile once, never overwrite it", () => {
  const empty = { id: "u", birth_year: null, birth_date: null, country: null, region: null };
  const f = fillFromBody(empty, { birth_date: "1990-05-01", country: "us", region: "tx" });
  assertEquals(f.birth_date, "1990-05-01");
  assertEquals(f.birth_year, 1990);
  assertEquals(f.country, "US");
  assertEquals(f.region, "US-TX");
  const set = { id: "u", birth_year: 1990, birth_date: "1990-05-01", country: "US", region: "US-TX" };
  assertEquals(fillFromBody(set, { birth_date: "2001-01-01", country: "DE", region: "BY" }), {});
  // A state can be added later if it was missing.
  assertEquals(fillFromBody({ ...set, region: null }, { region: "NY" }), { region: "US-NY" });
});

Deno.test("eligibility messages", () => {
  const r = readRules(env({ BLOCKED_REGIONS: "US-AZ", AGE_RULES: "US-MS:21" }));
  const base = { id: "u", birth_year: 1990, birth_date: "1990-05-01", country: "US", region: "US-TX" };
  checkEligible(base, "2026-11-12", r);
  assertThrows(() => checkEligible({ ...base, country: null }, "2026-11-12", r), HttpError, "where you live");
  assertThrows(() => checkEligible({ ...base, region: null }, "2026-11-12", r), HttpError, "state or province");
  assertThrows(() => checkEligible({ ...base, region: "US-AZ" }, "2026-11-12", r), HttpError, "aren't available");
  assertThrows(() => checkEligible({ ...base, region: "US-MS", birth_date: "2006-01-01" }, "2026-11-12", r), HttpError, "21 and over");
  assertThrows(() => checkEligible({ ...base, birth_date: null, birth_year: null }, "2026-11-12", r), HttpError, "date of birth");
  checkEligible({ ...base, country: "DE", region: null }, "2026-11-12", r); // no state needed in Germany
});

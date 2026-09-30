import { assertEquals } from "jsr:@std/assert@1";
import { scheduleDates, settleInstant, TEMPLATES, usesHold } from "./common.ts";

Deno.test("settles 3h after local midnight (Berlin, CEST)", () => {
  // 2026-09-30 ends at 2026-10-01 00:00 CEST = 2026-09-30T22:00Z; +3h = 01:00Z
  assertEquals(settleInstant("2026-09-30", "Europe/Berlin").toISOString(), "2026-10-01T01:00:00.000Z");
});

Deno.test("settles 3h after local midnight (New York, EDT)", () => {
  assertEquals(settleInstant("2026-09-30", "America/New_York").toISOString(), "2026-10-01T07:00:00.000Z");
});

Deno.test("weekend schedule picks only Saturdays and Sundays", () => {
  const d = scheduleDates(TEMPLATES["weekend"], "2026-09-30"); // Wednesday
  assertEquals(d.slice(0, 4), ["2026-10-03", "2026-10-04", "2026-10-10", "2026-10-11"]);
  assertEquals(d.length, 8);
});

Deno.test("only short consecutive races are holds", () => {
  assertEquals(usesHold(TEMPLATES["sprint-5"]), true);
  assertEquals(usesHold(TEMPLATES["10k-week"]), false);
  assertEquals(usesHold(TEMPLATES["weekend"]), false);
});

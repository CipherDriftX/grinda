import { assertEquals } from "jsr:@std/assert@1";
import { consecutiveDates, hostFee, scheduleDates, serviceFee, settleInstant, TEMPLATES, usesHold, windowSteps } from "./common.ts";

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

Deno.test("purse fee: 50 cents + 4% on top, none for Pro", () => {
  assertEquals(serviceFee(2000, false), 130);
  assertEquals(serviceFee(2000, true), 0);
  assertEquals(serviceFee(500, false), 70);
});

Deno.test("host gets 5% on top, only on public purses", () => {
  assertEquals(hostFee(2000, "host"), 100);
  assertEquals(hostFee(2000, "crew"), 0);
  assertEquals(hostFee(2000, "house"), 0);
});

Deno.test("window steps count only inside the window", () => {
  const hourly = Array.from({ length: 24 }, (_, h) => (h >= 6 && h < 9 ? 1000 : 10));
  assertEquals(windowSteps(hourly, 6, 9), 3000);
  assertEquals(windowSteps(hourly, null, null), null);
});

Deno.test("purse days run back to back across month ends", () => {
  assertEquals(consecutiveDates("2026-10-30", 4), ["2026-10-30", "2026-10-31", "2026-11-01", "2026-11-02"]);
});

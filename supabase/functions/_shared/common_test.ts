import { assertEquals } from "jsr:@std/assert@1";
import { consecutiveDates, hostFee, scheduleDates, quoteEntry, serviceFee, settleInstant, TEMPLATES, windowSteps } from "./common.ts";

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

Deno.test("purse fee: 0.99 + 5% by card, 0.50 + 4% from the balance", () => {
  assertEquals(serviceFee(2000, false, "card"), 199);
  assertEquals(serviceFee(2000, false, "balance"), 130);
  assertEquals(serviceFee(500, false, "card"), 124);
  assertEquals(serviceFee(500, false, "balance"), 70);
});

Deno.test("Pro: free from the balance, card cost only by card", () => {
  assertEquals(serviceFee(2000, true, "balance"), 0);
  assertEquals(serviceFee(2000, true, "card"), 109);
});

Deno.test("quote: balances that cover it all get the balance fee and no card", () => {
  const q = quoteEntry(2000, "house", false, 500, 1700);
  assertEquals([q.funding, q.fee, q.total, q.fromCredit, q.fromVault, q.fromCard], ["balance", 130, 2130, 500, 1630, 0]);
});

Deno.test("quote: a card part pays the card fee, balances first", () => {
  const q = quoteEntry(2000, "host", false, 500, 1000);
  // 2000 entry + 199 fee + 100 host = 2299; 500 credit + 1000 Vault, 799 by card.
  assertEquals([q.funding, q.fee, q.host, q.total, q.fromCredit, q.fromVault, q.fromCard], ["card", 199, 100, 2299, 500, 1000, 799]);
});

Deno.test("quote: a card never charges under 50 cents and every cent is paid once", () => {
  for (const entry of [500, 1000, 2000, 5000, 10000]) {
    for (const kind of ["house", "host", "crew"]) {
      for (const isPro of [false, true]) {
        for (let have = 0; have <= entry + 800; have += 7) {
          for (const q of [quoteEntry(entry, kind, isPro, have, 0), quoteEntry(entry, kind, isPro, 0, have), quoteEntry(entry, kind, isPro, have >> 1, have - (have >> 1))]) {
            assertEquals(q.fromCredit + q.fromVault + q.fromCard, q.total);
            assertEquals(q.total, q.entry + q.fee + q.host);
            assertEquals(q.fromCard === 0 || q.fromCard >= 50, true);
            assertEquals(q.fromCredit >= 0 && q.fromVault >= 0 && q.fromCredit + q.fromVault <= have, true);
          }
        }
      }
    }
  }
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

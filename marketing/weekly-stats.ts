// Builds the weekly "Steppie in numbers" post for X and Discord from the live
// public-stats endpoint. Real numbers only: if the endpoint fails, nothing is posted.
//
//   deno run --allow-net --allow-env marketing/weekly-stats.ts            # print X thread
//   DISCORD_WEBHOOK_URL=... deno run --allow-net --allow-env marketing/weekly-stats.ts --discord
//
// Env: STEPPIE_API (https://<project>.supabase.co), STEPPIE_ANON_KEY

type Stats = {
  walkers: number;
  steps_walked: number;
  km_walked: number;
  races_finished: number;
  completion_rate: number;
  returned_cents: number;
  kept_cents: number;
  currency: string;
  weight_lost_kg_opt_in: number;
};

const api = Deno.env.get("STEPPIE_API");
const key = Deno.env.get("STEPPIE_ANON_KEY");
if (!api || !key) {
  console.error("Set STEPPIE_API and STEPPIE_ANON_KEY.");
  Deno.exit(1);
}

async function load(currency: "EUR" | "USD"): Promise<Stats> {
  const res = await fetch(`${api}/functions/v1/public-stats?currency=${currency}`, {
    headers: { apikey: key!, Authorization: `Bearer ${key}` },
  });
  if (!res.ok) throw new Error(`public-stats ${res.status}`);
  return await res.json();
}

const [eur, usd] = await Promise.all([load("EUR"), load("USD")]);
const n = (x: number) => Math.round(x).toLocaleString("en-US");
const money = (cents: number, cur: string) =>
  (cents / 100).toLocaleString("en-US", { style: "currency", currency: cur, maximumFractionDigits: 0 });

const returned = [eur.returned_cents > 0 ? money(eur.returned_cents, "EUR") : null,
  usd.returned_cents > 0 ? money(usd.returned_cents, "USD") : null].filter(Boolean).join(" + ") || "0";

const lines = [
  `Steppie, so far:`,
  ``,
  `🚶 ${n(eur.walkers)} people have raced`,
  `👣 ${n(eur.steps_walked)} steps`,
  `🗺️ ${n(eur.km_walked)} km walked`,
  `🏁 ${n(eur.races_finished)} races finished (${Math.round(eur.completion_rate * 100)}% finish rate)`,
  `💸 ${returned} returned to walkers`,
  eur.weight_lost_kg_opt_in > 0 ? `⚖️ ${n(eur.weight_lost_kg_opt_in)} kg lost (self-reported, opt-in)` : null,
  ``,
  `Money on the line, back when you finish. #BackYourself`,
].filter((l) => l !== null).join("\n");

const thread = [
  lines,
  `How it works: pick a daily step goal, stake €5–€500. Short races are only a hold on your card. Finish and it's released; miss and it's kept.`,
  `Every number above is live from our database. We publish what we keep too: ${money(eur.kept_cents, "EUR")}${usd.kept_cents ? ` + ${money(usd.kept_cents, "USD")}` : ""} from missed races. We'd rather you finish.`,
];

if (Deno.args.includes("--discord")) {
  const hook = Deno.env.get("DISCORD_WEBHOOK_URL");
  if (!hook) throw new Error("Set DISCORD_WEBHOOK_URL");
  const res = await fetch(hook, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ username: "Steppie", content: thread.join("\n\n") }),
  });
  console.log(res.ok ? "Posted to Discord." : `Discord error ${res.status}`);
} else {
  thread.forEach((t, i) => console.log(`--- post ${i + 1}/${thread.length} (${t.length} chars) ---\n${t}\n`));
}

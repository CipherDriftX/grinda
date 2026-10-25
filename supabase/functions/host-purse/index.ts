// Starts a member purse. Crew: private, code only, up to 12, free. Public
// (host): listed for everyone, the host earns 5% on top of every entry. A
// public purse costs HOST_CREATE_CENTS (Vault first, then card), free once a
// month with Pro. It's listed once paid.
import {
  admin, handler, HOST_CREATE_CENTS, HttpError, json, requireUser, stripe, STRIPE_API_VERSION, stripeCustomer,
} from "../_shared/common.ts";

type Body = {
  name: string;
  kind: "crew" | "host";
  daily_goal: number;
  days: number;
  entry_units: number;
  currency: "EUR" | "USD";
  starts_at: string; // ISO, the local start day
};

const GOALS = [5000, 7500, 10000, 12500, 15000];
const LENGTHS = [1, 3, 5, 7, 14, 21, 30];
const ENTRIES = [5, 10, 20, 25, 50, 100];

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await requireUser(req);
  const body = (await req.json()) as Body;
  const db = admin();

  const name = (body.name ?? "").trim().replace(/\s+/g, " ");
  if (name.length < 3 || name.length > 28) throw new HttpError(400, "Pick a name between 3 and 28 letters.");
  if (!["crew", "host"].includes(body.kind)) throw new HttpError(400, "Unknown purse type.");
  if (!GOALS.includes(body.daily_goal) || !LENGTHS.includes(body.days) || !ENTRIES.includes(body.entry_units)) {
    throw new HttpError(400, "That combination isn't available.");
  }
  if (!["EUR", "USD"].includes(body.currency)) throw new HttpError(400, "Unsupported currency.");
  const startsOn = body.starts_at?.slice(0, 10);
  const tomorrow = new Date(Date.now() + 12 * 3600_000).toISOString().slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(startsOn ?? "") || startsOn < tomorrow) throw new HttpError(400, "Purses start tomorrow at the earliest.");

  const { data: profile } = await db.from("profiles").select("*").eq("id", user.id).maybeSingle();
  if (!profile?.birth_year || new Date().getUTCFullYear() - profile.birth_year < 18) {
    throw new HttpError(403, "Purses are for adults 18 and over.");
  }

  const { count: hosting } = await db.from("purses").select("id", { count: "exact", head: true })
    .eq("host_id", user.id).is("settled_at", null);
  if ((hosting ?? 0) >= 3) throw new HttpError(409, "You can host three purses at a time.");

  const code = await uniqueCode(db, name);
  const id = `member-${crypto.randomUUID().slice(0, 8)}`;

  // Public purses: free once a month with Pro, otherwise the host fee.
  const month = new Date().toISOString().slice(0, 7) + "-01";
  const free = body.kind === "crew" || (profile.is_pro && profile.host_free_month !== month);
  const fee = free ? 0 : HOST_CREATE_CENTS;
  const fromVault = Math.min(profile.vault_cents ?? 0, fee);
  const fromCard = fee - fromVault;

  const { data: purse, error } = await db.from("purses").insert({
    id, name,
    tagline: body.kind === "crew" ? `A private purse for ${firstName(profile.display_name)}'s crew.` : `Hosted by ${firstName(profile.display_name)}.`,
    kind: body.kind,
    art: body.kind === "crew" ? "crew" : "megaphone",
    daily_goal: body.daily_goal,
    days: body.days,
    entry_cents: body.entry_units * 100,
    currency: body.currency,
    starts_on: startsOn,
    host_id: user.id,
    code,
    cap: body.kind === "crew" ? 12 : null,
    listed: fromCard === 0,
  }).select().single();
  if (error || !purse) throw error ?? new Error("insert failed");

  if (body.kind === "host" && profile.is_pro && fee === 0) {
    await db.from("profiles").update({ host_free_month: month }).eq("id", user.id);
  }
  if (fromVault > 0) {
    const { error: e } = await db.rpc("adjust_balance", { uid: user.id, vault_delta: -fromVault, credit_delta: 0 });
    if (e) {
      await db.from("purses").delete().eq("id", id);
      throw new HttpError(409, "Your balance changed. Try again.");
    }
    await db.from("ledger_entries").insert({
      race_id: null, user_id: user.id, kind: "fee", amount_cents: fromVault, currency: body.currency,
      stripe_ref: `host_${id}`, label: `Hosting ${name}`,
    });
  }

  const reply = boardRow(purse, profile.display_name);
  if (fromCard === 0) return json({ purse: reply, payment: null });

  const customerId = await stripeCustomer(db, user.id, profile);
  const intent = await stripe.paymentIntents.create({
    amount: fromCard,
    currency: body.currency.toLowerCase(),
    customer: customerId,
    payment_method_types: ["card"],
    description: `Steppie host fee: ${name}`,
    statement_descriptor_suffix: "STEPPIE HOST",
    metadata: { purse_id: id, user_id: user.id, kind: "host_fee" },
  }, { idempotencyKey: `host-${id}` });
  const key = await stripe.ephemeralKeys.create({ customer: customerId }, { apiVersion: STRIPE_API_VERSION });

  return json({
    purse: reply,
    payment: {
      race_id: crypto.randomUUID(), // PaymentSheet reply shape; no race for a host fee
      bib_number: 0,
      payment_intent_client_secret: intent.client_secret,
      customer_id: customerId,
      ephemeral_key: key.secret,
      publishable_key: Deno.env.get("STRIPE_PUBLISHABLE_KEY"),
      capture_method: "automatic",
    },
  });
}));

function firstName(n: string | null): string {
  return (n ?? "").split(" ")[0] || "A walker";
}

// deno-lint-ignore no-explicit-any
async function uniqueCode(db: any, name: string): Promise<string> {
  const head = name.toUpperCase().replace(/[^A-Z]/g, "").slice(0, 8) || "CREW";
  for (let i = 0; i < 20; i++) {
    const code = `${head}-${10 + Math.floor(Math.random() * 90)}`;
    const { count } = await db.from("purses").select("id", { count: "exact", head: true }).eq("code", code);
    if (!count) return code;
  }
  return `${head}-${crypto.randomUUID().slice(0, 4).toUpperCase()}`;
}

// The same shape as a purse_board row, so the app decodes it as a Purse.
// deno-lint-ignore no-explicit-any
function boardRow(p: any, hostName: string | null) {
  return {
    id: p.id, name: p.name, tagline: p.tagline, kind: p.kind, art: p.art, daily_goal: p.daily_goal, days: p.days,
    window: null, entry_units: p.entry_cents / 100, currency: p.currency, starts_at: `${p.starts_on}T00:00:00Z`,
    entrants: 0, still_in: 0, on_pace: 0, sponsor_cents: 0, host_name: firstName(hostName), code: p.code,
    cap: p.cap, pro_only: false, benched: 0, late_syncs_back: 0,
  };
}

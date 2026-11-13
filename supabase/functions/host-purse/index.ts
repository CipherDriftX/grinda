// Starts a member purse. Crew: private, code only, up to 12, free. Public
// (host): listed for everyone, the host earns 5% on top of every entry. A
// public purse costs HOST_CREATE_CENTS (Vault first, then a Whop checkout),
// free once a month with Pro. It's listed once paid; an unpaid one is called
// off after an hour and its Vault part goes back.
import {
  admin, CARD_MIN, handler, HOST_CREATE_CENTS, HttpError, json, moneyError, proActive, requireUser,
} from "../_shared/common.ts";
import { type Declared, ensureEligible } from "../_shared/eligibility.ts";
import { createCheckout } from "../_shared/whop.ts";

type Body = Declared & {
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
const MAX_HOSTED = 3;

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

  const { data: found } = await db.from("profiles").select("*").eq("id", user.id).maybeSingle();
  if (!found) throw new HttpError(403, "Finish setting up your profile first.");
  // Every entrant is checked when they join; the host is checked here, crew purses too.
  const profile = await ensureEligible(db, found, body, new Date().toISOString().slice(0, 10));

  // A public purse still waiting for its card: hand back the same checkout.
  const { data: open } = await db.from("purses").select("*").eq("host_id", user.id).eq("listed", false)
    .not("host_checkout_url", "is", null).eq("name", name).maybeSingle();
  if (open) {
    return json({ purse: boardRow(open, profile.display_name), checkout: { id: open.host_checkout_id, url: open.host_checkout_url } });
  }

  // Public purses: free once a month with Pro, otherwise the host fee.
  const month = new Date().toISOString().slice(0, 7) + "-01";
  const proFree = body.kind === "host" && proActive(profile) && profile.host_free_month !== month;
  const fee = body.kind === "crew" || proFree ? 0 : HOST_CREATE_CENTS;
  let fromVault = profile.currency === body.currency || !profile.currency ? Math.min(profile.vault_cents ?? 0, fee) : 0;
  let fromCard = fee - fromVault;
  if (fromCard > 0 && fromCard < CARD_MIN) {
    fromVault -= CARD_MIN - fromCard;
    fromCard = CARD_MIN;
  }

  const id = `member-${crypto.randomUUID().slice(0, 8)}`;
  const tagline = body.kind === "crew"
    ? `A private purse for ${firstName(profile.display_name)}'s crew.`
    : `Hosted by ${firstName(profile.display_name)}.`;
  let error = null;
  for (let attempt = 0; attempt < 3; attempt++) {
    const code = await uniqueCode(db, name);
    ({ error } = await db.rpc("open_host_purse", {
      uid: user.id,
      spec: {
        id, name, tagline, kind: body.kind, art: body.kind === "crew" ? "crew" : "megaphone",
        daily_goal: body.daily_goal, days: body.days, entry_cents: body.entry_units * 100, currency: body.currency,
        starts_on: startsOn, code, cap: body.kind === "crew" ? 12 : null,
        fee_cents: fee, from_vault: fromVault, from_card: fromCard, free_month: proFree ? month : null,
      },
      max_hosted: MAX_HOSTED,
    }));
    if (!error?.message?.includes("purses_code_key")) break; // a code taken between check and insert: try another
  }
  if (error) throw moneyError(error);

  const { data: purse } = await db.from("purses").select("*").eq("id", id).single();
  const reply = boardRow(purse, profile.display_name);
  if (fromCard === 0) return json({ purse: reply, checkout: null });

  let checkout;
  try {
    checkout = await createCheckout({
      amountCents: fromCard,
      currency: body.currency,
      title: `Host a purse: ${name}`,
      description: "Your purse is listed for everyone once this is paid. You earn 5% on top of every entry.",
      meta: { kind: "host", purse_id: id, user_id: user.id },
    });
  } catch (e) {
    await db.rpc("cancel_host_purse", { pid: id });
    console.error("checkout", e);
    throw new HttpError(502, "Card payments are down for a moment. Nothing was charged; try again soon.");
  }
  await db.from("purses").update({ host_checkout_id: checkout.id, host_checkout_url: checkout.purchase_url }).eq("id", id);
  return json({ purse: reply, checkout: { id: checkout.id, url: checkout.purchase_url } });
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

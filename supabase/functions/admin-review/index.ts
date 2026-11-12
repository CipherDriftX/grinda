// The review desk. Before this, flagged days, Health screenshots and frozen
// payouts had no way to be answered: a race under review waited forever and
// so did its share of the purse.
//
// POST with header x-admin-secret: ADMIN_SECRET (no user login; keep the
// secret off phones). Actions:
//   { "action": "queue" }
//       races under review with their waiting days, open screenshots (links
//       valid one hour), frozen accounts, cash-outs that failed this week
//   { "action": "resolve_day", "race_id", "day", "verdict": "accept"|"reject", "note" }
//       decides one day; when none is left, the next settle run gives the
//       race its result and pays any held purse share
//   { "action": "unfreeze", "user_id", "note" }
//       lets cash-outs run again after a dispute is answered
// Example:
//   curl -X POST "$SUPABASE_URL/functions/v1/admin-review" \
//     -H "x-admin-secret: $ADMIN_SECRET" -d '{"action":"queue"}'
import { admin, json } from "../_shared/common.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Same-time compare of two secrets (hash both, then compare every byte). */
async function sameSecret(a: string, b: string): Promise<boolean> {
  const h = async (s: string) => new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s)));
  const [x, y] = await Promise.all([h(a), h(b)]);
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const secret = Deno.env.get("ADMIN_SECRET") ?? "";
  if (secret.length < 24) return json({ error: "ADMIN_SECRET is not set (24+ characters)." }, 503);
  if (!(await sameSecret(req.headers.get("x-admin-secret") ?? "", secret))) return json({ error: "no" }, 401);

  // deno-lint-ignore no-explicit-any
  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad body" }, 400);
  }
  const db = admin();

  if (body.action === "queue") {
    const { data: races } = await db.from("races")
      .select("id, user_id, name, purse_id, stake_cents, currency, timezone, start_date, end_date, settles_at")
      .eq("status", "underReview").order("settles_at").limit(200);
    const ids = (races ?? []).map((r) => r.id);
    const { data: days } = ids.length
      ? await db.from("race_days").select("race_id, day, goal, steps, hourly, flagged, disputed, late, submitted_at")
        .in("race_id", ids).or("flagged.eq.true,disputed.eq.true")
      : { data: [] };
    const { data: disputes } = await db.from("disputes").select("id, race_id, user_id, day, note, image_path, created_at")
      .eq("status", "open").order("created_at").limit(200);
    const withLinks = await Promise.all((disputes ?? []).map(async (d) => {
      if (!d.image_path) return { ...d, image_url: null };
      const { data } = await db.storage.from("disputes").createSignedUrl(d.image_path, 3600);
      return { ...d, image_url: data?.signedUrl ?? null };
    }));
    const { data: frozen } = await db.from("profiles").select("id, display_name, vault_cents, currency, payouts_frozen_at, payouts_frozen_reason")
      .not("payouts_frozen_at", "is", null);
    const { data: failed } = await db.from("cashouts").select("id, user_id, amount_cents, currency, method, failure, created_at")
      .eq("status", "failed").gt("created_at", new Date(Date.now() - 7 * 86_400_000).toISOString());
    return json({
      races: (races ?? []).map((r) => ({ ...r, waiting_days: (days ?? []).filter((d) => d.race_id === r.id) })),
      disputes: withLinks,
      frozen: frozen ?? [],
      failed_cashouts: failed ?? [],
    });
  }

  if (body.action === "resolve_day") {
    if (!UUID.test(body.race_id ?? "") || !/^\d{4}-\d{2}-\d{2}$/.test(body.day ?? "")) return json({ error: "race_id and day" }, 400);
    const { data, error } = await db.rpc("resolve_day", {
      rid: body.race_id, d: body.day, verdict: body.verdict, note: (body.note ?? "").slice(0, 300) || null,
    });
    if (error) return json({ error: error.message }, 400);
    return json({ result: data });
  }

  if (body.action === "unfreeze") {
    if (!UUID.test(body.user_id ?? "")) return json({ error: "user_id" }, 400);
    const { data, error } = await db.from("profiles")
      .update({ payouts_frozen_at: null, payouts_frozen_reason: `cleared: ${(body.note ?? "").slice(0, 200)}` })
      .eq("id", body.user_id).not("payouts_frozen_at", "is", null).select("id");
    if (error) return json({ error: error.message }, 400);
    return json({ result: data?.length ? "unfrozen" : "was not frozen" });
  }

  return json({ error: "unknown action" }, 400);
});

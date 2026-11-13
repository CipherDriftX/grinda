// The person closed a Whop checkout without paying. Calls the race (or the
// public purse) off at once, so its balances and Shields come back and the
// running limit frees up without waiting for settle's one-hour sweep. If the
// payment still lands later, whop-webhook refunds it.
import { admin, handler, HttpError, json, requireUser } from "../_shared/common.ts";

type Body = { race_id?: string; purse_id?: string };

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await requireUser(req);
  const body = (await req.json()) as Body;
  const db = admin();

  if (body.race_id) {
    const { data: race } = await db.from("races").select("user_id, status").eq("id", body.race_id).maybeSingle();
    if (!race || race.user_id !== user.id) throw new HttpError(404, "No such race.");
    if (race.status !== "pendingPayment") return json({ cancelled: false, status: race.status });
    const { data: ok, error } = await db.rpc("cancel_pending", { rid: body.race_id });
    if (error) throw error;
    return json({ cancelled: !!ok, status: ok ? "cancelled" : race.status });
  }
  if (body.purse_id) {
    const { data: purse } = await db.from("purses").select("host_id, listed").eq("id", body.purse_id).maybeSingle();
    if (!purse || purse.host_id !== user.id) throw new HttpError(404, "No such purse.");
    if (purse.listed) return json({ cancelled: false, status: "listed" });
    const { data: ok, error } = await db.rpc("cancel_host_purse", { pid: body.purse_id });
    if (error) throw error;
    return json({ cancelled: !!ok, status: ok ? "cancelled" : "pending" });
  }
  throw new HttpError(400, "Say which race or purse.");
}));

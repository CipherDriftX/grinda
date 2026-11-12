// Saves what the app collects at sign-up: the name shown on boards, the date
// of birth and where the person lives. The name can change any time. Date of
// birth and place are set once (see fillFromBody), so nobody can switch state
// or age one tap before paying; a move is a support request.
// Asking for place here, before any money, means nobody learns their state is
// blocked after they paid for Pro or an entry.
import { admin, handler, HttpError, json, requireUser } from "../_shared/common.ts";
import { type Declared, fillFromBody, isBlocked, readRules } from "../_shared/eligibility.ts";

type Body = Declared & { display_name?: string | null };

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await requireUser(req);
  const body = (await req.json()) as Body;
  const db = admin();

  const { data: profile } = await db.from("profiles").select("*").eq("id", user.id).maybeSingle();
  if (!profile) throw new HttpError(404, "No profile for this account.");

  const update: Record<string, unknown> = fillFromBody(profile, body);
  if (body.display_name !== undefined) {
    const name = (body.display_name ?? "").trim().replace(/\s+/g, " ").slice(0, 40);
    if (name.length < 1) throw new HttpError(400, "Pick a name.");
    update.display_name = name;
  }
  if (body.birth_date && !/^\d{4}-\d{2}-\d{2}$/.test(body.birth_date)) throw new HttpError(400, "Use a date like 1990-05-01.");

  let saved = profile;
  if (Object.keys(update).length) {
    const { data, error } = await db.from("profiles").update(update).eq("id", user.id).select("*").single();
    if (error) throw new HttpError(400, "That place or date doesn't look right.");
    saved = data;
  }

  let paidRaces = true;
  try {
    paidRaces = !isBlocked({ country: saved.country, region: saved.region }, readRules());
  } catch {
    paidRaces = false; // rules not set up yet in production
  }
  return json({
    display_name: saved.display_name,
    invite_code: saved.invite_code,
    country: saved.country,
    region: saved.region,
    has_birth_date: !!saved.birth_date,
    paid_races_available: paidRaces,
  });
}));

// Receives day totals + hourly buckets from the app. Steps only ever go up
// (late syncs add, never remove). Implausible data is flagged for a human,
// never auto-failed.
import { admin, handler, HttpError, json, localToday, requireUser, windowSteps } from "../_shared/common.ts";

type Body = {
  race_id: string;
  days: { date: string; steps: number; hourly: number[] }[];
  attestation?: string | null; // App Attest assertion (verified in a later version)
};

const MAX_PER_HOUR = 15_000; // ~250 steps/min sustained for a full hour
const MAX_PER_DAY = 60_000;

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await requireUser(req);
  const body = (await req.json()) as Body;
  const db = admin();

  const { data: race } = await db.from("races").select("id,user_id,status,timezone,purse_id").eq("id", body.race_id).maybeSingle();
  if (!race || race.user_id !== user.id) throw new HttpError(404, "Race not found.");
  if (race.status !== "active") return json({ ok: true });

  // Windowed purses (Dawn Patrol, Night Shift) only count steps inside the window.
  let win: { window_start: number | null; window_end: number | null } | null = null;
  if (race.purse_id) {
    const { data } = await db.from("purses").select("window_start,window_end").eq("id", race.purse_id).maybeSingle();
    win = data;
  }
  const today = localToday(race.timezone);

  const { data: existing } = await db.from("race_days").select("day,steps,goal,submitted_at").eq("race_id", race.id);
  const byDay = new Map((existing ?? []).map((d) => [d.day as string, d]));

  const now = Date.now();
  for (const d of body.days.slice(0, 40)) {
    const prev = byDay.get(d.date);
    if (!prev) continue; // not a race day
    if (prev.submitted_at && now - new Date(prev.submitted_at).getTime() < 60_000) continue; // rate limit
    const hourly = (d.hourly ?? []).slice(0, 24).map((h) => Math.max(0, Math.floor(h)));
    const counted = windowSteps(hourly, win?.window_start ?? null, win?.window_end ?? null) ?? d.steps;
    const steps = Math.max(0, Math.min(Math.floor(counted), 200_000));
    // A closed day that reaches its goal from this sync was saved by a late sync.
    const late = d.date < today && (prev.steps as number) < (prev.goal as number) && steps >= (prev.goal as number);
    const flagged = steps > MAX_PER_DAY || hourly.some((h) => h > MAX_PER_HOUR);
    await db.from("race_days").update({
      steps: Math.max(steps, prev.steps as number),
      ...(hourly.length ? { hourly } : {}),
      ...(flagged ? { flagged: true } : {}),
      ...(late ? { late: true } : {}),
      submitted_at: new Date().toISOString(),
    }).eq("race_id", race.id).eq("day", d.date);
  }

  return json({ ok: true });
}));

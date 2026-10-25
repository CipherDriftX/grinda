// A day was marked missed but the person walked it. The Health screenshot is
// stored privately for a person to check; the day counts as disputed (not
// missed) until they answer, and settle() waits for it.
import { decodeBase64 } from "jsr:@std/encoding@1/base64";
import { admin, handler, HttpError, json, requireUser } from "../_shared/common.ts";

type Body = { race_id: string; date: string; note: string; image_base64?: string | null };

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await requireUser(req);
  const body = (await req.json()) as Body;
  const db = admin();

  const { data: race } = await db.from("races").select("id,user_id,status").eq("id", body.race_id).maybeSingle();
  if (!race || race.user_id !== user.id) throw new HttpError(404, "Race not found.");
  if (!["active", "settling", "underReview"].includes(race.status)) throw new HttpError(409, "This race has already settled.");
  const { data: day } = await db.from("race_days").select("day").eq("race_id", race.id).eq("day", body.date).maybeSingle();
  if (!day) throw new HttpError(404, "That isn't a day in this race.");

  let path: string | null = null;
  if (body.image_base64) {
    const bytes = decodeBase64(body.image_base64);
    if (bytes.byteLength > 4_000_000) throw new HttpError(413, "That screenshot is too big.");
    path = `${user.id}/${race.id}/${body.date}.jpg`;
    const { error } = await db.storage.from("disputes").upload(path, bytes, { contentType: "image/jpeg", upsert: true });
    if (error) throw error;
  }

  await db.from("disputes").upsert({
    race_id: race.id, user_id: user.id, day: body.date, note: (body.note ?? "").slice(0, 500), image_path: path, status: "open",
  }, { onConflict: "race_id,day" });
  await db.from("race_days").update({ disputed: true }).eq("race_id", race.id).eq("day", body.date);

  return json({ ok: true });
}));

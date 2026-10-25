// Paid to Post: a link to a post about Steppie. A person counts real views 14
// days after posting and pays $1 per 1,000 to the Vault, up to $600 a post.
import { admin, handler, HttpError, json, requireUser } from "../_shared/common.ts";

const PLATFORMS: Record<string, RegExp> = {
  TikTok: /(^|\.)tiktok\.com$/,
  Instagram: /(^|\.)instagram\.com$/,
  YouTube: /(^|\.)(youtube\.com|youtu\.be)$/,
  X: /(^|\.)(x\.com|twitter\.com)$/,
};

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await requireUser(req);
  const { url: raw, platform } = (await req.json()) as { url: string; platform: string };
  const db = admin();

  let url: URL;
  try {
    url = new URL((raw ?? "").trim());
  } catch {
    throw new HttpError(400, "That link doesn't look right. Paste the full link to your post.");
  }
  const rule = PLATFORMS[platform];
  if (!rule || !/^https?:$/.test(url.protocol) || !rule.test(url.hostname.replace(/^www\./, ""))) {
    throw new HttpError(400, `That isn't a ${platform ?? "supported"} link.`);
  }

  const { count } = await db.from("post_submissions").select("id", { count: "exact", head: true })
    .eq("user_id", user.id).gte("created_at", new Date(Date.now() - 24 * 3600_000).toISOString());
  if ((count ?? 0) >= 5) throw new HttpError(429, "Five posts a day at most. Send the rest tomorrow.");

  url.search = url.hostname.includes("youtu") ? url.search : ""; // drop tracking params, keep YouTube ?v=
  const { error } = await db.from("post_submissions").insert({ user_id: user.id, url: url.toString(), platform });
  if (error?.code === "23505") throw new HttpError(409, "That post was already sent.");
  if (error) throw error;

  return json({ ok: true });
}));

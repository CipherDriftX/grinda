// Public, aggregate-only numbers for the app, the website, X threads and the Discord bot.
// GET /functions/v1/public-stats?currency=EUR
import { admin, handler, json } from "../_shared/common.ts";

Deno.serve(handler(async (req) => {
  const url = new URL(req.url);
  const cur = url.searchParams.get("currency") === "USD" ? "USD" : "EUR";
  const { data, error } = await admin().rpc("public_stats", { cur });
  if (error) throw error;
  return json(data, 200, {
    "Cache-Control": "public, max-age=300",
    "Access-Control-Allow-Origin": "*",
  });
}));

// Credits Steppie Shields bought in the App Store. The app sends the StoreKit
// transaction id; we look it up with Apple (App Store Server API), check it is
// ours, a Shield product, bought by this account (appAccountToken = user id),
// and not refunded. One grant per transaction id, counted in the same step.
import { admin, handler, HttpError, json, requireUser } from "../_shared/common.ts";
import { BUNDLE_ID, getTransaction } from "../_shared/appstore.ts";

const PRODUCTS: Record<string, number> = { "steppie.shield.1": 1, "steppie.shield.3": 3 };

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await requireUser(req);
  const { transaction_id } = (await req.json()) as { transaction_id: string };
  if (!transaction_id || !/^\d{1,20}$/.test(transaction_id)) throw new HttpError(400, "Bad transaction.");

  const t = await getTransaction(transaction_id);
  const qty = PRODUCTS[t.productId];
  if (t.bundleId !== BUNDLE_ID || !qty) throw new HttpError(400, "That isn't a Shield.");
  if (t.revocationDate) throw new HttpError(400, "That purchase was refunded.");
  if (t.appAccountToken && t.appAccountToken.toLowerCase() !== user.id.toLowerCase()) {
    throw new HttpError(403, "That purchase belongs to another account.");
  }

  const { data: shields, error } = await admin().rpc("grant_shields", {
    uid: user.id, tx: transaction_id, product: t.productId, qty,
  });
  if (error) throw error;
  return json({ shields });
}));

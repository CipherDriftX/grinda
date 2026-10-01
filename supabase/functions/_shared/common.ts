// Shared helpers for Steppie Edge Functions.
import { createClient, type SupabaseClient, type User } from "npm:@supabase/supabase-js@2";
import Stripe from "npm:stripe@17";

export const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  apiVersion: "2025-02-24.acacia",
  httpClient: Stripe.createFetchHttpClient(),
});

export const STRIPE_API_VERSION = "2025-02-24.acacia";

export function admin(): SupabaseClient {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
}

export async function requireUser(req: Request): Promise<User> {
  const auth = req.headers.get("Authorization") ?? "";
  const client = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
    auth: { persistSession: false },
  });
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) throw new HttpError(401, "Please sign in again.");
  return data.user;
}

export class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

export function json(body: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...headers },
  });
}

export function handler(fn: (req: Request) => Promise<Response>) {
  return async (req: Request): Promise<Response> => {
    try {
      return await fn(req);
    } catch (e) {
      if (e instanceof HttpError) return json({ error: e.message }, e.status);
      console.error(e);
      return json({ error: "Something went wrong on our side. Your money is safe; try again in a minute." }, 500);
    }
  };
}

// Race board: the server's copy is authoritative (never trust client goals or durations).
export type Template = {
  id: string;
  name: string;
  dailyGoal: number;
  days: number;
  graceDays: number;
  schedule: "consecutive" | "weekends";
  staked: boolean;
};

export const TEMPLATES: Record<string, Template> = {
  "sprint-5": { id: "sprint-5", name: "5-Day Sprint", dailyGoal: 8000, days: 5, graceDays: 0, schedule: "consecutive", staked: true },
  "10k-week": { id: "10k-week", name: "10K Week", dailyGoal: 10000, days: 7, graceDays: 1, schedule: "consecutive", staked: true },
  "weekend": { id: "weekend", name: "Weekend Warrior", dailyGoal: 12000, days: 8, graceDays: 1, schedule: "weekends", staked: true },
  "reset-30": { id: "reset-30", name: "30-Day Reset", dailyGoal: 8000, days: 30, graceDays: 2, schedule: "consecutive", staked: true },
};

/** Comebacks: five days at the missed race's goal (the goal is filled in per race). */
export const COMEBACK: Template = { id: "comeback", name: "Comeback", dailyGoal: 0, days: 5, graceDays: 0, schedule: "consecutive", staked: true };

/** Holds (manual capture) only when the race settles well inside Stripe's 7-day authorisation window. */
export function usesHold(t: Template): boolean {
  return t.staked && t.schedule === "consecutive" && t.days <= 5;
}

/** Calendar dates (YYYY-MM-DD) the race runs on, starting at `start`. */
export function scheduleDates(t: Template, start: string): string[] {
  const out: string[] = [];
  const d = new Date(`${start}T12:00:00Z`);
  while (out.length < t.days) {
    const dow = d.getUTCDay();
    if (t.schedule === "consecutive" || dow === 0 || dow === 6) out.push(d.toISOString().slice(0, 10));
    d.setUTCDate(d.getUTCDate() + 1);
  }
  return out;
}

/** UTC instant of local midnight at the end of `date` in `tz`, plus `graceHours`. */
export function settleInstant(date: string, tz: string, graceHours = 3): Date {
  // Find the UTC offset of `tz` around that date, then shift local midnight (next day 00:00) to UTC.
  const next = new Date(`${date}T00:00:00Z`);
  next.setUTCDate(next.getUTCDate() + 1);
  const fmt = new Intl.DateTimeFormat("en-US", {
    timeZone: tz, hour12: false, year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit",
  });
  const parts = Object.fromEntries(fmt.formatToParts(next).map((p) => [p.type, p.value]));
  const asLocal = Date.UTC(+parts.year, +parts.month - 1, +parts.day, +parts.hour % 24, +parts.minute);
  const offsetMs = asLocal - next.getTime();
  return new Date(next.getTime() - offsetMs + graceHours * 3600_000);
}

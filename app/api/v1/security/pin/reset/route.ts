import { requireAuth } from "@/lib/server/auth-context";
import { resetPin } from "@/lib/server/auth-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { enforceRateLimit } from "@/lib/server/rate-limit";
import { getClientIp } from "@/lib/server/request";
import { parseBody, resetPinSchema } from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const auth = await requireAuth(request);
    const ip = getClientIp(request);

    enforceRateLimit(`pin-reset:${auth.userId}:${ip}`, {
      limit: 5,
      windowMs: 60_000,
      message: "Muitas tentativas de redefinicao de PIN.",
    });

    const body = parseBody(resetPinSchema, await request.json());
    await resetPin(auth.userId, body);

    return ok({ success: true });
  } catch (error) {
    return handleRouteError(error);
  }
}

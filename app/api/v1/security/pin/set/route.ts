import { requireAuth } from "@/lib/server/auth-context";
import { setPin } from "@/lib/server/auth-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { enforceRateLimit } from "@/lib/server/rate-limit";
import { getClientIp } from "@/lib/server/request";
import { parseBody, setPinSchema } from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const auth = await requireAuth(request);
    const ip = getClientIp(request);

    enforceRateLimit(`pin-set:${auth.userId}:${ip}`, {
      limit: 5,
      windowMs: 60_000,
      message: "Muitas tentativas de configuracao de PIN.",
    });

    const body = parseBody(setPinSchema, await request.json());
    await setPin(auth.userId, body.pin);

    return ok({ success: true });
  } catch (error) {
    return handleRouteError(error);
  }
}

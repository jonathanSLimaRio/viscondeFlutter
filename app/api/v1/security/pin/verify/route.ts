import { requireAuth } from "@/lib/server/auth-context";
import { verifyPin } from "@/lib/server/auth-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { enforceRateLimit } from "@/lib/server/rate-limit";
import { getClientIp } from "@/lib/server/request";
import { parseBody, verifyPinSchema } from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const auth = await requireAuth(request);
    const ip = getClientIp(request);

    enforceRateLimit(`pin-verify:${auth.userId}:${ip}`, {
      limit: 10,
      windowMs: 60_000,
      message: "Muitas tentativas de PIN. Aguarde um minuto.",
    });

    const body = parseBody(verifyPinSchema, await request.json());
    const result = await verifyPin(auth.userId, body.pin);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

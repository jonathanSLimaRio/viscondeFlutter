import { loginWithEmail } from "@/lib/server/auth-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { enforceRateLimit } from "@/lib/server/rate-limit";
import { getClientIp } from "@/lib/server/request";
import { loginSchema, parseBody } from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const ip = getClientIp(request);
    enforceRateLimit(`login:${ip}`, {
      limit: 8,
      windowMs: 60_000,
      message: "Muitas tentativas de login. Aguarde um minuto.",
    });

    const body = parseBody(loginSchema, await request.json());
    const result = await loginWithEmail(body, request);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

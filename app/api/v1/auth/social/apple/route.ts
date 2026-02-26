import { loginWithApple } from "@/lib/server/auth-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { enforceRateLimit } from "@/lib/server/rate-limit";
import { getClientIp } from "@/lib/server/request";
import { parseBody, socialLoginSchema } from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const ip = getClientIp(request);
    enforceRateLimit(`apple:${ip}`, {
      limit: 8,
      windowMs: 60_000,
      message: "Muitas tentativas de login social. Aguarde um minuto.",
    });

    const body = parseBody(socialLoginSchema, await request.json());
    const result = await loginWithApple(body, request);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

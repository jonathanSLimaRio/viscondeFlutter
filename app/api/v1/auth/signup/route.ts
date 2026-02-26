import { parseBody, signUpSchema } from "@/lib/server/schemas";
import { signUpWithEmail } from "@/lib/server/auth-service";
import { enforceRateLimit } from "@/lib/server/rate-limit";
import { getClientIp } from "@/lib/server/request";
import { handleRouteError, ok } from "@/lib/server/http";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const ip = getClientIp(request);
    enforceRateLimit(`signup:${ip}`, {
      limit: 5,
      windowMs: 60_000,
      message: "Muitas tentativas de cadastro. Aguarde um minuto.",
    });

    const body = parseBody(signUpSchema, await request.json());
    const result = await signUpWithEmail(body, request);

    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

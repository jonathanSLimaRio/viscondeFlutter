import { requestPasswordReset } from "@/lib/server/auth-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { enforceRateLimit } from "@/lib/server/rate-limit";
import { getClientIp } from "@/lib/server/request";
import { forgotPasswordSchema, parseBody } from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const ip = getClientIp(request);
    enforceRateLimit(`forgot:${ip}`, {
      limit: 5,
      windowMs: 60_000,
      message: "Muitas solicitacoes de redefinicao. Aguarde um minuto.",
    });

    const body = parseBody(forgotPasswordSchema, await request.json());
    await requestPasswordReset(body.email, request);

    return ok({
      success: true,
      message: "Se o e-mail existir, enviaremos instrucoes de redefinicao.",
    });
  } catch (error) {
    return handleRouteError(error);
  }
}

import { handleRouteError, ok } from "@/lib/server/http";
import { enforceRateLimit } from "@/lib/server/rate-limit";
import { joinRemoteRoomByCode } from "@/lib/server/remote-story-service";
import { getClientIp } from "@/lib/server/request";
import { joinRemoteRoomSchema, parseBody } from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const body = parseBody(joinRemoteRoomSchema, await request.json());
    const ip = getClientIp(request);

    enforceRateLimit(`remote-join:${body.code.toUpperCase()}:${ip}`, {
      limit: 10,
      windowMs: 60_000,
      message: "Muitas tentativas de entrada na sala. Aguarde um minuto.",
    });

    const result = await joinRemoteRoomByCode({
      code: body.code,
      displayName: body.displayName,
      request,
    });

    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

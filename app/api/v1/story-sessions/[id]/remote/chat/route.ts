import { handleRouteError, ok } from "@/lib/server/http";
import { enforceRateLimit } from "@/lib/server/rate-limit";
import { requireUserOrParticipantAuth } from "@/lib/server/remote-auth";
import { createStoryInteraction } from "@/lib/server/remote-story-service";
import { getClientIp } from "@/lib/server/request";
import { createRemoteChatSchema, parseBody } from "@/lib/server/schemas";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, context: Params) {
  try {
    const auth = await requireUserOrParticipantAuth(request);
    const { id } = await context.params;
    const ip = getClientIp(request);

    enforceRateLimit(`remote-chat:${id}:${ip}`, {
      limit: 50,
      windowMs: 60_000,
      message: "Muitas mensagens em pouco tempo.",
    });

    const body = parseBody(createRemoteChatSchema, await request.json());
    const result = await createStoryInteraction(auth, id, {
      type: "CHAT",
      messageText: body.messageText,
    });

    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

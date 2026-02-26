import { handleRouteError, ok } from "@/lib/server/http";
import { enforceRateLimit } from "@/lib/server/rate-limit";
import { requireUserOrParticipantAuth } from "@/lib/server/remote-auth";
import { createStoryInteraction } from "@/lib/server/remote-story-service";
import { getClientIp } from "@/lib/server/request";
import { createRemoteReactionSchema, parseBody } from "@/lib/server/schemas";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, context: Params) {
  try {
    const auth = await requireUserOrParticipantAuth(request);
    const { id } = await context.params;
    const ip = getClientIp(request);

    enforceRateLimit(`remote-reaction:${id}:${ip}`, {
      limit: 80,
      windowMs: 60_000,
      message: "Muitas reacoes em pouco tempo.",
    });

    const body = parseBody(createRemoteReactionSchema, await request.json());
    const result = await createStoryInteraction(auth, id, {
      type: "REACTION",
      emoji: body.emoji,
    });

    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

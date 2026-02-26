import { handleRouteError, ok } from "@/lib/server/http";
import { enforceRateLimit } from "@/lib/server/rate-limit";
import { requireParticipantAuth } from "@/lib/server/remote-auth";
import { createRemoteStepByParticipant } from "@/lib/server/remote-story-service";
import { getClientIp } from "@/lib/server/request";
import { createRemoteStepSchema, parseBody } from "@/lib/server/schemas";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, context: Params) {
  try {
    const participant = await requireParticipantAuth(request);
    const { id } = await context.params;

    const ip = getClientIp(request);
    enforceRateLimit(`remote-step:${participant.participantId}:${ip}`, {
      limit: 40,
      windowMs: 60_000,
      message: "Muitas etapas remotas em pouco tempo.",
    });

    const body = parseBody(createRemoteStepSchema, await request.json());
    const result = await createRemoteStepByParticipant(participant, id, body);

    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

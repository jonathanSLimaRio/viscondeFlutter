import { requireParticipantAuth } from "@/lib/server/remote-auth";
import { handleRouteError, ok } from "@/lib/server/http";
import { z } from "zod";
import { parseBody } from "@/lib/server/schemas";
import { createCoopVoteByParticipant } from "@/lib/server/remote-story-service";

export const runtime = "nodejs";

const coopVoteSchema = z.object({
  stepIndex: z.number().int().min(0),
  optionId: z.string().min(1),
  optionLabel: z.string().min(1),
});

type Params = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, context: Params) {
  try {
    const auth = await requireParticipantAuth(request);
    const { id } = await context.params;
    const body = parseBody(coopVoteSchema, await request.json());

    const result = await createCoopVoteByParticipant(auth, id, body);

    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

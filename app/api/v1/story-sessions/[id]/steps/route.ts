import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { createStoryStepSchema, parseBody } from "@/lib/server/schemas";
import { createStoryStep } from "@/lib/server/story-service";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { id } = await context.params;
    const body = parseBody(createStoryStepSchema, await request.json());
    const result = await createStoryStep(auth.userId, id, body);

    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

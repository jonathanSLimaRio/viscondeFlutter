import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { parseBody, updateStoryModeSchema } from "@/lib/server/schemas";
import { updateStoryMode } from "@/lib/server/story-service";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function PATCH(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { id } = await context.params;
    const body = parseBody(updateStoryModeSchema, await request.json());
    const result = await updateStoryMode(auth.userId, id, body.mode);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

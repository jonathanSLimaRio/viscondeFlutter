import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { getStorySession, updateStorySessionSetup } from "@/lib/server/story-service";
import { parseBody, updateStorySessionSetupSchema } from "@/lib/server/schemas";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function GET(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { id } = await context.params;
    const result = await getStorySession(auth.userId, id);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

export async function PATCH(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { id } = await context.params;
    const body = parseBody(updateStorySessionSetupSchema, await request.json());
    const result = await updateStorySessionSetup(auth.userId, id, body);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

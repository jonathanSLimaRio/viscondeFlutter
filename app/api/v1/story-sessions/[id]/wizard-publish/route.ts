import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { parseBody, wizardPublishStorySessionSchema } from "@/lib/server/schemas";
import { wizardPublishStorySession } from "@/lib/server/story-service";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { id } = await context.params;
    const body = parseBody(wizardPublishStorySessionSchema, await request.json());
    const result = await wizardPublishStorySession(auth.userId, id, body);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

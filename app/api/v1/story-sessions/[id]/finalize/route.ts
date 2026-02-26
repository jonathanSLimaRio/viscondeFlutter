import { requireAuth } from "@/lib/server/auth-context";
import { finalizeStorySession } from "@/lib/server/story-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { finalizeStorySessionSchema, parseBody } from "@/lib/server/schemas";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { id } = await context.params;
    const body = parseBody(finalizeStorySessionSchema, await request.json());
    const result = await finalizeStorySession(auth.userId, id, body);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

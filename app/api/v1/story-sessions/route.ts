import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { createStorySession } from "@/lib/server/story-service";
import { createStorySessionSchema, parseBody } from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const auth = await requireAuth(request);
    const body = parseBody(createStorySessionSchema, await request.json());
    const result = await createStorySession(auth.userId, body);

    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

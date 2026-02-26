import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { listStoriesQuerySchema } from "@/lib/server/schemas";
import { listStories } from "@/lib/server/story-service";

export const runtime = "nodejs";

export async function GET(request: Request) {
  try {
    const auth = await requireAuth(request);
    const url = new URL(request.url);

    const filters = listStoriesQuerySchema.parse({
      childProfileId: url.searchParams.get("childProfileId") ?? undefined,
      status: url.searchParams.get("status") ?? undefined,
    });

    const result = await listStories(auth.userId, filters);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

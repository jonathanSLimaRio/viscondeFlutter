import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { getStoryById } from "@/lib/server/story-service";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function GET(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { id } = await context.params;
    const result = await getStoryById(auth.userId, id);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

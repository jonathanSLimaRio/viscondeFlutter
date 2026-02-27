import { requireAuth } from "@/lib/server/auth-context";
import { getChildGamificationProgress } from "@/lib/server/gamification-service";
import { handleRouteError, ok } from "@/lib/server/http";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ childId: string }>;
};

export async function GET(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { childId } = await context.params;

    const result = await getChildGamificationProgress(auth.userId, childId);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

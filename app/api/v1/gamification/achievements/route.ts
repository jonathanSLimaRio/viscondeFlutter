import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { listUserAchievements } from "@/lib/server/gamification-service";

export const runtime = "nodejs";

export async function GET(request: Request) {
  try {
    const auth = await requireAuth(request);
    const result = await listUserAchievements(auth.userId);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

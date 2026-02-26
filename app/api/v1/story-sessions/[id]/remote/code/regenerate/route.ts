import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { requireParentalUnlock } from "@/lib/server/parental-gate";
import { regenerateRemoteRoomCode } from "@/lib/server/remote-story-service";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    await requireParentalUnlock(request, auth.userId);
    const { id } = await context.params;

    const result = await regenerateRemoteRoomCode(auth.userId, id);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

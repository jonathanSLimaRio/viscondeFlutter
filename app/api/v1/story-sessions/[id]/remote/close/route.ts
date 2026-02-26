import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { closeRemoteRoom } from "@/lib/server/remote-story-service";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { id } = await context.params;

    const result = await closeRemoteRoom(auth.userId, id);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

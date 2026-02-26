import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { requireParentalUnlock } from "@/lib/server/parental-gate";
import { openRemoteRoom } from "@/lib/server/remote-story-service";
import { openRemoteRoomSchema, parseBody } from "@/lib/server/schemas";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    await requireParentalUnlock(request, auth.userId);
    const { id } = await context.params;

    let rawBody: unknown = {};
    try {
      rawBody = await request.json();
    } catch {
      rawBody = {};
    }

    const body = parseBody(openRemoteRoomSchema, rawBody);
    const result = await openRemoteRoom(auth.userId, id, {
      callMode: body.callMode,
    });

    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

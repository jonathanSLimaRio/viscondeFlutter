import { requireAdminAuth } from "@/lib/server/admin-auth-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { updateModerationTerm } from "@/lib/server/moderation-admin-service";
import { parseBody, updateModerationTermSchema } from "@/lib/server/schemas";

export const runtime = "nodejs";

type Params = { params: Promise<{ id: string }> };

export async function PATCH(request: Request, context: Params) {
  try {
    const auth = await requireAdminAuth(request);
    const { id } = await context.params;
    const body = parseBody(updateModerationTermSchema, await request.json());
    const result = await updateModerationTerm(auth.userId, id, body);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

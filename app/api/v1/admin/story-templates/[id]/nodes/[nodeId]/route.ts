import { requireAdminAuth } from "@/lib/server/admin-auth-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { parseBody, updateAdminStoryTemplateNodeSchema } from "@/lib/server/schemas";
import { updateAdminStoryTemplateNode } from "@/lib/server/story-template-admin-service";

export const runtime = "nodejs";

type Params = { params: Promise<{ id: string; nodeId: string }> };

export async function PATCH(request: Request, context: Params) {
  try {
    const auth = await requireAdminAuth(request);
    const { id, nodeId } = await context.params;
    const body = parseBody(updateAdminStoryTemplateNodeSchema, await request.json());
    const result = await updateAdminStoryTemplateNode(auth.userId, id, nodeId, body);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

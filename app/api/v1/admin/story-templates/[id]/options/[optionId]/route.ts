import { requireAdminAuth } from "@/lib/server/admin-auth-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { parseBody, updateAdminStoryTemplateOptionSchema } from "@/lib/server/schemas";
import { updateAdminStoryTemplateOption } from "@/lib/server/story-template-admin-service";

export const runtime = "nodejs";

type Params = { params: Promise<{ id: string; optionId: string }> };

export async function PATCH(request: Request, context: Params) {
  try {
    const auth = await requireAdminAuth(request);
    const { id, optionId } = await context.params;
    const body = parseBody(updateAdminStoryTemplateOptionSchema, await request.json());
    const result = await updateAdminStoryTemplateOption(auth.userId, id, optionId, body);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

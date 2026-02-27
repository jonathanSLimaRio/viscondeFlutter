import { requireAdminAuth } from "@/lib/server/admin-auth-service";
import { updateAdminVirtueTemplate } from "@/lib/server/content-admin-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { parseBody, updateAdminVirtueTemplateSchema } from "@/lib/server/schemas";

export const runtime = "nodejs";

type Params = { params: Promise<{ id: string }> };

export async function PATCH(request: Request, context: Params) {
  try {
    const auth = await requireAdminAuth(request);
    const { id } = await context.params;
    const body = parseBody(updateAdminVirtueTemplateSchema, await request.json());
    const result = await updateAdminVirtueTemplate(auth.userId, id, body);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

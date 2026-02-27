import { requireAdminAuth } from "@/lib/server/admin-auth-service";
import { updateAdminVirtue } from "@/lib/server/content-admin-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { parseBody, updateAdminVirtueSchema } from "@/lib/server/schemas";

export const runtime = "nodejs";

type Params = { params: Promise<{ id: string }> };

export async function PATCH(request: Request, context: Params) {
  try {
    const auth = await requireAdminAuth(request);
    const { id } = await context.params;
    const body = parseBody(updateAdminVirtueSchema, await request.json());
    const result = await updateAdminVirtue(auth.userId, id, body);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

import { requireAdminAuth } from "@/lib/server/admin-auth-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { parseBody, updateAdminThemeSchema } from "@/lib/server/schemas";
import { updateAdminTheme } from "@/lib/server/content-admin-service";

export const runtime = "nodejs";

type Params = { params: Promise<{ id: string }> };

export async function PATCH(request: Request, context: Params) {
  try {
    const auth = await requireAdminAuth(request);
    const { id } = await context.params;
    const body = parseBody(updateAdminThemeSchema, await request.json());
    const result = await updateAdminTheme(auth.userId, id, body);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

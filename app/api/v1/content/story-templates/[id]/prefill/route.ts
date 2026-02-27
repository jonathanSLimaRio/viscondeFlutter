import { requireAuth } from "@/lib/server/auth-context";
import { getPublicStoryTemplatePrefill } from "@/lib/server/content-admin-service";
import { handleRouteError, ok } from "@/lib/server/http";

export const runtime = "nodejs";

type Params = { params: Promise<{ id: string }> };

export async function GET(request: Request, context: Params) {
  try {
    await requireAuth(request);
    const { id } = await context.params;
    const result = await getPublicStoryTemplatePrefill(id);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

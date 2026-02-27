import { requireAdminAuth } from "@/lib/server/admin-auth-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { publishAdminStoryTemplate } from "@/lib/server/story-template-admin-service";

export const runtime = "nodejs";

type Params = { params: Promise<{ id: string }> };

export async function POST(request: Request, context: Params) {
  try {
    const auth = await requireAdminAuth(request);
    const { id } = await context.params;
    const result = await publishAdminStoryTemplate(auth.userId, id);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

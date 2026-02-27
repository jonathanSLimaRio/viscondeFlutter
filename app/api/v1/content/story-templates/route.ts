import { requireAuth } from "@/lib/server/auth-context";
import { listPublicStoryTemplates } from "@/lib/server/content-admin-service";
import { handleRouteError, ok } from "@/lib/server/http";

export const runtime = "nodejs";

export async function GET(request: Request) {
  try {
    await requireAuth(request);
    const result = await listPublicStoryTemplates();
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

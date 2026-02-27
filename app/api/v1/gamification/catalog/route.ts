import { requireAuth } from "@/lib/server/auth-context";
import { listCatalogForChild } from "@/lib/server/gamification-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { listGamificationCatalogQuerySchema } from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function GET(request: Request) {
  try {
    const auth = await requireAuth(request);
    const url = new URL(request.url);

    const query = listGamificationCatalogQuerySchema.parse({
      childProfileId: url.searchParams.get("childProfileId") ?? undefined,
      type: url.searchParams.get("type") ?? undefined,
    });

    const result = await listCatalogForChild(auth.userId, query);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

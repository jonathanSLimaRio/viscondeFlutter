import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { virtueSuggestQuerySchema } from "@/lib/server/schemas";
import { suggestVirtueForChildProfile } from "@/lib/server/virtue-service";

export const runtime = "nodejs";

export async function GET(request: Request) {
  try {
    const auth = await requireAuth(request);
    const url = new URL(request.url);

    const query = virtueSuggestQuerySchema.parse({
      childProfileId: url.searchParams.get("childProfileId") ?? undefined,
    });

    const result = await suggestVirtueForChildProfile(auth.userId, query.childProfileId);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

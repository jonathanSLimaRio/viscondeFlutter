import { requireAuth } from "@/lib/server/auth-context";
import { unlockCatalogItem } from "@/lib/server/gamification-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { requireParentalUnlock } from "@/lib/server/parental-gate";
import { parseBody, unlockCatalogItemSchema } from "@/lib/server/schemas";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ childId: string }>;
};

export async function POST(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    await requireParentalUnlock(request, auth.userId);
    const { childId } = await context.params;
    const body = parseBody(unlockCatalogItemSchema, await request.json());

    const result = await unlockCatalogItem(auth.userId, {
      childProfileId: childId,
      itemId: body.itemId,
    });

    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

import { requireAuth } from "@/lib/server/auth-context";
import { equipCatalogItem } from "@/lib/server/gamification-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { equipCatalogItemSchema, parseBody } from "@/lib/server/schemas";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ childId: string }>;
};

export async function POST(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { childId } = await context.params;
    const body = parseBody(equipCatalogItemSchema, await request.json());

    const result = await equipCatalogItem(auth.userId, {
      childProfileId: childId,
      itemId: body.itemId,
      equipped: body.equipped,
    });

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

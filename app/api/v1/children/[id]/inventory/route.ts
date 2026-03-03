import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { getChildInventory } from "@/lib/server/inventory-service";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function GET(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { id } = await context.params;
    const inventory = await getChildInventory(auth.userId, id);
    return ok(inventory);
  } catch (error) {
    return handleRouteError(error);
  }
}

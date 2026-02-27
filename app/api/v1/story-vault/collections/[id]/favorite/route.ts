import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { setStoryVaultCollectionFavorite } from "@/lib/server/story-vault-service";
import { parseBody, setStoryCollectionFavoriteSchema } from "@/lib/server/schemas";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function PATCH(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { id } = await context.params;
    const body = parseBody(setStoryCollectionFavoriteSchema, await request.json());
    const result = await setStoryVaultCollectionFavorite(auth.userId, id, body.isFavorite);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

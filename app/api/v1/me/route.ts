import { requireAuth } from "@/lib/server/auth-context";
import { getMe, updateMe } from "@/lib/server/profile-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { parseBody, updateMeSchema } from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function GET(request: Request) {
  try {
    const auth = await requireAuth(request);
    const result = await getMe(auth.userId);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

export async function PATCH(request: Request) {
  try {
    const auth = await requireAuth(request);
    const body = parseBody(updateMeSchema, await request.json());
    const result = await updateMe(auth.userId, body);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

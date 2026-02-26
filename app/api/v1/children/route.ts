import { requireAuth } from "@/lib/server/auth-context";
import { createChild, listChildren } from "@/lib/server/profile-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { createChildSchema, parseBody } from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function GET(request: Request) {
  try {
    const auth = await requireAuth(request);
    const result = await listChildren(auth.userId);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

export async function POST(request: Request) {
  try {
    const auth = await requireAuth(request);
    const body = parseBody(createChildSchema, await request.json());
    const result = await createChild(auth.userId, body);

    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

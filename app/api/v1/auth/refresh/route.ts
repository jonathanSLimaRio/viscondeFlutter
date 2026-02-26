import { refreshAuthSession } from "@/lib/server/auth-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { parseBody, refreshSchema } from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const body = parseBody(refreshSchema, await request.json());
    const result = await refreshAuthSession(body.refreshToken, request);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

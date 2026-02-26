import {
  logoutFromAccessContext,
  logoutFromRefreshToken,
} from "@/lib/server/auth-service";
import { requireAuth } from "@/lib/server/auth-context";
import { ApiError } from "@/lib/server/errors";
import { handleRouteError, ok } from "@/lib/server/http";
import { logoutSchema, parseBody } from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const body = parseBody(logoutSchema, await request.json());

    if (body.refreshToken) {
      await logoutFromRefreshToken(body.refreshToken);
      return ok({ success: true });
    }

    const auth = await requireAuth(request);
    await logoutFromAccessContext(auth);

    return ok({ success: true });
  } catch (error) {
    if (error instanceof ApiError) {
      return handleRouteError(error);
    }

    return handleRouteError(error);
  }
}

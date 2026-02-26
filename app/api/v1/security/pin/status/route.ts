import { requireAuth } from "@/lib/server/auth-context";
import { getPinStatus } from "@/lib/server/auth-service";
import { handleRouteError, ok } from "@/lib/server/http";

export const runtime = "nodejs";

export async function GET(request: Request) {
  try {
    const auth = await requireAuth(request);
    const result = await getPinStatus(auth.userId);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

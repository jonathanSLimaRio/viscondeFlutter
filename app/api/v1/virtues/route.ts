import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { listActiveVirtues } from "@/lib/server/virtue-service";

export const runtime = "nodejs";

export async function GET(request: Request) {
  try {
    await requireAuth(request);
    const result = await listActiveVirtues();

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

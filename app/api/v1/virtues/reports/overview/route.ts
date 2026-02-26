import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { requireParentalUnlock } from "@/lib/server/parental-gate";
import { getVirtueReportsOverview } from "@/lib/server/virtue-report-service";

export const runtime = "nodejs";

export async function GET(request: Request) {
  try {
    const auth = await requireAuth(request);
    await requireParentalUnlock(request, auth.userId);

    const result = await getVirtueReportsOverview(auth.userId);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

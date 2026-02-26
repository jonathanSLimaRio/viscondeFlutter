import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { requireParentalUnlock } from "@/lib/server/parental-gate";
import { getVirtueReportByChild } from "@/lib/server/virtue-report-service";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ childId: string }>;
};

export async function GET(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    await requireParentalUnlock(request, auth.userId);
    const { childId } = await context.params;

    const result = await getVirtueReportByChild(auth.userId, childId);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

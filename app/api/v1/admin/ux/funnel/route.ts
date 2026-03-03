import { requireAdminAuth } from "@/lib/server/admin-auth-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { uxFunnelQuerySchema } from "@/lib/server/schemas";
import { getUxFunnelOverview } from "@/lib/server/ux-analytics-service";

export const runtime = "nodejs";

export async function GET(request: Request) {
  try {
    await requireAdminAuth(request);

    const url = new URL(request.url);
    const query = uxFunnelQuerySchema.parse({
      dateFrom: url.searchParams.get("dateFrom") ?? undefined,
      dateTo: url.searchParams.get("dateTo") ?? undefined,
      timezone: url.searchParams.get("timezone") ?? undefined,
    });

    const result = await getUxFunnelOverview(query);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

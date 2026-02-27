import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { listStoryVaultCollections } from "@/lib/server/story-vault-service";
import { listStoryVaultCollectionsQuerySchema } from "@/lib/server/schemas";

export const runtime = "nodejs";

function parseDateOnly(value?: string) {
  if (!value) {
    return undefined;
  }

  const [yearText, monthText, dayText] = value.split("-");
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  if (!Number.isInteger(year) || !Number.isInteger(month) || !Number.isInteger(day)) {
    return undefined;
  }

  return new Date(Date.UTC(year, month - 1, day, 0, 0, 0, 0));
}

export async function GET(request: Request) {
  try {
    const auth = await requireAuth(request);
    const url = new URL(request.url);

    const query = listStoryVaultCollectionsQuerySchema.parse({
      childProfileId: url.searchParams.get("childProfileId") ?? undefined,
      dateFrom: url.searchParams.get("dateFrom") ?? undefined,
      dateTo: url.searchParams.get("dateTo") ?? undefined,
      theme: url.searchParams.get("theme") ?? undefined,
      virtueId: url.searchParams.get("virtueId") ?? undefined,
      favoriteOnly: url.searchParams.get("favoriteOnly") ?? undefined,
    });

    const result = await listStoryVaultCollections(auth.userId, {
      childProfileId: query.childProfileId,
      dateFrom: parseDateOnly(query.dateFrom),
      dateTo: parseDateOnly(query.dateTo),
      theme: query.theme,
      virtueId: query.virtueId,
      favoriteOnly: query.favoriteOnly,
    });

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

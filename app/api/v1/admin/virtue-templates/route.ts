import { requireAdminAuth } from "@/lib/server/admin-auth-service";
import {
  createAdminVirtueTemplate,
  listAdminVirtueTemplates,
} from "@/lib/server/content-admin-service";
import { handleRouteError, ok } from "@/lib/server/http";
import {
  createAdminVirtueTemplateSchema,
  listAdminVirtueTemplatesQuerySchema,
  parseBody,
} from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function GET(request: Request) {
  try {
    await requireAdminAuth(request);
    const url = new URL(request.url);
    const query = listAdminVirtueTemplatesQuerySchema.parse({
      virtueId: url.searchParams.get("virtueId") ?? undefined,
      ageBand: url.searchParams.get("ageBand") ?? undefined,
    });

    const result = await listAdminVirtueTemplates(query);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

export async function POST(request: Request) {
  try {
    const auth = await requireAdminAuth(request);
    const body = parseBody(createAdminVirtueTemplateSchema, await request.json());
    const result = await createAdminVirtueTemplate(auth.userId, body);
    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

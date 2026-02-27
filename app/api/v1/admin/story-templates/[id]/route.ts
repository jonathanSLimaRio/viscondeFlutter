import { requireAdminAuth } from "@/lib/server/admin-auth-service";
import {
  getAdminStoryTemplate,
  updateAdminStoryTemplate,
} from "@/lib/server/story-template-admin-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { parseBody, updateAdminStoryTemplateSchema } from "@/lib/server/schemas";

export const runtime = "nodejs";

type Params = { params: Promise<{ id: string }> };

export async function GET(request: Request, context: Params) {
  try {
    await requireAdminAuth(request);
    const { id } = await context.params;
    const result = await getAdminStoryTemplate(id);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

export async function PUT(request: Request, context: Params) {
  try {
    const auth = await requireAdminAuth(request);
    const { id } = await context.params;
    const body = parseBody(updateAdminStoryTemplateSchema, await request.json());
    const result = await updateAdminStoryTemplate(auth.userId, id, body);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

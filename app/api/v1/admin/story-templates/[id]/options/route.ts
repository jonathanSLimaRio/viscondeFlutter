import { requireAdminAuth } from "@/lib/server/admin-auth-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { createAdminStoryTemplateOptionSchema, parseBody } from "@/lib/server/schemas";
import { addAdminStoryTemplateOption } from "@/lib/server/story-template-admin-service";

export const runtime = "nodejs";

type Params = { params: Promise<{ id: string }> };

export async function POST(request: Request, context: Params) {
  try {
    const auth = await requireAdminAuth(request);
    const { id } = await context.params;
    const body = parseBody(createAdminStoryTemplateOptionSchema, await request.json());
    const result = await addAdminStoryTemplateOption(auth.userId, id, body);
    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

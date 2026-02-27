import { requireAdminAuth } from "@/lib/server/admin-auth-service";
import {
  createAdminStoryTemplate,
  listAdminStoryTemplates,
} from "@/lib/server/story-template-admin-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { createAdminStoryTemplateSchema, parseBody } from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function GET(request: Request) {
  try {
    await requireAdminAuth(request);
    const result = await listAdminStoryTemplates();
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

export async function POST(request: Request) {
  try {
    const auth = await requireAdminAuth(request);
    const body = parseBody(createAdminStoryTemplateSchema, await request.json());
    const result = await createAdminStoryTemplate(auth.userId, body);
    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

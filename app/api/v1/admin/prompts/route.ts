import { requireAdminAuth } from "@/lib/server/admin-auth-service";
import { createAdminPrompt, listAdminPrompts } from "@/lib/server/content-admin-service";
import { handleRouteError, ok } from "@/lib/server/http";
import {
  createAdminPromptSchema,
  listAdminPromptsQuerySchema,
  parseBody,
} from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function GET(request: Request) {
  try {
    await requireAdminAuth(request);
    const url = new URL(request.url);
    const query = listAdminPromptsQuerySchema.parse({
      kind: url.searchParams.get("kind") ?? undefined,
      themeId: url.searchParams.get("themeId") ?? undefined,
      virtueId: url.searchParams.get("virtueId") ?? undefined,
      ageBand: url.searchParams.get("ageBand") ?? undefined,
      mode: url.searchParams.get("mode") ?? undefined,
    });

    const result = await listAdminPrompts(query);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

export async function POST(request: Request) {
  try {
    const auth = await requireAdminAuth(request);
    const body = parseBody(createAdminPromptSchema, await request.json());
    const result = await createAdminPrompt(auth.userId, body);
    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

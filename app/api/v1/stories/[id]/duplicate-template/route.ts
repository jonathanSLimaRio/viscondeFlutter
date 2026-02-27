import { requireAuth } from "@/lib/server/auth-context";
import { duplicateStoryAsTemplate } from "@/lib/server/story-vault-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { duplicateStoryTemplateSchema, parseBody } from "@/lib/server/schemas";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { id } = await context.params;

    let rawBody: unknown = {};
    try {
      rawBody = await request.json();
    } catch {
      rawBody = {};
    }

    const body = parseBody(duplicateStoryTemplateSchema, rawBody);
    const result = await duplicateStoryAsTemplate(auth.userId, id, body);
    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

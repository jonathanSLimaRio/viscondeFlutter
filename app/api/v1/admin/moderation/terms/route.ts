import { requireAdminAuth } from "@/lib/server/admin-auth-service";
import {
  createModerationTerm,
  listModerationTerms,
} from "@/lib/server/moderation-admin-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { createModerationTermSchema, parseBody } from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function GET(request: Request) {
  try {
    await requireAdminAuth(request);
    const result = await listModerationTerms();
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

export async function POST(request: Request) {
  try {
    const auth = await requireAdminAuth(request);
    const body = parseBody(createModerationTermSchema, await request.json());
    const result = await createModerationTerm(auth.userId, body);
    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

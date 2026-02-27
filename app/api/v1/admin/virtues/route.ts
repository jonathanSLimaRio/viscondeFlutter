import { requireAdminAuth } from "@/lib/server/admin-auth-service";
import {
  createAdminVirtue,
  listAdminVirtues,
} from "@/lib/server/content-admin-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { createAdminVirtueSchema, parseBody } from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function GET(request: Request) {
  try {
    await requireAdminAuth(request);
    const result = await listAdminVirtues();
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

export async function POST(request: Request) {
  try {
    const auth = await requireAdminAuth(request);
    const body = parseBody(createAdminVirtueSchema, await request.json());
    const result = await createAdminVirtue(auth.userId, body);
    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

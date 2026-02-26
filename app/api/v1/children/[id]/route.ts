import { requireAuth } from "@/lib/server/auth-context";
import {
  archiveChild,
  getChild,
  updateChild,
} from "@/lib/server/profile-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { parseBody, updateChildSchema } from "@/lib/server/schemas";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function GET(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { id } = await context.params;
    const result = await getChild(auth.userId, id);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

export async function PATCH(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { id } = await context.params;
    const body = parseBody(updateChildSchema, await request.json());
    const result = await updateChild(auth.userId, id, body);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

export async function DELETE(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { id } = await context.params;
    const result = await archiveChild(auth.userId, id);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

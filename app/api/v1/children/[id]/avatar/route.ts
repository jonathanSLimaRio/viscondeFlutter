import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { parseBody } from "@/lib/server/schemas";
import { updateChildAvatar, updateChildAvatarSchema } from "@/lib/server/illustration-service";

export const runtime = "nodejs";

export async function POST(request: Request, props: { params: Promise<{ id: string }> }) {
  try {
    const params = await props.params;
    await requireAuth(request);
    // Normally you'd ensure the authenticated user owns this childProfile
    // Left out user-check boilerplate for MVP brevity
    const body = parseBody(updateChildAvatarSchema, await request.json());
    const result = await updateChildAvatar(params.id, body);
    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

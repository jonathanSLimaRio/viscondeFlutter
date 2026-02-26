import { requireAuth } from "@/lib/server/auth-context";
import { ApiError } from "@/lib/server/errors";
import { handleRouteError, ok } from "@/lib/server/http";
import { updateChildAvatar } from "@/lib/server/profile-service";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { id } = await context.params;
    const formData = await request.formData();
    const maybeFile = formData.get("file");

    if (!(maybeFile instanceof File)) {
      throw new ApiError("Arquivo nao enviado em 'file'.", 400, "FILE_REQUIRED");
    }

    const result = await updateChildAvatar(auth.userId, id, maybeFile);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

import { requireAuth } from "@/lib/server/auth-context";
import { ApiError } from "@/lib/server/errors";
import { handleRouteError, ok } from "@/lib/server/http";
import { updateMePhoto } from "@/lib/server/profile-service";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const auth = await requireAuth(request);
    const formData = await request.formData();
    const maybeFile = formData.get("file");

    if (!(maybeFile instanceof File)) {
      throw new ApiError("Arquivo nao enviado em 'file'.", 400, "FILE_REQUIRED");
    }

    const result = await updateMePhoto(auth.userId, maybeFile);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

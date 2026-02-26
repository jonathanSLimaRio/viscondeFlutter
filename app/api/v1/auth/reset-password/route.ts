import { resetPassword } from "@/lib/server/auth-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { parseBody, resetPasswordSchema } from "@/lib/server/schemas";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const body = parseBody(resetPasswordSchema, await request.json());
    await resetPassword(body);

    return ok({
      success: true,
      message: "Senha redefinida com sucesso.",
    });
  } catch (error) {
    return handleRouteError(error);
  }
}

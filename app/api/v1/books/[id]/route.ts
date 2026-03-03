import { requireAuth } from "@/lib/server/auth-context";
import { getBookProject } from "@/lib/server/book-service";
import { handleRouteError, ok } from "@/lib/server/http";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function GET(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { id } = await context.params;
    const project = await getBookProject(auth.userId, id);
    return ok(project);
  } catch (error) {
    return handleRouteError(error);
  }
}

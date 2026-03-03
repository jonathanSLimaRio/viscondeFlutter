import { requireAuth } from "@/lib/server/auth-context";
import { createMonthlyBookProject } from "@/lib/server/book-service";
import { handleRouteError, ok } from "@/lib/server/http";
import { z } from "zod";

export const runtime = "nodejs";

const createBookSchema = z.object({
  monthStr: z.string().regex(/^\d{4}-\d{2}$/, "Invalid month format. Expected YYYY-MM"),
});

type Params = {
  params: Promise<{ childId: string }>;
};

export async function POST(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const { childId } = await context.params;
    const body = await request.json();
    const { monthStr } = createBookSchema.parse(body);

    const project = await createMonthlyBookProject(auth.userId, childId, monthStr);
    return ok(project);
  } catch (error) {
    return handleRouteError(error);
  }
}

import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { parseBody } from "@/lib/server/schemas";
import { requestNarration, requestNarrationSchema, listNarrationJobs } from "@/lib/server/voice-service";

export const runtime = "nodejs";

export async function GET(request: Request, props: { params: Promise<{ id: string }> }) {
  try {
    const params = await props.params;
    await requireAuth(request);
    const result = await listNarrationJobs(params.id);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

export async function POST(request: Request, props: { params: Promise<{ id: string }> }) {
  try {
    const params = await props.params;
    await requireAuth(request);
    const body = parseBody(requestNarrationSchema, await request.json());
    const result = await requestNarration(params.id, body);
    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

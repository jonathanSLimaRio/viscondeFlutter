import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { parseBody } from "@/lib/server/schemas";
import { generateIllustrationSchema, requestStoryIllustration, getStoryIllustration } from "@/lib/server/illustration-service";

export const runtime = "nodejs";

export async function GET(request: Request, props: { params: Promise<{ id: string }> }) {
  try {
    const params = await props.params;
    await requireAuth(request);
    const url = new URL(request.url);
    const stepIndex = parseInt(url.searchParams.get("stepIndex") || "0", 10);

    if (stepIndex <= 0) {
      return ok(null);
    }

    const result = await getStoryIllustration(params.id, stepIndex);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

export async function POST(request: Request, props: { params: Promise<{ id: string }> }) {
  try {
    const params = await props.params;
    await requireAuth(request);
    const body = parseBody(generateIllustrationSchema, await request.json());
    const result = await requestStoryIllustration(params.id, body);
    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

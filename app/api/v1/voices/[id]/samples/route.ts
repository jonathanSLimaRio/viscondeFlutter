import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { requireParentalUnlock } from "@/lib/server/parental-gate";
import { parseBody } from "@/lib/server/schemas";
import { addVoiceSample, addVoiceSampleSchema } from "@/lib/server/voice-service";

export const runtime = "nodejs";

export async function POST(request: Request, props: { params: Promise<{ id: string }> }) {
  try {
    const params = await props.params;
    const auth = await requireAuth(request);
    await requireParentalUnlock(request, auth.userId);
    const body = parseBody(addVoiceSampleSchema, await request.json());
    const result = await addVoiceSample(auth.userId, params.id, body);
    return ok(result, 201);
  } catch (error) {
    return handleRouteError(error);
  }
}

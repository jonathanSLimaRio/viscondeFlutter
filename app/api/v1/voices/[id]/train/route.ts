import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { requireParentalUnlock } from "@/lib/server/parental-gate";
import { trainVoiceProfile } from "@/lib/server/voice-service";

export const runtime = "nodejs";

export async function POST(request: Request, props: { params: Promise<{ id: string }> }) {
  try {
    const params = await props.params;
    const auth = await requireAuth(request);
    await requireParentalUnlock(request, auth.userId);
    const result = await trainVoiceProfile(auth.userId, params.id);
    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

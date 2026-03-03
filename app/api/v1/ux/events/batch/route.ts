import { tryAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { parseBody, uxEventsBatchSchema } from "@/lib/server/schemas";
import { ingestUxEvents } from "@/lib/server/ux-analytics-service";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const auth = await tryAuth(request);
    const body = parseBody(uxEventsBatchSchema, await request.json());

    const result = await ingestUxEvents({
      auth,
      appSessionId: body.appSessionId,
      client: body.client,
      events: body.events,
    });

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

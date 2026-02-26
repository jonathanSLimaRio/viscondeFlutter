import { requireAuth } from "@/lib/server/auth-context";
import { handleRouteError, ok } from "@/lib/server/http";
import { enforceRateLimit } from "@/lib/server/rate-limit";
import { getClientIp } from "@/lib/server/request";
import { parseBody, storyIdeasSchema } from "@/lib/server/schemas";
import { requestStoryIdeas } from "@/lib/server/story-service";

export const runtime = "nodejs";

type Params = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, context: Params) {
  try {
    const auth = await requireAuth(request);
    const ip = getClientIp(request);
    const { id } = await context.params;

    enforceRateLimit(`story-ideas:${auth.userId}:${id}:${ip}`, {
      limit: 12,
      windowMs: 60_000,
      message: "Muitas solicitacoes de ideias. Aguarde um minuto.",
    });

    const body = parseBody(storyIdeasSchema, await request.json());
    const result = await requestStoryIdeas(auth.userId, id, body);

    return ok(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

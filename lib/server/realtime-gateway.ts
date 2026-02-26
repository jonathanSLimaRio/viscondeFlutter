import { ApiError } from "@/lib/server/errors";
import { env } from "@/lib/server/env";

const HEALTH_TIMEOUT_MS = 1_800;
const PUBLISH_TIMEOUT_MS = 1_800;

function requireRealtimeGatewayConfig() {
  if (!env.realtimeGatewayInternalHttpUrl || !env.realtimeGatewayInternalSecret) {
    throw new ApiError(
      "Gateway realtime indisponivel. Configure REALTIME_GATEWAY_INTERNAL_HTTP_URL e REALTIME_GATEWAY_INTERNAL_SECRET.",
      503,
      "REALTIME_UNAVAILABLE"
    );
  }

  if (!env.realtimeGatewayPublicWsUrl) {
    throw new ApiError(
      "Gateway realtime sem URL publica de websocket configurada.",
      503,
      "REALTIME_UNAVAILABLE"
    );
  }
}

async function doFetchWithTimeout(input: RequestInfo | URL, init: RequestInit, timeoutMs: number) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    return await fetch(input, {
      ...init,
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timer);
  }
}

export function getRealtimePublicWsUrl() {
  return env.realtimeGatewayPublicWsUrl;
}

export function buildJoinLink(joinCode: string) {
  const base = env.appBaseUrl ?? "https://visconde.app";
  const safeBase = base.endsWith("/") ? base.slice(0, -1) : base;
  return `${safeBase}/remote/join?code=${encodeURIComponent(joinCode)}`;
}

export function buildRtcConfig() {
  const iceServers: Array<{
    urls: string | string[];
    username?: string;
    credential?: string;
  }> = [];

  if (env.webrtcStunUrls.length > 0) {
    iceServers.push({
      urls: env.webrtcStunUrls,
    });
  }

  if (env.webrtcTurnUrl) {
    iceServers.push({
      urls: env.webrtcTurnUrl,
      username: env.webrtcTurnUsername,
      credential: env.webrtcTurnPassword,
    });
  }

  return {
    iceServers,
  };
}

export async function assertRealtimeGatewayAvailable() {
  requireRealtimeGatewayConfig();

  try {
    const response = await doFetchWithTimeout(
      `${env.realtimeGatewayInternalHttpUrl}/internal/health`,
      {
        method: "GET",
        headers: {
          "x-realtime-secret": env.realtimeGatewayInternalSecret ?? "",
        },
      },
      HEALTH_TIMEOUT_MS
    );

    if (!response.ok) {
      throw new Error(`status ${response.status}`);
    }
  } catch {
    throw new ApiError(
      "Gateway realtime indisponivel no momento. Tente novamente em instantes.",
      503,
      "REALTIME_UNAVAILABLE"
    );
  }
}

export async function publishRealtimeRoomEvent(input: {
  remoteRoomId: string;
  event: string;
  payload: unknown;
  throwOnFailure?: boolean;
}) {
  if (!env.realtimeGatewayInternalHttpUrl || !env.realtimeGatewayInternalSecret) {
    if (input.throwOnFailure) {
      throw new ApiError("Gateway realtime nao configurado.", 503, "REALTIME_UNAVAILABLE");
    }
    return;
  }

  try {
    const response = await doFetchWithTimeout(
      `${env.realtimeGatewayInternalHttpUrl}/internal/publish`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-realtime-secret": env.realtimeGatewayInternalSecret,
        },
        body: JSON.stringify({
          remoteRoomId: input.remoteRoomId,
          event: input.event,
          payload: input.payload,
        }),
      },
      PUBLISH_TIMEOUT_MS
    );

    if (!response.ok && input.throwOnFailure) {
      throw new ApiError("Falha ao publicar evento realtime.", 503, "REALTIME_UNAVAILABLE");
    }
  } catch {
    if (input.throwOnFailure) {
      throw new ApiError("Falha ao publicar evento realtime.", 503, "REALTIME_UNAVAILABLE");
    }
  }
}

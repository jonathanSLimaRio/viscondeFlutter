import { getBearerToken } from "@/lib/server/auth-context";
import { ApiError } from "@/lib/server/errors";
import { verifyAccessToken, verifyRemoteParticipantToken } from "@/lib/server/jwt";

export type UserAccessContext = {
  kind: "user";
  userId: string;
  sessionId: string;
};

export type ParticipantAccessContext = {
  kind: "participant";
  storyId: string;
  remoteRoomId: string;
  participantId: string;
  role: "HOST_PARENT" | "GUEST_CHILD";
};

export type UserOrParticipantAccessContext = UserAccessContext | ParticipantAccessContext;

export async function requireParticipantAuth(request: Request): Promise<ParticipantAccessContext> {
  const token = getBearerToken(request);

  if (!token) {
    throw new ApiError("Token de participante nao informado.", 401, "UNAUTHORIZED");
  }

  try {
    const participant = await verifyRemoteParticipantToken(token);
    return {
      kind: "participant",
      ...participant,
    };
  } catch {
    throw new ApiError("Token de participante invalido ou expirado.", 401, "UNAUTHORIZED");
  }
}

export async function requireUserOrParticipantAuth(
  request: Request
): Promise<UserOrParticipantAccessContext> {
  const token = getBearerToken(request);

  if (!token) {
    throw new ApiError("Token de acesso nao informado.", 401, "UNAUTHORIZED");
  }

  try {
    const access = await verifyAccessToken(token);
    return {
      kind: "user",
      userId: access.userId,
      sessionId: access.sessionId,
    };
  } catch {
    // Fallback para token de participante
  }

  try {
    const participant = await verifyRemoteParticipantToken(token);
    return {
      kind: "participant",
      ...participant,
    };
  } catch {
    throw new ApiError("Token invalido ou expirado.", 401, "UNAUTHORIZED");
  }
}

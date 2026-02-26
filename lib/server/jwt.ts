import { jwtVerify, SignJWT } from "jose";

import { env } from "@/lib/server/env";

type TokenType = "access" | "refresh";
type RemoteParticipantRole = "HOST_PARENT" | "GUEST_CHILD";

type TokenPayload = {
  sub: string;
  sid: string;
  typ: TokenType;
};

const secret = new TextEncoder().encode(env.jwtSecret);

async function signToken(payload: TokenPayload, expiresIn: string) {
  return new SignJWT({ typ: payload.typ, sid: payload.sid })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(payload.sub)
    .setIssuedAt()
    .setExpirationTime(expiresIn)
    .sign(secret);
}

export async function signAccessToken(input: { userId: string; sessionId: string }) {
  return signToken(
    { sub: input.userId, sid: input.sessionId, typ: "access" },
    `${env.accessTokenTtlMinutes}m`
  );
}

export async function signRefreshToken(input: {
  userId: string;
  sessionId: string;
}) {
  return signToken(
    { sub: input.userId, sid: input.sessionId, typ: "refresh" },
    `${env.refreshTokenTtlDays}d`
  );
}

async function verifyToken(token: string, expectedType: TokenType) {
  const { payload } = await jwtVerify(token, secret, {
    algorithms: ["HS256"],
  });

  const type = payload.typ;
  const subject = payload.sub;
  const sessionId = payload.sid;

  if (type !== expectedType || typeof subject !== "string") {
    throw new Error("Token invalido.");
  }

  if (typeof sessionId !== "string") {
    throw new Error("Token sem sessao valida.");
  }

  return {
    userId: subject,
    sessionId,
  };
}

export async function verifyAccessToken(token: string) {
  return verifyToken(token, "access");
}

export async function verifyRefreshToken(token: string) {
  return verifyToken(token, "refresh");
}

export async function signRemoteParticipantToken(input: {
  storyId: string;
  remoteRoomId: string;
  participantId: string;
  role: RemoteParticipantRole;
}) {
  return new SignJWT({
    typ: "remote_participant",
    rid: input.remoteRoomId,
    pid: input.participantId,
    role: input.role,
  })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(input.storyId)
    .setIssuedAt()
    .setExpirationTime(`${env.remoteParticipantTokenTtlMinutes}m`)
    .sign(secret);
}

export async function verifyRemoteParticipantToken(token: string) {
  const { payload } = await jwtVerify(token, secret, {
    algorithms: ["HS256"],
  });

  if (payload.typ !== "remote_participant") {
    throw new Error("Tipo de token remoto invalido.");
  }

  const storyId = payload.sub;
  const remoteRoomId = payload.rid;
  const participantId = payload.pid;
  const role = payload.role;

  if (
    typeof storyId !== "string" ||
    typeof remoteRoomId !== "string" ||
    typeof participantId !== "string" ||
    (role !== "HOST_PARENT" && role !== "GUEST_CHILD")
  ) {
    throw new Error("Token remoto invalido.");
  }

  return {
    storyId,
    remoteRoomId,
    participantId,
    role,
  } as const;
}

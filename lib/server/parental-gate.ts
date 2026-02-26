import { jwtVerify, SignJWT } from "jose";

import { env } from "@/lib/server/env";
import { ApiError } from "@/lib/server/errors";

const parentalSecret = new TextEncoder().encode(env.jwtSecret);
const parentalUnlockTtlMinutes = 10;
const parentalHeader = "x-parental-unlock-token";

type ParentalUnlockPayload = {
  typ: "parental_unlock";
};

export async function issueParentalUnlockToken(userId: string) {
  const parentalUnlockToken = await new SignJWT({
    typ: "parental_unlock",
  } satisfies ParentalUnlockPayload)
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(userId)
    .setIssuedAt()
    .setExpirationTime(`${parentalUnlockTtlMinutes}m`)
    .sign(parentalSecret);

  return {
    parentalUnlockToken,
    parentalUnlockExpiresAt: new Date(
      Date.now() + parentalUnlockTtlMinutes * 60 * 1000
    ),
    unlockTtlMinutes: parentalUnlockTtlMinutes,
  };
}

export async function verifyParentalUnlockToken(parentalUnlockToken: string) {
  try {
    const { payload } = await jwtVerify(parentalUnlockToken, parentalSecret, {
      algorithms: ["HS256"],
    });

    if (payload.typ !== "parental_unlock") {
      throw new ApiError("Token de desbloqueio invalido.", 401, "PARENTAL_UNLOCK_INVALID");
    }

    if (typeof payload.sub !== "string") {
      throw new ApiError("Token de desbloqueio sem usuario.", 401, "PARENTAL_UNLOCK_INVALID");
    }

    return {
      userId: payload.sub,
    };
  } catch {
    throw new ApiError(
      "Token de desbloqueio invalido ou expirado.",
      401,
      "PARENTAL_UNLOCK_INVALID"
    );
  }
}

export async function requireParentalUnlock(request: Request, userId: string) {
  const token = request.headers.get(parentalHeader);

  if (!token) {
    throw new ApiError(
      "Area protegida por PIN. Desbloqueie a area adulta para continuar.",
      401,
      "PARENTAL_UNLOCK_REQUIRED"
    );
  }

  const payload = await verifyParentalUnlockToken(token);
  if (payload.userId !== userId) {
    throw new ApiError(
      "Token de desbloqueio nao pertence ao usuario autenticado.",
      401,
      "PARENTAL_UNLOCK_INVALID"
    );
  }
}

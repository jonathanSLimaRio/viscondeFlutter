import { randomBytes, randomUUID } from "node:crypto";

import type { Account, User } from "@prisma/client";

import { prisma } from "@/lib/prisma";
import { env } from "@/lib/server/env";
import { sendPasswordResetEmail } from "@/lib/server/email";
import { ApiError } from "@/lib/server/errors";
import { hashLookupToken, hashSecret, verifySecret } from "@/lib/server/hash";
import {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
} from "@/lib/server/jwt";
import { issueParentalUnlockToken } from "@/lib/server/parental-gate";
import { getClientIp, getUserAgent } from "@/lib/server/request";
import { verifyAppleIdentityToken } from "@/lib/server/social/apple";
import { verifyGoogleIdToken } from "@/lib/server/social/google";
import { toUserDTO } from "@/lib/server/user";

type AuthUser = Pick<
  User,
  "id" | "name" | "email" | "timezone" | "imageUrl" | "createdAt" | "updatedAt"
>;

type SocialIdentity = {
  provider: "google" | "apple";
  providerAccountId: string;
  email: string | null;
  name: string | null;
  imageUrl: string | null;
};

function getRefreshExpiryDate() {
  return new Date(Date.now() + env.refreshTokenTtlDays * 24 * 60 * 60 * 1000);
}

function getPasswordResetExpiryDate() {
  return new Date(Date.now() + env.passwordResetTtlMinutes * 60 * 1000);
}

async function createAuditEvent(input: {
  userId?: string;
  action: string;
  meta?: Record<string, unknown>;
  ipAddress?: string;
}) {
  try {
    await prisma.auditEvent.create({
      data: {
        userId: input.userId,
        action: input.action,
        meta: input.meta ? (input.meta as never) : undefined,
        ipAddress: input.ipAddress,
      },
    });
  } catch {
    // Nao interromper fluxo por falha de auditoria no MVP.
  }
}

async function issueMobileTokens(userId: string, request: Request) {
  const sessionId = randomUUID();
  const refreshToken = await signRefreshToken({
    userId,
    sessionId,
  });
  const accessToken = await signAccessToken({
    userId,
    sessionId,
  });

  await prisma.mobileSession.create({
    data: {
      id: sessionId,
      userId,
      refreshTokenHash: await hashSecret(refreshToken),
      expiresAt: getRefreshExpiryDate(),
      userAgent: getUserAgent(request),
      ipAddress: getClientIp(request),
    },
  });

  return {
    accessToken,
    refreshToken,
  };
}

async function getSafeUserById(userId: string): Promise<AuthUser> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      name: true,
      email: true,
      timezone: true,
      imageUrl: true,
      createdAt: true,
      updatedAt: true,
    },
  });

  if (!user) {
    throw new ApiError("Usuario nao encontrado.", 404, "USER_NOT_FOUND");
  }

  return user;
}

async function markUserLogin(userId: string) {
  await prisma.user.update({
    where: { id: userId },
    data: {
      lastLoginAt: new Date(),
    },
  });
}

async function upsertSocialAccount(userId: string, identity: SocialIdentity) {
  await prisma.account.upsert({
    where: {
      provider_providerAccountId: {
        provider: identity.provider,
        providerAccountId: identity.providerAccountId,
      },
    },
    update: {
      type: "oauth",
    },
    create: {
      userId,
      type: "oauth",
      provider: identity.provider,
      providerAccountId: identity.providerAccountId,
    },
  });
}

export async function signUpWithEmail(
  input: {
    email: string;
    password: string;
    name?: string | null;
    timezone?: string;
  },
  request: Request
) {
  const existing = await prisma.user.findUnique({
    where: {
      email: input.email,
    },
  });

  if (existing) {
    throw new ApiError("E-mail ja cadastrado.", 409, "EMAIL_ALREADY_USED");
  }

  const user = await prisma.user.create({
    data: {
      email: input.email,
      name: input.name ?? null,
      timezone: input.timezone ?? "UTC",
      passwordHash: await hashSecret(input.password),
    },
  });

  await markUserLogin(user.id);

  const tokens = await issueMobileTokens(user.id, request);

  await createAuditEvent({
    userId: user.id,
    action: "AUTH_SIGNUP_EMAIL",
    ipAddress: getClientIp(request),
  });

  return {
    ...tokens,
    user: toUserDTO(await getSafeUserById(user.id)),
  };
}

export async function loginWithEmail(
  input: {
    email: string;
    password: string;
  },
  request: Request
) {
  const user = await prisma.user.findUnique({
    where: {
      email: input.email,
    },
  });

  if (!user || !user.passwordHash) {
    throw new ApiError("Credenciais invalidas.", 401, "INVALID_CREDENTIALS");
  }

  const passwordValid = await verifySecret(user.passwordHash, input.password);
  if (!passwordValid) {
    throw new ApiError("Credenciais invalidas.", 401, "INVALID_CREDENTIALS");
  }

  await markUserLogin(user.id);

  const tokens = await issueMobileTokens(user.id, request);

  await createAuditEvent({
    userId: user.id,
    action: "AUTH_LOGIN_EMAIL",
    ipAddress: getClientIp(request),
  });

  return {
    ...tokens,
    user: toUserDTO(await getSafeUserById(user.id)),
  };
}

async function findOrCreateUserFromSocial(
  identity: SocialIdentity,
  timezone?: string
): Promise<User> {
  const existingAccount = await prisma.account.findUnique({
    where: {
      provider_providerAccountId: {
        provider: identity.provider,
        providerAccountId: identity.providerAccountId,
      },
    },
    include: {
      user: true,
    },
  });

  if (existingAccount?.user) {
    return existingAccount.user;
  }

  if (identity.email) {
    const existingUser = await prisma.user.findUnique({
      where: {
        email: identity.email,
      },
    });

    if (existingUser) {
      await prisma.user.update({
        where: { id: existingUser.id },
        data: {
          name: existingUser.name ?? identity.name,
          imageUrl: existingUser.imageUrl ?? identity.imageUrl,
          image: existingUser.image ?? identity.imageUrl,
          timezone: existingUser.timezone || timezone || "UTC",
        },
      });

      await upsertSocialAccount(existingUser.id, identity);

      return existingUser;
    }
  }

  const created = await prisma.user.create({
    data: {
      email: identity.email,
      name: identity.name,
      imageUrl: identity.imageUrl,
      image: identity.imageUrl,
      timezone: timezone ?? "UTC",
    },
  });

  await upsertSocialAccount(created.id, identity);

  return created;
}

export async function loginWithGoogle(
  input: { idToken: string; timezone?: string },
  request: Request
) {
  const identity = await verifyGoogleIdToken(input.idToken);
  const user = await findOrCreateUserFromSocial(identity, input.timezone);

  await markUserLogin(user.id);

  const tokens = await issueMobileTokens(user.id, request);

  await createAuditEvent({
    userId: user.id,
    action: "AUTH_LOGIN_GOOGLE",
    ipAddress: getClientIp(request),
  });

  return {
    ...tokens,
    user: toUserDTO(await getSafeUserById(user.id)),
  };
}

export async function loginWithApple(
  input: { idToken: string; timezone?: string },
  request: Request
) {
  const identity = await verifyAppleIdentityToken(input.idToken);
  const user = await findOrCreateUserFromSocial(identity, input.timezone);

  await markUserLogin(user.id);

  const tokens = await issueMobileTokens(user.id, request);

  await createAuditEvent({
    userId: user.id,
    action: "AUTH_LOGIN_APPLE",
    ipAddress: getClientIp(request),
  });

  return {
    ...tokens,
    user: toUserDTO(await getSafeUserById(user.id)),
  };
}

export async function refreshAuthSession(refreshToken: string, request: Request) {
  let tokenPayload: { userId: string; sessionId: string };

  try {
    tokenPayload = await verifyRefreshToken(refreshToken);
  } catch {
    throw new ApiError("Refresh token invalido.", 401, "INVALID_REFRESH_TOKEN");
  }

  const session = await prisma.mobileSession.findUnique({
    where: { id: tokenPayload.sessionId },
  });

  if (!session || session.userId !== tokenPayload.userId) {
    throw new ApiError("Sessao invalida.", 401, "INVALID_SESSION");
  }

  if (session.revokedAt) {
    throw new ApiError("Sessao revogada.", 401, "SESSION_REVOKED");
  }

  if (session.expiresAt.getTime() < Date.now()) {
    throw new ApiError("Sessao expirada.", 401, "SESSION_EXPIRED");
  }

  const refreshValid = await verifySecret(session.refreshTokenHash, refreshToken);
  if (!refreshValid) {
    throw new ApiError("Refresh token invalido.", 401, "INVALID_REFRESH_TOKEN");
  }

  const nextRefreshToken = await signRefreshToken({
    userId: tokenPayload.userId,
    sessionId: tokenPayload.sessionId,
  });

  await prisma.mobileSession.update({
    where: { id: session.id },
    data: {
      refreshTokenHash: await hashSecret(nextRefreshToken),
      expiresAt: getRefreshExpiryDate(),
      userAgent: getUserAgent(request),
      ipAddress: getClientIp(request),
    },
  });

  const accessToken = await signAccessToken({
    userId: tokenPayload.userId,
    sessionId: tokenPayload.sessionId,
  });

  return {
    accessToken,
    refreshToken: nextRefreshToken,
    user: toUserDTO(await getSafeUserById(tokenPayload.userId)),
  };
}

export async function logoutFromRefreshToken(refreshToken: string) {
  let tokenPayload: { userId: string; sessionId: string };

  try {
    tokenPayload = await verifyRefreshToken(refreshToken);
  } catch {
    throw new ApiError("Refresh token invalido.", 401, "INVALID_REFRESH_TOKEN");
  }

  await prisma.mobileSession.updateMany({
    where: {
      id: tokenPayload.sessionId,
      userId: tokenPayload.userId,
      revokedAt: null,
    },
    data: {
      revokedAt: new Date(),
    },
  });
}

export async function logoutFromAccessContext(input: {
  userId: string;
  sessionId: string;
}) {
  await prisma.mobileSession.updateMany({
    where: {
      id: input.sessionId,
      userId: input.userId,
      revokedAt: null,
    },
    data: {
      revokedAt: new Date(),
    },
  });
}

export async function requestPasswordReset(email: string, request: Request) {
  const user = await prisma.user.findUnique({
    where: { email },
  });

  if (!user) {
    return;
  }

  const rawToken = randomBytes(32).toString("base64url");
  const tokenHash = hashLookupToken(rawToken);

  await prisma.passwordResetToken.create({
    data: {
      userId: user.id,
      tokenHash,
      expiresAt: getPasswordResetExpiryDate(),
    },
  });

  await sendPasswordResetEmail({
    email,
    token: rawToken,
  });

  await createAuditEvent({
    userId: user.id,
    action: "AUTH_FORGOT_PASSWORD",
    ipAddress: getClientIp(request),
  });
}

export async function resetPassword(input: {
  token: string;
  newPassword: string;
}) {
  const tokenHash = hashLookupToken(input.token);

  const resetRecord = await prisma.passwordResetToken.findUnique({
    where: { tokenHash },
  });

  if (!resetRecord || resetRecord.usedAt) {
    throw new ApiError("Token de redefinicao invalido.", 400, "INVALID_RESET_TOKEN");
  }

  if (resetRecord.expiresAt.getTime() < Date.now()) {
    throw new ApiError("Token de redefinicao expirado.", 400, "EXPIRED_RESET_TOKEN");
  }

  const newPasswordHash = await hashSecret(input.newPassword);

  await prisma.$transaction([
    prisma.user.update({
      where: { id: resetRecord.userId },
      data: {
        passwordHash: newPasswordHash,
      },
    }),
    prisma.passwordResetToken.update({
      where: { id: resetRecord.id },
      data: {
        usedAt: new Date(),
      },
    }),
    prisma.mobileSession.updateMany({
      where: {
        userId: resetRecord.userId,
        revokedAt: null,
      },
      data: {
        revokedAt: new Date(),
      },
    }),
  ]);

  await createAuditEvent({
    userId: resetRecord.userId,
    action: "AUTH_RESET_PASSWORD",
  });
}

export async function getAuthenticatedUser(userId: string) {
  return toUserDTO(await getSafeUserById(userId));
}

async function verifySocialReauth(
  userAccounts: Account[],
  input: { googleIdToken?: string; appleIdentityToken?: string }
) {
  const googleAccount = userAccounts.find((account) => account.provider === "google");
  if (googleAccount) {
    if (!input.googleIdToken) {
      throw new ApiError(
        "Reautenticacao Google obrigatoria para redefinir PIN.",
        401,
        "REAUTH_REQUIRED"
      );
    }

    const identity = await verifyGoogleIdToken(input.googleIdToken);
    if (identity.providerAccountId !== googleAccount.providerAccountId) {
      throw new ApiError("Conta Google nao confere.", 401, "REAUTH_FAILED");
    }

    return;
  }

  const appleAccount = userAccounts.find((account) => account.provider === "apple");
  if (appleAccount) {
    if (!input.appleIdentityToken) {
      throw new ApiError(
        "Reautenticacao Apple obrigatoria para redefinir PIN.",
        401,
        "REAUTH_REQUIRED"
      );
    }

    const identity = await verifyAppleIdentityToken(input.appleIdentityToken);
    if (identity.providerAccountId !== appleAccount.providerAccountId) {
      throw new ApiError("Conta Apple nao confere.", 401, "REAUTH_FAILED");
    }

    return;
  }

  throw new ApiError(
    "Nao foi possivel reautenticar com os dados enviados.",
    401,
    "REAUTH_REQUIRED"
  );
}

export async function setPin(userId: string, pin: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      pinHash: true,
    },
  });

  if (!user) {
    throw new ApiError("Usuario nao encontrado.", 404, "USER_NOT_FOUND");
  }

  if (user.pinHash) {
    throw new ApiError("PIN ja definido. Use reset para trocar.", 409, "PIN_ALREADY_SET");
  }

  await prisma.user.update({
    where: { id: userId },
    data: {
      pinHash: await hashSecret(pin),
      pinUpdatedAt: new Date(),
    },
  });
}

export async function getPinStatus(userId: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      pinHash: true,
      pinUpdatedAt: true,
    },
  });

  if (!user) {
    throw new ApiError("Usuario nao encontrado.", 404, "USER_NOT_FOUND");
  }

  return {
    hasPin: Boolean(user.pinHash),
    pinUpdatedAt: user.pinUpdatedAt,
  };
}

export async function verifyPin(userId: string, pin: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      pinHash: true,
    },
  });

  if (!user?.pinHash) {
    throw new ApiError("PIN ainda nao configurado.", 400, "PIN_NOT_SET");
  }

  const valid = await verifySecret(user.pinHash, pin);
  if (!valid) {
    throw new ApiError("PIN invalido.", 401, "INVALID_PIN");
  }

  const unlock = await issueParentalUnlockToken(userId);

  return {
    verified: true,
    unlockTtlMinutes: unlock.unlockTtlMinutes,
    parentalUnlockToken: unlock.parentalUnlockToken,
    parentalUnlockExpiresAt: unlock.parentalUnlockExpiresAt,
  };
}

export async function resetPin(
  userId: string,
  input: {
    newPin: string;
    currentPassword?: string;
    googleIdToken?: string;
    appleIdentityToken?: string;
  }
) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: {
      accounts: true,
    },
  });

  if (!user) {
    throw new ApiError("Usuario nao encontrado.", 404, "USER_NOT_FOUND");
  }

  if (user.passwordHash) {
    if (!input.currentPassword) {
      throw new ApiError("Senha atual obrigatoria para redefinir PIN.", 401, "REAUTH_REQUIRED");
    }

    const valid = await verifySecret(user.passwordHash, input.currentPassword);
    if (!valid) {
      throw new ApiError("Senha atual invalida.", 401, "REAUTH_FAILED");
    }
  } else {
    await verifySocialReauth(user.accounts, input);
  }

  await prisma.user.update({
    where: { id: userId },
    data: {
      pinHash: await hashSecret(input.newPin),
      pinUpdatedAt: new Date(),
    },
  });

  await createAuditEvent({
    userId,
    action: "SECURITY_PIN_RESET",
  });
}

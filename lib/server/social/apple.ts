import { createRemoteJWKSet, jwtVerify } from "jose";
import { z } from "zod";

import { env } from "@/lib/server/env";
import { ApiError } from "@/lib/server/errors";

const applePayloadSchema = z.object({
  sub: z.string().min(1),
  email: z.string().email().optional(),
});

const appleIssuer = "https://appleid.apple.com";
const appleJwks = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));

export type AppleIdentity = {
  provider: "apple";
  providerAccountId: string;
  email: string | null;
  name: string | null;
  imageUrl: string | null;
};

export async function verifyAppleIdentityToken(
  identityToken: string
): Promise<AppleIdentity> {
  const verifyOptions: {
    issuer: string;
    audience?: string;
  } = {
    issuer: appleIssuer,
  };

  if (env.appleClientId) {
    verifyOptions.audience = env.appleClientId;
  }

  let payload: unknown;

  try {
    const result = await jwtVerify(identityToken, appleJwks, verifyOptions);
    payload = result.payload;
  } catch {
    throw new ApiError("Token Apple invalido.", 401, "INVALID_APPLE_TOKEN");
  }

  const parsed = applePayloadSchema.parse(payload);

  return {
    provider: "apple",
    providerAccountId: parsed.sub,
    email: parsed.email ?? null,
    name: null,
    imageUrl: null,
  };
}

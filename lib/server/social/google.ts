import { z } from "zod";

import { env } from "@/lib/server/env";
import { ApiError } from "@/lib/server/errors";

const googleTokenInfoSchema = z.object({
  sub: z.string().min(1),
  email: z.string().email().optional(),
  email_verified: z.string().optional(),
  name: z.string().optional(),
  picture: z.string().url().optional(),
  aud: z.string().optional(),
});

export type GoogleIdentity = {
  provider: "google";
  providerAccountId: string;
  email: string | null;
  name: string | null;
  imageUrl: string | null;
};

export async function verifyGoogleIdToken(idToken: string): Promise<GoogleIdentity> {
  const url = new URL("https://oauth2.googleapis.com/tokeninfo");
  url.searchParams.set("id_token", idToken);

  const response = await fetch(url.toString(), {
    method: "GET",
    cache: "no-store",
  });

  if (!response.ok) {
    throw new ApiError("Token Google invalido.", 401, "INVALID_GOOGLE_TOKEN");
  }

  const payload = googleTokenInfoSchema.parse(await response.json());

  if (env.googleClientId && payload.aud !== env.googleClientId) {
    throw new ApiError("Token Google com audiencia invalida.", 401, "INVALID_GOOGLE_AUDIENCE");
  }

  if (payload.email_verified !== "true") {
    throw new ApiError("E-mail Google nao verificado.", 401, "UNVERIFIED_GOOGLE_EMAIL");
  }

  return {
    provider: "google",
    providerAccountId: payload.sub,
    email: payload.email ?? null,
    name: payload.name ?? null,
    imageUrl: payload.picture ?? null,
  };
}

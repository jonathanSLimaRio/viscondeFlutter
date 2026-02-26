import { ApiError } from "@/lib/server/errors";
import { verifyAccessToken } from "@/lib/server/jwt";

export type AuthContext = {
  userId: string;
  sessionId: string;
};

export function getBearerToken(request: Request) {
  const authHeader = request.headers.get("authorization");
  if (!authHeader) return null;

  const [scheme, token] = authHeader.split(" ");
  if (scheme?.toLowerCase() !== "bearer" || !token) {
    return null;
  }

  return token;
}

export async function requireAuth(request: Request): Promise<AuthContext> {
  const token = getBearerToken(request);

  if (!token) {
    throw new ApiError("Token de acesso nao informado.", 401, "UNAUTHORIZED");
  }

  try {
    return await verifyAccessToken(token);
  } catch {
    throw new ApiError("Token de acesso invalido ou expirado.", 401, "UNAUTHORIZED");
  }
}

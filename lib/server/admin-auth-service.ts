import { prisma } from "@/lib/prisma";
import { requireAuth } from "@/lib/server/auth-context";
import { ApiError } from "@/lib/server/errors";

export async function requireAdminUser(userId: string) {
  const user = await prisma.user.findUnique({
    where: {
      id: userId,
    },
    select: {
      id: true,
      role: true,
    },
  });

  if (!user) {
    throw new ApiError("Usuario nao encontrado.", 404, "USER_NOT_FOUND");
  }

  if (user.role !== "ADMIN") {
    throw new ApiError("Acesso restrito a administradores.", 403, "ADMIN_FORBIDDEN");
  }
}

export async function requireAdminAuth(request: Request) {
  const auth = await requireAuth(request);
  await requireAdminUser(auth.userId);
  return auth;
}

import type { ChildProfile, User } from "@prisma/client";

export function toUserDTO(
  user: Pick<
    User,
    "id" | "name" | "email" | "timezone" | "imageUrl" | "createdAt" | "updatedAt"
  >
) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    timezone: user.timezone,
    imageUrl: user.imageUrl,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

export function toChildDTO(
  child: Pick<
    ChildProfile,
    | "id"
    | "name"
    | "birthDate"
    | "avatarUrl"
    | "favoriteThemes"
    | "isArchived"
    | "createdAt"
    | "updatedAt"
  >
) {
  return {
    id: child.id,
    name: child.name,
    birthDate: child.birthDate.toISOString(),
    avatarUrl: child.avatarUrl,
    favoriteThemes: child.favoriteThemes,
    isArchived: child.isArchived,
    createdAt: child.createdAt,
    updatedAt: child.updatedAt,
  };
}

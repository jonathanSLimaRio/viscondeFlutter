import type { ChildProfile, User } from "@prisma/client";

export function toUserDTO(
  user: Pick<
    User,
    | "id"
    | "name"
    | "email"
    | "timezone"
    | "imageUrl"
    | "avatarPresetKey"
    | "avatarVariant"
    | "avatarAccent"
    | "role"
    | "createdAt"
    | "updatedAt"
  >
) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    timezone: user.timezone,
    imageUrl: user.imageUrl,
    avatarPresetKey: user.avatarPresetKey,
    avatarVariant: user.avatarVariant,
    avatarAccent: user.avatarAccent,
    role: user.role,
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
    | "avatarPresetKey"
    | "avatarVariant"
    | "avatarAccent"
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
    avatarPresetKey: child.avatarPresetKey,
    avatarVariant: child.avatarVariant,
    avatarAccent: child.avatarAccent,
    favoriteThemes: child.favoriteThemes,
    isArchived: child.isArchived,
    createdAt: child.createdAt,
    updatedAt: child.updatedAt,
  };
}

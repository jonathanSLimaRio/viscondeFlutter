import { prisma } from "@/lib/prisma";
import { ApiError } from "@/lib/server/errors";
import { moderateTextInput } from "@/lib/server/moderation-service";
import { toChildDTO, toUserDTO } from "@/lib/server/user";
import { uploadFileToWordPress } from "@/lib/server/wordpress";

export async function getMe(userId: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      name: true,
      email: true,
      timezone: true,
      imageUrl: true,
      avatarPresetKey: true,
      avatarVariant: true,
      avatarAccent: true,
      role: true,
      createdAt: true,
      updatedAt: true,
      childProfiles: {
        where: {
          isArchived: false,
        },
        orderBy: {
          createdAt: "desc",
        },
      },
    },
  });

  if (!user) {
    throw new ApiError("Usuario nao encontrado.", 404, "USER_NOT_FOUND");
  }

  return {
    ...toUserDTO(user),
    children: user.childProfiles.map((child) => toChildDTO(child)),
  };
}

export async function updateMe(
  userId: string,
  input: {
    name?: string | null;
    timezone?: string;
    avatarPresetKey?: string;
    avatarVariant?: number;
    avatarAccent?: string;
  }
) {
  const normalizedName =
    typeof input.name === "string" && input.name.trim().length > 0
      ? await moderateTextInput({
          value: input.name,
          scope: "USER_NAME",
          field: "name",
          userId,
        })
      : input.name ?? undefined;

  const updated = await prisma.user.update({
    where: { id: userId },
    data: {
      name: normalizedName,
      timezone: input.timezone,
      avatarPresetKey: input.avatarPresetKey,
      avatarVariant: input.avatarVariant,
      avatarAccent: input.avatarAccent,
    },
    select: {
      id: true,
      name: true,
      email: true,
      timezone: true,
      imageUrl: true,
      avatarPresetKey: true,
      avatarVariant: true,
      avatarAccent: true,
      role: true,
      createdAt: true,
      updatedAt: true,
    },
  });

  return toUserDTO(updated);
}

export async function updateMePhoto(userId: string, file: File) {
  const upload = await uploadFileToWordPress({
    file,
    filenamePrefix: `user-${userId}`,
  });

  if (!upload.sourceUrl) {
    throw new ApiError("Upload sem URL valida.", 502, "WORDPRESS_INVALID_RESPONSE");
  }

  const updated = await prisma.user.update({
    where: { id: userId },
    data: {
      imageUrl: upload.sourceUrl,
      image: upload.sourceUrl,
    },
    select: {
      id: true,
      name: true,
      email: true,
      timezone: true,
      imageUrl: true,
      avatarPresetKey: true,
      avatarVariant: true,
      avatarAccent: true,
      role: true,
      createdAt: true,
      updatedAt: true,
    },
  });

  return {
    user: toUserDTO(updated),
    mediaId: upload.mediaId,
    sourceUrl: upload.sourceUrl,
  };
}

export async function listChildren(userId: string) {
  const children = await prisma.childProfile.findMany({
    where: {
      userId,
      isArchived: false,
    },
    orderBy: {
      createdAt: "desc",
    },
  });

  return children.map((child) => toChildDTO(child));
}

export async function createChild(
  userId: string,
  input: {
    name: string;
    birthDate: Date;
    favoriteThemes: string[];
  }
) {
  const normalizedName = await moderateTextInput({
    value: input.name,
    scope: "CHILD_NAME",
    field: "name",
    userId,
  });

  const created = await prisma.childProfile.create({
    data: {
      userId,
      name: normalizedName,
      birthDate: input.birthDate,
      favoriteThemes: input.favoriteThemes,
    },
  });

  return toChildDTO(created);
}

export async function getChild(userId: string, childId: string) {
  const child = await prisma.childProfile.findFirst({
    where: {
      id: childId,
      userId,
      isArchived: false,
    },
  });

  if (!child) {
    throw new ApiError("Perfil infantil nao encontrado.", 404, "CHILD_NOT_FOUND");
  }

  return toChildDTO(child);
}

export async function updateChild(
  userId: string,
  childId: string,
  input: {
    name?: string;
    birthDate?: Date;
    favoriteThemes?: string[];
    isArchived?: boolean;
    avatarPresetKey?: string;
    avatarVariant?: number;
    avatarAccent?: string;
  }
) {
  const existing = await prisma.childProfile.findFirst({
    where: {
      id: childId,
      userId,
    },
  });

  if (!existing) {
    throw new ApiError("Perfil infantil nao encontrado.", 404, "CHILD_NOT_FOUND");
  }

  const normalizedName =
    input.name && input.name.trim().length > 0
      ? await moderateTextInput({
          value: input.name,
          scope: "CHILD_NAME",
          field: "name",
          userId,
        })
      : undefined;

  const updated = await prisma.childProfile.update({
    where: { id: childId },
    data: {
      name: normalizedName,
      birthDate: input.birthDate,
      favoriteThemes: input.favoriteThemes,
      isArchived: input.isArchived,
      avatarPresetKey: input.avatarPresetKey,
      avatarVariant: input.avatarVariant,
      avatarAccent: input.avatarAccent,
    },
  });

  return toChildDTO(updated);
}

export async function archiveChild(userId: string, childId: string) {
  const existing = await prisma.childProfile.findFirst({
    where: {
      id: childId,
      userId,
      isArchived: false,
    },
  });

  if (!existing) {
    throw new ApiError("Perfil infantil nao encontrado.", 404, "CHILD_NOT_FOUND");
  }

  const archived = await prisma.childProfile.update({
    where: { id: childId },
    data: {
      isArchived: true,
    },
  });

  return toChildDTO(archived);
}

export async function updateChildAvatar(userId: string, childId: string, file: File) {
  const child = await prisma.childProfile.findFirst({
    where: {
      id: childId,
      userId,
      isArchived: false,
    },
  });

  if (!child) {
    throw new ApiError("Perfil infantil nao encontrado.", 404, "CHILD_NOT_FOUND");
  }

  const upload = await uploadFileToWordPress({
    file,
    filenamePrefix: `child-${childId}`,
  });

  if (!upload.sourceUrl) {
    throw new ApiError("Upload sem URL valida.", 502, "WORDPRESS_INVALID_RESPONSE");
  }

  const updated = await prisma.childProfile.update({
    where: { id: childId },
    data: {
      avatarUrl: upload.sourceUrl,
    },
  });

  return {
    child: toChildDTO(updated),
    mediaId: upload.mediaId,
    sourceUrl: upload.sourceUrl,
  };
}

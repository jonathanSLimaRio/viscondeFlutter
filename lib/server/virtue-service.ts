import type { AgeBand, Virtue } from "@prisma/client";

import { prisma } from "@/lib/prisma";
import { ApiError } from "@/lib/server/errors";

type VirtueDTO = {
  id: string;
  slug: string;
  name: string;
  shortDescription: string;
  iconKey: string;
  sortOrder: number;
};

const preferredVirtuesByBand: Record<AgeBand, string[]> = {
  AGE_4_5: ["empatia", "gratidao", "respeito"],
  AGE_6_8: ["coragem", "cooperacao", "honestidade"],
  AGE_9_10: ["responsabilidade", "paciencia", "honestidade"],
};

function toVirtueDTO(virtue: {
  id: string;
  slug: string;
  name: string;
  shortDescription: string;
  iconKey: string;
  sortOrder: number;
}) {
  return {
    id: virtue.id,
    slug: virtue.slug,
    name: virtue.name,
    shortDescription: virtue.shortDescription,
    iconKey: virtue.iconKey,
    sortOrder: virtue.sortOrder,
  } satisfies VirtueDTO;
}

export function resolveAgeBand(ageYears: number): AgeBand {
  if (ageYears <= 5) {
    return "AGE_4_5";
  }

  if (ageYears <= 8) {
    return "AGE_6_8";
  }

  return "AGE_9_10";
}

function clampChildAge(ageYears: number) {
  if (ageYears < 4) return 4;
  if (ageYears > 10) return 10;
  return ageYears;
}

function calculateAgeYears(birthDate: Date) {
  const now = new Date();
  let years = now.getFullYear() - birthDate.getFullYear();

  const beforeBirthday =
    now.getMonth() < birthDate.getMonth() ||
    (now.getMonth() === birthDate.getMonth() && now.getDate() < birthDate.getDate());

  if (beforeBirthday) {
    years -= 1;
  }

  return Math.max(years, 0);
}

async function getOwnedChildOrThrow(userId: string, childProfileId: string) {
  const child = await prisma.childProfile.findFirst({
    where: {
      id: childProfileId,
      userId,
      isArchived: false,
    },
    select: {
      id: true,
      birthDate: true,
      name: true,
    },
  });

  if (!child) {
    throw new ApiError("Perfil infantil nao encontrado.", 404, "CHILD_NOT_FOUND");
  }

  return child;
}

async function findLeastUsedVirtueForChild(input: {
  userId: string;
  childProfileId: string;
  candidates: Virtue[];
}) {
  const recentStories = await prisma.story.findMany({
    where: {
      userId: input.userId,
      childProfileId: input.childProfileId,
      status: "PUBLISHED",
      virtueId: {
        in: input.candidates.map((candidate) => candidate.id),
      },
    },
    select: {
      virtueId: true,
      publishedAt: true,
    },
    orderBy: {
      publishedAt: "desc",
    },
    take: 50,
  });

  const usageMap = new Map<string, number>();

  for (const candidate of input.candidates) {
    usageMap.set(candidate.id, 0);
  }

  for (const story of recentStories) {
    if (!story.virtueId) {
      continue;
    }

    usageMap.set(story.virtueId, (usageMap.get(story.virtueId) ?? 0) + 1);
  }

  const sorted = [...input.candidates].sort((left, right) => {
    const leftUsage = usageMap.get(left.id) ?? 0;
    const rightUsage = usageMap.get(right.id) ?? 0;

    if (leftUsage !== rightUsage) {
      return leftUsage - rightUsage;
    }

    return left.sortOrder - right.sortOrder;
  });

  return {
    selected: sorted[0] ?? null,
    alternatives: sorted.slice(1, 4),
  };
}

export async function listActiveVirtues() {
  const virtues = await prisma.virtue.findMany({
    where: {
      isActive: true,
    },
    orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
    select: {
      id: true,
      slug: true,
      name: true,
      shortDescription: true,
      iconKey: true,
      sortOrder: true,
    },
  });

  return virtues.map(toVirtueDTO);
}

export async function suggestVirtueForChildProfile(userId: string, childProfileId: string) {
  const child = await getOwnedChildOrThrow(userId, childProfileId);

  const ageYears = clampChildAge(calculateAgeYears(child.birthDate));
  const ageBand = resolveAgeBand(ageYears);
  const preferredSlugs = preferredVirtuesByBand[ageBand];

  let candidates = await prisma.virtue.findMany({
    where: {
      isActive: true,
      slug: {
        in: preferredSlugs,
      },
    },
    orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
  });

  if (candidates.length === 0) {
    candidates = await prisma.virtue.findMany({
      where: {
        isActive: true,
      },
      orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
    });
  }

  if (candidates.length === 0) {
    throw new ApiError("Biblioteca de virtudes vazia. Rode o seed de virtudes.", 409, "VIRTUE_EMPTY");
  }

  const ranked = await findLeastUsedVirtueForChild({
    userId,
    childProfileId,
    candidates,
  });

  if (!ranked.selected) {
    throw new ApiError("Nao foi possivel sugerir uma virtude.", 500, "VIRTUE_SUGGESTION_FAILED");
  }

  return {
    virtue: toVirtueDTO(ranked.selected),
    ageBand,
    reason: `Sugestao por faixa etaria ${ageBand.replace("AGE_", "").replace("_", "-")} com menor repeticao recente.`,
    alternatives: ranked.alternatives.map(toVirtueDTO),
  };
}

export async function resolveVirtueForStoryCreation(input: {
  userId: string;
  childProfileId: string;
  virtueId?: string;
}) {
  const child = await getOwnedChildOrThrow(input.userId, input.childProfileId);
  const ageYears = clampChildAge(calculateAgeYears(child.birthDate));
  const ageBand = resolveAgeBand(ageYears);

  if (input.virtueId) {
    const virtue = await prisma.virtue.findFirst({
      where: {
        id: input.virtueId,
        isActive: true,
      },
      select: {
        id: true,
        slug: true,
        name: true,
        shortDescription: true,
        iconKey: true,
        sortOrder: true,
      },
    });

    if (!virtue) {
      throw new ApiError("Virtude informada nao encontrada.", 404, "VIRTUE_NOT_FOUND");
    }

    return {
      virtue,
      ageBand,
      virtueSource: "MANUAL" as const,
    };
  }

  const suggested = await suggestVirtueForChildProfile(input.userId, input.childProfileId);

  return {
    virtue: suggested.virtue,
    ageBand: suggested.ageBand,
    virtueSource: "AUTO" as const,
  };
}

export async function getVirtueById(virtueId: string) {
  const virtue = await prisma.virtue.findUnique({
    where: {
      id: virtueId,
    },
    select: {
      id: true,
      slug: true,
      name: true,
      shortDescription: true,
      iconKey: true,
      sortOrder: true,
      isActive: true,
    },
  });

  if (!virtue || !virtue.isActive) {
    throw new ApiError("Virtude nao encontrada.", 404, "VIRTUE_NOT_FOUND");
  }

  return toVirtueDTO(virtue);
}

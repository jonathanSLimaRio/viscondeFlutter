import type { StoryMode, StoryStepKind, StoryStatus } from "@prisma/client";

import { prisma } from "@/lib/prisma";
import { ApiError } from "@/lib/server/errors";
import { getStoryById } from "@/lib/server/story-service";

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

function normalizeTitle(value: string, max = 140) {
  const trimmed = value.trim();
  if (trimmed.length <= max) {
    return trimmed;
  }

  return trimmed.slice(0, max);
}

function parseChildOptionsJson(value: unknown) {
  if (!Array.isArray(value)) {
    return null;
  }

  const options = value
    .map((item) => {
      if (!item || typeof item !== "object") {
        return null;
      }

      const record = item as { id?: unknown; label?: unknown };
      if (typeof record.id !== "string" || typeof record.label !== "string") {
        return null;
      }

      return {
        id: record.id,
        label: record.label,
      };
    })
    .filter((item): item is { id: string; label: string } => Boolean(item));

  if (options.length === 0) {
    return null;
  }

  return options;
}

function toEpisodeStepDTO(step: {
  id: string;
  stepIndex: number;
  kind: StoryStepKind;
  modeUsed: StoryMode;
  localEventId: string;
  narratorPrompt: string | null;
  childOptionsJson: unknown;
  selectedOptionId: string | null;
  selectedOptionLabel: string | null;
  narratorText: string | null;
  autoSavedAt: Date;
  createdAt: Date;
}) {
  return {
    id: step.id,
    stepIndex: step.stepIndex,
    kind: step.kind,
    modeUsed: step.modeUsed,
    localEventId: step.localEventId,
    narratorPrompt: step.narratorPrompt,
    childOptions: parseChildOptionsJson(step.childOptionsJson),
    selectedOptionId: step.selectedOptionId,
    selectedOptionLabel: step.selectedOptionLabel,
    narratorText: step.narratorText,
    autoSavedAt: step.autoSavedAt,
    createdAt: step.createdAt,
  };
}

function startOfDay(date: Date) {
  const output = new Date(date);
  output.setHours(0, 0, 0, 0);
  return output;
}

function endOfDay(date: Date) {
  const output = new Date(date);
  output.setHours(23, 59, 59, 999);
  return output;
}

export async function listStoryVaultCollections(
  userId: string,
  filters: {
    childProfileId?: string;
    dateFrom?: Date;
    dateTo?: Date;
    theme?: string;
    virtueId?: string;
    favoriteOnly?: boolean;
  }
) {
  if (filters.dateFrom && filters.dateTo && filters.dateFrom.getTime() > filters.dateTo.getTime()) {
    throw new ApiError("Periodo de datas invalido.", 400, "INVALID_DATE_RANGE");
  }

  const collections = await prisma.storyCollection.findMany({
    where: {
      userId,
      childProfileId: filters.childProfileId,
      theme: filters.theme ? { contains: filters.theme, mode: "insensitive" } : undefined,
      virtueId: filters.virtueId,
      isFavorite: filters.favoriteOnly ? true : undefined,
      lastReferenceAt:
        filters.dateFrom || filters.dateTo
          ? {
              gte: filters.dateFrom ? startOfDay(filters.dateFrom) : undefined,
              lte: filters.dateTo ? endOfDay(filters.dateTo) : undefined,
            }
          : undefined,
    },
    include: {
      childProfile: {
        select: {
          id: true,
          name: true,
          avatarUrl: true,
        },
      },
      virtue: {
        select: {
          id: true,
          slug: true,
          name: true,
          shortDescription: true,
          iconKey: true,
          sortOrder: true,
        },
      },
      stories: {
        orderBy: {
          episodeNumber: "desc",
        },
        select: {
          id: true,
          episodeNumber: true,
          titleDraft: true,
          titleFinal: true,
          status: true,
          publishedAt: true,
          updatedAt: true,
          currentStepIndex: true,
        },
      },
    },
    orderBy: {
      lastReferenceAt: "desc",
    },
  });

  return collections.map((collection) => {
    const publishedCount = collection.stories.filter((story) => story.status === "PUBLISHED").length;
    const draftCount = collection.stories.filter((story) => story.status === "DRAFT").length;
    const latestEpisode = collection.stories[0] ?? null;

    return {
      id: collection.id,
      title: collection.title,
      theme: collection.theme,
      virtue: collection.virtue,
      isFavorite: collection.isFavorite,
      child: {
        id: collection.childProfile.id,
        name: collection.childProfile.name,
        avatarUrl: collection.childProfile.avatarUrl,
      },
      episodesCount: collection.stories.length,
      publishedCount,
      draftCount,
      lastReferenceAt: collection.lastReferenceAt,
      latestEpisode: latestEpisode
        ? {
            storyId: latestEpisode.id,
            episodeNumber: latestEpisode.episodeNumber,
            title: latestEpisode.titleFinal ?? latestEpisode.titleDraft,
            status: latestEpisode.status,
            publishedAt: latestEpisode.publishedAt,
            updatedAt: latestEpisode.updatedAt,
            currentStepIndex: latestEpisode.currentStepIndex,
          }
        : null,
    };
  });
}

export async function getStoryVaultCollectionDetails(userId: string, collectionId: string) {
  const collection = await prisma.storyCollection.findFirst({
    where: {
      id: collectionId,
      userId,
    },
    include: {
      childProfile: {
        select: {
          id: true,
          name: true,
          avatarUrl: true,
          birthDate: true,
        },
      },
      virtue: {
        select: {
          id: true,
          slug: true,
          name: true,
          shortDescription: true,
          iconKey: true,
          sortOrder: true,
        },
      },
      stories: {
        orderBy: {
          episodeNumber: "asc",
        },
        include: {
          characters: {
            orderBy: {
              createdAt: "asc",
            },
          },
          steps: {
            orderBy: {
              stepIndex: "asc",
            },
          },
        },
      },
    },
  });

  if (!collection) {
    throw new ApiError("Colecao de historias nao encontrada.", 404, "STORY_COLLECTION_NOT_FOUND");
  }

  return {
    collection: {
      id: collection.id,
      title: collection.title,
      theme: collection.theme,
      virtue: collection.virtue,
      isFavorite: collection.isFavorite,
      templateFromStoryId: collection.templateFromStoryId,
      lastReferenceAt: collection.lastReferenceAt,
      createdAt: collection.createdAt,
      updatedAt: collection.updatedAt,
      child: {
        id: collection.childProfile.id,
        name: collection.childProfile.name,
        avatarUrl: collection.childProfile.avatarUrl,
        birthDate: collection.childProfile.birthDate,
      },
    },
    episodes: collection.stories.map((story) => ({
      storyId: story.id,
      episodeNumber: story.episodeNumber,
      title: story.titleFinal ?? story.titleDraft,
      titleDraft: story.titleDraft,
      titleFinal: story.titleFinal,
      status: story.status,
      publishedAt: story.publishedAt,
      updatedAt: story.updatedAt,
      currentStepIndex: story.currentStepIndex,
      scenario: story.scenario,
      objective: story.objective,
      characters: story.characters.map((character) => ({
        id: character.id,
        name: character.name,
        role: character.role,
        createdAt: character.createdAt,
      })),
      steps: story.steps.map(toEpisodeStepDTO),
    })),
  };
}

export async function setStoryVaultCollectionFavorite(
  userId: string,
  collectionId: string,
  isFavorite: boolean
) {
  const updated = await prisma.storyCollection.updateMany({
    where: {
      id: collectionId,
      userId,
    },
    data: {
      isFavorite,
    },
  });

  if (updated.count === 0) {
    throw new ApiError("Colecao de historias nao encontrada.", 404, "STORY_COLLECTION_NOT_FOUND");
  }

  const collection = await prisma.storyCollection.findUniqueOrThrow({
    where: {
      id: collectionId,
    },
    select: {
      id: true,
      isFavorite: true,
      updatedAt: true,
    },
  });

  return collection;
}

export async function continueStoryAsNextEpisode(
  userId: string,
  storyId: string,
  input: {
    titleDraft?: string;
  }
) {
  const source = await prisma.story.findFirst({
    where: {
      id: storyId,
      userId,
    },
    include: {
      collection: {
        select: {
          id: true,
          childProfileId: true,
          title: true,
        },
      },
      characters: {
        orderBy: {
          createdAt: "asc",
        },
      },
    },
  });

  if (!source) {
    throw new ApiError("Historia nao encontrada.", 404, "STORY_NOT_FOUND");
  }

  if (source.status !== "PUBLISHED") {
    throw new ApiError(
      "Apenas historias publicadas podem ser continuadas.",
      409,
      "STORY_CONTINUE_SOURCE_NOT_PUBLISHED"
    );
  }

  const existingDraft = await prisma.story.findFirst({
    where: {
      collectionId: source.collectionId,
      status: "DRAFT",
    },
    select: {
      id: true,
    },
  });

  if (existingDraft) {
    throw new ApiError(
      "A colecao ja possui um episodio em rascunho.",
      409,
      "STORY_COLLECTION_DRAFT_EXISTS"
    );
  }

  const latestEpisode = await prisma.story.findFirst({
    where: {
      collectionId: source.collectionId,
    },
    orderBy: {
      episodeNumber: "desc",
    },
    select: {
      episodeNumber: true,
    },
  });

  const nextEpisodeNumber = (latestEpisode?.episodeNumber ?? 0) + 1;
  const titleDraft = normalizeTitle(
    input.titleDraft?.trim() ||
      `Episodio ${nextEpisodeNumber}: ${source.collection.title || source.titleFinal || source.titleDraft}`
  );
  const now = new Date();

  const created = await prisma.$transaction(async (tx) => {
    const story = await tx.story.create({
      data: {
        userId,
        childProfileId: source.childProfileId,
        collectionId: source.collectionId,
        episodeNumber: nextEpisodeNumber,
        continuedFromStoryId: source.id,
        sessionKind: "PRESENTIAL",
        virtueId: source.virtueId,
        titleDraft,
        theme: source.theme,
        scenario: source.scenario,
        objective: source.objective,
        ageBand: source.ageBand,
        virtueSource: source.virtueSource,
        dilemmaText: source.dilemmaText,
        endQuestionText: source.endQuestionText,
        status: "DRAFT",
        currentMode: "PARENT_NARRATOR",
        currentStepIndex: 0,
        ageSnapshotYears: source.ageSnapshotYears,
        startedAt: now,
        characters: {
          create: source.characters.map((character) => ({
            name: character.name,
            role: character.role ?? undefined,
          })),
        },
      },
      select: {
        id: true,
        collectionId: true,
      },
    });

    await tx.storyCollection.update({
      where: {
        id: source.collectionId,
      },
      data: {
        lastReferenceAt: now,
      },
    });

    return story;
  });

  return {
    collectionId: created.collectionId,
    story: await getStoryById(userId, created.id),
  };
}

export async function duplicateStoryAsTemplate(
  userId: string,
  storyId: string,
  input: {
    childProfileId?: string;
  }
) {
  const source = await prisma.story.findFirst({
    where: {
      id: storyId,
      userId,
    },
    include: {
      collection: {
        select: {
          title: true,
        },
      },
      characters: {
        orderBy: {
          createdAt: "asc",
        },
      },
    },
  });

  if (!source) {
    throw new ApiError("Historia nao encontrada.", 404, "STORY_NOT_FOUND");
  }

  const targetChildId = input.childProfileId ?? source.childProfileId;
  const targetChild = await prisma.childProfile.findFirst({
    where: {
      id: targetChildId,
      userId,
      isArchived: false,
    },
    select: {
      id: true,
      birthDate: true,
    },
  });

  if (!targetChild) {
    throw new ApiError("Perfil infantil nao encontrado.", 404, "CHILD_NOT_FOUND");
  }

  const now = new Date();
  const collectionTitle = normalizeTitle(
    source.collection?.title || source.titleFinal || source.titleDraft
  );
  const titleDraft = normalizeTitle(
    `Repetir: ${source.titleFinal || source.titleDraft}`
  );

  const created = await prisma.$transaction(async (tx) => {
    const collection = await tx.storyCollection.create({
      data: {
        userId,
        childProfileId: targetChild.id,
        title: collectionTitle,
        theme: source.theme,
        virtueId: source.virtueId,
        templateFromStoryId: source.id,
        isFavorite: false,
        lastReferenceAt: now,
      },
      select: {
        id: true,
      },
    });

    const story = await tx.story.create({
      data: {
        userId,
        childProfileId: targetChild.id,
        collectionId: collection.id,
        episodeNumber: 1,
        sessionKind: "PRESENTIAL",
        virtueId: source.virtueId,
        titleDraft,
        theme: source.theme,
        scenario: source.scenario,
        objective: source.objective,
        ageBand: source.ageBand,
        virtueSource: source.virtueSource,
        dilemmaText: source.dilemmaText,
        endQuestionText: source.endQuestionText,
        status: "DRAFT",
        currentMode: "PARENT_NARRATOR",
        currentStepIndex: 0,
        ageSnapshotYears: calculateAgeYears(targetChild.birthDate),
        startedAt: now,
        characters: {
          create: source.characters.map((character) => ({
            name: character.name,
            role: character.role ?? undefined,
          })),
        },
      },
      select: {
        id: true,
      },
    });

    return {
      collectionId: collection.id,
      storyId: story.id,
    };
  });

  return {
    collectionId: created.collectionId,
    story: await getStoryById(userId, created.storyId),
  };
}

export function resolveStoryCollectionReferenceDate(story: {
  status: StoryStatus;
  publishedAt: Date | null;
  updatedAt: Date;
}) {
  if (story.status === "PUBLISHED" && story.publishedAt) {
    return story.publishedAt;
  }

  return story.updatedAt;
}

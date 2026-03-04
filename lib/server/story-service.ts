import type {
  AgeBand,
  CallMode,
  RemoteRoomStatus,
  StoryGameMode,
  StoryMode,
  StorySessionKind,
  StoryStatus,
  StoryStepKind,
  VirtueSource,
} from "@prisma/client";

import { prisma } from "@/lib/prisma";
import { resolveTemplateForStoryCreation } from "@/lib/server/content-admin-service";
import { ApiError } from "@/lib/server/errors";
import { processStoryPublished } from "@/lib/server/gamification-service";
import { moderateTextInput } from "@/lib/server/moderation-service";
import { generateStoryIdeas } from "@/lib/server/story-idea-service";
import { getChildInventory, getLatestStoryMemory } from "@/lib/server/inventory-service";
import { assertSafeContext } from "@/lib/server/story-safety";
import { resolveVirtueForStoryCreation } from "@/lib/server/virtue-service";
import { selectVirtueTemplateOrThrow } from "@/lib/server/virtue-template-service";
import {
  publishStoryModeChangedEvent,
  publishStoryStepCreatedEvent,
} from "@/lib/server/remote-realtime-events";

const MAX_STORY_STEPS = 12;
const MIN_STORY_STEPS_TO_PUBLISH = 3;

type StoryGameNodeDTO = {
  index: number;
  x: number;
  y: number;
  kind: "START" | "PATH" | "FINISH";
};

type StoryGameMapDTO = {
  biome: "FOREST" | "CASTLE" | "UNDERWATER" | "SPACE" | "TREASURE";
  totalNodes: number;
  nodes: StoryGameNodeDTO[];
};

function clamp(value: number, min: number, max: number) {
  return Math.min(Math.max(value, min), max);
}

function isPrismaUnknownFieldOrArgument(error: unknown, fieldName: string) {
  if (!(error instanceof Error)) {
    return false;
  }
  const message = error.message;
  return (
    message.includes(`Unknown field \`${fieldName}\``) ||
    message.includes(`Unknown argument \`${fieldName}\``)
  );
}

function isPrismaGameFieldCompatibilityError(error: unknown) {
  return (
    isPrismaUnknownFieldOrArgument(error, "gameMode") ||
    isPrismaUnknownFieldOrArgument(error, "gameNodeIndex") ||
    isPrismaUnknownFieldOrArgument(error, "gameActionKey") ||
    isPrismaUnknownFieldOrArgument(error, "gameActionLabel")
  );
}

function hashSeed(value: string) {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return Math.abs(hash >>> 0);
}

function computeStoryGameSeed(input: {
  storyId: string;
  theme: string;
  scenario: string;
  objective: string;
}) {
  return hashSeed(`${input.storyId}|${input.theme}|${input.scenario}|${input.objective}`);
}

function buildLinearTrailMap(seed: number): StoryGameMapDTO {
  let randomState = seed || 1;
  const nextRandom = () => {
    randomState = (Math.imul(randomState, 1664525) + 1013904223) >>> 0;
    return randomState / 0xffffffff;
  };

  const biomes: StoryGameMapDTO["biome"][] = [
    "FOREST",
    "CASTLE",
    "UNDERWATER",
    "SPACE",
    "TREASURE",
  ];

  const biome = biomes[seed % biomes.length] ?? "FOREST";
  const nodes: StoryGameNodeDTO[] = [];

  for (let index = 1; index <= MAX_STORY_STEPS; index += 1) {
    const progress = (index - 1) / (MAX_STORY_STEPS - 1);
    const x = clamp(0.08 + progress * 0.84, 0.06, 0.94);
    const wave = Math.sin(progress * Math.PI * 2.6 + nextRandom() * 0.8) * 0.18;
    const jitter = (nextRandom() - 0.5) * 0.06;
    const y = clamp(0.5 + wave + jitter, 0.2, 0.8);

    nodes.push({
      index,
      x: Number(x.toFixed(4)),
      y: Number(y.toFixed(4)),
      kind: index === 1 ? "START" : index === MAX_STORY_STEPS ? "FINISH" : "PATH",
    });
  }

  return {
    biome,
    totalNodes: MAX_STORY_STEPS,
    nodes,
  };
}

function parseGameMapNode(value: unknown): StoryGameNodeDTO | null {
  if (!value || typeof value !== "object") {
    return null;
  }

  const record = value as {
    index?: unknown;
    x?: unknown;
    y?: unknown;
    kind?: unknown;
  };

  const index = typeof record.index === "number" ? Math.trunc(record.index) : Number(record.index);
  const x = typeof record.x === "number" ? record.x : Number(record.x);
  const y = typeof record.y === "number" ? record.y : Number(record.y);
  const kind = record.kind;

  if (!Number.isFinite(index) || index < 1 || index > MAX_STORY_STEPS) {
    return null;
  }

  if (!Number.isFinite(x) || !Number.isFinite(y)) {
    return null;
  }

  if (kind !== "START" && kind !== "PATH" && kind !== "FINISH") {
    return null;
  }

  return {
    index,
    x: clamp(x, 0, 1),
    y: clamp(y, 0, 1),
    kind,
  };
}

function normalizeGameMapJson(raw: unknown, seed: number): StoryGameMapDTO {
  if (!raw || typeof raw !== "object") {
    return buildLinearTrailMap(seed);
  }

  const record = raw as {
    biome?: unknown;
    totalNodes?: unknown;
    nodes?: unknown;
  };

  const parsedNodes = Array.isArray(record.nodes)
    ? record.nodes.map(parseGameMapNode).filter((item): item is StoryGameNodeDTO => Boolean(item))
    : [];

  if (parsedNodes.length === 0) {
    return buildLinearTrailMap(seed);
  }

  const biome =
    record.biome === "FOREST" ||
    record.biome === "CASTLE" ||
    record.biome === "UNDERWATER" ||
    record.biome === "SPACE" ||
    record.biome === "TREASURE"
      ? record.biome
      : "FOREST";

  const totalNodesRaw =
    typeof record.totalNodes === "number" ? Math.trunc(record.totalNodes) : Number(record.totalNodes);

  return {
    biome,
    totalNodes: Number.isFinite(totalNodesRaw) && totalNodesRaw > 0 ? totalNodesRaw : MAX_STORY_STEPS,
    nodes: parsedNodes.sort((a, b) => a.index - b.index),
  };
}

export type StorySessionInclude = {
  childProfile: {
    select: {
      id: true;
      name: true;
      birthDate: true;
      avatarUrl: true;
    };
  };
  virtue: {
    select: {
      id: true;
      slug: true;
      name: true;
      shortDescription: true;
      iconKey: true;
      sortOrder: true;
    };
  };
  characters: {
    orderBy: {
      createdAt: "asc";
    };
  };
  steps: {
    orderBy: {
      stepIndex: "asc";
    };
  };
  remoteRoom: {
    select: {
      id: true;
      status: true;
      callMode: true;
      maxParticipants: true;
      joinCodeExpiresAt: true;
      joinCodeConsumedAt: true;
      closedAt: true;
      participants: {
        select: {
          id: true;
          role: true;
          displayName: true;
          status: true;
          lastSeenAt: true;
          joinedAt: true;
          leftAt: true;
        };
        orderBy: {
          joinedAt: "asc";
        };
      };
    };
  };
};

export const storySessionInclude: StorySessionInclude = {
  childProfile: {
    select: {
      id: true,
      name: true,
      birthDate: true,
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
  remoteRoom: {
    select: {
      id: true,
      status: true,
      callMode: true,
      maxParticipants: true,
      joinCodeExpiresAt: true,
      joinCodeConsumedAt: true,
      closedAt: true,
      participants: {
        select: {
          id: true,
          role: true,
          displayName: true,
          status: true,
          lastSeenAt: true,
          joinedAt: true,
          leftAt: true,
        },
        orderBy: {
          joinedAt: "asc",
        },
      },
    },
  },
};

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

async function resolveArtStyleIdOrThrow(artStyleId?: string | null) {
  if (artStyleId === undefined) {
    return undefined;
  }

  if (artStyleId === null) {
    return null;
  }

  const artStyle = await prisma.artStyle.findUnique({
    where: {
      id: artStyleId,
    },
    select: {
      id: true,
    },
  });

  if (!artStyle) {
    throw new ApiError("Estilo de ilustracao nao encontrado.", 404, "ART_STYLE_NOT_FOUND");
  }

  return artStyle.id;
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

function toStoryStepDTO(step: {
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
  gameNodeIndex: number | null;
  gameActionKey: string | null;
  gameActionLabel: string | null;
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
    gameNodeIndex: step.gameNodeIndex,
    gameActionKey: step.gameActionKey,
    gameActionLabel: step.gameActionLabel,
    autoSavedAt: step.autoSavedAt,
    createdAt: step.createdAt,
  };
}

export function toStorySessionDTO(story: {
  id: string;
  userId: string;
  childProfileId: string;
  collectionId: string;
  sourceTemplateId: string | null;
  artStyleId: string | null;
  episodeNumber: number;
  continuedFromStoryId: string | null;
  sessionKind: StorySessionKind;
  virtueId: string | null;
  titleDraft: string;
  titleFinal: string | null;
  theme: string;
  scenario: string;
  objective: string;
  ageBand: AgeBand | null;
  virtueSource: VirtueSource | null;
  dilemmaText: string | null;
  endQuestionText: string | null;
  status: StoryStatus;
  currentMode: StoryMode;
  currentStepIndex: number;
  gameMode: StoryGameMode;
  gameSeed: number;
  gameMapVersion: number;
  gameMapJson: unknown;
  ageSnapshotYears: number;
  startedAt: Date;
  publishedAt: Date | null;
  completedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  childProfile: {
    id: string;
    name: string;
    birthDate: Date;
    avatarUrl: string | null;
  };
  virtue: {
    id: string;
    slug: string;
    name: string;
    shortDescription: string;
    iconKey: string;
    sortOrder: number;
  } | null;
  characters: Array<{ id: string; name: string; role: string | null; createdAt: Date }>;
  steps: Array<{
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
    gameNodeIndex: number | null;
    gameActionKey: string | null;
    gameActionLabel: string | null;
    autoSavedAt: Date;
    createdAt: Date;
  }>;
  remoteRoom: {
    id: string;
    status: RemoteRoomStatus;
    callMode: CallMode;
    maxParticipants: number;
    joinCodeExpiresAt: Date;
    joinCodeConsumedAt: Date | null;
    closedAt: Date | null;
    participants: Array<{
      id: string;
      role: string;
      displayName: string;
      status: string;
      lastSeenAt: Date;
      joinedAt: Date;
      leftAt: Date | null;
    }>;
  } | null;
}) {
  const gameMap = normalizeGameMapJson(story.gameMapJson, story.gameSeed);

  return {
    id: story.id,
    userId: story.userId,
    childProfileId: story.childProfileId,
    collectionId: story.collectionId,
    sourceTemplateId: story.sourceTemplateId,
    artStyleId: story.artStyleId,
    episodeNumber: story.episodeNumber,
    continuedFromStoryId: story.continuedFromStoryId,
    sessionKind: story.sessionKind,
    titleDraft: story.titleDraft,
    titleFinal: story.titleFinal,
    title: story.titleFinal ?? story.titleDraft,
    theme: story.theme,
    scenario: story.scenario,
    objective: story.objective,
    ageBand: story.ageBand,
    virtueSource: story.virtueSource,
    dilemmaText: story.dilemmaText,
    endQuestionText: story.endQuestionText,
    virtue: story.virtue,
    status: story.status,
    currentMode: story.currentMode,
    currentStepIndex: story.currentStepIndex,
    game: {
      mode: story.gameMode,
      seed: story.gameSeed,
      mapVersion: story.gameMapVersion,
      map: gameMap,
    },
    ageSnapshotYears: story.ageSnapshotYears,
    startedAt: story.startedAt,
    publishedAt: story.publishedAt,
    completedAt: story.completedAt,
    createdAt: story.createdAt,
    updatedAt: story.updatedAt,
    child: {
      id: story.childProfile.id,
      name: story.childProfile.name,
      birthDate: story.childProfile.birthDate.toISOString(),
      avatarUrl: story.childProfile.avatarUrl,
    },
    characters: story.characters.map((character) => ({
      id: character.id,
      name: character.name,
      role: character.role,
      createdAt: character.createdAt,
    })),
    steps: story.steps.map(toStoryStepDTO),
    remote: story.remoteRoom
      ? {
          id: story.remoteRoom.id,
          status: story.remoteRoom.status,
          callMode: story.remoteRoom.callMode,
          maxParticipants: story.remoteRoom.maxParticipants,
          joinCodeExpiresAt: story.remoteRoom.joinCodeExpiresAt,
          joinCodeConsumedAt: story.remoteRoom.joinCodeConsumedAt,
          closedAt: story.remoteRoom.closedAt,
          isOpen:
            story.remoteRoom.status === "OPEN" || story.remoteRoom.status === "ACTIVE",
          participants: story.remoteRoom.participants.map((participant) => ({
            id: participant.id,
            role: participant.role,
            displayName: participant.displayName,
            status: participant.status,
            lastSeenAt: participant.lastSeenAt,
            joinedAt: participant.joinedAt,
            leftAt: participant.leftAt,
          })),
        }
      : null,
  };
}

async function getOwnedStoryOrThrow(userId: string, storyId: string) {
  const story = await prisma.story.findFirst({
    where: {
      id: storyId,
      userId,
    },
    include: storySessionInclude,
  });

  if (!story) {
    throw new ApiError("Sessao de historia nao encontrada.", 404, "STORY_NOT_FOUND");
  }

  return story;
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
    },
  });

  if (!child) {
    throw new ApiError("Perfil infantil nao encontrado.", 404, "CHILD_NOT_FOUND");
  }

  return child;
}

function resolveOptionCount(context: string) {
  if (/rapido|curto|simples|direto/iu.test(context)) {
    return 2;
  }

  if (/explorar|misterio|labirinto|mapa|pista/iu.test(context)) {
    return 4;
  }

  return 3;
}

function buildChildOptions(input: {
  scenario: string;
  objective: string;
  context: string;
  stepIndex: number;
}) {
  const count = resolveOptionCount(input.context);

  const candidates = [
    `Conversar com calma no cenario ${input.scenario}`,
    `Pedir ajuda para cumprir o objetivo: ${input.objective}`,
    "Tentar um plano criativo com os personagens",
    "Observar pistas antes de decidir",
  ];

  const start = input.stepIndex % candidates.length;
  const rotated = [
    ...candidates.slice(start),
    ...candidates.slice(0, start),
  ].slice(0, count);

  return rotated.map((label, index) => ({
    id: `opt-${index + 1}`,
    label,
  }));
}

export async function createStorySession(
  userId: string,
  input: {
    childProfileId: string;
    titleDraft: string;
    theme: string;
    scenario: string;
    characters: Array<{ name: string; role?: string }>;
    objective: string;
    startMode: StoryMode;
    virtueId?: string;
    sourceTemplateId?: string;
    artStyleId?: string;
  }
) {
  const normalizedTitleDraft = await moderateTextInput({
    value: input.titleDraft,
    scope: "STORY_TEXT",
    field: "titleDraft",
    userId,
  });
  const normalizedTheme = await moderateTextInput({
    value: input.theme,
    scope: "STORY_TEXT",
    field: "theme",
    userId,
  });
  const normalizedScenario = await moderateTextInput({
    value: input.scenario,
    scope: "STORY_TEXT",
    field: "scenario",
    userId,
  });
  const normalizedObjective = await moderateTextInput({
    value: input.objective,
    scope: "STORY_TEXT",
    field: "objective",
    userId,
  });
  const normalizedCharacters = await Promise.all(
    input.characters.map(async (character) => ({
      name: await moderateTextInput({
        value: character.name,
        scope: "STORY_TEXT",
        field: "characterName",
        userId,
      }),
      role: character.role
        ? await moderateTextInput({
            value: character.role,
            scope: "STORY_TEXT",
            field: "characterRole",
            userId,
          })
        : undefined,
    }))
  );

  const safetyContext: Array<{ field: string; value?: string | null }> = [];
  if (input.titleDraft !== undefined) {
    safetyContext.push({ field: "titulo", value: normalizedTitleDraft });
  }
  if (input.theme !== undefined) {
    safetyContext.push({ field: "tema", value: normalizedTheme });
  }
  if (input.scenario !== undefined) {
    safetyContext.push({ field: "cenario", value: normalizedScenario });
  }
  if (input.objective !== undefined) {
    safetyContext.push({ field: "objetivo", value: normalizedObjective });
  }
  if (input.characters !== undefined) {
    safetyContext.push(
      ...normalizedCharacters.map((character) => ({
        field: "personagem",
        value: `${character.name} ${character.role ?? ""}`,
      }))
    );
  }
  if (safetyContext.length > 0) {
    assertSafeContext(safetyContext);
  }

  const child = await getOwnedChildOrThrow(userId, input.childProfileId);
  const sourceTemplate = await resolveTemplateForStoryCreation(input.sourceTemplateId);
  const resolvedArtStyleId = await resolveArtStyleIdOrThrow(input.artStyleId);
  const resolvedVirtueId = input.virtueId ?? sourceTemplate?.virtueId ?? undefined;

  const resolvedVirtue = await resolveVirtueForStoryCreation({
    userId,
    childProfileId: child.id,
    virtueId: resolvedVirtueId,
  });

  const template = await selectVirtueTemplateOrThrow({
    virtueId: resolvedVirtue.virtue.id,
    ageBand: resolvedVirtue.ageBand,
  });

  const now = new Date();

  const created = await prisma.$transaction(async (tx) => {
    const collection = await tx.storyCollection.create({
      data: {
        userId,
        childProfileId: child.id,
        title: normalizedTitleDraft,
        theme: normalizedTheme,
        virtueId: resolvedVirtue.virtue.id,
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
        childProfileId: child.id,
        collectionId: collection.id,
        sourceTemplateId: sourceTemplate?.id ?? null,
        artStyleId: resolvedArtStyleId ?? null,
        episodeNumber: 1,
        virtueId: resolvedVirtue.virtue.id,
        titleDraft: normalizedTitleDraft,
        theme: normalizedTheme,
        scenario: normalizedScenario,
        objective: normalizedObjective,
        ageBand: resolvedVirtue.ageBand,
        virtueSource: resolvedVirtue.virtueSource,
        dilemmaText: template.dilemmaText,
        endQuestionText: template.endQuestionText,
        status: "DRAFT",
        sessionKind: "PRESENTIAL",
        currentMode: input.startMode,
        ageSnapshotYears: calculateAgeYears(child.birthDate),
        startedAt: now,
        characters: {
          create: normalizedCharacters.map((character) => ({
            name: character.name,
            role: character.role,
          })),
        },
      },
      include: storySessionInclude,
    });

    const gameSeed = computeStoryGameSeed({
      storyId: story.id,
      theme: normalizedTheme,
      scenario: normalizedScenario,
      objective: normalizedObjective,
    });

    const gameMap = buildLinearTrailMap(gameSeed);

    return tx.story.update({
      where: {
        id: story.id,
      },
      data: {
        gameMode: "TRAIL_LINEAR",
        gameSeed,
        gameMapVersion: 1,
        gameMapJson: gameMap as never,
      },
      include: storySessionInclude,
    });
  });

  return toStorySessionDTO(created);
}

export async function getStorySession(userId: string, storyId: string) {
  const story = await getOwnedStoryOrThrow(userId, storyId);
  return toStorySessionDTO(story);
}

export async function updateStorySessionSetup(
  userId: string,
  storyId: string,
  input: {
    titleDraft?: string;
    theme?: string;
    scenario?: string;
    objective?: string;
    characters?: Array<{ name: string; role?: string }>;
    virtueId?: string | null;
    sourceTemplateId?: string | null;
    artStyleId?: string | null;
    mode?: StoryMode;
  }
) {
  const story = await prisma.story.findFirst({
    where: {
      id: storyId,
      userId,
    },
    select: {
      id: true,
      status: true,
      childProfileId: true,
      collectionId: true,
      titleDraft: true,
      theme: true,
      scenario: true,
      objective: true,
      virtueId: true,
      sourceTemplateId: true,
      artStyleId: true,
      currentMode: true,
      characters: {
        orderBy: {
          createdAt: "asc",
        },
        select: {
          name: true,
          role: true,
        },
      },
    },
  });

  if (!story) {
    throw new ApiError("Sessao de historia nao encontrada.", 404, "STORY_NOT_FOUND");
  }

  if (story.status !== "DRAFT") {
    throw new ApiError("Apenas sessoes em rascunho podem ser editadas.", 409, "STORY_NOT_DRAFT");
  }

  const normalizedTitleDraft =
    input.titleDraft !== undefined
      ? await moderateTextInput({
          value: input.titleDraft,
          scope: "STORY_TEXT",
          field: "titleDraft",
          userId,
        })
      : story.titleDraft;
  const normalizedTheme =
    input.theme !== undefined
      ? await moderateTextInput({
          value: input.theme,
          scope: "STORY_TEXT",
          field: "theme",
          userId,
        })
      : story.theme;
  const normalizedScenario =
    input.scenario !== undefined
      ? await moderateTextInput({
          value: input.scenario,
          scope: "STORY_TEXT",
          field: "scenario",
          userId,
        })
      : story.scenario;
  const normalizedObjective =
    input.objective !== undefined
      ? await moderateTextInput({
          value: input.objective,
          scope: "STORY_TEXT",
          field: "objective",
          userId,
        })
      : story.objective;
  const normalizedCharacters =
    input.characters !== undefined
      ? await Promise.all(
          input.characters.map(async (character) => ({
            name: await moderateTextInput({
              value: character.name,
              scope: "STORY_TEXT",
              field: "characterName",
              userId,
            }),
            role: character.role
              ? await moderateTextInput({
                  value: character.role,
                  scope: "STORY_TEXT",
                  field: "characterRole",
                  userId,
                })
              : undefined,
          }))
        )
      : story.characters.map((character) => ({
          name: character.name,
          role: character.role ?? undefined,
        }));

  let nextVirtueId = story.virtueId;
  if (input.virtueId !== undefined) {
    if (input.virtueId === null) {
      const resolved = await resolveVirtueForStoryCreation({
        userId,
        childProfileId: story.childProfileId,
      });
      nextVirtueId = resolved.virtue.id;
    } else {
      const resolved = await resolveVirtueForStoryCreation({
        userId,
        childProfileId: story.childProfileId,
        virtueId: input.virtueId,
      });
      nextVirtueId = resolved.virtue.id;
    }
  }

  let nextSourceTemplateId = story.sourceTemplateId;
  if (input.sourceTemplateId !== undefined) {
    if (input.sourceTemplateId === null) {
      nextSourceTemplateId = null;
    } else {
      const resolvedTemplate = await resolveTemplateForStoryCreation(input.sourceTemplateId);
      nextSourceTemplateId = resolvedTemplate?.id ?? null;
    }
  }

  let nextArtStyleId = story.artStyleId;
  const resolvedArtStyle = await resolveArtStyleIdOrThrow(input.artStyleId);
  if (resolvedArtStyle !== undefined) {
    nextArtStyleId = resolvedArtStyle;
  }

  assertSafeContext([
    { field: "titulo", value: normalizedTitleDraft },
    { field: "tema", value: normalizedTheme },
    { field: "cenario", value: normalizedScenario },
    { field: "objetivo", value: normalizedObjective },
    ...normalizedCharacters.map((character) => ({
      field: "personagem",
      value: `${character.name} ${character.role ?? ""}`,
    })),
  ]);

  const mode = input.mode ?? story.currentMode;
  const now = new Date();

  await prisma.$transaction(async (tx) => {
    await tx.story.update({
      where: {
        id: story.id,
      },
      data: {
        titleDraft: normalizedTitleDraft,
        theme: normalizedTheme,
        scenario: normalizedScenario,
        objective: normalizedObjective,
        virtueId: nextVirtueId,
        sourceTemplateId: nextSourceTemplateId,
        artStyleId: nextArtStyleId,
        currentMode: mode,
      },
    });

    if (input.characters !== undefined) {
      await tx.storyCharacter.deleteMany({
        where: {
          storyId: story.id,
        },
      });

      await tx.storyCharacter.createMany({
        data: normalizedCharacters.map((character) => ({
          storyId: story.id,
          name: character.name,
          role: character.role ?? null,
        })),
      });
    }

    await tx.storyCollection.update({
      where: {
        id: story.collectionId,
      },
      data: {
        title: normalizedTitleDraft,
        theme: normalizedTheme,
        virtueId: nextVirtueId,
        lastReferenceAt: now,
      },
    });
  });

  return getStorySession(userId, storyId);
}

export async function updateStoryMode(userId: string, storyId: string, mode: StoryMode) {
  const story = await prisma.story.findFirst({
    where: {
      id: storyId,
      userId,
    },
    select: {
      id: true,
      status: true,
    },
  });

  if (!story) {
    throw new ApiError("Sessao de historia nao encontrada.", 404, "STORY_NOT_FOUND");
  }

  if (story.status !== "DRAFT") {
    throw new ApiError("Apenas sessoes em rascunho aceitam troca de modo.", 409, "STORY_NOT_DRAFT");
  }

  await prisma.story.update({
    where: {
      id: story.id,
    },
    data: {
      currentMode: mode,
    },
  });

  const updated = await getStorySession(userId, storyId);
  await publishStoryModeChangedEvent({
    storyId,
    mode,
  });

  return updated;
}

export async function createStoryStep(
  userId: string,
  storyId: string,
  input: {
    kind: StoryStepKind;
    stepIndex: number;
    narratorText?: string;
    narratorPrompt?: string;
    selectedOptionId?: string;
    selectedOptionLabel?: string;
    gameNodeIndex?: number;
    gameAction?: {
      key: string;
      label: string;
    };
    localEventId: string;
  }
) {
  const baseStorySelect = {
    id: true,
    collectionId: true,
    status: true,
    currentMode: true,
    currentStepIndex: true,
    scenario: true,
    objective: true,
  } as const;

  const story = await (async () => {
    try {
      const storyWithGame = await prisma.story.findFirst({
        where: {
          id: storyId,
          userId,
        },
        select: {
          ...baseStorySelect,
          gameMode: true,
        },
      });

      if (!storyWithGame) {
        return null;
      }

      return {
        ...storyWithGame,
        gameMode: storyWithGame.gameMode ?? "TRAIL_LINEAR",
      };
    } catch (error) {
      if (!isPrismaUnknownFieldOrArgument(error, "gameMode")) {
        throw error;
      }

      const legacyStory = await prisma.story.findFirst({
        where: {
          id: storyId,
          userId,
        },
        select: baseStorySelect,
      });

      if (!legacyStory) {
        return null;
      }

      return {
        ...legacyStory,
        gameMode: "TRAIL_LINEAR" as StoryGameMode,
      };
    }
  })();

  if (!story) {
    throw new ApiError("Sessao de historia nao encontrada.", 404, "STORY_NOT_FOUND");
  }

  if (story.status !== "DRAFT") {
    throw new ApiError("Apenas sessoes em rascunho aceitam novas etapas.", 409, "STORY_NOT_DRAFT");
  }

  if (input.stepIndex > MAX_STORY_STEPS) {
    throw new ApiError(
      `Limite maximo de ${MAX_STORY_STEPS} etapas atingido.`,
      409,
      "STEP_LIMIT_REACHED"
    );
  }

  if (input.stepIndex > story.currentStepIndex + 1) {
    throw new ApiError(
      "Ordem de etapa invalida. Salve a proxima etapa sequencialmente.",
      409,
      "STEP_OUT_OF_ORDER"
    );
  }

  const resolvedGameNodeIndex = input.gameNodeIndex ?? input.stepIndex;
  if (story.gameMode === "TRAIL_LINEAR" && resolvedGameNodeIndex !== input.stepIndex) {
    throw new ApiError(
      "No modo linear, gameNodeIndex deve corresponder ao stepIndex.",
      400,
      "INVALID_GAME_NODE_INDEX"
    );
  }

  const existingAtIndex = await prisma.storyStep.findUnique({
    where: {
      storyId_stepIndex: {
        storyId,
        stepIndex: input.stepIndex,
      },
    },
  });

  if (existingAtIndex) {
    if (existingAtIndex.localEventId === input.localEventId) {
      const result = {
        idempotent: true,
        step: toStoryStepDTO(existingAtIndex),
        story: await getStorySession(userId, storyId),
      };

      await publishStoryStepCreatedEvent({
        storyId,
        step: result.step,
        story: result.story,
        idempotent: result.idempotent,
      });

      return result;
    }

    throw new ApiError(
      "Etapa ja registrada com um evento diferente.",
      409,
      "STEP_ALREADY_EXISTS"
    );
  }

  const moderatedNarratorText = input.narratorText
    ? await moderateTextInput({
        value: input.narratorText,
        scope: "STORY_TEXT",
        field: "narratorText",
        userId,
      })
    : undefined;
  const moderatedNarratorPrompt = input.narratorPrompt
    ? await moderateTextInput({
        value: input.narratorPrompt,
        scope: "STORY_TEXT",
        field: "narratorPrompt",
        userId,
      })
    : undefined;
  const moderatedSelectedOptionLabel = input.selectedOptionLabel
    ? await moderateTextInput({
        value: input.selectedOptionLabel,
        scope: "STORY_TEXT",
        field: "selectedOptionLabel",
        userId,
      })
    : undefined;
  const moderatedGameActionLabel = input.gameAction?.label
    ? await moderateTextInput({
        value: input.gameAction.label,
        scope: "STORY_TEXT",
        field: "gameActionLabel",
        userId,
      })
    : undefined;

  const fallbackNarratorText =
    input.kind === "NARRATION" &&
    !moderatedNarratorText &&
    !moderatedNarratorPrompt &&
    moderatedGameActionLabel
      ? `Ação escolhida: ${moderatedGameActionLabel}.`
      : moderatedNarratorText;

  assertSafeContext([
    { field: "narracao", value: fallbackNarratorText },
    { field: "prompt", value: moderatedNarratorPrompt },
    { field: "escolha", value: moderatedSelectedOptionLabel },
    { field: "acao", value: moderatedGameActionLabel },
  ]);

  const childOptions =
    input.kind === "CHILD_CHOICE"
      ? buildChildOptions({
          scenario: story.scenario,
          objective: story.objective,
          context:
            moderatedSelectedOptionLabel ??
            moderatedGameActionLabel ??
            moderatedNarratorPrompt ??
            fallbackNarratorText ??
            story.objective,
          stepIndex: input.stepIndex,
        })
      : null;

  const now = new Date();

  const created = await prisma.$transaction(async (tx) => {
    const baseStepData = {
      storyId,
      stepIndex: input.stepIndex,
      kind: input.kind,
      modeUsed: story.currentMode,
      localEventId: input.localEventId,
      narratorPrompt: moderatedNarratorPrompt,
      childOptionsJson: childOptions as never,
      selectedOptionId: input.selectedOptionId,
      selectedOptionLabel: moderatedSelectedOptionLabel,
      narratorText: fallbackNarratorText,
      autoSavedAt: now,
    };

    const gameStepData = {
      ...baseStepData,
      gameNodeIndex: resolvedGameNodeIndex,
      gameActionKey: input.gameAction?.key?.trim() || null,
      gameActionLabel: moderatedGameActionLabel ?? null,
    };

    let step;
    try {
      step = await tx.storyStep.create({
        data: gameStepData,
      });
    } catch (error) {
      if (!isPrismaGameFieldCompatibilityError(error)) {
        throw error;
      }

      step = await tx.storyStep.create({
        data: baseStepData,
      });
    }

    await tx.story.update({
      where: {
        id: story.id,
      },
      data: {
        currentStepIndex:
          input.stepIndex > story.currentStepIndex
            ? input.stepIndex
            : story.currentStepIndex,
      },
    });

    await tx.storyCollection.update({
      where: {
        id: story.collectionId,
      },
      data: {
        lastReferenceAt: now,
      },
    });

    return step;
  });

  const result = {
    idempotent: false,
    step: toStoryStepDTO(created),
    story: await getStorySession(userId, storyId),
  };

  await publishStoryStepCreatedEvent({
    storyId,
    step: result.step,
    story: result.story,
    idempotent: result.idempotent,
  });

  return result;
}

export async function requestStoryIdeas(
  userId: string,
  storyId: string,
  input: {
    contextHint?: string;
  }
) {
  const moderatedContextHint = input.contextHint
    ? await moderateTextInput({
        value: input.contextHint,
        scope: "STORY_TEXT",
        field: "contextHint",
        userId,
      })
    : undefined;

  const story = await prisma.story.findFirst({
    where: {
      id: storyId,
      userId,
    },
    include: {
      characters: {
        orderBy: {
          createdAt: "asc",
        },
      },
      steps: {
        orderBy: {
          stepIndex: "desc",
        },
        take: 3,
      },
      virtue: {
        select: {
          name: true,
        },
      },
    },
  });

  if (!story) {
    throw new ApiError("Sessao de historia nao encontrada.", 404, "STORY_NOT_FOUND");
  }

  if (story.status !== "DRAFT") {
    throw new ApiError("Apenas sessoes em rascunho aceitam novas ideias.", 409, "STORY_NOT_DRAFT");
  }

  const lastNarrative = story.steps
    .map((step) => step.narratorText)
    .filter((item): item is string => Boolean(item))
    .at(0);

  const inventory = await getChildInventory(userId, story.childProfileId);
  const memory = await getLatestStoryMemory(userId, story.childProfileId);
  const inventoryItems = inventory
    .filter((item) => item.item.category === "ITEM")
    .map((item) => item.item.name);
  const companions = inventory
    .filter((item) => item.item.category === "COMPANION")
    .map((item) => item.item.name);

  const ideaResult = await generateStoryIdeas({
    theme: story.virtue?.name ? `${story.theme} (${story.virtue.name})` : story.theme,
    scenario: story.scenario,
    objective: story.objective,
    ageSnapshotYears: story.ageSnapshotYears,
    characters: story.characters.map((character) => character.name),
    currentMode: story.currentMode,
    contextHint: moderatedContextHint,
    lastNarrative,
    inventoryItems,
    activeCompanion: companions.length > 0 ? companions[0] : undefined,
    lastMemory: memory?.summary ?? undefined,
  });

  await prisma.storyIdeaLog.create({
    data: {
      storyId,
      stepIndex: story.currentStepIndex,
      source: ideaResult.source,
      safetyAdjusted: ideaResult.safetyAdjusted,
      promptInput: moderatedContextHint,
      ideasJson: ideaResult.ideas as never,
      fallbackReason: ideaResult.fallbackReason,
    },
  });

  return {
    ideas: ideaResult.ideas,
    source: ideaResult.source,
    safetyAdjusted: ideaResult.safetyAdjusted,
  };
}

type StoryPublishPreparation = {
  story: {
    id: string;
    collectionId: string;
    childProfileId: string;
    virtueId: string | null;
    continuedFromStoryId: string | null;
    titleDraft: string;
    theme: string;
    scenario: string;
    objective: string;
    status: StoryStatus;
    dilemmaText: string | null;
    endQuestionText: string | null;
    steps: Array<{ stepIndex: number }>;
    user: { timezone: string | null };
    virtue: { slug: string } | null;
  };
  publishMeta: {
    minimumRequiredSteps: number;
    stepCountBeforePublish: number;
    autoCompletedSteps: number;
    finalStepCount: number;
  };
};

async function prepareStoryForPublish(userId: string, storyId: string): Promise<StoryPublishPreparation> {
  const story = await prisma.story.findFirst({
    where: {
      id: storyId,
      userId,
    },
    select: {
      id: true,
      collectionId: true,
      childProfileId: true,
      virtueId: true,
      continuedFromStoryId: true,
      titleDraft: true,
      theme: true,
      scenario: true,
      objective: true,
      status: true,
      dilemmaText: true,
      endQuestionText: true,
      steps: {
        select: {
          stepIndex: true,
        },
        orderBy: {
          stepIndex: "asc",
        },
      },
      user: {
        select: {
          timezone: true,
        },
      },
      virtue: {
        select: {
          slug: true,
        },
      },
    },
  });

  if (!story) {
    throw new ApiError("Sessao de historia nao encontrada.", 404, "STORY_NOT_FOUND");
  }

  if (story.status !== "DRAFT") {
    throw new ApiError("A sessao ja foi publicada.", 409, "STORY_ALREADY_FINALIZED");
  }

  if (!story.dilemmaText || !story.endQuestionText) {
    throw new ApiError(
      "A historia precisa de dilema e pergunta final para ser publicada.",
      409,
      "VIRTUE_CONTEXT_REQUIRED"
    );
  }

  const stepCountBeforePublish = story.steps.length;
  const existingStepIndexes = new Set(story.steps.map((step) => step.stepIndex));
  let autoCompletedSteps = 0;

  for (let stepIndex = 1; stepIndex <= MIN_STORY_STEPS_TO_PUBLISH; stepIndex += 1) {
    if (existingStepIndexes.has(stepIndex)) {
      continue;
    }

    try {
      await createStoryStep(userId, storyId, {
        kind: "NARRATION",
        stepIndex,
        narratorPrompt: buildWizardAutoPrompt({
          titleDraft: story.titleDraft,
          theme: story.theme,
          scenario: story.scenario,
          objective: story.objective,
          stepIndex,
        }),
        localEventId: `publish-auto-${storyId}-${stepIndex}`,
      });
      autoCompletedSteps += 1;
    } catch (error) {
      if (error instanceof ApiError) {
        if (error.code === "STEP_ALREADY_EXISTS" || error.code === "STEP_OUT_OF_ORDER") {
          continue;
        }
      }
      throw error;
    }
  }

  const finalStepCount = await prisma.storyStep.count({
    where: {
      storyId: story.id,
    },
  });

  if (finalStepCount < MIN_STORY_STEPS_TO_PUBLISH) {
    throw new ApiError(
      `Sao necessarias pelo menos ${MIN_STORY_STEPS_TO_PUBLISH} etapas para publicar.`,
      400,
      "NOT_ENOUGH_STEPS"
    );
  }

  return {
    story,
    publishMeta: {
      minimumRequiredSteps: MIN_STORY_STEPS_TO_PUBLISH,
      stepCountBeforePublish,
      autoCompletedSteps,
      finalStepCount,
    },
  };
}

export async function finalizeStorySession(
  userId: string,
  storyId: string,
  input: {
    titleFinal?: string;
  }
) {
  const prepared = await prepareStoryForPublish(userId, storyId);
  const { story, publishMeta } = prepared;

  const now = new Date();
  const gamification = await prisma.$transaction(async (tx) => {
    await tx.story.update({
      where: {
        id: story.id,
      },
      data: {
        status: "PUBLISHED",
        titleFinal: input.titleFinal ?? story.titleDraft,
        publishedAt: now,
        completedAt: now,
      },
    });

    await tx.storyCollection.update({
      where: {
        id: story.collectionId,
      },
      data: {
        lastReferenceAt: now,
      },
    });

    return processStoryPublished(tx, {
      userId,
      storyId: story.id,
      childProfileId: story.childProfileId,
      virtueId: story.virtueId,
      virtueSlug: story.virtue?.slug ?? null,
      continuedFromStoryId: story.continuedFromStoryId,
      publishedAt: now,
      timezone: story.user.timezone,
      source: "LIVE",
    });
  });

  return {
    status: "PUBLISHED" as const,
    story: await getStoryById(userId, storyId),
    gamification,
    publishMeta,
  };
}

function buildWizardAutoPrompt(input: {
  titleDraft: string;
  theme: string;
  scenario: string;
  objective: string;
  stepIndex: number;
}) {
  return `Etapa ${input.stepIndex}: avance a historia "${input.titleDraft}" com foco em ${input.theme}, no cenario ${input.scenario}, rumo ao objetivo ${input.objective}.`;
}

export async function wizardPublishStorySession(
  userId: string,
  storyId: string,
  input: {
    titleFinal?: string;
  }
) {
  return finalizeStorySession(userId, storyId, input);
}

export async function listStories(
  userId: string,
  filters: {
    childProfileId?: string;
    status?: StoryStatus;
  }
) {
  const stories = await prisma.story.findMany({
    where: {
      userId,
      childProfileId: filters.childProfileId,
      status: filters.status,
    },
    include: {
      childProfile: {
        select: {
          id: true,
          name: true,
        },
      },
      virtue: {
        select: {
          id: true,
          slug: true,
          name: true,
        },
      },
      remoteRoom: {
        select: {
          id: true,
          status: true,
          callMode: true,
        },
      },
      _count: {
        select: {
          steps: true,
        },
      },
    },
    orderBy: {
      updatedAt: "desc",
    },
  });

  return stories.map((story) => ({
    id: story.id,
    childProfileId: story.childProfileId,
    collectionId: story.collectionId,
    sourceTemplateId: story.sourceTemplateId,
    episodeNumber: story.episodeNumber,
    continuedFromStoryId: story.continuedFromStoryId,
    sessionKind: story.sessionKind,
    childName: story.childProfile.name,
    titleDraft: story.titleDraft,
    titleFinal: story.titleFinal,
    title: story.titleFinal ?? story.titleDraft,
    theme: story.theme,
    scenario: story.scenario,
    objective: story.objective,
    ageBand: story.ageBand,
    virtueSource: story.virtueSource,
    dilemmaText: story.dilemmaText,
    endQuestionText: story.endQuestionText,
    virtue: story.virtue,
    remote: story.remoteRoom,
    status: story.status,
    currentMode: story.currentMode,
    currentStepIndex: story.currentStepIndex,
    ageSnapshotYears: story.ageSnapshotYears,
    startedAt: story.startedAt,
    publishedAt: story.publishedAt,
    completedAt: story.completedAt,
    createdAt: story.createdAt,
    updatedAt: story.updatedAt,
    stepsCount: story._count.steps,
  }));
}

export async function getStoryById(userId: string, storyId: string) {
  const story = await getOwnedStoryOrThrow(userId, storyId);
  return toStorySessionDTO(story);
}

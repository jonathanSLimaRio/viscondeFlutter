import type {
  AgeBand,
  CallMode,
  RemoteRoomStatus,
  StoryMode,
  StorySessionKind,
  StoryStatus,
  StoryStepKind,
  VirtueSource,
} from "@prisma/client";

import { prisma } from "@/lib/prisma";
import { ApiError } from "@/lib/server/errors";
import { generateStoryIdeas } from "@/lib/server/story-idea-service";
import { assertSafeContext } from "@/lib/server/story-safety";
import { resolveVirtueForStoryCreation } from "@/lib/server/virtue-service";
import { selectVirtueTemplateOrThrow } from "@/lib/server/virtue-template-service";
import {
  publishStoryModeChangedEvent,
  publishStoryStepCreatedEvent,
} from "@/lib/server/remote-realtime-events";

const MAX_STORY_STEPS = 12;
const MIN_STORY_STEPS_TO_PUBLISH = 3;

type StorySessionInclude = {
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

const storySessionInclude: StorySessionInclude = {
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

function toStorySessionDTO(story: {
  id: string;
  userId: string;
  childProfileId: string;
  collectionId: string;
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
  return {
    id: story.id,
    userId: story.userId,
    childProfileId: story.childProfileId,
    collectionId: story.collectionId,
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
  }
) {
  assertSafeContext([
    { field: "titulo", value: input.titleDraft },
    { field: "tema", value: input.theme },
    { field: "cenario", value: input.scenario },
    { field: "objetivo", value: input.objective },
    ...input.characters.map((character) => ({
      field: "personagem",
      value: `${character.name} ${character.role ?? ""}`,
    })),
  ]);

  const child = await getOwnedChildOrThrow(userId, input.childProfileId);

  const resolvedVirtue = await resolveVirtueForStoryCreation({
    userId,
    childProfileId: child.id,
    virtueId: input.virtueId,
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
        title: input.titleDraft,
        theme: input.theme,
        virtueId: resolvedVirtue.virtue.id,
        isFavorite: false,
        lastReferenceAt: now,
      },
      select: {
        id: true,
      },
    });

    return tx.story.create({
      data: {
        userId,
        childProfileId: child.id,
        collectionId: collection.id,
        episodeNumber: 1,
        virtueId: resolvedVirtue.virtue.id,
        titleDraft: input.titleDraft,
        theme: input.theme,
        scenario: input.scenario,
        objective: input.objective,
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
          create: input.characters.map((character) => ({
            name: character.name,
            role: character.role,
          })),
        },
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
    localEventId: string;
  }
) {
  const story = await prisma.story.findFirst({
    where: {
      id: storyId,
      userId,
    },
    select: {
      id: true,
      collectionId: true,
      status: true,
      currentMode: true,
      currentStepIndex: true,
      scenario: true,
      objective: true,
    },
  });

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

  assertSafeContext([
    { field: "narracao", value: input.narratorText },
    { field: "prompt", value: input.narratorPrompt },
    { field: "escolha", value: input.selectedOptionLabel },
  ]);

  const childOptions =
    input.kind === "CHILD_CHOICE"
      ? buildChildOptions({
          scenario: story.scenario,
          objective: story.objective,
          context:
            input.selectedOptionLabel ??
            input.narratorPrompt ??
            input.narratorText ??
            story.objective,
          stepIndex: input.stepIndex,
        })
      : null;

  const now = new Date();

  const created = await prisma.$transaction(async (tx) => {
    const step = await tx.storyStep.create({
      data: {
        storyId,
        stepIndex: input.stepIndex,
        kind: input.kind,
        modeUsed: story.currentMode,
        localEventId: input.localEventId,
        narratorPrompt: input.narratorPrompt,
        childOptionsJson: childOptions as never,
        selectedOptionId: input.selectedOptionId,
        selectedOptionLabel: input.selectedOptionLabel,
        narratorText: input.narratorText,
        autoSavedAt: now,
      },
    });

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

  const ideaResult = await generateStoryIdeas({
    theme: story.virtue?.name ? `${story.theme} (${story.virtue.name})` : story.theme,
    scenario: story.scenario,
    objective: story.objective,
    ageSnapshotYears: story.ageSnapshotYears,
    characters: story.characters.map((character) => character.name),
    currentMode: story.currentMode,
    contextHint: input.contextHint,
    lastNarrative,
  });

  await prisma.storyIdeaLog.create({
    data: {
      storyId,
      stepIndex: story.currentStepIndex,
      source: ideaResult.source,
      safetyAdjusted: ideaResult.safetyAdjusted,
      promptInput: input.contextHint,
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

export async function finalizeStorySession(
  userId: string,
  storyId: string,
  input: {
    titleFinal?: string;
  }
) {
  const story = await prisma.story.findFirst({
    where: {
      id: storyId,
      userId,
    },
    include: {
      _count: {
        select: {
          steps: true,
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

  if (story._count.steps < MIN_STORY_STEPS_TO_PUBLISH) {
    throw new ApiError(
      `Sao necessarias pelo menos ${MIN_STORY_STEPS_TO_PUBLISH} etapas para publicar.`,
      400,
      "NOT_ENOUGH_STEPS"
    );
  }

  const now = new Date();

  await prisma.story.update({
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

  await prisma.storyCollection.update({
    where: {
      id: story.collectionId,
    },
    data: {
      lastReferenceAt: now,
    },
  });

  return {
    status: "PUBLISHED" as const,
    story: await getStoryById(userId, storyId),
  };
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

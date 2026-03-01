import { createHash, randomInt } from "node:crypto";

import type {
  CallMode,
  InteractionType,
  RemoteParticipantRole,
  RemoteRoomStatus,
  StoryStepKind,
} from "@prisma/client";

import { prisma } from "@/lib/prisma";
import { ApiError } from "@/lib/server/errors";
import { moderateTextInput } from "@/lib/server/moderation-service";
import { getUserAgent } from "@/lib/server/request";
import {
  assertRealtimeGatewayAvailable,
  buildJoinLink,
  buildRtcConfig,
  getRealtimePublicWsUrl,
  publishRealtimeRoomEvent,
} from "@/lib/server/realtime-gateway";
import { createStoryStep, getStorySession } from "@/lib/server/story-service";
import {
  type ParticipantAccessContext,
  type UserOrParticipantAccessContext,
} from "@/lib/server/remote-auth";
import { env } from "@/lib/server/env";
import { signRemoteParticipantToken } from "@/lib/server/jwt";

const JOIN_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const JOIN_CODE_LENGTH = 6;

function generateJoinCode() {
  let output = "";
  for (let i = 0; i < JOIN_CODE_LENGTH; i += 1) {
    const index = randomInt(0, JOIN_CODE_ALPHABET.length);
    output += JOIN_CODE_ALPHABET[index] ?? "A";
  }
  return output;
}

function normalizeJoinCode(code: string) {
  return code.replace(/[^A-Za-z0-9]/g, "").toUpperCase();
}

function hashJoinCode(code: string) {
  return createHash("sha256").update(code).digest("hex");
}

function toRemoteRoomDTO(room: {
  id: string;
  status: RemoteRoomStatus;
  callMode: CallMode;
  maxParticipants: number;
  joinCodeExpiresAt: Date;
  joinCodeConsumedAt: Date | null;
  closedAt: Date | null;
  participants: Array<{
    id: string;
    role: RemoteParticipantRole;
    displayName: string;
    status: string;
    lastSeenAt: Date;
    joinedAt: Date;
    leftAt: Date | null;
  }>;
}) {
  return {
    id: room.id,
    status: room.status,
    callMode: room.callMode,
    maxParticipants: room.maxParticipants,
    joinCodeExpiresAt: room.joinCodeExpiresAt,
    joinCodeConsumedAt: room.joinCodeConsumedAt,
    closedAt: room.closedAt,
    isOpen: room.status === "OPEN" || room.status === "ACTIVE",
    participants: room.participants
      .map((participant) => ({
        id: participant.id,
        role: participant.role,
        displayName: participant.displayName,
        status: participant.status,
        lastSeenAt: participant.lastSeenAt,
        joinedAt: participant.joinedAt,
        leftAt: participant.leftAt,
      }))
      .sort((left, right) => left.role.localeCompare(right.role)),
  };
}

function getHostDisplayName(userName: string | null | undefined) {
  const normalized = userName?.trim();
  if (normalized) {
    return normalized;
  }
  return "Responsavel";
}

async function getOwnedDraftStoryOrThrow(userId: string, storyId: string) {
  const story = await prisma.story.findFirst({
    where: {
      id: storyId,
      userId,
    },
    select: {
      id: true,
      userId: true,
      status: true,
      currentMode: true,
      currentStepIndex: true,
      titleDraft: true,
      titleFinal: true,
      user: {
        select: {
          name: true,
        },
      },
      remoteRoom: {
        include: {
          participants: {
            orderBy: {
              joinedAt: "asc",
            },
          },
        },
      },
    },
  });

  if (!story) {
    throw new ApiError("Sessao de historia nao encontrada.", 404, "STORY_NOT_FOUND");
  }

  if (story.status !== "DRAFT") {
    throw new ApiError("Apenas historias em rascunho permitem sala remota.", 409, "STORY_NOT_DRAFT");
  }

  return story;
}

function assertRoomIsOpenStatus(status: RemoteRoomStatus) {
  if (status !== "OPEN" && status !== "ACTIVE") {
    throw new ApiError("Sala remota indisponivel.", 409, "REMOTE_ROOM_CLOSED");
  }
}

async function ensureParticipantInRoom(input: {
  participant: ParticipantAccessContext;
  storyId: string;
}) {
  const row = await prisma.remoteStoryParticipant.findFirst({
    where: {
      id: input.participant.participantId,
      remoteRoomId: input.participant.remoteRoomId,
      role: input.participant.role,
      remoteRoom: {
        storyId: input.storyId,
      },
    },
    include: {
      remoteRoom: {
        include: {
          participants: {
            orderBy: {
              joinedAt: "asc",
            },
          },
          story: {
            select: {
              id: true,
              userId: true,
              status: true,
              currentMode: true,
            },
          },
        },
      },
    },
  });

  if (!row) {
    throw new ApiError("Participante remoto invalido.", 401, "REMOTE_PARTICIPANT_INVALID");
  }

  assertRoomIsOpenStatus(row.remoteRoom.status);

  if (row.remoteRoom.story.status !== "DRAFT") {
    throw new ApiError("A historia nao aceita interacoes remotas.", 409, "STORY_NOT_DRAFT");
  }

  if (row.status === "LEFT") {
    throw new ApiError("Participante saiu da sala remota.", 401, "REMOTE_PARTICIPANT_LEFT");
  }

  await prisma.remoteStoryParticipant.update({
    where: {
      id: row.id,
    },
    data: {
      status: "CONNECTED",
      lastSeenAt: new Date(),
    },
  });

  return row;
}

async function resolveRemoteActorForInteraction(input: {
  auth: UserOrParticipantAccessContext;
  storyId: string;
}) {
  if (input.auth.kind === "user") {
    const room = await prisma.remoteStoryRoom.findFirst({
      where: {
        storyId: input.storyId,
        ownerUserId: input.auth.userId,
      },
      include: {
        story: {
          select: {
            id: true,
            status: true,
          },
        },
        participants: {
          orderBy: {
            joinedAt: "asc",
          },
        },
        owner: {
          select: {
            id: true,
            name: true,
          },
        },
      },
    });

    if (!room) {
      throw new ApiError("Sala remota nao encontrada.", 404, "REMOTE_ROOM_NOT_FOUND");
    }

    assertRoomIsOpenStatus(room.status);

    if (room.story.status !== "DRAFT") {
      throw new ApiError("A historia nao aceita interacoes remotas.", 409, "STORY_NOT_DRAFT");
    }

    const hostParticipant = await prisma.remoteStoryParticipant.upsert({
      where: {
        remoteRoomId_role: {
          remoteRoomId: room.id,
          role: "HOST_PARENT",
        },
      },
      update: {
        displayName: getHostDisplayName(room.owner.name),
        status: "CONNECTED",
        lastSeenAt: new Date(),
      },
      create: {
        remoteRoomId: room.id,
        role: "HOST_PARENT",
        displayName: getHostDisplayName(room.owner.name),
        status: "CONNECTED",
        lastSeenAt: new Date(),
      },
    });

    return {
      storyOwnerUserId: room.ownerUserId,
      remoteRoomId: room.id,
      authorRole: "HOST_PARENT" as const,
      authorUserId: input.auth.userId,
      authorParticipantId: hostParticipant.id,
      authorDisplayName: hostParticipant.displayName,
    };
  }

  const participant = await ensureParticipantInRoom({
    participant: input.auth,
    storyId: input.storyId,
  });

  return {
    storyOwnerUserId: participant.remoteRoom.story.userId,
    remoteRoomId: participant.remoteRoom.id,
    authorRole: participant.role,
    authorUserId: null,
    authorParticipantId: participant.id,
    authorDisplayName: participant.displayName,
  };
}

async function publishPresenceUpdate(remoteRoomId: string) {
  const participants = await prisma.remoteStoryParticipant.findMany({
    where: {
      remoteRoomId,
    },
    orderBy: {
      joinedAt: "asc",
    },
    select: {
      id: true,
      role: true,
      displayName: true,
      status: true,
      lastSeenAt: true,
    },
  });

  await publishRealtimeRoomEvent({
    remoteRoomId,
    event: "presence.updated",
    payload: {
      participants,
    },
  });
}

export async function openRemoteRoom(
  userId: string,
  storyId: string,
  input: { callMode?: CallMode }
) {
  await assertRealtimeGatewayAvailable();

  const story = await getOwnedDraftStoryOrThrow(userId, storyId);
  const joinCode = generateJoinCode();
  const joinCodeHash = hashJoinCode(joinCode);
  const joinCodeExpiresAt = new Date(Date.now() + env.remoteJoinCodeTtlMinutes * 60 * 1000);

  const savedRoom = await prisma.$transaction(async (tx) => {
    const room = await tx.remoteStoryRoom.upsert({
      where: {
        storyId,
      },
      update: {
        ownerUserId: userId,
        status: "OPEN",
        joinCodeHash,
        joinCodeExpiresAt,
        joinCodeConsumedAt: null,
        callMode: input.callMode ?? "AUDIO",
        maxParticipants: 2,
        closedAt: null,
      },
      create: {
        storyId,
        ownerUserId: userId,
        status: "OPEN",
        joinCodeHash,
        joinCodeExpiresAt,
        joinCodeConsumedAt: null,
        callMode: input.callMode ?? "AUDIO",
        maxParticipants: 2,
      },
      include: {
        participants: {
          orderBy: {
            joinedAt: "asc",
          },
        },
      },
    });

    await tx.remoteStoryParticipant.upsert({
      where: {
        remoteRoomId_role: {
          remoteRoomId: room.id,
          role: "HOST_PARENT",
        },
      },
      update: {
        displayName: getHostDisplayName(story.user.name),
        status: "CONNECTED",
        lastSeenAt: new Date(),
        leftAt: null,
      },
      create: {
        remoteRoomId: room.id,
        role: "HOST_PARENT",
        displayName: getHostDisplayName(story.user.name),
        status: "CONNECTED",
        lastSeenAt: new Date(),
      },
    });

    await tx.remoteStoryParticipant.updateMany({
      where: {
        remoteRoomId: room.id,
        role: "GUEST_CHILD",
      },
      data: {
        status: "LEFT",
        leftAt: new Date(),
      },
    });

    await tx.story.update({
      where: { id: storyId },
      data: {
        sessionKind: "REMOTE",
      },
    });

    return tx.remoteStoryRoom.findUniqueOrThrow({
      where: {
        id: room.id,
      },
      include: {
        participants: {
          orderBy: {
            joinedAt: "asc",
          },
        },
      },
    });
  });

  const hostParticipant = savedRoom.participants.find(
    (participant) => participant.role === "HOST_PARENT"
  );

  if (!hostParticipant) {
    throw new ApiError("Participante host nao encontrado.", 500, "REMOTE_HOST_NOT_FOUND");
  }

  const hostParticipantToken = await signRemoteParticipantToken({
    storyId,
    remoteRoomId: savedRoom.id,
    participantId: hostParticipant.id,
    role: "HOST_PARENT",
  });

  await publishPresenceUpdate(savedRoom.id);

  return {
    joinCode,
    joinLink: buildJoinLink(joinCode),
    hostParticipantToken,
    signalingWsUrl: getRealtimePublicWsUrl(),
    rtcConfig: buildRtcConfig(),
    expiresAt: savedRoom.joinCodeExpiresAt,
    remoteRoom: toRemoteRoomDTO(savedRoom),
  };
}

export async function regenerateRemoteRoomCode(userId: string, storyId: string) {
  await assertRealtimeGatewayAvailable();

  const room = await prisma.remoteStoryRoom.findFirst({
    where: {
      storyId,
      ownerUserId: userId,
    },
    include: {
      participants: {
        orderBy: {
          joinedAt: "asc",
        },
      },
      story: {
        select: {
          status: true,
        },
      },
    },
  });

  if (!room) {
    throw new ApiError("Sala remota nao encontrada.", 404, "REMOTE_ROOM_NOT_FOUND");
  }

  if (room.story.status !== "DRAFT") {
    throw new ApiError("A historia nao aceita sala remota.", 409, "STORY_NOT_DRAFT");
  }

  const joinCode = generateJoinCode();
  const joinCodeHash = hashJoinCode(joinCode);
  const joinCodeExpiresAt = new Date(Date.now() + env.remoteJoinCodeTtlMinutes * 60 * 1000);

  const updated = await prisma.$transaction(async (tx) => {
    await tx.remoteStoryRoom.update({
      where: {
        id: room.id,
      },
      data: {
        status: "OPEN",
        joinCodeHash,
        joinCodeExpiresAt,
        joinCodeConsumedAt: null,
        closedAt: null,
      },
    });

    await tx.remoteStoryParticipant.updateMany({
      where: {
        remoteRoomId: room.id,
        role: "GUEST_CHILD",
      },
      data: {
        status: "LEFT",
        leftAt: new Date(),
      },
    });

    return tx.remoteStoryRoom.findUniqueOrThrow({
      where: {
        id: room.id,
      },
      include: {
        participants: {
          orderBy: {
            joinedAt: "asc",
          },
        },
      },
    });
  });

  const hostParticipant = updated.participants.find(
    (participant) => participant.role === "HOST_PARENT"
  );

  if (!hostParticipant) {
    throw new ApiError("Participante host nao encontrado.", 500, "REMOTE_HOST_NOT_FOUND");
  }

  const hostParticipantToken = await signRemoteParticipantToken({
    storyId,
    remoteRoomId: updated.id,
    participantId: hostParticipant.id,
    role: "HOST_PARENT",
  });

  await publishRealtimeRoomEvent({
    remoteRoomId: updated.id,
    event: "remote.code.regenerated",
    payload: {
      expiresAt: updated.joinCodeExpiresAt,
    },
  });

  return {
    joinCode,
    joinLink: buildJoinLink(joinCode),
    hostParticipantToken,
    signalingWsUrl: getRealtimePublicWsUrl(),
    rtcConfig: buildRtcConfig(),
    expiresAt: updated.joinCodeExpiresAt,
    remoteRoom: toRemoteRoomDTO(updated),
  };
}

export async function closeRemoteRoom(userId: string, storyId: string) {
  const room = await prisma.remoteStoryRoom.findFirst({
    where: {
      storyId,
      ownerUserId: userId,
    },
    include: {
      participants: {
        orderBy: {
          joinedAt: "asc",
        },
      },
    },
  });

  if (!room) {
    throw new ApiError("Sala remota nao encontrada.", 404, "REMOTE_ROOM_NOT_FOUND");
  }

  const now = new Date();

  const updated = await prisma.$transaction(async (tx) => {
    await tx.remoteStoryRoom.update({
      where: {
        id: room.id,
      },
      data: {
        status: "CLOSED",
        closedAt: now,
      },
    });

    await tx.remoteStoryParticipant.updateMany({
      where: {
        remoteRoomId: room.id,
      },
      data: {
        status: "LEFT",
        leftAt: now,
      },
    });

    await tx.story.update({
      where: {
        id: storyId,
      },
      data: {
        sessionKind: "PRESENTIAL",
      },
    });

    return tx.remoteStoryRoom.findUniqueOrThrow({
      where: {
        id: room.id,
      },
      include: {
        participants: {
          orderBy: {
            joinedAt: "asc",
          },
        },
      },
    });
  });

  await publishRealtimeRoomEvent({
    remoteRoomId: room.id,
    event: "remote.closed",
    payload: {
      storyId,
      closedAt: now,
    },
  });

  return {
    remoteRoom: toRemoteRoomDTO(updated),
  };
}

export async function getRemoteRoomState(userId: string, storyId: string) {
  await getOwnedDraftStoryOrThrow(userId, storyId);

  const room = await prisma.remoteStoryRoom.findFirst({
    where: {
      storyId,
      ownerUserId: userId,
    },
    include: {
      participants: {
        orderBy: {
          joinedAt: "asc",
        },
      },
    },
  });

  if (!room) {
    throw new ApiError("Sala remota nao encontrada.", 404, "REMOTE_ROOM_NOT_FOUND");
  }

  const hostParticipant = room.participants.find(
    (participant) => participant.role === "HOST_PARENT"
  );
  if (!hostParticipant) {
    throw new ApiError("Participante host nao encontrado.", 500, "REMOTE_HOST_NOT_FOUND");
  }

  const hostParticipantToken = await signRemoteParticipantToken({
    storyId,
    remoteRoomId: room.id,
    participantId: hostParticipant.id,
    role: "HOST_PARENT",
  });

  const storySnapshot = await getStorySession(userId, storyId);

  return {
    remoteRoom: toRemoteRoomDTO(room),
    storySnapshot,
    hostParticipantToken,
    signalingWsUrl: getRealtimePublicWsUrl(),
    rtcConfig: buildRtcConfig(),
  };
}

export async function joinRemoteRoomByCode(input: {
  code: string;
  displayName: string;
  request: Request;
}) {
  await assertRealtimeGatewayAvailable();

  const normalizedCode = normalizeJoinCode(input.code);
  const joinCodeHash = hashJoinCode(normalizedCode);

  const room = await prisma.remoteStoryRoom.findFirst({
    where: {
      joinCodeHash,
      status: {
        in: ["OPEN", "ACTIVE"],
      },
      joinCodeExpiresAt: {
        gt: new Date(),
      },
      closedAt: null,
    },
    include: {
      story: {
        select: {
          id: true,
          userId: true,
          status: true,
        },
      },
      participants: {
        orderBy: {
          joinedAt: "asc",
        },
      },
    },
  });

  if (!room || room.joinCodeConsumedAt) {
    throw new ApiError("Codigo de sala invalido ou expirado.", 400, "ROOM_CODE_INVALID");
  }

  if (room.story.status !== "DRAFT") {
    throw new ApiError("A sala remota desta historia nao esta mais ativa.", 409, "STORY_NOT_DRAFT");
  }

  const connectedCount = room.participants.filter((participant) => participant.status !== "LEFT").length;
  if (connectedCount >= room.maxParticipants) {
    throw new ApiError("Sala remota lotada para o MVP 1:1.", 409, "REMOTE_ROOM_FULL");
  }

  const userAgent = getUserAgent(input.request);
  const safeDisplayName = input.displayName.trim();

  const updatedRoom = await prisma.$transaction(async (tx) => {
    const participant = await tx.remoteStoryParticipant.upsert({
      where: {
        remoteRoomId_role: {
          remoteRoomId: room.id,
          role: "GUEST_CHILD",
        },
      },
      update: {
        displayName: safeDisplayName,
        status: "CONNECTED",
        joinedAt: new Date(),
        leftAt: null,
        lastSeenAt: new Date(),
        deviceInfo: userAgent,
      },
      create: {
        remoteRoomId: room.id,
        role: "GUEST_CHILD",
        displayName: safeDisplayName,
        status: "CONNECTED",
        lastSeenAt: new Date(),
        deviceInfo: userAgent,
      },
    });

    await tx.remoteStoryRoom.update({
      where: {
        id: room.id,
      },
      data: {
        status: "ACTIVE",
        joinCodeConsumedAt: new Date(),
      },
    });

    await tx.remoteStoryParticipant.updateMany({
      where: {
        remoteRoomId: room.id,
        role: "HOST_PARENT",
      },
      data: {
        status: "CONNECTED",
        lastSeenAt: new Date(),
      },
    });

    const nextRoom = await tx.remoteStoryRoom.findUniqueOrThrow({
      where: {
        id: room.id,
      },
      include: {
        participants: {
          orderBy: {
            joinedAt: "asc",
          },
        },
      },
    });

    return {
      participant,
      room: nextRoom,
    };
  });

  const guestParticipantToken = await signRemoteParticipantToken({
    storyId: room.story.id,
    remoteRoomId: room.id,
    participantId: updatedRoom.participant.id,
    role: "GUEST_CHILD",
  });

  const storySnapshot = await getStorySession(room.story.userId, room.story.id);

  await publishPresenceUpdate(room.id);

  return {
    guestParticipantToken,
    remoteRoom: toRemoteRoomDTO(updatedRoom.room),
    storySnapshot,
    signalingWsUrl: getRealtimePublicWsUrl(),
    rtcConfig: buildRtcConfig(),
  };
}

export async function createRemoteStepByParticipant(
  participant: ParticipantAccessContext,
  storyId: string,
  input: {
    kind: StoryStepKind;
    stepIndex: number;
    selectedOptionId?: string;
    selectedOptionLabel?: string;
    localEventId: string;
  }
) {
  if (participant.role !== "GUEST_CHILD") {
    throw new ApiError("Somente convidado infantil pode enviar escolha remota.", 403, "REMOTE_FORBIDDEN");
  }

  if (input.kind !== "CHILD_CHOICE") {
    throw new ApiError("Somente etapa CHILD_CHOICE e permitida remotamente.", 400, "REMOTE_STEP_KIND_INVALID");
  }

  const row = await ensureParticipantInRoom({
    participant,
    storyId,
  });

  if (row.remoteRoom.story.currentMode !== "CHILD_CHOOSER") {
    throw new ApiError(
      "A historia nao esta em modo de escolha da crianca no momento.",
      409,
      "REMOTE_CHILD_MODE_REQUIRED"
    );
  }

  const result = await createStoryStep(row.remoteRoom.story.userId, storyId, {
    kind: "CHILD_CHOICE",
    stepIndex: input.stepIndex,
    selectedOptionId: input.selectedOptionId,
    selectedOptionLabel: input.selectedOptionLabel,
    localEventId: input.localEventId,
  });

  return result;
}

export async function createStoryInteraction(
  auth: UserOrParticipantAccessContext,
  storyId: string,
  input: {
    type: InteractionType;
    messageText?: string;
    emoji?: string;
  }
) {
  const moderatedMessageText =
    input.type === "CHAT" && input.messageText
      ? await moderateTextInput({
          value: input.messageText,
          scope: "CHAT_TEXT",
          field: "messageText",
        })
      : input.messageText;

  const actor = await resolveRemoteActorForInteraction({
    auth,
    storyId,
  });

  const interaction = await prisma.storyInteraction.create({
    data: {
      storyId,
      remoteRoomId: actor.remoteRoomId,
      type: input.type,
      authorRole: actor.authorRole,
      authorUserId: actor.authorUserId,
      authorParticipantId: actor.authorParticipantId,
      authorDisplayName: actor.authorDisplayName,
      messageText: moderatedMessageText,
      emoji: input.emoji,
    },
  });

  await publishRealtimeRoomEvent({
    remoteRoomId: actor.remoteRoomId,
    event: input.type === "CHAT" ? "chat.created" : "reaction.created",
    payload: {
      interaction,
    },
  });

  return interaction;
}

export async function getStoryInteractionsForAdult(userId: string, storyId: string) {
  const story = await prisma.story.findFirst({
    where: {
      id: storyId,
      userId,
    },
    select: {
      id: true,
      titleDraft: true,
      titleFinal: true,
      remoteRoom: {
        select: {
          id: true,
        },
      },
    },
  });

  if (!story) {
    throw new ApiError("Historia nao encontrada.", 404, "STORY_NOT_FOUND");
  }

  const interactions = await prisma.storyInteraction.findMany({
    where: {
      storyId,
    },
    orderBy: {
      createdAt: "asc",
    },
    select: {
      id: true,
      type: true,
      authorRole: true,
      authorDisplayName: true,
      messageText: true,
      emoji: true,
      createdAt: true,
    },
  });

  return {
    story: {
      id: story.id,
      title: story.titleFinal ?? story.titleDraft,
      remoteRoomId: story.remoteRoom?.id ?? null,
    },
    interactions,
  };
}

export async function assertHostOrParticipantCanCloseRoom(
  auth: UserOrParticipantAccessContext,
  storyId: string
) {
  if (auth.kind === "user") {
    const room = await prisma.remoteStoryRoom.findFirst({
      where: {
        storyId,
        ownerUserId: auth.userId,
      },
      select: {
        id: true,
      },
    });

    if (!room) {
      throw new ApiError("Sala remota nao encontrada.", 404, "REMOTE_ROOM_NOT_FOUND");
    }

    return {
      ownerUserId: auth.userId,
    };
  }

  if (auth.role !== "HOST_PARENT") {
    throw new ApiError("Somente host pode encerrar a sala remota.", 403, "REMOTE_FORBIDDEN");
  }

  const participant = await ensureParticipantInRoom({
    participant: auth,
    storyId,
  });

  return {
    ownerUserId: participant.remoteRoom.story.userId,
  };
}

export async function touchParticipantHeartbeat(participant: ParticipantAccessContext) {
  await prisma.remoteStoryParticipant.updateMany({
    where: {
      id: participant.participantId,
      remoteRoomId: participant.remoteRoomId,
    },
    data: {
      lastSeenAt: new Date(),
      status: "CONNECTED",
    },
  });
}

export async function createCoopVoteByParticipant(
  participant: ParticipantAccessContext,
  storyId: string,
  input: {
    stepIndex: number;
    optionId: string;
    optionLabel: string;
  }
) {
  if (participant.role !== "GUEST_CHILD") {
    throw new ApiError("Somente convidado infantil pode votar.", 403, "REMOTE_FORBIDDEN");
  }

  const row = await ensureParticipantInRoom({
    participant,
    storyId,
  });

  if (row.remoteRoom.story.currentMode !== "CHILD_CHOOSER") {
    throw new ApiError(
      "A historia nao esta em modo de escolha.",
      409,
      "REMOTE_CHILD_MODE_REQUIRED"
    );
  }

  // 1. Record the vote
  const vote = await prisma.storyVote.upsert({
    where: {
      storyId_stepIndex_participantId: {
        storyId,
        stepIndex: input.stepIndex,
        participantId: participant.participantId,
      },
    },
    update: {
      optionId: input.optionId,
      optionLabel: input.optionLabel,
    },
    create: {
      storyId,
      stepIndex: input.stepIndex,
      participantId: participant.participantId,
      optionId: input.optionId,
      optionLabel: input.optionLabel,
    },
  });

  // 2. Publish vote registered event
  await publishRealtimeRoomEvent({
    remoteRoomId: row.remoteRoom.id,
    event: "vote.registered",
    payload: {
      participantId: participant.participantId,
      displayName: row.displayName,
      stepIndex: input.stepIndex,
      optionId: input.optionId,
    },
  });

  // 3. Check if all connected guest children have voted
  const connectedGuests = await prisma.remoteStoryParticipant.count({
    where: {
      remoteRoomId: row.remoteRoom.id,
      role: "GUEST_CHILD",
      status: "CONNECTED",
    },
  });

  const votesAtStep = await prisma.storyVote.findMany({
    where: {
      storyId,
      stepIndex: input.stepIndex,
    },
  });

  if (votesAtStep.length >= connectedGuests && connectedGuests > 0) {
    // Everyone voted! Compute winner.
    const counts: Record<string, { label: string; count: number }> = {};
    for (const v of votesAtStep) {
      if (!counts[v.optionId]) {
        counts[v.optionId] = { label: v.optionLabel, count: 0 };
      }
      counts[v.optionId].count += 1;
    }

    let winnerId = votesAtStep[0].optionId;
    let winnerLabel = votesAtStep[0].optionLabel;
    let maxVotes = 0;

    for (const [id, data] of Object.entries(counts)) {
      if (data.count > maxVotes) {
        maxVotes = data.count;
        winnerId = id;
        winnerLabel = data.label;
      } else if (data.count === maxVotes) {
        // Simple tie-breaker: random 50/50
        if (Math.random() > 0.5) {
          winnerId = id;
          winnerLabel = data.label;
        }
      }
    }

    // Attempt to create the step. If it fails, another node might have done it.
    try {
      const stepResult = await createStoryStep(row.remoteRoom.story.userId, storyId, {
        kind: "CHILD_CHOICE",
        stepIndex: input.stepIndex,
        selectedOptionId: winnerId,
        selectedOptionLabel: winnerLabel,
        localEventId: `coop-vote-${input.stepIndex}-${winnerId}`,
      });

      return {
        isVoteLogged: true,
        allVoted: true,
        stepResult,
      };
    } catch (e) {
      // Ignore if step already generated
      console.warn("Failed to generate step after coop vote:", e);
    }
  }

  return {
    isVoteLogged: true,
    allVoted: false,
  };
}

import { prisma } from "@/lib/prisma";
import { publishRealtimeRoomEvent } from "@/lib/server/realtime-gateway";

async function findActiveRemoteRoomIdByStory(storyId: string) {
  const room = await prisma.remoteStoryRoom.findFirst({
    where: {
      storyId,
      status: {
        in: ["OPEN", "ACTIVE"],
      },
    },
    select: {
      id: true,
    },
  });

  return room?.id ?? null;
}

export async function publishStoryModeChangedEvent(input: {
  storyId: string;
  mode: string;
}) {
  const remoteRoomId = await findActiveRemoteRoomIdByStory(input.storyId);
  if (!remoteRoomId) {
    return;
  }

  await publishRealtimeRoomEvent({
    remoteRoomId,
    event: "story.mode.changed",
    payload: {
      storyId: input.storyId,
      mode: input.mode,
    },
  });
}

export async function publishStoryStepCreatedEvent(input: {
  storyId: string;
  step: unknown;
  story: unknown;
  idempotent: boolean;
}) {
  const remoteRoomId = await findActiveRemoteRoomIdByStory(input.storyId);
  if (!remoteRoomId) {
    return;
  }

  await publishRealtimeRoomEvent({
    remoteRoomId,
    event: "story.step.created",
    payload: {
      storyId: input.storyId,
      step: input.step,
      story: input.story,
      idempotent: input.idempotent,
    },
  });
}

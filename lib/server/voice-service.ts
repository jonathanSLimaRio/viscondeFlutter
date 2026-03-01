import { prisma } from "@/lib/server/db";
import { z } from "zod";

export const createVoiceProfileSchema = z.object({
  name: z.string().trim().min(1).max(120),
  relationship: z.string().trim().min(1).max(120).optional(),
});

export const addVoiceSampleSchema = z.object({
  storageUrl: z.string().url().max(1000),
  duration: z.number().optional(),
  transcript: z.string().optional(),
});

export const requestNarrationSchema = z.object({
  voiceProfileId: z.string().min(1).max(120),
  stepIndex: z.number().int().min(1),
});

export async function listVoiceProfiles(userId: string) {
  return prisma.voiceProfile.findMany({
    where: { userId },
    orderBy: { createdAt: "desc" },
    include: { samples: true },
  });
}

export async function getVoiceProfile(userId: string, profileId: string) {
  const profile = await prisma.voiceProfile.findUnique({
    where: { id: profileId },
    include: { samples: true },
  });
  if (!profile || profile.userId !== userId) {
    throw new Error("Profile not found");
  }
  return profile;
}

export async function createVoiceProfile(
  userId: string,
  data: z.infer<typeof createVoiceProfileSchema>
) {
  return prisma.voiceProfile.create({
    data: {
      userId,
      name: data.name,
      relationship: data.relationship,
      status: "PENDING",
    },
  });
}

export async function addVoiceSample(
  userId: string,
  profileId: string,
  data: z.infer<typeof addVoiceSampleSchema>
) {
  const profile = await getVoiceProfile(userId, profileId);

  return prisma.voiceSample.create({
    data: {
      voiceProfileId: profile.id,
      storageUrl: data.storageUrl,
      duration: data.duration,
      transcript: data.transcript,
    },
  });
}

export async function trainVoiceProfile(userId: string, profileId: string) {
  await getVoiceProfile(userId, profileId);

  // Fake training MVP: immediately set to READY.
  return prisma.voiceProfile.update({
    where: { id: profileId },
    data: { status: "READY" },
  });
}

export async function requestNarration(
  storyId: string,
  data: z.infer<typeof requestNarrationSchema>
) {
  return prisma.narrationJob.create({
    data: {
      storyId,
      stepIndex: data.stepIndex,
      voiceProfileId: data.voiceProfileId,
      status: "COMPLETED", // Fake async processing MVP: ready immediately.
      outputUrl: "https://actions.google.com/sounds/v1/water/waves_crashing_on_rock_beach.ogg", // Publicly accessible mock audio
    },
  });
}

export async function listNarrationJobs(storyId: string) {
  return prisma.narrationJob.findMany({
    where: { storyId },
    orderBy: { createdAt: "asc" },
  });
}

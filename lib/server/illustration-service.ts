import { prisma } from "@/lib/server/db";
import { z } from "zod";

export const generateIllustrationSchema = z.object({
  stepIndex: z.number().int().min(1),
  artStyleId: z.string().min(1).max(120).optional(),
});

export const updateChildAvatarSchema = z.object({
  photoUrl: z.string().url().max(1000),
});

export async function listArtStyles() {
  const styles = await prisma.artStyle.findMany({
    orderBy: { name: "asc" },
  });

  if (styles.length === 0) {
    // If empty DB, return some mock defaults for MVP purposes
    return [
      { id: "style_aquarela", name: "Aquarela Suave", promptTemplate: "Watercolor style" },
      { id: "style_cartoon", name: "Cartoon Aventura", promptTemplate: "Cartoon network style" },
      { id: "style_fantasia", name: "Fantasia Épica", promptTemplate: "Epic fantasy concept art" },
    ];
  }

  return styles;
}

export async function requestStoryIllustration(
  storyId: string,
  data: z.infer<typeof generateIllustrationSchema>
) {
  // First, check if there's an existing one to avoid duplicates
  const existing = await prisma.storyIllustration.findUnique({
    where: {
      storyId_stepIndex: {
        storyId,
        stepIndex: data.stepIndex,
      },
    },
  });

  if (existing) {
    return existing;
  }

  // MVP: create a 'COMPLETED' illustration with a mock generic image,
  // since a real one requires external API integrations like DALL-E/Midjourney
  return prisma.storyIllustration.create({
    data: {
      storyId,
      stepIndex: data.stepIndex,
      status: "COMPLETED", // directly completed for MVP flow
      promptUsed: "Mock generated prompt based on chapter theme",
      imageUrl: "https://images.unsplash.com/photo-1519077227415-3818e69abdc6?q=80&w=600&auto=format&fit=crop", // placeholder art
      provider: "mock-v1",
    },
  });
}

export async function getStoryIllustration(storyId: string, stepIndex: number) {
  return prisma.storyIllustration.findUnique({
    where: {
      storyId_stepIndex: {
        storyId,
        stepIndex,
      },
    },
  });
}

export async function updateChildAvatar(
  childProfileId: string,
  data: z.infer<typeof updateChildAvatarSchema>
) {
  const existing = await prisma.childAvatar.findUnique({
    where: { childProfileId },
  });

  if (existing) {
    return prisma.childAvatar.update({
      where: { childProfileId },
      data: { photoUrl: data.photoUrl, status: "READY" },
    });
  }

  return prisma.childAvatar.create({
    data: {
      childProfileId,
      photoUrl: data.photoUrl,
      status: "READY",
    },
  });
}

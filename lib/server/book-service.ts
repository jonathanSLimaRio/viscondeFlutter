import prisma from "@/lib/server/prisma";
import { BookProjectStatus } from "@prisma/client";
import { moderateTextInput } from "@/lib/server/moderation-service";
import { ApiError } from "@/lib/server/error";
import { storySessionInclude, toStorySessionDTO } from "@/lib/server/story-service";

export async function createMonthlyBookProject(userId: string, childProfileId: string, monthStr: string) {
  // Check if an existing book project for this month already exists
  const existingProject = await prisma.bookProject.findUnique({
    where: {
      childProfileId_month: {
        childProfileId,
        month: monthStr,
      }
    }
  });

  if (existingProject) {
    return existingProject;
  }

  // Determine start/end of the given month (e.g., '2023-10')
  const [year, month] = monthStr.split('-').map(Number);
  const startDate = new Date(year, month - 1, 1);
  const endDate = new Date(year, month, 0, 23, 59, 59, 999);

  // Fetch stories completed in this month
  const stories = await prisma.story.findMany({
    where: {
      childProfileId,
      status: "PUBLISHED",
      createdAt: {
        gte: startDate,
        lte: endDate,
      }
    },
    orderBy: { createdAt: "asc" }
  });

  if (stories.length === 0) {
    throw new ApiError("No published stories found for this month.", 400, "NO_STORIES_FOUND");
  }

  const child = await prisma.childProfile.findUnique({ where: { id: childProfileId } });

  // Create the BookProject
  const newBook = await prisma.bookProject.create({
    data: {
      userId,
      childProfileId,
      month: monthStr,
      title: `O Livro de Aventuras de ${child?.name || 'Visconde'} - ${monthStr}`,
      includedStories: stories.map(s => s.id),
      status: "READY", // In MVP, frontend generates PDF so it evaluates as READY instantly.
    }
  });

  return newBook;
}

export async function getBookProject(userId: string, bookProjectId: string) {
  const project = await prisma.bookProject.findUnique({
    where: { id: bookProjectId }
  });

  if (!project) {
    throw new ApiError("Book project not found.", 404, "NOT_FOUND");
  }

  if (project.userId !== userId) {
    throw new ApiError("Unauthorized", 403, "UNAUTHORIZED");
  }

  const fullStories = await prisma.story.findMany({
    where: { id: { in: project.includedStories } },
    include: storySessionInclude,
    orderBy: { createdAt: 'asc' },
  });

  return {
    ...project,
    stories: fullStories.map(toStorySessionDTO)
  };
}

export async function listChildBookProjects(userId: string, childProfileId: string) {
  const projects = await prisma.bookProject.findMany({
    where: {
      childProfileId,
      userId,
    },
    orderBy: { createdAt: "desc" }
  });

  return projects;
}

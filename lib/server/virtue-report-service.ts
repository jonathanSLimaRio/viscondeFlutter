import { prisma } from "@/lib/prisma";
import { ApiError } from "@/lib/server/errors";

type StoryVirtueProjection = {
  id: string;
  titleDraft: string;
  titleFinal: string | null;
  publishedAt: Date | null;
  virtueId: string | null;
  dilemmaText: string | null;
  endQuestionText: string | null;
  childProfileId: string;
  childProfile: {
    id: string;
    name: string;
    avatarUrl: string | null;
    birthDate: Date;
  };
  virtue: {
    id: string;
    slug: string;
    name: string;
  } | null;
};

function buildVirtueStats(stories: StoryVirtueProjection[]) {
  const map = new Map<string, { id: string; slug: string; name: string; count: number }>();

  for (const story of stories) {
    if (!story.virtue) {
      continue;
    }

    const existing = map.get(story.virtue.id);
    if (existing) {
      existing.count += 1;
      map.set(story.virtue.id, existing);
      continue;
    }

    map.set(story.virtue.id, {
      id: story.virtue.id,
      slug: story.virtue.slug,
      name: story.virtue.name,
      count: 1,
    });
  }

  return [...map.values()].sort((left, right) => {
    if (left.count !== right.count) {
      return right.count - left.count;
    }

    return left.name.localeCompare(right.name);
  });
}

export async function getVirtueReportsOverview(userId: string) {
  const stories = await prisma.story.findMany({
    where: {
      userId,
      status: "PUBLISHED",
    },
    select: {
      id: true,
      titleDraft: true,
      titleFinal: true,
      publishedAt: true,
      virtueId: true,
      dilemmaText: true,
      endQuestionText: true,
      childProfileId: true,
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
        },
      },
    },
    orderBy: {
      publishedAt: "desc",
    },
  });

  const grouped = new Map<string, StoryVirtueProjection[]>();
  for (const story of stories) {
    const current = grouped.get(story.childProfileId) ?? [];
    current.push(story);
    grouped.set(story.childProfileId, current);
  }

  const children = [...grouped.entries()].map(([childId, childStories]) => {
    const child = childStories[0]?.childProfile;

    const storiesWithVirtue = childStories.filter((story) => Boolean(story.virtueId));
    const storiesWithoutVirtue = childStories.length - storiesWithVirtue.length;
    const virtueStats = buildVirtueStats(childStories);

    const recentVirtues = childStories
      .filter((story) => Boolean(story.virtue))
      .slice(0, 5)
      .map((story) => ({
        storyId: story.id,
        virtue: story.virtue,
        publishedAt: story.publishedAt,
      }));

    return {
      child: {
        id: childId,
        name: child?.name ?? "-",
        avatarUrl: child?.avatarUrl ?? null,
        birthDate: child?.birthDate.toISOString() ?? null,
      },
      totals: {
        publishedStories: childStories.length,
        storiesWithVirtue: storiesWithVirtue.length,
        storiesWithoutVirtue,
      },
      lastPublishedAt: childStories[0]?.publishedAt ?? null,
      virtueStats,
      recentVirtues,
    };
  });

  children.sort((left, right) => left.child.name.localeCompare(right.child.name));

  const totals = {
    publishedStories: stories.length,
    storiesWithVirtue: stories.filter((story) => Boolean(story.virtueId)).length,
    storiesWithoutVirtue: stories.filter((story) => !story.virtueId).length,
  };

  return {
    generatedAt: new Date(),
    totals,
    children,
  };
}

export async function getVirtueReportByChild(userId: string, childId: string) {
  const child = await prisma.childProfile.findFirst({
    where: {
      id: childId,
      userId,
      isArchived: false,
    },
    select: {
      id: true,
      name: true,
      avatarUrl: true,
      birthDate: true,
    },
  });

  if (!child) {
    throw new ApiError("Perfil infantil nao encontrado.", 404, "CHILD_NOT_FOUND");
  }

  const stories = await prisma.story.findMany({
    where: {
      userId,
      childProfileId: childId,
      status: "PUBLISHED",
    },
    select: {
      id: true,
      titleDraft: true,
      titleFinal: true,
      publishedAt: true,
      virtueId: true,
      dilemmaText: true,
      endQuestionText: true,
      childProfileId: true,
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
        },
      },
    },
    orderBy: {
      publishedAt: "desc",
    },
  });

  const storiesWithVirtue = stories.filter((story) => Boolean(story.virtueId));

  return {
    generatedAt: new Date(),
    child: {
      id: child.id,
      name: child.name,
      avatarUrl: child.avatarUrl,
      birthDate: child.birthDate.toISOString(),
    },
    totals: {
      publishedStories: stories.length,
      storiesWithVirtue: storiesWithVirtue.length,
      storiesWithoutVirtue: stories.length - storiesWithVirtue.length,
    },
    virtueStats: buildVirtueStats(stories),
    stories: stories.map((story) => ({
      storyId: story.id,
      title: story.titleFinal ?? story.titleDraft,
      publishedAt: story.publishedAt,
      virtue: story.virtue,
      dilemmaText: story.dilemmaText,
      endQuestionText: story.endQuestionText,
    })),
  };
}

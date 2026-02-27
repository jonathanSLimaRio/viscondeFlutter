import type {
  CatalogItemType,
  MissionKind,
  Prisma,
  WalletReason,
} from "@prisma/client";

import { prisma } from "@/lib/prisma";
import { ApiError } from "@/lib/server/errors";

type DbClient = Prisma.TransactionClient | typeof prisma;

type WalletView = {
  coins: number;
  stars: number;
};

type ChildStreakView = {
  currentDays: number;
  bestDays: number;
  shieldCount: number;
  lastCountedDate: Date | null;
};

export type StoryPublishedGamificationResult = {
  wallet: WalletView;
  delta: {
    coins: number;
    stars: number;
  };
  unlockedAchievements: Array<{
    key: string;
    title: string;
    rewardCoins: number;
    rewardStars: number;
  }>;
  completedMissions: Array<{
    id: string;
    kind: MissionKind;
    title: string;
    rewardCoins: number;
    rewardStars: number;
  }>;
  streak: ChildStreakView;
};

type StoryPublishedInput = {
  userId: string;
  storyId: string;
  childProfileId: string;
  virtueId: string | null;
  virtueSlug: string | null;
  continuedFromStoryId: string | null;
  publishedAt: Date;
  timezone: string;
  source: "LIVE" | "BACKFILL";
};

const BASE_STORY_REWARD = {
  coins: 12,
  stars: 0,
};

const MISSION_REWARD_DEFAULT = {
  coins: 35,
  stars: 1,
};

const MISSION_REWARD_VIRTUE = {
  coins: 40,
  stars: 1,
};

const ACHIEVEMENT_KEY_FIRST_STORY = "primeira_historia";
const ACHIEVEMENT_KEY_STREAK_7 = "streak_7_dias";

const DEFAULT_ACHIEVEMENT_REWARDS: Record<string, { coins: number; stars: number }> = {
  [ACHIEVEMENT_KEY_FIRST_STORY]: { coins: 50, stars: 2 },
  [ACHIEVEMENT_KEY_STREAK_7]: { coins: 80, stars: 3 },
};

const weekdayToIndex: Record<string, number> = {
  Sun: 0,
  Mon: 1,
  Tue: 2,
  Wed: 3,
  Thu: 4,
  Fri: 5,
  Sat: 6,
};

function toIsoDateKey(parts: { year: number; month: number; day: number }) {
  return `${parts.year.toString().padStart(4, "0")}-${parts.month
    .toString()
    .padStart(2, "0")}-${parts.day.toString().padStart(2, "0")}`;
}

function toUtcDateFromDateKey(dateKey: string) {
  return new Date(`${dateKey}T00:00:00.000Z`);
}

function diffDaysBetweenDateKeys(fromDateKey: string, toDateKey: string) {
  const from = toUtcDateFromDateKey(fromDateKey).getTime();
  const to = toUtcDateFromDateKey(toDateKey).getTime();
  return Math.round((to - from) / (24 * 60 * 60 * 1000));
}

function getLocalDateParts(date: Date, timezone: string) {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    weekday: "short",
  });

  const parts = formatter.formatToParts(date);
  const year = Number(parts.find((part) => part.type === "year")?.value ?? "0");
  const month = Number(parts.find((part) => part.type === "month")?.value ?? "0");
  const day = Number(parts.find((part) => part.type === "day")?.value ?? "0");
  const weekdayShort = parts.find((part) => part.type === "weekday")?.value ?? "Mon";
  const weekday = weekdayToIndex[weekdayShort] ?? 1;

  return {
    year,
    month,
    day,
    weekday,
  };
}

function getLocalDateKey(date: Date, timezone: string) {
  const parts = getLocalDateParts(date, timezone);
  return toIsoDateKey(parts);
}

function getWeekKeyMonday(date: Date, timezone: string) {
  const parts = getLocalDateParts(date, timezone);
  const base = Date.UTC(parts.year, parts.month - 1, parts.day);
  const mondayOffset = (parts.weekday + 6) % 7;
  const mondayDate = new Date(base - mondayOffset * 24 * 60 * 60 * 1000);

  return toIsoDateKey({
    year: mondayDate.getUTCFullYear(),
    month: mondayDate.getUTCMonth() + 1,
    day: mondayDate.getUTCDate(),
  });
}

function resolveTimezone(input: string | null | undefined) {
  if (typeof input !== "string" || input.trim().length === 0) {
    return "UTC";
  }

  return input.trim();
}

function hashString(input: string) {
  let hash = 0;
  for (let index = 0; index < input.length; index += 1) {
    hash = (hash * 31 + input.charCodeAt(index)) >>> 0;
  }

  return hash;
}

async function getOwnedChildOrThrow(db: DbClient, userId: string, childProfileId: string) {
  const child = await db.childProfile.findFirst({
    where: {
      id: childProfileId,
      userId,
      isArchived: false,
    },
    select: {
      id: true,
      userId: true,
    },
  });

  if (!child) {
    throw new ApiError("Perfil infantil nao encontrado.", 404, "GAMIFICATION_CHILD_NOT_FOUND");
  }

  return child;
}

async function getOrCreateWallet(db: DbClient, userId: string) {
  const existing = await db.wallet.findUnique({
    where: {
      userId,
    },
  });

  if (existing) {
    return existing;
  }

  return db.wallet.create({
    data: {
      userId,
      coins: 0,
      stars: 0,
    },
  });
}

async function applyWalletDelta(
  db: DbClient,
  input: {
    userId: string;
    reason: WalletReason;
    deltaCoins: number;
    deltaStars: number;
    referenceType?: string;
    referenceId?: string;
  }
) {
  const wallet = await getOrCreateWallet(db, input.userId);

  if (input.deltaCoins === 0 && input.deltaStars === 0) {
    return wallet;
  }

  const nextCoins = wallet.coins + input.deltaCoins;
  const nextStars = wallet.stars + input.deltaStars;

  if (nextCoins < 0 || nextStars < 0) {
    throw new ApiError(
      "Saldo insuficiente para desbloquear este item.",
      409,
      "GAMIFICATION_INSUFFICIENT_FUNDS"
    );
  }

  const updated = await db.wallet.update({
    where: {
      id: wallet.id,
    },
    data: {
      coins: nextCoins,
      stars: nextStars,
    },
  });

  if (input.deltaCoins !== 0) {
    await db.walletTransaction.create({
      data: {
        walletId: wallet.id,
        userId: input.userId,
        currencyType: "COIN",
        amount: input.deltaCoins,
        reason: input.reason,
        referenceType: input.referenceType,
        referenceId: input.referenceId,
        balanceAfter: nextCoins,
      },
    });
  }

  if (input.deltaStars !== 0) {
    await db.walletTransaction.create({
      data: {
        walletId: wallet.id,
        userId: input.userId,
        currencyType: "STAR",
        amount: input.deltaStars,
        reason: input.reason,
        referenceType: input.referenceType,
        referenceId: input.referenceId,
        balanceAfter: nextStars,
      },
    });
  }

  return updated;
}

async function ensureChildStreak(
  db: DbClient,
  input: {
    userId: string;
    childProfileId: string;
    timezone: string;
    referenceDate: Date;
  }
) {
  const weekKey = getWeekKeyMonday(input.referenceDate, input.timezone);

  let streak = await db.childStreak.findUnique({
    where: {
      childProfileId: input.childProfileId,
    },
  });

  if (!streak) {
    streak = await db.childStreak.create({
      data: {
        userId: input.userId,
        childProfileId: input.childProfileId,
        currentDays: 0,
        bestDays: 0,
        shieldCount: 0,
        lastShieldGrantWeekKey: null,
      },
    });
  }

  if (streak.lastShieldGrantWeekKey !== weekKey) {
    streak = await db.childStreak.update({
      where: {
        id: streak.id,
      },
      data: {
        shieldCount: Math.min(2, streak.shieldCount + 1),
        lastShieldGrantWeekKey: weekKey,
      },
    });
  }

  return streak;
}

async function advanceStreakOnPublish(
  db: DbClient,
  input: {
    userId: string;
    childProfileId: string;
    timezone: string;
    publishedAt: Date;
  }
) {
  const streak = await ensureChildStreak(db, {
    userId: input.userId,
    childProfileId: input.childProfileId,
    timezone: input.timezone,
    referenceDate: input.publishedAt,
  });

  const currentDateKey = getLocalDateKey(input.publishedAt, input.timezone);
  const lastDateKey = streak.lastCountedDate
    ? getLocalDateKey(streak.lastCountedDate, input.timezone)
    : null;

  if (lastDateKey === currentDateKey) {
    return streak;
  }

  let nextCurrentDays = 1;
  let nextShieldCount = streak.shieldCount;

  if (lastDateKey) {
    const gap = diffDaysBetweenDateKeys(lastDateKey, currentDateKey);

    if (gap === 1) {
      nextCurrentDays = streak.currentDays + 1;
    } else if (gap === 2 && streak.shieldCount > 0) {
      nextCurrentDays = streak.currentDays + 1;
      nextShieldCount = streak.shieldCount - 1;
    } else if (gap <= 0) {
      nextCurrentDays = streak.currentDays;
      nextShieldCount = streak.shieldCount;
    }
  }

  const nextBestDays = Math.max(streak.bestDays, nextCurrentDays);

  return db.childStreak.update({
    where: {
      id: streak.id,
    },
    data: {
      currentDays: nextCurrentDays,
      bestDays: nextBestDays,
      shieldCount: nextShieldCount,
      lastCountedDate: toUtcDateFromDateKey(currentDateKey),
    },
  });
}

type WeeklyMissionRuntime = {
  kind: MissionKind;
  title: string;
  description: string;
  targetValue: number;
  virtueId: string | null;
  rewardCoins: number;
  rewardStars: number;
};

async function ensureWeeklyMissions(
  db: DbClient,
  input: {
    userId: string;
    childProfileId: string;
    timezone: string;
    referenceDate: Date;
  }
) {
  const weekKey = getWeekKeyMonday(input.referenceDate, input.timezone);

  const existing = await db.childWeeklyMission.findMany({
    where: {
      userId: input.userId,
      childProfileId: input.childProfileId,
      weekKey,
    },
    orderBy: {
      createdAt: "asc",
    },
  });

  if (existing.length >= 3) {
    return {
      weekKey,
      missions: existing,
    };
  }

  const activeVirtues = await db.virtue.findMany({
    where: {
      isActive: true,
    },
    orderBy: [{ sortOrder: "asc" }, { slug: "asc" }],
    select: {
      id: true,
      slug: true,
      name: true,
    },
  });

  if (activeVirtues.length === 0) {
    throw new ApiError(
      "Catalogo de virtudes indisponivel para gerar missao semanal.",
      409,
      "GAMIFICATION_MISSION_CONFIG_INVALID"
    );
  }

  const virtueIndex = hashString(weekKey) % activeVirtues.length;
  const virtueOfWeek = activeVirtues[virtueIndex];

  const childHasAnyPublished =
    (await db.story.count({
      where: {
        userId: input.userId,
        childProfileId: input.childProfileId,
        status: "PUBLISHED",
      },
    })) > 0;

  const missionDefinitions: WeeklyMissionRuntime[] = [
    {
      kind: "PUBLISH_COUNT",
      title: "Conte 2 capitulos",
      description: "Publique 2 capitulos nesta semana.",
      targetValue: 2,
      virtueId: null,
      rewardCoins: MISSION_REWARD_DEFAULT.coins,
      rewardStars: MISSION_REWARD_DEFAULT.stars,
    },
    {
      kind: "PUBLISH_WITH_VIRTUE",
      title: `1 historia sobre ${virtueOfWeek.name.toLowerCase()}`,
      description: `Publique 1 capitulo com a virtude ${virtueOfWeek.name}.`,
      targetValue: 1,
      virtueId: virtueOfWeek.id,
      rewardCoins: MISSION_REWARD_VIRTUE.coins,
      rewardStars: MISSION_REWARD_VIRTUE.stars,
    },
    {
      kind: "CONTINUE_EPISODE",
      title: childHasAnyPublished ? "Continue 1 episodio" : "Publique 1 capitulo",
      description: childHasAnyPublished
        ? "Publique 1 episodio de continuacao nesta semana."
        : "Publique 1 capitulo nesta semana.",
      targetValue: 1,
      virtueId: null,
      rewardCoins: MISSION_REWARD_DEFAULT.coins,
      rewardStars: MISSION_REWARD_DEFAULT.stars,
    },
  ];

  for (const mission of missionDefinitions) {
    const alreadyExists = existing.some((stored) => {
      const sameVirtue = mission.virtueId
        ? stored.virtueId === mission.virtueId
        : stored.virtueId === null;
      return stored.kind === mission.kind && sameVirtue;
    });

    if (alreadyExists) {
      continue;
    }

    await db.childWeeklyMission.create({
      data: {
        userId: input.userId,
        childProfileId: input.childProfileId,
        weekKey,
        kind: mission.kind,
        title: mission.title,
        description: mission.description,
        targetValue: mission.targetValue,
        progressValue: 0,
        status: "ACTIVE",
        virtueId: mission.virtueId,
        rewardCoins: mission.rewardCoins,
        rewardStars: mission.rewardStars,
      },
    });
  }

  const missions = await db.childWeeklyMission.findMany({
    where: {
      userId: input.userId,
      childProfileId: input.childProfileId,
      weekKey,
    },
    orderBy: {
      createdAt: "asc",
    },
  });

  return {
    weekKey,
    missions,
  };
}

async function progressWeeklyMissionsOnPublish(
  db: DbClient,
  input: {
    userId: string;
    childProfileId: string;
    storyId: string;
    virtueId: string | null;
    continuedFromStoryId: string | null;
    publishedAt: Date;
    timezone: string;
    source: StoryPublishedInput["source"];
  }
) {
  const missionSet = await ensureWeeklyMissions(db, {
    userId: input.userId,
    childProfileId: input.childProfileId,
    timezone: input.timezone,
    referenceDate: input.publishedAt,
  });

  const publishedBeforeCount = await db.story.count({
    where: {
      userId: input.userId,
      childProfileId: input.childProfileId,
      status: "PUBLISHED",
      publishedAt: {
        lt: input.publishedAt,
      },
    },
  });

  const completedMissions: StoryPublishedGamificationResult["completedMissions"] = [];
  let deltaCoins = 0;
  let deltaStars = 0;

  for (const mission of missionSet.missions) {
    if (mission.status !== "ACTIVE") {
      continue;
    }

    let shouldIncrement = false;

    if (mission.kind === "PUBLISH_COUNT") {
      shouldIncrement = true;
    }

    if (mission.kind === "PUBLISH_WITH_VIRTUE" && mission.virtueId && mission.virtueId === input.virtueId) {
      shouldIncrement = true;
    }

    if (mission.kind === "CONTINUE_EPISODE") {
      shouldIncrement =
        Boolean(input.continuedFromStoryId) ||
        (!input.continuedFromStoryId && publishedBeforeCount === 0);
    }

    if (!shouldIncrement) {
      continue;
    }

    const nextProgress = Math.min(mission.targetValue, mission.progressValue + 1);
    const willComplete = nextProgress >= mission.targetValue;

    const updated = await db.childWeeklyMission.update({
      where: {
        id: mission.id,
      },
      data: {
        progressValue: nextProgress,
        status: willComplete ? "COMPLETED" : mission.status,
        completedAt: willComplete ? input.publishedAt : mission.completedAt,
      },
    });

    if (!willComplete) {
      continue;
    }

    await applyWalletDelta(db, {
      userId: input.userId,
      reason: input.source === "BACKFILL" ? "BACKFILL" : "MISSION_COMPLETED",
      deltaCoins: mission.rewardCoins,
      deltaStars: mission.rewardStars,
      referenceType: "weekly_mission",
      referenceId: mission.id,
    });

    deltaCoins += mission.rewardCoins;
    deltaStars += mission.rewardStars;

    completedMissions.push({
      id: updated.id,
      kind: updated.kind,
      title: updated.title,
      rewardCoins: updated.rewardCoins,
      rewardStars: updated.rewardStars,
    });
  }

  return {
    completedMissions,
    deltaCoins,
    deltaStars,
  };
}

async function unlockAchievementsOnPublish(
  db: DbClient,
  input: {
    userId: string;
    storyId: string;
    virtueSlug: string | null;
    streak: ChildStreakView;
    source: StoryPublishedInput["source"];
  }
) {
  const publishedCount = await db.story.count({
    where: {
      userId: input.userId,
      status: "PUBLISHED",
    },
  });

  const desiredKeys = new Set<string>();

  if (publishedCount === 1) {
    desiredKeys.add(ACHIEVEMENT_KEY_FIRST_STORY);
  }

  if (input.streak.currentDays >= 7) {
    desiredKeys.add(ACHIEVEMENT_KEY_STREAK_7);
  }

  if (input.virtueSlug) {
    desiredKeys.add(`virtude_${input.virtueSlug}`);
  }

  if (desiredKeys.size === 0) {
    return {
      unlockedAchievements: [] as StoryPublishedGamificationResult["unlockedAchievements"],
      deltaCoins: 0,
      deltaStars: 0,
    };
  }

  const activeAchievements = await db.achievement.findMany({
    where: {
      key: {
        in: Array.from(desiredKeys),
      },
      isActive: true,
    },
    select: {
      id: true,
      key: true,
      title: true,
      rewardCoins: true,
      rewardStars: true,
    },
  });

  if (activeAchievements.length === 0) {
    return {
      unlockedAchievements: [] as StoryPublishedGamificationResult["unlockedAchievements"],
      deltaCoins: 0,
      deltaStars: 0,
    };
  }

  const existing = await db.userAchievement.findMany({
    where: {
      userId: input.userId,
      achievementId: {
        in: activeAchievements.map((achievement) => achievement.id),
      },
    },
    select: {
      achievementId: true,
    },
  });

  const existingIds = new Set(existing.map((item) => item.achievementId));

  const unlockedAchievements: StoryPublishedGamificationResult["unlockedAchievements"] = [];
  let deltaCoins = 0;
  let deltaStars = 0;

  for (const achievement of activeAchievements) {
    if (existingIds.has(achievement.id)) {
      continue;
    }

    await db.userAchievement.create({
      data: {
        userId: input.userId,
        achievementId: achievement.id,
        unlockedAt: new Date(),
        progressValue: 1,
        metaJson: {
          storyId: input.storyId,
          key: achievement.key,
        },
      },
    });

    await applyWalletDelta(db, {
      userId: input.userId,
      reason: input.source === "BACKFILL" ? "BACKFILL" : "ACHIEVEMENT_UNLOCK",
      deltaCoins: achievement.rewardCoins,
      deltaStars: achievement.rewardStars,
      referenceType: "achievement",
      referenceId: achievement.id,
    });

    deltaCoins += achievement.rewardCoins;
    deltaStars += achievement.rewardStars;

    unlockedAchievements.push({
      key: achievement.key,
      title: achievement.title,
      rewardCoins: achievement.rewardCoins,
      rewardStars: achievement.rewardStars,
    });
  }

  return {
    unlockedAchievements,
    deltaCoins,
    deltaStars,
  };
}

export async function processStoryPublished(
  db: DbClient,
  input: StoryPublishedInput
): Promise<StoryPublishedGamificationResult> {
  const eventKey = `story-published:${input.storyId}`;

  const existingEvent = await db.gamificationEvent.findUnique({
    where: {
      eventKey,
    },
  });

  if (existingEvent) {
    const wallet = await getOrCreateWallet(db, input.userId);
    const streak = await ensureChildStreak(db, {
      userId: input.userId,
      childProfileId: input.childProfileId,
      timezone: input.timezone,
      referenceDate: input.publishedAt,
    });

    return {
      wallet: {
        coins: wallet.coins,
        stars: wallet.stars,
      },
      delta: {
        coins: 0,
        stars: 0,
      },
      unlockedAchievements: [],
      completedMissions: [],
      streak: {
        currentDays: streak.currentDays,
        bestDays: streak.bestDays,
        shieldCount: streak.shieldCount,
        lastCountedDate: streak.lastCountedDate,
      },
    };
  }

  let totalCoins = 0;
  let totalStars = 0;

  const baseReason: WalletReason = input.source === "BACKFILL" ? "BACKFILL" : "STORY_PUBLISHED";

  let wallet = await applyWalletDelta(db, {
    userId: input.userId,
    reason: baseReason,
    deltaCoins: BASE_STORY_REWARD.coins,
    deltaStars: BASE_STORY_REWARD.stars,
    referenceType: "story",
    referenceId: input.storyId,
  });

  totalCoins += BASE_STORY_REWARD.coins;
  totalStars += BASE_STORY_REWARD.stars;

  const missionResult = await progressWeeklyMissionsOnPublish(db, {
    userId: input.userId,
    childProfileId: input.childProfileId,
    storyId: input.storyId,
    virtueId: input.virtueId,
    continuedFromStoryId: input.continuedFromStoryId,
    publishedAt: input.publishedAt,
    timezone: input.timezone,
    source: input.source,
  });

  totalCoins += missionResult.deltaCoins;
  totalStars += missionResult.deltaStars;

  const streak = await advanceStreakOnPublish(db, {
    userId: input.userId,
    childProfileId: input.childProfileId,
    timezone: input.timezone,
    publishedAt: input.publishedAt,
  });

  const achievementResult = await unlockAchievementsOnPublish(db, {
    userId: input.userId,
    storyId: input.storyId,
    virtueSlug: input.virtueSlug,
    streak: {
      currentDays: streak.currentDays,
      bestDays: streak.bestDays,
      shieldCount: streak.shieldCount,
      lastCountedDate: streak.lastCountedDate,
    },
    source: input.source,
  });

  totalCoins += achievementResult.deltaCoins;
  totalStars += achievementResult.deltaStars;

  wallet = await getOrCreateWallet(db, input.userId);

  await db.gamificationEvent.create({
    data: {
      eventKey,
      userId: input.userId,
      storyId: input.storyId,
      childProfileId: input.childProfileId,
      processedAt: new Date(),
      metaJson: {
        source: input.source,
        deltaCoins: totalCoins,
        deltaStars: totalStars,
      },
    },
  });

  return {
    wallet: {
      coins: wallet.coins,
      stars: wallet.stars,
    },
    delta: {
      coins: totalCoins,
      stars: totalStars,
    },
    unlockedAchievements: achievementResult.unlockedAchievements,
    completedMissions: missionResult.completedMissions,
    streak: {
      currentDays: streak.currentDays,
      bestDays: streak.bestDays,
      shieldCount: streak.shieldCount,
      lastCountedDate: streak.lastCountedDate,
    },
  };
}

export async function getWalletWithRecentTransactions(userId: string) {
  const wallet = await getOrCreateWallet(prisma, userId);
  const transactions = await prisma.walletTransaction.findMany({
    where: {
      userId,
    },
    orderBy: {
      createdAt: "desc",
    },
    take: 20,
  });

  return {
    coins: wallet.coins,
    stars: wallet.stars,
    recentTransactions: transactions.map((transaction) => ({
      id: transaction.id,
      currencyType: transaction.currencyType,
      amount: transaction.amount,
      reason: transaction.reason,
      referenceType: transaction.referenceType,
      referenceId: transaction.referenceId,
      balanceAfter: transaction.balanceAfter,
      createdAt: transaction.createdAt,
    })),
  };
}

export async function listUserAchievements(userId: string) {
  const achievements = await prisma.achievement.findMany({
    where: {
      isActive: true,
    },
    orderBy: [{ sortOrder: "asc" }, { key: "asc" }],
    include: {
      userAchievements: {
        where: {
          userId,
        },
        select: {
          unlockedAt: true,
        },
        take: 1,
      },
    },
  });

  return achievements.map((achievement) => {
    const unlocked = achievement.userAchievements[0] ?? null;
    return {
      id: achievement.id,
      key: achievement.key,
      title: achievement.title,
      description: achievement.description,
      iconKey: achievement.iconKey,
      rewardCoins: achievement.rewardCoins,
      rewardStars: achievement.rewardStars,
      sortOrder: achievement.sortOrder,
      unlockedAt: unlocked?.unlockedAt ?? null,
      unlocked: Boolean(unlocked),
    };
  });
}

export async function listCatalogForChild(
  userId: string,
  input: {
    childProfileId: string;
    type?: CatalogItemType;
  }
) {
  await getOwnedChildOrThrow(prisma, userId, input.childProfileId);

  const items = await prisma.gamificationCatalogItem.findMany({
    where: {
      isActive: true,
      type: input.type,
    },
    orderBy: [{ sortOrder: "asc" }, { key: "asc" }],
  });

  const inventory = await prisma.childInventoryItem.findMany({
    where: {
      childProfileId: input.childProfileId,
      itemId: {
        in: items.map((item) => item.id),
      },
    },
    select: {
      itemId: true,
      equipped: true,
      unlockedAt: true,
    },
  });

  const inventoryByItemId = new Map(inventory.map((entry) => [entry.itemId, entry]));

  return items.map((item) => {
    const unlock = inventoryByItemId.get(item.id);
    return {
      id: item.id,
      key: item.key,
      type: item.type,
      name: item.name,
      description: item.description,
      iconKey: item.iconKey,
      priceCoins: item.priceCoins,
      priceStars: item.priceStars,
      sortOrder: item.sortOrder,
      unlocked: Boolean(unlock),
      equipped: unlock?.equipped ?? false,
      unlockedAt: unlock?.unlockedAt ?? null,
    };
  });
}

export async function getChildGamificationProgress(userId: string, childProfileId: string) {
  await getOwnedChildOrThrow(prisma, userId, childProfileId);

  const user = await prisma.user.findUnique({
    where: {
      id: userId,
    },
    select: {
      timezone: true,
    },
  });

  const timezone = resolveTimezone(user?.timezone);

  const now = new Date();

  await prisma.$transaction(async (tx) => {
    await ensureChildStreak(tx, {
      userId,
      childProfileId,
      timezone,
      referenceDate: now,
    });

    await ensureWeeklyMissions(tx, {
      userId,
      childProfileId,
      timezone,
      referenceDate: now,
    });
  });

  const weekKey = getWeekKeyMonday(now, timezone);

  const streak = await prisma.childStreak.findUnique({
    where: {
      childProfileId,
    },
  });

  const weeklyMissions = await prisma.childWeeklyMission.findMany({
    where: {
      userId,
      childProfileId,
      weekKey,
    },
    orderBy: [{ status: "asc" }, { createdAt: "asc" }],
    include: {
      virtue: {
        select: {
          id: true,
          slug: true,
          name: true,
          iconKey: true,
        },
      },
    },
  });

  const inventory = await prisma.childInventoryItem.findMany({
    where: {
      childProfileId,
    },
    include: {
      item: {
        select: {
          id: true,
          key: true,
          type: true,
          name: true,
          iconKey: true,
        },
      },
    },
  });

  return {
    childProfileId,
    weekKey,
    streak: {
      currentDays: streak?.currentDays ?? 0,
      bestDays: streak?.bestDays ?? 0,
      shieldCount: streak?.shieldCount ?? 0,
      lastCountedDate: streak?.lastCountedDate ?? null,
    },
    weeklyMissions: weeklyMissions.map((mission) => ({
      id: mission.id,
      weekKey: mission.weekKey,
      kind: mission.kind,
      title: mission.title,
      description: mission.description,
      targetValue: mission.targetValue,
      progressValue: mission.progressValue,
      status: mission.status,
      rewardCoins: mission.rewardCoins,
      rewardStars: mission.rewardStars,
      completedAt: mission.completedAt,
      virtue: mission.virtue,
    })),
    inventorySummary: {
      totalUnlocked: inventory.length,
      equippedItems: inventory
        .filter((entry) => entry.equipped)
        .map((entry) => ({
          id: entry.item.id,
          key: entry.item.key,
          type: entry.item.type,
          name: entry.item.name,
          iconKey: entry.item.iconKey,
        })),
    },
  };
}

export async function unlockCatalogItem(
  userId: string,
  input: {
    childProfileId: string;
    itemId: string;
  }
) {
  await getOwnedChildOrThrow(prisma, userId, input.childProfileId);

  const item = await prisma.gamificationCatalogItem.findFirst({
    where: {
      id: input.itemId,
      isActive: true,
    },
  });

  if (!item) {
    throw new ApiError("Item de catalogo nao encontrado.", 404, "GAMIFICATION_ITEM_NOT_FOUND");
  }

  const existingUnlock = await prisma.childInventoryItem.findUnique({
    where: {
      childProfileId_itemId: {
        childProfileId: input.childProfileId,
        itemId: input.itemId,
      },
    },
  });

  if (existingUnlock) {
    throw new ApiError("Item ja desbloqueado para esta crianca.", 409, "GAMIFICATION_ITEM_ALREADY_UNLOCKED");
  }

  return prisma.$transaction(async (tx) => {
    const wallet = await applyWalletDelta(tx, {
      userId,
      reason: "PURCHASE_SPEND",
      deltaCoins: -item.priceCoins,
      deltaStars: -item.priceStars,
      referenceType: "catalog_item",
      referenceId: item.id,
    });

    const inventoryItem = await tx.childInventoryItem.create({
      data: {
        childProfileId: input.childProfileId,
        itemId: item.id,
        unlockedAt: new Date(),
        equipped: false,
      },
      include: {
        item: {
          select: {
            id: true,
            key: true,
            type: true,
            name: true,
            iconKey: true,
          },
        },
      },
    });

    return {
      wallet: {
        coins: wallet.coins,
        stars: wallet.stars,
      },
      spent: {
        coins: item.priceCoins,
        stars: item.priceStars,
      },
      inventoryItem: {
        id: inventoryItem.id,
        unlockedAt: inventoryItem.unlockedAt,
        equipped: inventoryItem.equipped,
        item: inventoryItem.item,
      },
    };
  });
}

export async function equipCatalogItem(
  userId: string,
  input: {
    childProfileId: string;
    itemId: string;
    equipped: boolean;
  }
) {
  await getOwnedChildOrThrow(prisma, userId, input.childProfileId);

  const inventoryItem = await prisma.childInventoryItem.findUnique({
    where: {
      childProfileId_itemId: {
        childProfileId: input.childProfileId,
        itemId: input.itemId,
      },
    },
    include: {
      item: {
        select: {
          type: true,
        },
      },
    },
  });

  if (!inventoryItem) {
    throw new ApiError("Item nao desbloqueado para esta crianca.", 404, "GAMIFICATION_ITEM_NOT_FOUND");
  }

  await prisma.$transaction(async (tx) => {
    if (input.equipped) {
      await tx.childInventoryItem.updateMany({
        where: {
          childProfileId: input.childProfileId,
          item: {
            type: inventoryItem.item.type,
          },
        },
        data: {
          equipped: false,
        },
      });
    }

    await tx.childInventoryItem.update({
      where: {
        id: inventoryItem.id,
      },
      data: {
        equipped: input.equipped,
      },
    });
  });

  const equippedItems = await prisma.childInventoryItem.findMany({
    where: {
      childProfileId: input.childProfileId,
      equipped: true,
    },
    include: {
      item: {
        select: {
          id: true,
          key: true,
          type: true,
          name: true,
          iconKey: true,
        },
      },
    },
    orderBy: {
      updatedAt: "desc",
    },
  });

  return {
    equippedItems: equippedItems.map((entry) => ({
      id: entry.item.id,
      key: entry.item.key,
      type: entry.item.type,
      name: entry.item.name,
      iconKey: entry.item.iconKey,
    })),
  };
}

export async function runGamificationBackfill() {
  const stories = await prisma.story.findMany({
    where: {
      status: "PUBLISHED",
    },
    orderBy: {
      publishedAt: "asc",
    },
    include: {
      virtue: {
        select: {
          slug: true,
        },
      },
      user: {
        select: {
          timezone: true,
        },
      },
    },
  });

  let processed = 0;
  let skipped = 0;

  for (const story of stories) {
    const publishedAt = story.publishedAt;
    if (!publishedAt) {
      continue;
    }

    const result = await prisma.$transaction(async (tx) => {
      return processStoryPublished(tx, {
        userId: story.userId,
        storyId: story.id,
        childProfileId: story.childProfileId,
        virtueId: story.virtueId,
        virtueSlug: story.virtue?.slug ?? null,
        continuedFromStoryId: story.continuedFromStoryId,
        publishedAt,
        timezone: resolveTimezone(story.user.timezone),
        source: "BACKFILL",
      });
    });

    if (result.delta.coins === 0 && result.delta.stars === 0) {
      skipped += 1;
    } else {
      processed += 1;
    }
  }

  return {
    totalStories: stories.length,
    processed,
    skipped,
  };
}

export function defaultAchievementRewardForKey(key: string) {
  if (Object.hasOwn(DEFAULT_ACHIEVEMENT_REWARDS, key)) {
    return DEFAULT_ACHIEVEMENT_REWARDS[key];
  }

  if (key.startsWith("virtude_")) {
    return {
      coins: 25,
      stars: 1,
    };
  }

  return {
    coins: 0,
    stars: 0,
  };
}

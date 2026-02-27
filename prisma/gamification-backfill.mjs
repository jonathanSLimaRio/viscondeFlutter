import "dotenv/config";

import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "@prisma/client";
import pg from "pg";

const { Pool } = pg;

const databaseUrl =
  process.env.PRISMA_DATABASE_URL ??
  process.env.DATABASE_URL ??
  process.env.POSTGRES_URL;

if (!databaseUrl) {
  throw new Error(
    "Database URL ausente. Defina PRISMA_DATABASE_URL, DATABASE_URL ou POSTGRES_URL."
  );
}

const pool = new Pool({ connectionString: databaseUrl });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

const WEEKDAY_INDEX = {
  Sun: 0,
  Mon: 1,
  Tue: 2,
  Wed: 3,
  Thu: 4,
  Fri: 5,
  Sat: 6,
};

function toIsoDateKey({ year, month, day }) {
  return `${String(year).padStart(4, "0")}-${String(month).padStart(
    2,
    "0"
  )}-${String(day).padStart(2, "0")}`;
}

function localDateParts(date, timezone) {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    weekday: "short",
  });

  const parts = formatter.formatToParts(date);
  const year = Number(parts.find((part) => part.type === "year")?.value ?? "0");
  const month = Number(
    parts.find((part) => part.type === "month")?.value ?? "0"
  );
  const day = Number(parts.find((part) => part.type === "day")?.value ?? "0");
  const weekday =
    WEEKDAY_INDEX[parts.find((part) => part.type === "weekday")?.value ?? "Mon"] ??
    1;

  return { year, month, day, weekday };
}

function localDateKey(date, timezone) {
  return toIsoDateKey(localDateParts(date, timezone));
}

function utcDateFromDateKey(dateKey) {
  return new Date(`${dateKey}T00:00:00.000Z`);
}

function diffDays(fromDateKey, toDateKey) {
  const from = utcDateFromDateKey(fromDateKey).getTime();
  const to = utcDateFromDateKey(toDateKey).getTime();
  return Math.round((to - from) / (24 * 60 * 60 * 1000));
}

function mondayWeekKey(date, timezone) {
  const parts = localDateParts(date, timezone);
  const base = Date.UTC(parts.year, parts.month - 1, parts.day);
  const mondayOffset = (parts.weekday + 6) % 7;
  const monday = new Date(base - mondayOffset * 24 * 60 * 60 * 1000);

  return toIsoDateKey({
    year: monday.getUTCFullYear(),
    month: monday.getUTCMonth() + 1,
    day: monday.getUTCDate(),
  });
}

function normalizeTimezone(value) {
  if (typeof value !== "string" || value.trim().length === 0) {
    return "UTC";
  }
  return value.trim();
}

async function getOrCreateWallet(tx, userId) {
  const existing = await tx.wallet.findUnique({ where: { userId } });
  if (existing) {
    return existing;
  }

  return tx.wallet.create({
    data: {
      userId,
      coins: 0,
      stars: 0,
    },
  });
}

async function applyWalletDelta(tx, input) {
  const wallet = await getOrCreateWallet(tx, input.userId);
  const nextCoins = wallet.coins + input.coins;
  const nextStars = wallet.stars + input.stars;

  if (nextCoins < 0 || nextStars < 0) {
    return wallet;
  }

  const updated = await tx.wallet.update({
    where: { id: wallet.id },
    data: {
      coins: nextCoins,
      stars: nextStars,
    },
  });

  if (input.coins !== 0) {
    await tx.walletTransaction.create({
      data: {
        walletId: wallet.id,
        userId: input.userId,
        currencyType: "COIN",
        amount: input.coins,
        reason: "BACKFILL",
        referenceType: input.referenceType,
        referenceId: input.referenceId,
        balanceAfter: nextCoins,
      },
    });
  }

  if (input.stars !== 0) {
    await tx.walletTransaction.create({
      data: {
        walletId: wallet.id,
        userId: input.userId,
        currencyType: "STAR",
        amount: input.stars,
        reason: "BACKFILL",
        referenceType: input.referenceType,
        referenceId: input.referenceId,
        balanceAfter: nextStars,
      },
    });
  }

  return updated;
}

async function ensureStreak(tx, userId, childProfileId, timezone, publishedAt) {
  const weekKey = mondayWeekKey(publishedAt, timezone);

  let streak = await tx.childStreak.findUnique({ where: { childProfileId } });
  if (!streak) {
    streak = await tx.childStreak.create({
      data: {
        userId,
        childProfileId,
        currentDays: 0,
        bestDays: 0,
        shieldCount: 0,
      },
    });
  }

  if (streak.lastShieldGrantWeekKey !== weekKey) {
    streak = await tx.childStreak.update({
      where: { id: streak.id },
      data: {
        shieldCount: Math.min(2, streak.shieldCount + 1),
        lastShieldGrantWeekKey: weekKey,
      },
    });
  }

  const currentKey = localDateKey(publishedAt, timezone);
  const lastKey = streak.lastCountedDate
    ? localDateKey(streak.lastCountedDate, timezone)
    : null;

  if (lastKey === currentKey) {
    return streak;
  }

  let nextCurrent = 1;
  let nextShield = streak.shieldCount;

  if (lastKey) {
    const gap = diffDays(lastKey, currentKey);
    if (gap === 1) {
      nextCurrent = streak.currentDays + 1;
    } else if (gap === 2 && streak.shieldCount > 0) {
      nextCurrent = streak.currentDays + 1;
      nextShield = streak.shieldCount - 1;
    }
  }

  const nextBest = Math.max(streak.bestDays, nextCurrent);

  return tx.childStreak.update({
    where: { id: streak.id },
    data: {
      currentDays: nextCurrent,
      bestDays: nextBest,
      shieldCount: nextShield,
      lastCountedDate: utcDateFromDateKey(currentKey),
    },
  });
}

async function ensureAchievement(tx, userId, key, storyId, reward) {
  const achievement = await tx.achievement.findUnique({ where: { key } });
  if (!achievement) {
    return { unlocked: false, rewardCoins: 0, rewardStars: 0 };
  }

  const existing = await tx.userAchievement.findFirst({
    where: {
      userId,
      achievementId: achievement.id,
    },
  });

  if (existing) {
    return { unlocked: false, rewardCoins: 0, rewardStars: 0 };
  }

  await tx.userAchievement.create({
    data: {
      userId,
      achievementId: achievement.id,
      progressValue: 1,
      metaJson: { storyId, key },
    },
  });

  await applyWalletDelta(tx, {
    userId,
    coins: reward.coins,
    stars: reward.stars,
    referenceType: "achievement",
    referenceId: achievement.id,
  });

  return { unlocked: true, rewardCoins: reward.coins, rewardStars: reward.stars };
}

async function main() {
  const stories = await prisma.story.findMany({
    where: {
      status: "PUBLISHED",
      publishedAt: {
        not: null,
      },
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
    orderBy: {
      publishedAt: "asc",
    },
  });

  let processed = 0;
  let skipped = 0;

  for (const story of stories) {
    if (!story.publishedAt) {
      continue;
    }

    const eventKey = `story-published:${story.id}`;

    const alreadyProcessed = await prisma.gamificationEvent.findUnique({
      where: { eventKey },
      select: { id: true },
    });

    if (alreadyProcessed) {
      skipped += 1;
      continue;
    }

    await prisma.$transaction(async (tx) => {
      await applyWalletDelta(tx, {
        userId: story.userId,
        coins: 12,
        stars: 0,
        referenceType: "story",
        referenceId: story.id,
      });

      const timezone = normalizeTimezone(story.user.timezone);
      const streak = await ensureStreak(
        tx,
        story.userId,
        story.childProfileId,
        timezone,
        story.publishedAt
      );

      const publishedCount = await tx.story.count({
        where: {
          userId: story.userId,
          status: "PUBLISHED",
          publishedAt: {
            lte: story.publishedAt,
          },
        },
      });

      if (publishedCount === 1) {
        await ensureAchievement(tx, story.userId, "primeira_historia", story.id, {
          coins: 50,
          stars: 2,
        });
      }

      if (streak.currentDays >= 7) {
        await ensureAchievement(tx, story.userId, "streak_7_dias", story.id, {
          coins: 80,
          stars: 3,
        });
      }

      if (story.virtue?.slug) {
        await ensureAchievement(
          tx,
          story.userId,
          `virtude_${story.virtue.slug}`,
          story.id,
          {
            coins: 25,
            stars: 1,
          }
        );
      }

      await tx.gamificationEvent.create({
        data: {
          eventKey,
          userId: story.userId,
          storyId: story.id,
          childProfileId: story.childProfileId,
          metaJson: {
            source: "BACKFILL",
          },
        },
      });
    });

    processed += 1;
  }

  console.log(`Historias publicadas encontradas: ${stories.length}`);
  console.log(`Backfill processado: ${processed}`);
  console.log(`Backfill ignorado (idempotencia): ${skipped}`);
}

main()
  .catch((error) => {
    console.error("Falha no backfill de gamificacao:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });

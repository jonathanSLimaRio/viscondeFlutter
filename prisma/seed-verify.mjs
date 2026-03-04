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

const pool = new Pool({
  connectionString: databaseUrl,
});

const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

const demoAccounts = [
  { key: "admin", email: "admin@visconde.app" },
  { key: "demo", email: "demo@visconde.app" },
];

async function verifyAccount(account) {
  const user = await prisma.user.findUnique({
    where: { email: account.email },
    select: { id: true, email: true },
  });

  if (!user) {
    return [`Conta nao encontrada para email=${account.email}`];
  }

  const seededStoryFilter = {
    userId: user.id,
    id: {
      startsWith: `seed_${account.key}_story_`,
    },
  };

  const stories = await prisma.story.findMany({
    where: seededStoryFilter,
    select: {
      id: true,
      status: true,
      sessionKind: true,
      currentStepIndex: true,
      gameMapJson: true,
    },
  });

  const errors = [];

  if (stories.length === 0) {
    errors.push(`Nenhuma historia seedada encontrada para ${account.email}.`);
    return errors;
  }

  const draftPresencialCount = stories.filter(
    (story) => story.status === "DRAFT" && story.sessionKind === "PRESENTIAL"
  ).length;
  if (draftPresencialCount < 1) {
    errors.push(`${account.email}: esperado >=1 DRAFT presencial.`);
  }

  const draftPresencialUnder3Count = stories.filter(
    (story) =>
      story.status === "DRAFT" &&
      story.sessionKind === "PRESENTIAL" &&
      story.currentStepIndex < 3
  ).length;
  if (draftPresencialUnder3Count < 1) {
    errors.push(`${account.email}: esperado >=1 DRAFT presencial com <3 etapas.`);
  }

  const draftPresencialUpTo1Count = stories.filter(
    (story) =>
      story.status === "DRAFT" &&
      story.sessionKind === "PRESENTIAL" &&
      story.currentStepIndex <= 1
  ).length;
  if (draftPresencialUpTo1Count < 1) {
    errors.push(`${account.email}: esperado >=1 DRAFT presencial com 0-1 etapa.`);
  }

  const draftPresencialWith2Count = stories.filter(
    (story) =>
      story.status === "DRAFT" &&
      story.sessionKind === "PRESENTIAL" &&
      story.currentStepIndex === 2
  ).length;
  if (draftPresencialWith2Count < 1) {
    errors.push(`${account.email}: esperado >=1 DRAFT presencial com 2 etapas.`);
  }

  const publishedCount = stories.filter((story) => story.status === "PUBLISHED").length;
  if (publishedCount < 1) {
    errors.push(`${account.email}: esperado >=1 historia PUBLISHED.`);
  }

  const archivedCount = stories.filter((story) => story.status === "ARCHIVED").length;
  if (archivedCount < 1) {
    errors.push(`${account.email}: esperado >=1 historia ARCHIVED.`);
  }

  const missingMapCount = stories.filter((story) => story.gameMapJson == null).length;
  if (missingMapCount > 0) {
    errors.push(
      `${account.email}: ${missingMapCount} historias seedadas sem gameMapJson preenchido.`
    );
  }

  const collections = await prisma.storyCollection.findMany({
    where: { userId: user.id },
    select: {
      childProfileId: true,
      stories: {
        orderBy: { episodeNumber: "desc" },
        take: 1,
        select: { status: true },
      },
    },
  });

  const childIds = [...new Set(collections.map((collection) => collection.childProfileId))];
  for (const childId of childIds) {
    const hasDraftLatest = collections.some(
      (collection) =>
        collection.childProfileId === childId && collection.stories[0]?.status === "DRAFT"
    );
    if (!hasDraftLatest) {
      errors.push(
        `${account.email}: esperado >=1 colecao com ultimo episodio DRAFT para child=${childId}.`
      );
    }
  }

  const storyIds = stories.map((story) => story.id);
  const stepsCount = await prisma.storyStep.count({
    where: { storyId: { in: storyIds } },
  });
  if (stepsCount < 1) {
    errors.push(`${account.email}: esperado >=1 etapa nas historias seedadas.`);
    return errors;
  }

  const missingNodeIndexCount = await prisma.storyStep.count({
    where: {
      storyId: {
        in: storyIds,
      },
      gameNodeIndex: null,
    },
  });
  if (missingNodeIndexCount > 0) {
    errors.push(
      `${account.email}: ${missingNodeIndexCount} etapas sem gameNodeIndex preenchido.`
    );
  }

  return errors;
}

async function main() {
  const allErrors = [];

  for (const account of demoAccounts) {
    const errors = await verifyAccount(account);
    allErrors.push(...errors);
  }

  if (allErrors.length > 0) {
    console.error("Falha na verificacao do seed QA:");
    for (const error of allErrors) {
      console.error(`- ${error}`);
    }
    process.exitCode = 1;
    return;
  }

  console.log("Verificacao de seed QA concluida com sucesso.");
}

main()
  .catch((error) => {
    console.error("Falha ao verificar seed QA:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });

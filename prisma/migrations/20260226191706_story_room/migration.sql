-- CreateEnum
CREATE TYPE "StoryStatus" AS ENUM ('DRAFT', 'PUBLISHED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "StoryMode" AS ENUM ('PARENT_NARRATOR', 'CHILD_CHOOSER');

-- CreateEnum
CREATE TYPE "StoryStepKind" AS ENUM ('NARRATION', 'CHILD_CHOICE', 'SYSTEM');

-- CreateTable
CREATE TABLE "Story" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "childProfileId" TEXT NOT NULL,
    "titleDraft" TEXT NOT NULL,
    "titleFinal" TEXT,
    "theme" TEXT NOT NULL,
    "scenario" TEXT NOT NULL,
    "objective" TEXT NOT NULL,
    "status" "StoryStatus" NOT NULL DEFAULT 'DRAFT',
    "currentMode" "StoryMode" NOT NULL DEFAULT 'PARENT_NARRATOR',
    "currentStepIndex" INTEGER NOT NULL DEFAULT 0,
    "ageSnapshotYears" INTEGER NOT NULL,
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "publishedAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Story_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StoryCharacter" (
    "id" TEXT NOT NULL,
    "storyId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "role" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StoryCharacter_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StoryStep" (
    "id" TEXT NOT NULL,
    "storyId" TEXT NOT NULL,
    "stepIndex" INTEGER NOT NULL,
    "kind" "StoryStepKind" NOT NULL,
    "modeUsed" "StoryMode" NOT NULL,
    "localEventId" TEXT NOT NULL,
    "narratorPrompt" TEXT,
    "childOptionsJson" JSONB,
    "selectedOptionId" TEXT,
    "selectedOptionLabel" TEXT,
    "narratorText" TEXT,
    "autoSavedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StoryStep_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StoryIdeaLog" (
    "id" TEXT NOT NULL,
    "storyId" TEXT NOT NULL,
    "stepIndex" INTEGER,
    "source" TEXT NOT NULL,
    "safetyAdjusted" BOOLEAN NOT NULL DEFAULT false,
    "promptInput" TEXT,
    "ideasJson" JSONB NOT NULL,
    "fallbackReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StoryIdeaLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Story_userId_childProfileId_status_idx" ON "Story"("userId", "childProfileId", "status");

-- CreateIndex
CREATE INDEX "Story_updatedAt_idx" ON "Story"("updatedAt");

-- CreateIndex
CREATE INDEX "StoryCharacter_storyId_idx" ON "StoryCharacter"("storyId");

-- CreateIndex
CREATE UNIQUE INDEX "StoryStep_storyId_stepIndex_key" ON "StoryStep"("storyId", "stepIndex");

-- CreateIndex
CREATE INDEX "StoryStep_storyId_localEventId_idx" ON "StoryStep"("storyId", "localEventId");

-- CreateIndex
CREATE INDEX "StoryStep_storyId_createdAt_idx" ON "StoryStep"("storyId", "createdAt");

-- CreateIndex
CREATE INDEX "StoryIdeaLog_storyId_createdAt_idx" ON "StoryIdeaLog"("storyId", "createdAt");

-- AddForeignKey
ALTER TABLE "Story" ADD CONSTRAINT "Story_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Story" ADD CONSTRAINT "Story_childProfileId_fkey" FOREIGN KEY ("childProfileId") REFERENCES "ChildProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StoryCharacter" ADD CONSTRAINT "StoryCharacter_storyId_fkey" FOREIGN KEY ("storyId") REFERENCES "Story"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StoryStep" ADD CONSTRAINT "StoryStep_storyId_fkey" FOREIGN KEY ("storyId") REFERENCES "Story"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StoryIdeaLog" ADD CONSTRAINT "StoryIdeaLog_storyId_fkey" FOREIGN KEY ("storyId") REFERENCES "Story"("id") ON DELETE CASCADE ON UPDATE CASCADE;

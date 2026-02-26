-- CreateEnum
CREATE TYPE "AgeBand" AS ENUM ('AGE_4_5', 'AGE_6_8', 'AGE_9_10');

-- CreateEnum
CREATE TYPE "VirtueSource" AS ENUM ('MANUAL', 'AUTO');

-- AlterTable
ALTER TABLE "Story"
ADD COLUMN "virtueId" TEXT,
ADD COLUMN "ageBand" "AgeBand",
ADD COLUMN "virtueSource" "VirtueSource",
ADD COLUMN "dilemmaText" TEXT,
ADD COLUMN "endQuestionText" TEXT;

-- CreateTable
CREATE TABLE "Virtue" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "shortDescription" TEXT NOT NULL,
    "iconKey" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Virtue_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VirtueTemplate" (
    "id" TEXT NOT NULL,
    "virtueId" TEXT NOT NULL,
    "ageBand" "AgeBand" NOT NULL,
    "dilemmaText" TEXT NOT NULL,
    "endQuestionText" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "VirtueTemplate_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Virtue_slug_key" ON "Virtue"("slug");

-- CreateIndex
CREATE INDEX "Virtue_isActive_sortOrder_idx" ON "Virtue"("isActive", "sortOrder");

-- CreateIndex
CREATE INDEX "VirtueTemplate_virtueId_ageBand_isActive_idx" ON "VirtueTemplate"("virtueId", "ageBand", "isActive");

-- CreateIndex
CREATE UNIQUE INDEX "VirtueTemplate_virtueId_ageBand_sortOrder_key" ON "VirtueTemplate"("virtueId", "ageBand", "sortOrder");

-- CreateIndex
CREATE INDEX "Story_childProfileId_virtueId_status_idx" ON "Story"("childProfileId", "virtueId", "status");

-- AddForeignKey
ALTER TABLE "Story" ADD CONSTRAINT "Story_virtueId_fkey" FOREIGN KEY ("virtueId") REFERENCES "Virtue"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VirtueTemplate" ADD CONSTRAINT "VirtueTemplate_virtueId_fkey" FOREIGN KEY ("virtueId") REFERENCES "Virtue"("id") ON DELETE CASCADE ON UPDATE CASCADE;

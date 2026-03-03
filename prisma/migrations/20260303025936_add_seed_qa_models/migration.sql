-- CreateEnum
CREATE TYPE "VoiceProfileStatus" AS ENUM ('PENDING', 'READY', 'FAILED');

-- CreateEnum
CREATE TYPE "NarrationJobStatus" AS ENUM ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED');

-- CreateEnum
CREATE TYPE "IllustrationStatus" AS ENUM ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED');

-- CreateEnum
CREATE TYPE "BookProjectStatus" AS ENUM ('DRAFT', 'GENERATING', 'READY', 'FAILED');

-- CreateEnum
CREATE TYPE "PrintOrderStatus" AS ENUM ('PENDING', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELED');

-- CreateEnum
CREATE TYPE "RarityLevel" AS ENUM ('COMMON', 'RARE', 'EPIC', 'LEGENDARY');

-- CreateEnum
CREATE TYPE "ItemCategory" AS ENUM ('ITEM', 'COMPANION', 'BADGE');

-- AlterEnum
ALTER TYPE "CallMode" ADD VALUE 'COOP';

-- AlterTable
ALTER TABLE "Story" ADD COLUMN     "artStyleId" TEXT;

-- CreateTable
CREATE TABLE "StoryVote" (
    "id" TEXT NOT NULL,
    "storyId" TEXT NOT NULL,
    "stepIndex" INTEGER NOT NULL,
    "participantId" TEXT NOT NULL,
    "optionId" TEXT NOT NULL,
    "optionLabel" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StoryVote_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VoiceProfile" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "relationship" TEXT,
    "status" "VoiceProfileStatus" NOT NULL DEFAULT 'PENDING',
    "provider" TEXT,
    "metadataJson" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "VoiceProfile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VoiceSample" (
    "id" TEXT NOT NULL,
    "voiceProfileId" TEXT NOT NULL,
    "storageUrl" TEXT NOT NULL,
    "duration" DOUBLE PRECISION,
    "transcript" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "VoiceSample_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NarrationJob" (
    "id" TEXT NOT NULL,
    "storyId" TEXT NOT NULL,
    "stepIndex" INTEGER,
    "voiceProfileId" TEXT NOT NULL,
    "status" "NarrationJobStatus" NOT NULL DEFAULT 'PENDING',
    "outputUrl" TEXT,
    "metadataJson" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NarrationJob_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ArtStyle" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "promptTemplate" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ArtStyle_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ChildAvatar" (
    "id" TEXT NOT NULL,
    "childProfileId" TEXT NOT NULL,
    "status" TEXT,
    "photoUrl" TEXT,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ChildAvatar_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StoryIllustration" (
    "id" TEXT NOT NULL,
    "storyId" TEXT NOT NULL,
    "stepIndex" INTEGER NOT NULL,
    "status" "IllustrationStatus" NOT NULL DEFAULT 'PENDING',
    "promptUsed" TEXT,
    "imageUrl" TEXT,
    "provider" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "StoryIllustration_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "InventoryItem" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "rarity" "RarityLevel" NOT NULL DEFAULT 'COMMON',
    "category" "ItemCategory" NOT NULL DEFAULT 'ITEM',
    "icon" TEXT NOT NULL,
    "tags" TEXT[],

    CONSTRAINT "InventoryItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ChildInventory" (
    "id" TEXT NOT NULL,
    "childProfileId" TEXT NOT NULL,
    "itemId" TEXT NOT NULL,
    "qty" INTEGER NOT NULL DEFAULT 1,
    "acquiredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastUsedAt" TIMESTAMP(3),

    CONSTRAINT "ChildInventory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StoryMemory" (
    "id" TEXT NOT NULL,
    "storyId" TEXT NOT NULL,
    "childProfileId" TEXT NOT NULL,
    "summary" TEXT NOT NULL,
    "usedItems" TEXT[],
    "virtueLearned" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "StoryMemory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BookProject" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "childProfileId" TEXT NOT NULL,
    "month" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "status" "BookProjectStatus" NOT NULL DEFAULT 'DRAFT',
    "pdfUrl" TEXT,
    "includedStories" TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "BookProject_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PrintOrder" (
    "id" TEXT NOT NULL,
    "bookProjectId" TEXT NOT NULL,
    "provider" TEXT,
    "status" "PrintOrderStatus" NOT NULL DEFAULT 'PENDING',
    "trackingCode" TEXT,
    "addressSnapshot" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PrintOrder_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "StoryVote_storyId_stepIndex_idx" ON "StoryVote"("storyId", "stepIndex");

-- CreateIndex
CREATE UNIQUE INDEX "StoryVote_storyId_stepIndex_participantId_key" ON "StoryVote"("storyId", "stepIndex", "participantId");

-- CreateIndex
CREATE INDEX "VoiceProfile_userId_status_idx" ON "VoiceProfile"("userId", "status");

-- CreateIndex
CREATE INDEX "VoiceSample_voiceProfileId_idx" ON "VoiceSample"("voiceProfileId");

-- CreateIndex
CREATE INDEX "NarrationJob_storyId_status_idx" ON "NarrationJob"("storyId", "status");

-- CreateIndex
CREATE INDEX "NarrationJob_voiceProfileId_status_idx" ON "NarrationJob"("voiceProfileId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "ChildAvatar_childProfileId_key" ON "ChildAvatar"("childProfileId");

-- CreateIndex
CREATE UNIQUE INDEX "StoryIllustration_storyId_stepIndex_key" ON "StoryIllustration"("storyId", "stepIndex");

-- CreateIndex
CREATE UNIQUE INDEX "InventoryItem_key_key" ON "InventoryItem"("key");

-- CreateIndex
CREATE UNIQUE INDEX "ChildInventory_childProfileId_itemId_key" ON "ChildInventory"("childProfileId", "itemId");

-- CreateIndex
CREATE UNIQUE INDEX "StoryMemory_storyId_childProfileId_key" ON "StoryMemory"("storyId", "childProfileId");

-- CreateIndex
CREATE UNIQUE INDEX "BookProject_childProfileId_month_key" ON "BookProject"("childProfileId", "month");

-- CreateIndex
CREATE INDEX "PrintOrder_bookProjectId_status_idx" ON "PrintOrder"("bookProjectId", "status");

-- AddForeignKey
ALTER TABLE "Story" ADD CONSTRAINT "Story_artStyleId_fkey" FOREIGN KEY ("artStyleId") REFERENCES "ArtStyle"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StoryVote" ADD CONSTRAINT "StoryVote_storyId_fkey" FOREIGN KEY ("storyId") REFERENCES "Story"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StoryVote" ADD CONSTRAINT "StoryVote_participantId_fkey" FOREIGN KEY ("participantId") REFERENCES "RemoteStoryParticipant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VoiceProfile" ADD CONSTRAINT "VoiceProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VoiceSample" ADD CONSTRAINT "VoiceSample_voiceProfileId_fkey" FOREIGN KEY ("voiceProfileId") REFERENCES "VoiceProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NarrationJob" ADD CONSTRAINT "NarrationJob_storyId_fkey" FOREIGN KEY ("storyId") REFERENCES "Story"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NarrationJob" ADD CONSTRAINT "NarrationJob_voiceProfileId_fkey" FOREIGN KEY ("voiceProfileId") REFERENCES "VoiceProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ChildAvatar" ADD CONSTRAINT "ChildAvatar_childProfileId_fkey" FOREIGN KEY ("childProfileId") REFERENCES "ChildProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StoryIllustration" ADD CONSTRAINT "StoryIllustration_storyId_fkey" FOREIGN KEY ("storyId") REFERENCES "Story"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ChildInventory" ADD CONSTRAINT "ChildInventory_childProfileId_fkey" FOREIGN KEY ("childProfileId") REFERENCES "ChildProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ChildInventory" ADD CONSTRAINT "ChildInventory_itemId_fkey" FOREIGN KEY ("itemId") REFERENCES "InventoryItem"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StoryMemory" ADD CONSTRAINT "StoryMemory_storyId_fkey" FOREIGN KEY ("storyId") REFERENCES "Story"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StoryMemory" ADD CONSTRAINT "StoryMemory_childProfileId_fkey" FOREIGN KEY ("childProfileId") REFERENCES "ChildProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookProject" ADD CONSTRAINT "BookProject_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookProject" ADD CONSTRAINT "BookProject_childProfileId_fkey" FOREIGN KEY ("childProfileId") REFERENCES "ChildProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PrintOrder" ADD CONSTRAINT "PrintOrder_bookProjectId_fkey" FOREIGN KEY ("bookProjectId") REFERENCES "BookProject"("id") ON DELETE CASCADE ON UPDATE CASCADE;

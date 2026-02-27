-- CreateEnum
CREATE TYPE "CurrencyType" AS ENUM ('COIN', 'STAR');
CREATE TYPE "CatalogItemType" AS ENUM ('SCENARIO', 'CHARACTER', 'SKIN', 'AVATAR');
CREATE TYPE "WalletReason" AS ENUM ('STORY_PUBLISHED', 'MISSION_COMPLETED', 'ACHIEVEMENT_UNLOCK', 'PURCHASE_REFUND', 'PURCHASE_SPEND', 'BACKFILL');
CREATE TYPE "MissionKind" AS ENUM ('PUBLISH_COUNT', 'PUBLISH_WITH_VIRTUE', 'CONTINUE_EPISODE');
CREATE TYPE "MissionStatus" AS ENUM ('ACTIVE', 'COMPLETED', 'EXPIRED');

-- CreateTable
CREATE TABLE "Wallet" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "coins" INTEGER NOT NULL DEFAULT 0,
    "stars" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "Wallet_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "WalletTransaction" (
    "id" TEXT NOT NULL,
    "walletId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "currencyType" "CurrencyType" NOT NULL,
    "amount" INTEGER NOT NULL,
    "reason" "WalletReason" NOT NULL,
    "referenceType" TEXT,
    "referenceId" TEXT,
    "balanceAfter" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "WalletTransaction_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "Achievement" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "iconKey" TEXT NOT NULL,
    "rewardCoins" INTEGER NOT NULL DEFAULT 0,
    "rewardStars" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "Achievement_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "UserAchievement" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "achievementId" TEXT NOT NULL,
    "unlockedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "progressValue" INTEGER NOT NULL DEFAULT 0,
    "metaJson" JSONB,
    CONSTRAINT "UserAchievement_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "GamificationCatalogItem" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "type" "CatalogItemType" NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "iconKey" TEXT NOT NULL,
    "priceCoins" INTEGER NOT NULL DEFAULT 0,
    "priceStars" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "GamificationCatalogItem_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ChildInventoryItem" (
    "id" TEXT NOT NULL,
    "childProfileId" TEXT NOT NULL,
    "itemId" TEXT NOT NULL,
    "unlockedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "equipped" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "ChildInventoryItem_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ChildStreak" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "childProfileId" TEXT NOT NULL,
    "currentDays" INTEGER NOT NULL DEFAULT 0,
    "bestDays" INTEGER NOT NULL DEFAULT 0,
    "lastCountedDate" TIMESTAMP(3),
    "shieldCount" INTEGER NOT NULL DEFAULT 0,
    "lastShieldGrantWeekKey" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "ChildStreak_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ChildWeeklyMission" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "childProfileId" TEXT NOT NULL,
    "weekKey" TEXT NOT NULL,
    "kind" "MissionKind" NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "targetValue" INTEGER NOT NULL,
    "progressValue" INTEGER NOT NULL DEFAULT 0,
    "status" "MissionStatus" NOT NULL DEFAULT 'ACTIVE',
    "virtueId" TEXT,
    "rewardCoins" INTEGER NOT NULL DEFAULT 0,
    "rewardStars" INTEGER NOT NULL DEFAULT 0,
    "completedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "ChildWeeklyMission_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "GamificationEvent" (
    "id" TEXT NOT NULL,
    "eventKey" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "storyId" TEXT,
    "childProfileId" TEXT,
    "processedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "metaJson" JSONB,
    CONSTRAINT "GamificationEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Wallet_userId_key" ON "Wallet"("userId");
CREATE INDEX "WalletTransaction_userId_createdAt_idx" ON "WalletTransaction"("userId", "createdAt");
CREATE UNIQUE INDEX "Achievement_key_key" ON "Achievement"("key");
CREATE INDEX "Achievement_isActive_sortOrder_idx" ON "Achievement"("isActive", "sortOrder");
CREATE UNIQUE INDEX "UserAchievement_userId_achievementId_key" ON "UserAchievement"("userId", "achievementId");
CREATE INDEX "UserAchievement_userId_unlockedAt_idx" ON "UserAchievement"("userId", "unlockedAt");
CREATE UNIQUE INDEX "GamificationCatalogItem_key_key" ON "GamificationCatalogItem"("key");
CREATE INDEX "GamificationCatalogItem_type_isActive_sortOrder_idx" ON "GamificationCatalogItem"("type", "isActive", "sortOrder");
CREATE UNIQUE INDEX "ChildInventoryItem_childProfileId_itemId_key" ON "ChildInventoryItem"("childProfileId", "itemId");
CREATE INDEX "ChildInventoryItem_childProfileId_equipped_idx" ON "ChildInventoryItem"("childProfileId", "equipped");
CREATE UNIQUE INDEX "ChildStreak_childProfileId_key" ON "ChildStreak"("childProfileId");
CREATE INDEX "ChildStreak_userId_updatedAt_idx" ON "ChildStreak"("userId", "updatedAt");
CREATE INDEX "ChildWeeklyMission_childProfileId_weekKey_status_idx" ON "ChildWeeklyMission"("childProfileId", "weekKey", "status");
CREATE UNIQUE INDEX "ChildWeeklyMission_childProfileId_weekKey_kind_virtueId_key" ON "ChildWeeklyMission"("childProfileId", "weekKey", "kind", "virtueId");
CREATE UNIQUE INDEX "GamificationEvent_eventKey_key" ON "GamificationEvent"("eventKey");
CREATE INDEX "GamificationEvent_userId_processedAt_idx" ON "GamificationEvent"("userId", "processedAt");
CREATE INDEX "GamificationEvent_storyId_processedAt_idx" ON "GamificationEvent"("storyId", "processedAt");

-- AddForeignKey
ALTER TABLE "Wallet" ADD CONSTRAINT "Wallet_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "WalletTransaction" ADD CONSTRAINT "WalletTransaction_walletId_fkey" FOREIGN KEY ("walletId") REFERENCES "Wallet"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "WalletTransaction" ADD CONSTRAINT "WalletTransaction_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "UserAchievement" ADD CONSTRAINT "UserAchievement_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "UserAchievement" ADD CONSTRAINT "UserAchievement_achievementId_fkey" FOREIGN KEY ("achievementId") REFERENCES "Achievement"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ChildInventoryItem" ADD CONSTRAINT "ChildInventoryItem_childProfileId_fkey" FOREIGN KEY ("childProfileId") REFERENCES "ChildProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ChildInventoryItem" ADD CONSTRAINT "ChildInventoryItem_itemId_fkey" FOREIGN KEY ("itemId") REFERENCES "GamificationCatalogItem"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ChildStreak" ADD CONSTRAINT "ChildStreak_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ChildStreak" ADD CONSTRAINT "ChildStreak_childProfileId_fkey" FOREIGN KEY ("childProfileId") REFERENCES "ChildProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ChildWeeklyMission" ADD CONSTRAINT "ChildWeeklyMission_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ChildWeeklyMission" ADD CONSTRAINT "ChildWeeklyMission_childProfileId_fkey" FOREIGN KEY ("childProfileId") REFERENCES "ChildProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ChildWeeklyMission" ADD CONSTRAINT "ChildWeeklyMission_virtueId_fkey" FOREIGN KEY ("virtueId") REFERENCES "Virtue"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "GamificationEvent" ADD CONSTRAINT "GamificationEvent_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

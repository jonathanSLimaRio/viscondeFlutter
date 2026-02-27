-- CreateTable
CREATE TABLE "StoryCollection" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "childProfileId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "theme" TEXT NOT NULL,
    "virtueId" TEXT,
    "isFavorite" BOOLEAN NOT NULL DEFAULT false,
    "templateFromStoryId" TEXT,
    "lastReferenceAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "StoryCollection_pkey" PRIMARY KEY ("id")
);

-- AlterTable
ALTER TABLE "Story" ADD COLUMN "collectionId" TEXT;
ALTER TABLE "Story" ADD COLUMN "episodeNumber" INTEGER NOT NULL DEFAULT 1;
ALTER TABLE "Story" ADD COLUMN "continuedFromStoryId" TEXT;

-- Backfill StoryCollection from existing stories (1 collection per legacy story)
INSERT INTO "StoryCollection" (
    "id",
    "userId",
    "childProfileId",
    "title",
    "theme",
    "virtueId",
    "isFavorite",
    "templateFromStoryId",
    "lastReferenceAt",
    "createdAt",
    "updatedAt"
)
SELECT
    'col_' || "id" AS "id",
    "userId",
    "childProfileId",
    COALESCE("titleFinal", "titleDraft") AS "title",
    "theme",
    "virtueId",
    false AS "isFavorite",
    NULL::TEXT AS "templateFromStoryId",
    CASE
        WHEN "status" = 'PUBLISHED' AND "publishedAt" IS NOT NULL THEN "publishedAt"
        ELSE "updatedAt"
    END AS "lastReferenceAt",
    "createdAt",
    "updatedAt"
FROM "Story";

-- Backfill collectionId in Story
UPDATE "Story"
SET "collectionId" = 'col_' || "id"
WHERE "collectionId" IS NULL;

-- Make collectionId required after backfill
ALTER TABLE "Story" ALTER COLUMN "collectionId" SET NOT NULL;

-- CreateIndex
CREATE INDEX "StoryCollection_userId_childProfileId_lastReferenceAt_idx" ON "StoryCollection"("userId", "childProfileId", "lastReferenceAt");
CREATE INDEX "StoryCollection_userId_isFavorite_lastReferenceAt_idx" ON "StoryCollection"("userId", "isFavorite", "lastReferenceAt");
CREATE INDEX "StoryCollection_userId_virtueId_lastReferenceAt_idx" ON "StoryCollection"("userId", "virtueId", "lastReferenceAt");
CREATE INDEX "Story_collectionId_status_publishedAt_updatedAt_idx" ON "Story"("collectionId", "status", "publishedAt", "updatedAt");
CREATE UNIQUE INDEX "Story_collectionId_episodeNumber_key" ON "Story"("collectionId", "episodeNumber");

-- AddForeignKey
ALTER TABLE "StoryCollection" ADD CONSTRAINT "StoryCollection_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "StoryCollection" ADD CONSTRAINT "StoryCollection_childProfileId_fkey" FOREIGN KEY ("childProfileId") REFERENCES "ChildProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "StoryCollection" ADD CONSTRAINT "StoryCollection_virtueId_fkey" FOREIGN KEY ("virtueId") REFERENCES "Virtue"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "StoryCollection" ADD CONSTRAINT "StoryCollection_templateFromStoryId_fkey" FOREIGN KEY ("templateFromStoryId") REFERENCES "Story"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "Story" ADD CONSTRAINT "Story_collectionId_fkey" FOREIGN KEY ("collectionId") REFERENCES "StoryCollection"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Story" ADD CONSTRAINT "Story_continuedFromStoryId_fkey" FOREIGN KEY ("continuedFromStoryId") REFERENCES "Story"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- CreateEnum
CREATE TYPE "StorySessionKind" AS ENUM ('PRESENTIAL', 'REMOTE');

-- CreateEnum
CREATE TYPE "RemoteRoomStatus" AS ENUM ('OPEN', 'ACTIVE', 'CLOSED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "RemoteParticipantRole" AS ENUM ('HOST_PARENT', 'GUEST_CHILD');

-- CreateEnum
CREATE TYPE "RemoteParticipantStatus" AS ENUM ('CONNECTED', 'DISCONNECTED', 'LEFT');

-- CreateEnum
CREATE TYPE "CallMode" AS ENUM ('NONE', 'AUDIO', 'VIDEO');

-- CreateEnum
CREATE TYPE "InteractionType" AS ENUM ('CHAT', 'REACTION');

-- AlterTable
ALTER TABLE "Story"
ADD COLUMN "sessionKind" "StorySessionKind" NOT NULL DEFAULT 'PRESENTIAL';

-- CreateTable
CREATE TABLE "RemoteStoryRoom" (
    "id" TEXT NOT NULL,
    "storyId" TEXT NOT NULL,
    "ownerUserId" TEXT NOT NULL,
    "status" "RemoteRoomStatus" NOT NULL DEFAULT 'OPEN',
    "joinCodeHash" TEXT NOT NULL,
    "joinCodeExpiresAt" TIMESTAMP(3) NOT NULL,
    "joinCodeConsumedAt" TIMESTAMP(3),
    "callMode" "CallMode" NOT NULL DEFAULT 'AUDIO',
    "maxParticipants" INTEGER NOT NULL DEFAULT 2,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "closedAt" TIMESTAMP(3),

    CONSTRAINT "RemoteStoryRoom_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RemoteStoryParticipant" (
    "id" TEXT NOT NULL,
    "remoteRoomId" TEXT NOT NULL,
    "role" "RemoteParticipantRole" NOT NULL,
    "displayName" TEXT NOT NULL,
    "status" "RemoteParticipantStatus" NOT NULL DEFAULT 'CONNECTED',
    "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "leftAt" TIMESTAMP(3),
    "deviceInfo" TEXT,

    CONSTRAINT "RemoteStoryParticipant_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StoryInteraction" (
    "id" TEXT NOT NULL,
    "storyId" TEXT NOT NULL,
    "remoteRoomId" TEXT NOT NULL,
    "type" "InteractionType" NOT NULL,
    "authorRole" "RemoteParticipantRole" NOT NULL,
    "authorUserId" TEXT,
    "authorParticipantId" TEXT,
    "authorDisplayName" TEXT NOT NULL,
    "messageText" TEXT,
    "emoji" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StoryInteraction_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "RemoteStoryRoom_storyId_key" ON "RemoteStoryRoom"("storyId");

-- CreateIndex
CREATE INDEX "RemoteStoryRoom_ownerUserId_status_idx" ON "RemoteStoryRoom"("ownerUserId", "status");

-- CreateIndex
CREATE INDEX "RemoteStoryRoom_joinCodeExpiresAt_idx" ON "RemoteStoryRoom"("joinCodeExpiresAt");

-- CreateIndex
CREATE UNIQUE INDEX "RemoteStoryParticipant_remoteRoomId_role_key" ON "RemoteStoryParticipant"("remoteRoomId", "role");

-- CreateIndex
CREATE INDEX "RemoteStoryParticipant_remoteRoomId_status_idx" ON "RemoteStoryParticipant"("remoteRoomId", "status");

-- CreateIndex
CREATE INDEX "StoryInteraction_storyId_createdAt_idx" ON "StoryInteraction"("storyId", "createdAt");

-- CreateIndex
CREATE INDEX "StoryInteraction_remoteRoomId_createdAt_idx" ON "StoryInteraction"("remoteRoomId", "createdAt");

-- AddForeignKey
ALTER TABLE "RemoteStoryRoom" ADD CONSTRAINT "RemoteStoryRoom_storyId_fkey" FOREIGN KEY ("storyId") REFERENCES "Story"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RemoteStoryRoom" ADD CONSTRAINT "RemoteStoryRoom_ownerUserId_fkey" FOREIGN KEY ("ownerUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RemoteStoryParticipant" ADD CONSTRAINT "RemoteStoryParticipant_remoteRoomId_fkey" FOREIGN KEY ("remoteRoomId") REFERENCES "RemoteStoryRoom"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StoryInteraction" ADD CONSTRAINT "StoryInteraction_storyId_fkey" FOREIGN KEY ("storyId") REFERENCES "Story"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StoryInteraction" ADD CONSTRAINT "StoryInteraction_remoteRoomId_fkey" FOREIGN KEY ("remoteRoomId") REFERENCES "RemoteStoryRoom"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StoryInteraction" ADD CONSTRAINT "StoryInteraction_authorUserId_fkey" FOREIGN KEY ("authorUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StoryInteraction" ADD CONSTRAINT "StoryInteraction_authorParticipantId_fkey" FOREIGN KEY ("authorParticipantId") REFERENCES "RemoteStoryParticipant"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- DropForeignKey
ALTER TABLE "PrintOrder" DROP CONSTRAINT "PrintOrder_bookProjectId_fkey";

-- DropForeignKey
ALTER TABLE "RemoteStoryParticipant" DROP CONSTRAINT "RemoteStoryParticipant_remoteRoomId_fkey";

-- DropForeignKey
ALTER TABLE "RemoteStoryRoom" DROP CONSTRAINT "RemoteStoryRoom_ownerUserId_fkey";

-- DropForeignKey
ALTER TABLE "RemoteStoryRoom" DROP CONSTRAINT "RemoteStoryRoom_storyId_fkey";

-- DropForeignKey
ALTER TABLE "StoryInteraction" DROP CONSTRAINT "StoryInteraction_authorParticipantId_fkey";

-- DropForeignKey
ALTER TABLE "StoryInteraction" DROP CONSTRAINT "StoryInteraction_authorUserId_fkey";

-- DropForeignKey
ALTER TABLE "StoryInteraction" DROP CONSTRAINT "StoryInteraction_remoteRoomId_fkey";

-- DropForeignKey
ALTER TABLE "StoryInteraction" DROP CONSTRAINT "StoryInteraction_storyId_fkey";

-- DropForeignKey
ALTER TABLE "StoryVote" DROP CONSTRAINT "StoryVote_participantId_fkey";

-- DropForeignKey
ALTER TABLE "StoryVote" DROP CONSTRAINT "StoryVote_storyId_fkey";

-- DropTable
DROP TABLE "PrintOrder";

-- DropTable
DROP TABLE "RemoteStoryParticipant";

-- DropTable
DROP TABLE "RemoteStoryRoom";

-- DropTable
DROP TABLE "StoryInteraction";

-- DropTable
DROP TABLE "StoryVote";

-- DropEnum
DROP TYPE "CallMode";

-- DropEnum
DROP TYPE "InteractionType";

-- DropEnum
DROP TYPE "PrintOrderStatus";

-- DropEnum
DROP TYPE "RemoteParticipantRole";

-- DropEnum
DROP TYPE "RemoteParticipantStatus";

-- DropEnum
DROP TYPE "RemoteRoomStatus";


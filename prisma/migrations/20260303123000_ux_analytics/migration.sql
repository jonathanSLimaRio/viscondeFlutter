-- CreateEnum
CREATE TYPE "UxEventName" AS ENUM (
    'SESSION_STARTED',
    'AUTH_ERROR_SHOWN',
    'STORY_CREATE_STARTED',
    'STORY_CREATE_STEP_COMPLETED',
    'STORY_CREATE_ABANDONED',
    'STORY_PUBLISHED',
    'GAME_HUB_OPENED'
);

-- CreateTable
CREATE TABLE "UxAnalyticsEvent" (
    "id" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "eventName" "UxEventName" NOT NULL,
    "appSessionId" TEXT NOT NULL,
    "userId" TEXT,
    "mobileSessionId" TEXT,
    "childHash" TEXT,
    "occurredAt" TIMESTAMP(3) NOT NULL,
    "receivedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "source" TEXT,
    "params" JSONB,
    "platform" TEXT,
    "appVersion" TEXT,
    "appBuild" TEXT,
    "locale" TEXT,
    "timezone" TEXT,

    CONSTRAINT "UxAnalyticsEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "UxAnalyticsEvent_eventId_key" ON "UxAnalyticsEvent"("eventId");
CREATE INDEX "UxAnalyticsEvent_eventName_occurredAt_idx" ON "UxAnalyticsEvent"("eventName", "occurredAt");
CREATE INDEX "UxAnalyticsEvent_appSessionId_occurredAt_idx" ON "UxAnalyticsEvent"("appSessionId", "occurredAt");
CREATE INDEX "UxAnalyticsEvent_userId_occurredAt_idx" ON "UxAnalyticsEvent"("userId", "occurredAt");
CREATE INDEX "UxAnalyticsEvent_mobileSessionId_occurredAt_idx" ON "UxAnalyticsEvent"("mobileSessionId", "occurredAt");
CREATE INDEX "UxAnalyticsEvent_childHash_occurredAt_idx" ON "UxAnalyticsEvent"("childHash", "occurredAt");

-- AddForeignKey
ALTER TABLE "UxAnalyticsEvent" ADD CONSTRAINT "UxAnalyticsEvent_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('USER', 'ADMIN');
CREATE TYPE "PromptKind" AS ENUM ('IDEA_SYSTEM', 'IDEA_FALLBACK', 'NARRATOR_HINT');
CREATE TYPE "StoryTemplateNodeKind" AS ENUM ('START', 'NARRATION', 'CHOICE', 'END');
CREATE TYPE "ModerationPolicy" AS ENUM ('BLOCK', 'SANITIZE');
CREATE TYPE "ModerationScope" AS ENUM ('USER_NAME', 'CHILD_NAME', 'STORY_TEXT', 'CHAT_TEXT', 'TEMPLATE_TEXT');
CREATE TYPE "ModerationAction" AS ENUM ('BLOCK', 'SANITIZE');

-- AlterTable
ALTER TABLE "User" ADD COLUMN "role" "UserRole" NOT NULL DEFAULT 'USER';
ALTER TABLE "Story" ADD COLUMN "sourceTemplateId" TEXT;

-- CreateTable
CREATE TABLE "StoryTheme" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "shortDescription" TEXT NOT NULL,
    "iconKey" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "StoryTheme_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ContentPrompt" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "kind" "PromptKind" NOT NULL,
    "title" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "themeId" TEXT,
    "virtueId" TEXT,
    "ageBand" "AgeBand",
    "mode" "StoryMode",
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "ContentPrompt_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "StoryTemplate" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "themeId" TEXT,
    "virtueId" TEXT,
    "ageBand" "AgeBand",
    "defaultScenario" TEXT NOT NULL,
    "defaultObjective" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "isPublished" BOOLEAN NOT NULL DEFAULT false,
    "version" INTEGER NOT NULL DEFAULT 1,
    "createdByUserId" TEXT NOT NULL,
    "updatedByUserId" TEXT NOT NULL,
    "publishedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "StoryTemplate_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "StoryTemplateCharacter" (
    "id" TEXT NOT NULL,
    "templateId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "role" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "StoryTemplateCharacter_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "StoryTemplateNode" (
    "id" TEXT NOT NULL,
    "templateId" TEXT NOT NULL,
    "nodeKey" TEXT NOT NULL,
    "kind" "StoryTemplateNodeKind" NOT NULL,
    "title" TEXT NOT NULL,
    "narratorText" TEXT,
    "promptHint" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "StoryTemplateNode_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "StoryTemplateOption" (
    "id" TEXT NOT NULL,
    "nodeId" TEXT NOT NULL,
    "optionKey" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "nextNodeId" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "StoryTemplateOption_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ModerationTerm" (
    "id" TEXT NOT NULL,
    "termNormalized" TEXT NOT NULL,
    "displayTerm" TEXT NOT NULL,
    "policy" "ModerationPolicy" NOT NULL,
    "replacement" TEXT,
    "scope" "ModerationScope" NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdByUserId" TEXT NOT NULL,
    "updatedByUserId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "ModerationTerm_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ModerationEvent" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "scope" "ModerationScope" NOT NULL,
    "field" TEXT NOT NULL,
    "originalPreview" TEXT NOT NULL,
    "action" "ModerationAction" NOT NULL,
    "matchedTerm" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ModerationEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "StoryTheme_slug_key" ON "StoryTheme"("slug");
CREATE INDEX "StoryTheme_isActive_sortOrder_idx" ON "StoryTheme"("isActive", "sortOrder");

CREATE UNIQUE INDEX "ContentPrompt_key_key" ON "ContentPrompt"("key");
CREATE INDEX "ContentPrompt_kind_isActive_sortOrder_idx" ON "ContentPrompt"("kind", "isActive", "sortOrder");
CREATE INDEX "ContentPrompt_themeId_virtueId_ageBand_mode_idx" ON "ContentPrompt"("themeId", "virtueId", "ageBand", "mode");

CREATE UNIQUE INDEX "StoryTemplate_slug_key" ON "StoryTemplate"("slug");
CREATE INDEX "StoryTemplate_isPublished_isActive_updatedAt_idx" ON "StoryTemplate"("isPublished", "isActive", "updatedAt");
CREATE INDEX "StoryTemplate_themeId_virtueId_ageBand_idx" ON "StoryTemplate"("themeId", "virtueId", "ageBand");

CREATE INDEX "StoryTemplateCharacter_templateId_sortOrder_idx" ON "StoryTemplateCharacter"("templateId", "sortOrder");

CREATE UNIQUE INDEX "StoryTemplateNode_templateId_nodeKey_key" ON "StoryTemplateNode"("templateId", "nodeKey");
CREATE INDEX "StoryTemplateNode_templateId_sortOrder_idx" ON "StoryTemplateNode"("templateId", "sortOrder");

CREATE UNIQUE INDEX "StoryTemplateOption_nodeId_optionKey_key" ON "StoryTemplateOption"("nodeId", "optionKey");
CREATE INDEX "StoryTemplateOption_nodeId_sortOrder_idx" ON "StoryTemplateOption"("nodeId", "sortOrder");
CREATE INDEX "StoryTemplateOption_nextNodeId_idx" ON "StoryTemplateOption"("nextNodeId");

CREATE UNIQUE INDEX "ModerationTerm_termNormalized_key" ON "ModerationTerm"("termNormalized");
CREATE INDEX "ModerationTerm_scope_isActive_idx" ON "ModerationTerm"("scope", "isActive");

CREATE INDEX "ModerationEvent_scope_createdAt_idx" ON "ModerationEvent"("scope", "createdAt");
CREATE INDEX "ModerationEvent_userId_createdAt_idx" ON "ModerationEvent"("userId", "createdAt");

CREATE INDEX "Story_sourceTemplateId_idx" ON "Story"("sourceTemplateId");

-- AddForeignKey
ALTER TABLE "ContentPrompt" ADD CONSTRAINT "ContentPrompt_themeId_fkey" FOREIGN KEY ("themeId") REFERENCES "StoryTheme"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "ContentPrompt" ADD CONSTRAINT "ContentPrompt_virtueId_fkey" FOREIGN KEY ("virtueId") REFERENCES "Virtue"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "StoryTemplate" ADD CONSTRAINT "StoryTemplate_themeId_fkey" FOREIGN KEY ("themeId") REFERENCES "StoryTheme"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "StoryTemplate" ADD CONSTRAINT "StoryTemplate_virtueId_fkey" FOREIGN KEY ("virtueId") REFERENCES "Virtue"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "StoryTemplate" ADD CONSTRAINT "StoryTemplate_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "StoryTemplate" ADD CONSTRAINT "StoryTemplate_updatedByUserId_fkey" FOREIGN KEY ("updatedByUserId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "StoryTemplateCharacter" ADD CONSTRAINT "StoryTemplateCharacter_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "StoryTemplate"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "StoryTemplateNode" ADD CONSTRAINT "StoryTemplateNode_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "StoryTemplate"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "StoryTemplateOption" ADD CONSTRAINT "StoryTemplateOption_nodeId_fkey" FOREIGN KEY ("nodeId") REFERENCES "StoryTemplateNode"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "StoryTemplateOption" ADD CONSTRAINT "StoryTemplateOption_nextNodeId_fkey" FOREIGN KEY ("nextNodeId") REFERENCES "StoryTemplateNode"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ModerationTerm" ADD CONSTRAINT "ModerationTerm_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "ModerationTerm" ADD CONSTRAINT "ModerationTerm_updatedByUserId_fkey" FOREIGN KEY ("updatedByUserId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "ModerationEvent" ADD CONSTRAINT "ModerationEvent_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "Story" ADD CONSTRAINT "Story_sourceTemplateId_fkey" FOREIGN KEY ("sourceTemplateId") REFERENCES "StoryTemplate"("id") ON DELETE SET NULL ON UPDATE CASCADE;

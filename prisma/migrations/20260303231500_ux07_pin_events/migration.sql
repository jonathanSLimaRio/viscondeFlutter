-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.

ALTER TYPE "UxEventName" ADD VALUE 'PIN_PROMPT_SHOWN';
ALTER TYPE "UxEventName" ADD VALUE 'PIN_PROMPT_SUCCESS';
ALTER TYPE "UxEventName" ADD VALUE 'PIN_PROMPT_ABANDON';
ALTER TYPE "UxEventName" ADD VALUE 'PIN_LOCK_NOW_CLICKED';

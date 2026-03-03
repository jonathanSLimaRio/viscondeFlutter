-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "UxEventName" ADD VALUE 'VAULT_STATE_SHOWN';
ALTER TYPE "UxEventName" ADD VALUE 'VAULT_RETRY_TAPPED';
ALTER TYPE "UxEventName" ADD VALUE 'VAULT_EMPTY_CTA_TAPPED';
ALTER TYPE "UxEventName" ADD VALUE 'GAME_STATE_SHOWN';
ALTER TYPE "UxEventName" ADD VALUE 'GAME_RETRY_TAPPED';
ALTER TYPE "UxEventName" ADD VALUE 'GAME_EMPTY_CTA_TAPPED';

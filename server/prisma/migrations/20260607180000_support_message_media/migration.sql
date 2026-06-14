-- AlterTable
ALTER TABLE "support_messages" ADD COLUMN "message_type" TEXT NOT NULL DEFAULT 'text';
ALTER TABLE "support_messages" ADD COLUMN "media_url" TEXT;
ALTER TABLE "support_messages" ADD COLUMN "sticker_id" TEXT;

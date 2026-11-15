-- AlterTable AI community comments
ALTER TABLE "ai_community_comments" ADD COLUMN IF NOT EXISTS "parent_id" TEXT NOT NULL DEFAULT '0';
ALTER TABLE "ai_community_comments" ADD COLUMN IF NOT EXISTS "root_id" TEXT NOT NULL DEFAULT '0';
ALTER TABLE "ai_community_comments" ADD COLUMN IF NOT EXISTS "reply_to_user_id" TEXT NOT NULL DEFAULT '';
ALTER TABLE "ai_community_comments" ADD COLUMN IF NOT EXISTS "reply_to_user_name" TEXT NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS "ai_community_comments_post_id_root_id_created_at_idx"
  ON "ai_community_comments"("post_id", "root_id", "created_at");

-- CreateTable product review comments
CREATE TABLE IF NOT EXISTS "shop_product_review_comments" (
    "id" TEXT NOT NULL,
    "review_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "parent_id" TEXT NOT NULL DEFAULT '0',
    "root_id" TEXT NOT NULL DEFAULT '0',
    "reply_to_user_id" TEXT NOT NULL DEFAULT '',
    "reply_to_user_name" TEXT NOT NULL DEFAULT '',
    "content" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "shop_product_review_comments_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "shop_product_review_comments_review_id_created_at_idx"
  ON "shop_product_review_comments"("review_id", "created_at");

CREATE INDEX IF NOT EXISTS "shop_product_review_comments_review_id_root_id_created_at_idx"
  ON "shop_product_review_comments"("review_id", "root_id", "created_at");

DO $$ BEGIN
  ALTER TABLE "shop_product_review_comments"
    ADD CONSTRAINT "shop_product_review_comments_review_id_fkey"
    FOREIGN KEY ("review_id") REFERENCES "shop_product_reviews"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "shop_product_review_comments"
    ADD CONSTRAINT "shop_product_review_comments_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "user_accounts"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

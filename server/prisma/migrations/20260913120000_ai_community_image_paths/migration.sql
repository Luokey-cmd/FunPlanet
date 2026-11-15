-- AlterTable
ALTER TABLE "ai_community_posts" ADD COLUMN IF NOT EXISTS "image_paths" TEXT[] DEFAULT ARRAY[]::TEXT[];

-- Backfill from single image_path
UPDATE "ai_community_posts"
SET "image_paths" = ARRAY["image_path"]
WHERE COALESCE("image_path", '') <> ''
  AND (cardinality("image_paths") = 0 OR "image_paths" IS NULL);

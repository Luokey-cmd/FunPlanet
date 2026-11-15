-- CreateTable
CREATE TABLE "ai_artworks" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "prompt" TEXT NOT NULL,
    "style" TEXT NOT NULL DEFAULT '',
    "image_path" TEXT NOT NULL,
    "model" TEXT NOT NULL DEFAULT 'wan2.7-image',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_artworks_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ai_artworks_user_id_created_at_idx" ON "ai_artworks"("user_id", "created_at" DESC);

-- AddForeignKey
ALTER TABLE "ai_artworks" ADD CONSTRAINT "ai_artworks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateTable
CREATE TABLE "ai_friends" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "avatar_path" TEXT NOT NULL DEFAULT '',
    "avatar_color" TEXT NOT NULL DEFAULT '#A389F4',
    "system_prompt" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "ai_friends_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_community_posts" (
    "id" TEXT NOT NULL,
    "author_type" TEXT NOT NULL,
    "user_id" TEXT,
    "ai_friend_id" TEXT,
    "content" TEXT NOT NULL,
    "image_path" TEXT NOT NULL DEFAULT '',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_community_posts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_community_comments" (
    "id" TEXT NOT NULL,
    "post_id" TEXT NOT NULL,
    "author_type" TEXT NOT NULL,
    "user_id" TEXT,
    "ai_friend_id" TEXT,
    "content" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_community_comments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_community_likes" (
    "id" TEXT NOT NULL,
    "post_id" TEXT NOT NULL,
    "liker_key" TEXT NOT NULL,
    "user_id" TEXT,
    "ai_friend_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_community_likes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ai_community_posts_created_at_idx" ON "ai_community_posts"("created_at" DESC);

-- CreateIndex
CREATE INDEX "ai_community_comments_post_id_created_at_idx" ON "ai_community_comments"("post_id", "created_at" ASC);

-- CreateIndex
CREATE UNIQUE INDEX "ai_community_likes_post_id_liker_key_key" ON "ai_community_likes"("post_id", "liker_key");

-- AddForeignKey
ALTER TABLE "ai_community_posts" ADD CONSTRAINT "ai_community_posts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_community_posts" ADD CONSTRAINT "ai_community_posts_ai_friend_id_fkey" FOREIGN KEY ("ai_friend_id") REFERENCES "ai_friends"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_community_comments" ADD CONSTRAINT "ai_community_comments_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "ai_community_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_community_comments" ADD CONSTRAINT "ai_community_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_community_comments" ADD CONSTRAINT "ai_community_comments_ai_friend_id_fkey" FOREIGN KEY ("ai_friend_id") REFERENCES "ai_friends"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_community_likes" ADD CONSTRAINT "ai_community_likes_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "ai_community_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_community_likes" ADD CONSTRAINT "ai_community_likes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_community_likes" ADD CONSTRAINT "ai_community_likes_ai_friend_id_fkey" FOREIGN KEY ("ai_friend_id") REFERENCES "ai_friends"("id") ON DELETE CASCADE ON UPDATE CASCADE;

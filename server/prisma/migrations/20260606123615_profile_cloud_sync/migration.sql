-- AlterTable
ALTER TABLE "user_profiles" ADD COLUMN     "avatar_path" TEXT NOT NULL DEFAULT 'assets/images/头像.jpg',
ADD COLUMN     "daily_browse_count" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "daily_browse_reward_claimed" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "daily_check_in_done" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "daily_share_done" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "fun_coins" INTEGER NOT NULL DEFAULT 500,
ADD COLUMN     "points" INTEGER NOT NULL DEFAULT 1000,
ADD COLUMN     "push_enabled" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "vip_level" INTEGER NOT NULL DEFAULT 1;

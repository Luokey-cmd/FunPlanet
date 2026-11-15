-- 新注册用户默认无积分、无趣玩币
ALTER TABLE "user_profiles" ALTER COLUMN "points" SET DEFAULT 0;
ALTER TABLE "user_profiles" ALTER COLUMN "fun_coins" SET DEFAULT 0;

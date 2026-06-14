-- 新注册用户默认使用空白头像（由 App 端展示占位图）
ALTER TABLE "user_profiles" ALTER COLUMN "avatar_path" SET DEFAULT '';

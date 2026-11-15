-- 恢复英文表名，注释改为简短中文说明
ALTER TABLE "用户账号信息" RENAME TO "user_accounts";
ALTER TABLE "用户扩展资料" RENAME TO "user_profiles";

COMMENT ON TABLE "user_accounts" IS '用户账号信息';
COMMENT ON TABLE "user_profiles" IS '用户扩展资料';

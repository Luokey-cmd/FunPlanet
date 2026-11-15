ALTER TABLE "user_accounts" RENAME TO "用户账号信息";
ALTER TABLE "user_profiles" RENAME TO "用户扩展资料";

COMMENT ON TABLE "用户账号信息" IS '用户账号信息';
COMMENT ON TABLE "用户扩展资料" IS '用户扩展资料';

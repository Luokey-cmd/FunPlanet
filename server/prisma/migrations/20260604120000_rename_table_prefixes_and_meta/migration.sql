-- Rename tables with domain prefixes
ALTER TABLE "users" RENAME TO "user_accounts";
ALTER TABLE "addresses" RENAME TO "user_addresses";
ALTER TABLE "wallet_ledgers" RENAME TO "user_wallet_ledgers";
ALTER TABLE "notifications" RENAME TO "user_notifications";
ALTER TABLE "favorites" RENAME TO "user_favorites";
ALTER TABLE "browse_history" RENAME TO "user_browse_history";

ALTER TABLE "products" RENAME TO "shop_products";
ALTER TABLE "banners" RENAME TO "shop_banners";
ALTER TABLE "cart_items" RENAME TO "shop_cart_items";
ALTER TABLE "orders" RENAME TO "shop_orders";
ALTER TABLE "order_items" RENAME TO "shop_order_items";
ALTER TABLE "coupon_templates" RENAME TO "shop_coupon_templates";
ALTER TABLE "product_reviews" RENAME TO "shop_product_reviews";

ALTER TABLE "support_conversations" RENAME TO "admin_support_conversations";
ALTER TABLE "support_messages" RENAME TO "admin_support_messages";

-- Add updated_at (修改日期) where missing
ALTER TABLE "user_profiles" ADD COLUMN IF NOT EXISTS "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "user_profiles" ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "shop_banners" ADD COLUMN IF NOT EXISTS "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "shop_banners" ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "user_favorites" ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "user_browse_history" ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "shop_coupon_templates" ADD COLUMN IF NOT EXISTS "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "shop_coupon_templates" ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "user_coupons" ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "user_notifications" ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "shop_order_items" ADD COLUMN IF NOT EXISTS "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "shop_order_items" ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "user_wallet_ledgers" ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "admin_support_conversations" ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "admin_support_messages" ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "shop_product_reviews" ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "ai_artworks" ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "ai_friends" ADD COLUMN IF NOT EXISTS "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "ai_friends" ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "ai_community_posts" ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "ai_community_comments" ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "ai_community_likes" ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- Table metadata catalog (数据长度 / 修改日期 / 分类 / 注释)
CREATE TABLE "sys_table_catalog" (
    "table_name" TEXT NOT NULL,
    "data_length" INTEGER NOT NULL DEFAULT 0,
    "category" TEXT NOT NULL,
    "comment" TEXT NOT NULL,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sys_table_catalog_pkey" PRIMARY KEY ("table_name")
);

INSERT INTO "sys_table_catalog" ("table_name", "data_length", "category", "comment", "updated_at") VALUES
('_prisma_migrations', 4, 'system', 'Prisma 迁移记录表', CURRENT_TIMESTAMP),
('user_accounts', 8, 'user', '账号主表：手机号、密码、昵称、对外 user_id', CURRENT_TIMESTAMP),
('user_profiles', 15, 'user', '用户扩展资料：头像、积分、趣币、VIP、每日任务', CURRENT_TIMESTAMP),
('user_addresses', 8, 'user', '收货地址', CURRENT_TIMESTAMP),
('user_wallet_ledgers', 7, 'user', '积分/趣币流水', CURRENT_TIMESTAMP),
('user_notifications', 8, 'user', 'App 内通知', CURRENT_TIMESTAMP),
('user_favorites', 5, 'user', '商品收藏', CURRENT_TIMESTAMP),
('user_browse_history', 5, 'user', '商品浏览记录', CURRENT_TIMESTAMP),
('user_coupons', 6, 'user', '用户已领取的优惠券', CURRENT_TIMESTAMP),
('shop_products', 18, 'shop', '商品主表', CURRENT_TIMESTAMP),
('shop_banners', 6, 'shop', '首页轮播图', CURRENT_TIMESTAMP),
('shop_cart_items', 7, 'shop', '购物车', CURRENT_TIMESTAMP),
('shop_orders', 16, 'shop', '订单主表', CURRENT_TIMESTAMP),
('shop_order_items', 10, 'shop', '订单明细', CURRENT_TIMESTAMP),
('shop_coupon_templates', 8, 'shop', '优惠券模板', CURRENT_TIMESTAMP),
('shop_product_reviews', 9, 'shop', '商品评价', CURRENT_TIMESTAMP),
('admin_support_conversations', 12, 'admin', '客服会话', CURRENT_TIMESTAMP),
('admin_support_messages', 10, 'admin', '客服消息', CURRENT_TIMESTAMP),
('ai_friends', 8, 'ai', 'AI 角色配置', CURRENT_TIMESTAMP),
('ai_artworks', 8, 'ai', 'AI 绘画作品', CURRENT_TIMESTAMP),
('ai_community_posts', 8, 'ai', 'AI 社区动态', CURRENT_TIMESTAMP),
('ai_community_comments', 8, 'ai', 'AI 社区评论', CURRENT_TIMESTAMP),
('ai_community_likes', 7, 'ai', 'AI 社区点赞', CURRENT_TIMESTAMP),
('sys_table_catalog', 5, 'system', '表元数据目录：字段数、分类、注释', CURRENT_TIMESTAMP);

-- PostgreSQL table comments (Navicat 注释列)
COMMENT ON TABLE "user_accounts" IS '[user] 账号主表';
COMMENT ON TABLE "user_profiles" IS '[user] 用户扩展资料';
COMMENT ON TABLE "user_addresses" IS '[user] 收货地址';
COMMENT ON TABLE "user_wallet_ledgers" IS '[user] 积分/趣币流水';
COMMENT ON TABLE "user_notifications" IS '[user] App 内通知';
COMMENT ON TABLE "user_favorites" IS '[user] 商品收藏';
COMMENT ON TABLE "user_browse_history" IS '[user] 浏览记录';
COMMENT ON TABLE "user_coupons" IS '[user] 已领优惠券';
COMMENT ON TABLE "shop_products" IS '[shop] 商品主表';
COMMENT ON TABLE "shop_banners" IS '[shop] 首页轮播';
COMMENT ON TABLE "shop_cart_items" IS '[shop] 购物车';
COMMENT ON TABLE "shop_orders" IS '[shop] 订单主表';
COMMENT ON TABLE "shop_order_items" IS '[shop] 订单明细';
COMMENT ON TABLE "shop_coupon_templates" IS '[shop] 优惠券模板';
COMMENT ON TABLE "shop_product_reviews" IS '[shop] 商品评价';
COMMENT ON TABLE "admin_support_conversations" IS '[admin] 客服会话';
COMMENT ON TABLE "admin_support_messages" IS '[admin] 客服消息';
COMMENT ON TABLE "ai_friends" IS '[ai] AI 角色';
COMMENT ON TABLE "ai_artworks" IS '[ai] AI 绘画';
COMMENT ON TABLE "ai_community_posts" IS '[ai] 社区动态';
COMMENT ON TABLE "ai_community_comments" IS '[ai] 社区评论';
COMMENT ON TABLE "ai_community_likes" IS '[ai] 社区点赞';
COMMENT ON TABLE "sys_table_catalog" IS '[system] 表元数据目录';

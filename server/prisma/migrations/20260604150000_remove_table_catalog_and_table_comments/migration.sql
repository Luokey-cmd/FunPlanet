-- 移除分类相关：元数据表与 Navicat 视图
DROP VIEW IF EXISTS "nav_table_overview";
DROP TABLE IF EXISTS "sys_table_catalog";

-- Navicat「注释」列：PostgreSQL 表注释（无前缀分类）
COMMENT ON TABLE "user_accounts" IS '账号主表：手机号、密码、昵称、对外 user_id';
COMMENT ON TABLE "user_profiles" IS '用户扩展资料：头像、积分、趣币、VIP、每日任务';
COMMENT ON TABLE "user_addresses" IS '收货地址';
COMMENT ON TABLE "user_wallet_ledgers" IS '积分/趣币流水';
COMMENT ON TABLE "user_notifications" IS 'App 内通知';
COMMENT ON TABLE "user_favorites" IS '商品收藏';
COMMENT ON TABLE "user_browse_history" IS '浏览记录';
COMMENT ON TABLE "user_coupons" IS '已领优惠券';
COMMENT ON TABLE "shop_products" IS '商品主表';
COMMENT ON TABLE "shop_banners" IS '首页轮播';
COMMENT ON TABLE "shop_cart_items" IS '购物车';
COMMENT ON TABLE "shop_orders" IS '订单主表';
COMMENT ON TABLE "shop_order_items" IS '订单明细';
COMMENT ON TABLE "shop_coupon_templates" IS '优惠券模板';
COMMENT ON TABLE "shop_product_reviews" IS '商品评价';
COMMENT ON TABLE "admin_support_conversations" IS '客服会话';
COMMENT ON TABLE "admin_support_messages" IS '客服消息';
COMMENT ON TABLE "ai_friends" IS 'AI 角色配置';
COMMENT ON TABLE "ai_artworks" IS 'AI 绘画作品';
COMMENT ON TABLE "ai_community_posts" IS '社区动态';
COMMENT ON TABLE "ai_community_comments" IS '社区评论';
COMMENT ON TABLE "ai_community_likes" IS '社区点赞';

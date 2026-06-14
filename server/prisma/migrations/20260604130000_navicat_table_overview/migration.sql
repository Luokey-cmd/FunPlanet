-- 注释列只保留说明文字，分类改由 sys_table_catalog.category 维护
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
COMMENT ON TABLE "sys_table_catalog" IS '表元数据目录';

-- Navicat 专用：一张视图集中展示 名称 / 数据长度 / 修改日期 / 分类 / 注释 / 行数
CREATE OR REPLACE VIEW "nav_table_overview" AS
SELECT
  c.table_name AS "名称",
  c.data_length AS "数据长度",
  c.updated_at AS "修改日期",
  c.category AS "分类",
  c.comment AS "注释",
  COALESCE(s.n_live_tup, 0)::bigint AS "行"
FROM sys_table_catalog c
LEFT JOIN pg_stat_user_tables s ON s.relname = c.table_name
ORDER BY c.category, c.table_name;

COMMENT ON VIEW "nav_table_overview" IS 'Navicat 表目录视图：数据长度、修改日期、分类、注释分列显示';

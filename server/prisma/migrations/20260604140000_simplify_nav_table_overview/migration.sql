-- 精简 Navicat 视图：只保留 名称 / 分类 / 注释 / 行
DROP VIEW IF EXISTS "nav_table_overview";
CREATE VIEW "nav_table_overview" AS
SELECT
  c.table_name AS "名称",
  c.category AS "分类",
  c.comment AS "注释",
  COALESCE(s.n_live_tup, 0)::bigint AS "行"
FROM sys_table_catalog c
LEFT JOIN pg_stat_user_tables s ON s.relname = c.table_name
ORDER BY c.category, c.table_name;

COMMENT ON VIEW "nav_table_overview" IS 'Navicat 表目录：名称、分类、注释分列显示';

-- 商品增加库存与上下架状态：存量商品默认库存 100、默认上架，不影响现有数据
ALTER TABLE "shop_products" ADD COLUMN "stock" INTEGER NOT NULL DEFAULT 100;
ALTER TABLE "shop_products" ADD COLUMN "is_on_shelf" BOOLEAN NOT NULL DEFAULT true;

// flash：这件商品当前命中的限时特价（utils/promotions.js 的
// getFlashPriceMap 给出），没有就是 null，三个促销字段一律给空，
// App 侧只认 promoPrice 有没有值，不用猜活动状态。
export function serializeProduct(p, flash = null) {
  return {
    id: p.id,
    name: p.name,
    nameEn: p.nameEn,
    price: Number(p.price),
    originalPrice: p.originalPrice == null ? null : Number(p.originalPrice),
    category: p.category,
    subCategory: p.subCategory,
    majorCategory: p.majorCategory,
    tag: p.tag,
    tagColor: p.tagColor,
    spec: p.spec,
    description: p.description,
    purchaseNotes: p.purchaseNotes,
    rating: Number(p.rating),
    sales: p.sales,
    stock: p.stock ?? 100,
    isOnShelf: p.isOnShelf ?? true,
    imagePath: p.imagePath,
    // 多图：老数据没有 imagePaths 时用主图兜底成一张，保证返回永远是数组
    imagePaths: Array.isArray(p.imagePaths) && p.imagePaths.length > 0 ? p.imagePaths : [p.imagePath],
    // 详情长图：没有就是空数组，App 侧为空时整段不显示
    detailImages: Array.isArray(p.detailImages) ? p.detailImages : [],
    videoPath: p.videoPath ?? null,
    brand: p.brand ?? null,
    series: p.series ?? null,
    rarity: p.rarity ?? null,
    suitableFor: p.suitableFor ?? null,
    sellingPoints: Array.isArray(p.sellingPoints) ? p.sellingPoints : [],
    // 数据丰富化：结构化参数与口碑统计，老数据没有就给空/默认，App 侧为空不显示
    attributes: p.attributes ?? null,
    reviewCount: p.reviewCount ?? 0,
    positiveRate: p.positiveRate ?? null,
    favoriteCount: p.favoriteCount ?? 0,
    promoPrice: flash ? flash.price : null,
    promotionName: flash ? flash.promotionName : null,
    promoEndsAt: flash ? flash.endsAt.toISOString() : null,
  };
}

export function serializeProduct(p) {
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
    imagePath: p.imagePath,
  };
}

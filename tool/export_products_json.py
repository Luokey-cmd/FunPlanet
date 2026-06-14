#!/usr/bin/env python3
"""从 products_catalog.dart 导出 JSON，供 Prisma seed 使用。"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'lib/data/products_catalog.dart'
OUT_DIR = ROOT / 'server/prisma/data'


def parse_value(key: str, block: str):
    if key in ('price', 'originalPrice', 'rating'):
        m = re.search(rf'{key}:\s*([\d.]+)', block)
        return float(m.group(1)) if m else None
    if key == 'sales':
        m = re.search(rf'{key}:\s*(\d+)', block)
        return int(m.group(1)) if m else 0
    m = re.search(rf"{key}:\s*'((?:\\'|[^'])*)'", block)
    if m:
        return m.group(1).replace("\\'", "'")
    m = re.search(rf'{key}:\s*null', block)
    if m:
        return None
    return None


def main():
    text = CATALOG.read_text(encoding='utf-8')
    blocks = re.findall(r'Product\((.*?)\n  \),', text, re.DOTALL)
    products = []
    for block in blocks:
        pid = parse_value('id', block)
        if not pid:
            continue
        products.append({
            'id': pid,
            'name': parse_value('name', block),
            'nameEn': parse_value('nameEn', block),
            'price': parse_value('price', block),
            'originalPrice': parse_value('originalPrice', block),
            'category': parse_value('category', block),
            'subCategory': parse_value('subCategory', block),
            'majorCategory': parse_value('majorCategory', block),
            'tag': parse_value('tag', block),
            'tagColor': parse_value('tagColor', block),
            'spec': parse_value('spec', block),
            'description': parse_value('description', block),
            'purchaseNotes': parse_value('purchaseNotes', block),
            'rating': parse_value('rating', block),
            'sales': parse_value('sales', block),
            'imagePath': parse_value('imagePath', block),
        })

    banners = [
        {'imagePath': 'assets/images/banners/banner1.png', 'productId': 'p09', 'sortOrder': 1},
        {'imagePath': 'assets/images/banners/banner2.png', 'productId': 'p38', 'sortOrder': 2},
        {'imagePath': 'assets/images/banners/banner3.png', 'productId': 'p28', 'sortOrder': 3},
    ]

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / 'products.json').write_text(json.dumps(products, ensure_ascii=False, indent=2), encoding='utf-8')
    (OUT_DIR / 'banners.json').write_text(json.dumps(banners, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'导出 {len(products)} 款商品、{len(banners)} 张轮播 → {OUT_DIR}')


if __name__ == '__main__':
    main()

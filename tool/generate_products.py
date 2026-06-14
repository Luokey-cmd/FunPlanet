#!/usr/bin/env python3
"""从 Excel + 商品 PNG 生成 lib/data/products_catalog.dart"""
import re
import shutil
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_IMG_DIR = ROOT / 'assets/images/products'
OUT = ROOT / 'lib/data/products_catalog.dart'

SKIP_IMAGE_STEMS = {'APP图标'}

NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}

MAJOR_TO_ID = {
    '玩具': 'toy',
    '文具': 'stationery',
    '手办': 'figure',
    '公仔': 'doll',
    '小卡': 'card',
    '谷子': 'merch',
}

PRICE_BY_SUB = {
    '文具笔类': (5.9, 9.9),
    '文具手账': (8.9, 14.9),
    '艺术灯具': (19.9, 28.9),
    '明星小卡': (3.9, 7.9),
    '收藏小卡': (3.9, 7.9),
    '谷子徽章': (7.9, 14.9),
    '解压玩具': (6.9, 12.9),
    '益智玩具': (9.9, 19.9),
    '配饰挂件': (6.9, 12.9),
    '配饰首饰': (12.9, 19.9),
    '桌游玩具': (12.9, 22.9),
    '棋牌玩具': (14.9, 22.9),
    '摆件饰品': (19.9, 29.9),
    '积木手办': (24.9, 30.0),
    '潮玩手办': (22.9, 30.0),
    '毛绒公仔': (16.9, 26.9),
    '潮玩公仔': (17.9, 29.9),
}

PRICE_RANGE = {
    'stationery': (5, 15),
    'card': (3, 8),
    'merch': (7, 14),
    'toy': (6, 22),
    'doll': (16, 28),
    'figure': (22, 30),
}


def find_product_image_dir() -> Path:
    images_root = ROOT / 'assets/images'
    candidates = [
        p for p in images_root.iterdir()
        if p.is_dir() and p.name not in {'products', 'icon'}
    ]
    if not candidates:
        raise SystemExit('未找到商品图片目录')

    def score(path: Path) -> tuple[int, int]:
        png_count = len(list(path.glob('*.png')))
        name_bonus = 1 if '商品' in path.name else 0
        return (name_bonus, png_count)

    best = max(candidates, key=score)
    if score(best)[1] < 10:
        raise SystemExit(f'商品图片过少: {best}')
    return best


def find_xlsx(image_dir: Path) -> Path | None:
    for pattern in ('*37*商品*.xlsx', '*商品*.xlsx', '*.xlsx'):
        matches = sorted(image_dir.glob(pattern))
        if matches:
            return matches[0]
    return None


def col_row(ref: str):
    m = re.match(r'([A-Z]+)(\d+)', ref)
    return m.group(1), int(m.group(2))


def col_idx(col: str) -> int:
    n = 0
    for c in col:
        n = n * 26 + (ord(c) - 64)
    return n


def parse_xlsx(path: Path) -> list[dict]:
    with zipfile.ZipFile(path) as z:
        ss_root = ET.fromstring(z.read('xl/sharedStrings.xml'))
        strings = []
        for si in ss_root.findall('m:si', NS):
            parts = []
            for t in si.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t'):
                if t.text:
                    parts.append(t.text)
            strings.append(''.join(parts))

        sheet = ET.fromstring(z.read('xl/worksheets/sheet1.xml'))
        rows: dict[int, dict[int, str]] = {}
        for c in sheet.findall('.//m:sheetData/m:row/m:c', NS):
            ref = c.get('r')
            col, row = col_row(ref)
            t = c.get('t')
            v = c.find('m:v', NS)
            if v is None or v.text is None:
                val = ''
            elif t == 's':
                val = strings[int(v.text)]
            else:
                val = v.text
            rows.setdefault(row, {})[col_idx(col)] = val

        items = []
        for row_num in sorted(rows):
            if row_num == 1:
                continue
            line = [rows[row_num].get(i, '') for i in range(1, 6)]
            items.append({
                'name': line[0],
                'description': line[1],
                'purchaseNotes': line[2],
                'subCategory': line[3],
                'majorCategory': line[4],
            })
        return items


def load_rows_from_catalog() -> list[dict]:
    text = OUT.read_text(encoding='utf-8')
    names = re.findall(r"name: '((?:\\'|[^'])*)'", text)
    descriptions = re.findall(r"description: '((?:\\'|[^'])*)'", text)
    purchase_notes = re.findall(r"purchaseNotes: '((?:\\'|[^'])*)'", text)
    sub_categories = re.findall(r"subCategory: '((?:\\'|[^'])*)'", text)
    major_categories = re.findall(r"majorCategory: '((?:\\'|[^'])*)'", text)

    def unescape(value: str) -> str:
        return value.replace("\\'", "'")

    rows = []
    for i, name in enumerate(names):
        rows.append({
            'name': unescape(name),
            'description': unescape(descriptions[i]) if i < len(descriptions) else '',
            'purchaseNotes': unescape(purchase_notes[i]) if i < len(purchase_notes) else '',
            'subCategory': unescape(sub_categories[i]) if i < len(sub_categories) else '',
            'majorCategory': unescape(major_categories[i]) if i < len(major_categories) else '',
        })
    return rows


def dart_str(s: str) -> str:
    return s.replace('\\', '\\\\').replace("'", "\\'")


def pick_price(category_id: str, index: int, sub_category: str = '') -> tuple[float, float]:
    if sub_category in PRICE_BY_SUB:
        lo, hi = PRICE_BY_SUB[sub_category]
    else:
        lo, hi = PRICE_RANGE.get(category_id, (6, 22))
    span = hi - lo
    price = lo + (index * 7 + span // 2) % (span + 1)
    price = round(price + (index % 3) * 0.8, 1)
    price = min(30.0, max(3.9, price))
    if price == int(price):
        price = float(int(price))
    original = round(price * 1.25, 1)
    original = min(36.0, original)
    if original == int(original):
        original = float(int(original))
    return price, original


def should_skip_image(stem: str) -> bool:
    normalized = stem.strip()
    if normalized in SKIP_IMAGE_STEMS:
        return True
    if normalized.upper().startswith('APP'):
        return '图标' in normalized or 'icon' in normalized.lower()
    return False


def main():
    img_dir = find_product_image_dir()
    xlsx = find_xlsx(img_dir)

    png_names = {
        p.stem for p in img_dir.glob('*.png')
        if not should_skip_image(p.stem)
    }

    if xlsx and xlsx.exists():
        rows = parse_xlsx(xlsx)
        print(f'使用 Excel: {xlsx.name}')
    elif OUT.exists():
        rows = load_rows_from_catalog()
        print('未找到 Excel，沿用现有 products_catalog.dart 商品信息')
    else:
        raise SystemExit('缺少 Excel 且不存在 products_catalog.dart，无法生成')

    missing = [r['name'] for r in rows if r['name'] not in png_names]
    if missing:
        raise SystemExit(f'缺少 PNG: {missing}')

    extra = sorted(png_names - {r['name'] for r in rows})
    if extra:
        print('提示: 未匹配商品的 PNG（已忽略）:', extra)

    OUT_IMG_DIR.mkdir(parents=True, exist_ok=True)

    lines = [
        "// GENERATED BY tool/generate_products.py — DO NOT EDIT BY HAND",
        "import 'product_data.dart';",
        "",
        "const catalogProducts = [",
    ]

    cat_counters: dict[str, int] = {}

    for i, row in enumerate(rows, start=1):
        pid = f'p{i:02d}'
        src = img_dir / f"{row['name']}.png"
        dst = OUT_IMG_DIR / f'{pid}.png'
        shutil.copy2(src, dst)

        major = row['majorCategory']
        cat_id = MAJOR_TO_ID.get(major, 'toy')
        cat_counters.setdefault(cat_id, 0)
        idx = cat_counters[cat_id]
        cat_counters[cat_id] += 1

        price, original = pick_price(cat_id, i, row['subCategory'])
        rating = round(4.7 + (i % 5) * 0.04, 1)
        sales = 800 + (i * 137) % 12000 + (idx * 300)
        tag = "'新品'" if i <= 6 else 'null'
        tag_color = "'new'" if i <= 6 else 'null'
        spec = f"'{dart_str(row['subCategory'])}'"
        image_path = f'assets/images/products/{pid}.png'

        lines.append("  Product(")
        lines.append(f"    id: '{pid}',")
        lines.append(f"    name: '{dart_str(row['name'])}',")
        lines.append(f"    nameEn: 'FunPlanet Item {i}',")
        lines.append(f"    price: {price},")
        lines.append(f"    originalPrice: {original},")
        lines.append(f"    category: '{cat_id}',")
        lines.append(f"    subCategory: '{dart_str(row['subCategory'])}',")
        lines.append(f"    majorCategory: '{dart_str(major)}',")
        if tag != 'null':
            lines.append(f"    tag: {tag},")
            lines.append(f"    tagColor: {tag_color},")
        lines.append(f"    spec: {spec},")
        lines.append(f"    description: '{dart_str(row['description'])}',")
        lines.append(f"    purchaseNotes: '{dart_str(row['purchaseNotes'])}',")
        lines.append(f"    rating: {rating},")
        lines.append(f"    sales: {sales},")
        lines.append(f"    imagePath: '{dart_str(image_path)}',")
        lines.append("  ),")

    lines.append("];")
    lines.append("")

    OUT.write_text('\n'.join(lines), encoding='utf-8')
    print(f'图片目录: {img_dir}')
    print(f'Copied {len(rows)} images -> {OUT_IMG_DIR}')
    print(f'Generated {len(rows)} products -> {OUT}')


if __name__ == '__main__':
    main()

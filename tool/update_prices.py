#!/usr/bin/env python3
"""批量更新 products_catalog.dart 平价策略"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'lib/data/products_catalog.dart'

PRICES = {
    'p01': 27.9,
    'p02': 16.9,
    'p03': 9.9,
    'p04': 24.9,
    'p05': 15.9,
    'p06': 8.9,
    'p07': 17.9,
    'p08': 30.0,
    'p09': 28.9,
    'p10': 12.9,
    'p11': 9.9,
    'p12': 21.9,
    'p13': 4.9,
    'p14': 23.9,
    'p15': 16.9,
    'p16': 6.9,
    'p17': 22.9,
    'p18': 5.9,
    'p19': 18.9,
    'p20': 8.8,
    'p21': 19.9,
    'p22': 19.9,
    'p23': 26.9,
    'p24': 14.9,
    'p25': 5.9,
    'p26': 29.9,
    'p27': 6.9,
    'p28': 9.9,
    'p29': 10.9,
    'p30': 8.9,
    'p31': 11.9,
    'p32': 9.9,
    'p33': 10.9,
    'p34': 12.9,
    'p35': 11.9,
    'p36': 4.9,
    'p37': 10.9,
    'p38': 21.9,
}


def fmt_price(p: float) -> str:
    return f'{int(p)}.0' if p == int(p) else str(p)


def original(p: float) -> float:
    o = round(p * 1.25, 1)
    return int(o) if o == int(o) else o


def main():
    text = CATALOG.read_text(encoding='utf-8')
    for pid, price in PRICES.items():
        op = original(price)
        pattern = (
            rf"(id: '{pid}',[\s\S]*?price: )[\d.]+(,[\s\n]*originalPrice: )[\d.]+"
        )
        repl = rf'\g<1>{fmt_price(price)}\g<2>{fmt_price(op)}'
        new_text, n = re.subn(pattern, repl, text, count=1, flags=re.DOTALL)
        if n != 1:
            raise SystemExit(f'更新失败 {pid}: 匹配 {n} 次')
        text = new_text
    CATALOG.write_text(text, encoding='utf-8')
    print(f'已更新 {len(PRICES)} 款，区间 {min(PRICES.values())} ~ {max(PRICES.values())} 元')


if __name__ == '__main__':
    main()

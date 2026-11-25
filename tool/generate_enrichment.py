#!/usr/bin/env python3
# FunPlanet 商品数据丰富化生成器（2026-11-25）
# 输入：products.json + inspired-products.json（服务端商品数据）
# 输出：enriched/products.json、enriched/inspired-products.json（每件补 8 个新字段）
#       enriched/virtual-reviews.json（虚拟用户 + 已完成订单 + 评价，供 seed 灌库）
# 规则：按商品编号做随机种子——同一件商品每次生成结果完全一致，可重复运行。
import json, random, re, sys
from pathlib import Path

SRC1 = Path(sys.argv[1]); SRC2 = Path(sys.argv[2]); OUT = Path(sys.argv[3])
OUT.mkdir(parents=True, exist_ok=True)
products = json.loads(SRC1.read_text(encoding='utf-8')) + json.loads(SRC2.read_text(encoding='utf-8'))
products.sort(key=lambda x: int(x['id'][1:]))

def rng_for(pid): return random.Random(int(pid[1:]) * 7919 + 13)

# ---------- 口碑 ----------
def positive_rate(rating, rnd):
    base = 84 + (float(rating) - 3.5) / 1.5 * 14
    return max(86, min(99, round(base + rnd.randint(-2, 2))))

def review_count(sales, rnd):
    if sales < 200: n = rnd.randint(4, 5)
    elif sales < 600: n = rnd.randint(5, 7)
    else: n = rnd.randint(7, 9)
    return n

# ---------- 参数模板（按大类） ----------
def pick_cm(spec, desc, lo, hi, rnd):
    m = re.search(r'(\d+(?:\.\d+)?)\s*cm', (spec or '') + ' ' + (desc or ''))
    if m: return f"{m.group(1)}cm"
    return f"{rnd.randint(lo, hi)}cm"

def attributes(p, rnd):
    cat = p['majorCategory']; spec = p.get('spec') or ''; desc = p.get('description') or ''
    sub = p.get('subCategory') or ''
    a = {}
    if cat == '手办':
        a['高度'] = pick_cm(spec, desc, 9, 24, rnd)
        a['材质'] = rnd.choice(['PVC、ABS', 'PVC', 'ABS、PVC'])
        if '比例' in sub: a['比例'] = rnd.choice(['1/7', '1/8', '1/6'])
        a['涂装'] = rnd.choice(['手工涂装', '精细涂装'])
        a['适用年龄'] = '15岁以上'
    elif cat == '公仔':
        a['高度'] = pick_cm(spec, desc, 12, 40, rnd)
        a['面料'] = rnd.choice(['水晶超柔面料', '短毛绒面料', '棉花娃娃专用面料'])
        a['填充'] = 'PP棉'
        a['适用年龄'] = '3岁以上'
    elif cat == '玩具':
        a['材质'] = rnd.choice(['ABS环保塑料', '优质纸板、塑料', '木质、塑料'])
        if '桌游' in sub or '棋牌' in sub:
            a['游戏人数'] = rnd.choice(['2-4人', '2-6人', '3-5人'])
            a['单局时长'] = rnd.choice(['20-40分钟', '30-60分钟', '15-30分钟'])
        a['适用年龄'] = rnd.choice(['6岁以上', '8岁以上', '3岁以上'])
    elif cat == '谷子':
        a['材质'] = rnd.choice(['马口铁', '亚克力', 'PET、纸质'])
        a['尺寸'] = pick_cm(spec, desc, 5, 15, rnd)
        a['工艺'] = rnd.choice(['覆膜防刮', '镭射工艺', '烫金工艺', '双面印刷'])
        a['适用年龄'] = '14岁以上'
    elif cat == '小卡':
        a['尺寸'] = rnd.choice(['55×85mm', '60×90mm'])
        a['材质'] = rnd.choice(['铜版纸覆膜', '珠光纸', '镭射纸'])
        a['数量'] = spec.split('，')[0][:12] if spec else '见规格'
        a['适用年龄'] = '14岁以上'
    elif cat == '文具':
        a['规格'] = (spec[:18] if spec else '标准规格')
        a['材质'] = rnd.choice(['塑料、纸质', '金属、塑料', '帆布、纸质'])
        a['适用年龄'] = '6岁以上'
    else:  # 实用类周边
        m = re.search(r'(\d+)\s*ml', spec + desc)
        if m: a['容量'] = f"{m.group(1)}ml"
        a['尺寸'] = pick_cm(spec, desc, 10, 35, rnd)
        a['材质'] = rnd.choice(['食品级塑料', '陶瓷', '帆布', '不锈钢、塑料'])
        a['适用年龄'] = '14岁以上'
    a['包装'] = rnd.choice(['独立彩盒', 'OPP袋装', '礼盒装'])
    return a

POINT_POOL = {
    '手办': ['涂装干净、细节到位', '造型还原、比例舒服', '底座稳固、摆放好看', '收藏展示效果好'],
    '公仔': ['手感柔软、抱着舒服', '做工扎实、线头少', '造型可爱、上镜出片', '填充饱满、不易变形'],
    '玩具': ['玩法耐玩、不容易腻', '做工结实、耐造', '规则简单、上手快', '适合朋友聚会一起玩'],
    '谷子': ['印刷清晰、颜色正', '覆膜防刮、好保存', '实物比图片还好看', '搭痛包很出效果'],
    '小卡': ['卡面清晰、色差小', '覆膜手感好', '收纳进卡册正合适', '自拍角度很出片'],
    '文具': ['实用又好看', '做工精细、不廉价', '造型独特、桌面出片', '日常使用频率高'],
    '实用类周边': ['质感扎实、不廉价', '日常用得上', '图案印刷清晰', '细节做工到位'],
}
SCENE_POOL = {
    '手办': ('放展示柜收藏', '送同好朋友'), '公仔': ('抱着睡或放床头', '送闺蜜、送对象'),
    '玩具': ('朋友聚会、宿舍一起玩', '送小朋友'), '谷子': ('搭痛包、放展示架', '送同担朋友'),
    '小卡': ('收进卡册收藏', '送同担朋友'), '文具': ('上课、办公日常用', '送同学、同事'),
    '实用类周边': ('日常生活使用', '送朋友当实用礼物'),
}
def enrich_product(p):
    rnd = rng_for(p['id'])
    cat = p['majorCategory']
    rate = positive_rate(p['rating'], rnd)
    n = review_count(int(p.get('sales') or 0), rnd)
    p['positiveRate'] = rate
    p['reviewCount'] = n
    p['favoriteCount'] = int((p.get('sales') or 0) * rnd.uniform(0.3, 0.9)) + rnd.randint(5, 60)
    sales = int(p.get('sales') or 0)
    p['stock'] = rnd.randint(3, 45) if sales >= 600 else rnd.randint(40, 320)
    attrs = attributes(p, rnd)
    p['attributes'] = attrs
    pts = rnd.sample(POINT_POOL[cat], 2)
    if '材质' in attrs: pts.insert(1, f"{attrs['材质']}材质")
    p['sellingPoints'] = pts[:3]
    scene, who = SCENE_POOL[cat]
    p['suitableFor'] = f"适合{scene}，也适合{who}"
    price = float(p['price'])
    if price >= 199: p['rarity'] = rnd.choice(['收藏级', '限量'])
    elif sales >= 700: p['rarity'] = '热门'
    elif price >= 99: p['rarity'] = '人气'
    else: p['rarity'] = '普通'
    p['brand'] = '趣玩星球'
    return n, rate

# ---------- 评价文本 ----------
PRAISE = {
    '手办': ['实物比图片还惊艳，涂装一点没翻车，摆在柜子里天天看。', '细节拉满，头发和衣服的层次都做出来了，这个价位很值。', '等了几天终于到手，造型还原度很高，底座也稳。', '朋友来家里一眼就看中了这个，质感真的好。'],
    '公仔': ['手感软乎乎的，抱着就不想撒手，做工也干净没线头。', '比想象中大只，填充很饱满，捏起来超治愈。', '买回来放床头了，每天看着心情都好，推荐。', '面料舒服不掉毛，孩子抱着睡了一周了。'],
    '玩具': ['和朋友玩了一晚上，规则简单但是很上头。', '做工比预期结实，配件齐全，这个价很良心。', '宿舍聚会全靠它，气氛一下就起来了。', '买给家里小朋友的，大人玩着都觉得有意思。'],
    '谷子': ['印刷超级清晰，实物颜色很正，覆膜手感也好。', '搭在痛包上效果绝了，出门被同担问链接了。', '包装很用心，到手完好无损，收藏党满意。', '比图上还好看，这个系列我准备集齐。'],
    '小卡': ['卡面状态很好，没有划痕没有白边，收进卡册美美的。', '这张自拍角度绝了，覆膜在光下特别好看。', '一套都很貌美，色差比想象中小很多。', '冲着颜值买的，到手质感超出预期。'],
    '文具': ['好看又实用，同事问我在哪买的。', '造型太可爱了，放桌上每天用心情都好。', '做工精细，一点不廉价，送人也拿得出手。', '已经用了一段时间了，质量没得说。'],
    '实用类周边': ['质感很好，日常真的用得上，不是摆设。', '图案印得很清晰，用了两周也没有掉。', '比普通款多了点心思，每天用着都开心。', '买来送人的，对方很喜欢，做工对得起价格。'],
}
NEUTRAL = ['整体还行，就是包装盒有个角压到了，不影响使用。', '东西本身不错，物流等了四五天才到。', '和图片有一点点色差，能接受的范围。', '质量对得起价格吧，没有特别惊艳。']
NEGATIVE = ['盒子压角有点严重，收藏的话会有点介意。', '实物颜色比图片暗一些，有点失望。', '有一处小瑕疵，懒得退了，将就用吧。', '发货有点慢，等了一周多才到。']

NAME_A = ['星', '月', '奶', '茶', '云', '柚', '桃', '莓', '猫', '兔', '鹿', '柠', '橘', '栗', '芋', '葵']
NAME_B = ['糖', '子', '酱', '喵', '丸', '团', '包', '卷', '饼', '冻', '露', '芽', '朵', '粒', '泡', '圈']
reviewers = []
nrnd = random.Random(42)
for i in range(120):
    reviewers.append({'key': f'vr{i+1:03d}', 'nickname': nrnd.choice(NAME_A) + nrnd.choice(NAME_B) + (nrnd.choice(['', '', '儿', '呀', str(nrnd.randint(1, 99))]))})

for p in products: enrich_product(p)

orders, reviews = [], []
order_seq = 0
for p in products:
    n = p['reviewCount']; rate = p['positiveRate']; rnd = rng_for(p['id'])
    pool = PRAISE[p['majorCategory']]
    deck = pool * 3; rnd.shuffle(deck)  # 同一商品内评价文本尽量不重复
    ndeck = NEUTRAL * 2; rnd.shuffle(ndeck)
    def take_praise(): return deck.pop() if deck else rnd.choice(pool)
    def take_neutral(): return ndeck.pop() if ndeck else rnd.choice(NEUTRAL)
    five_cut = rate - 13  # 5星占比；4星约9%、3星约3%、其余为1-2星差评，好评率≈5星+4星
    chosen = rnd.sample(reviewers, n)  # 同一商品不重复评价人：评价表有 (用户,订单,商品) 唯一约束，重复会被 upsert 吃掉一条
    for k in range(n):
        roll = rnd.random() * 100
        if roll < five_cut: stars, text = 5, take_praise()
        elif roll < five_cut + 9: stars, text = 4, (take_praise() if rnd.random() < 0.6 else take_neutral())
        elif roll < five_cut + 12: stars, text = 3, take_neutral()
        else: stars, text = rnd.choice([1, 2]), rnd.choice(NEGATIVE)
        if k == 0 and n >= 5: stars, text = 5, take_praise()  # 第一条保好评，详情页首屏好看
        reviewer = chosen[k]
        days = rnd.randint(2, 175)
        reviews.append({'reviewer': reviewer['key'], 'productId': p['id'], 'rating': stars,
                        'content': text, 'spec': (p.get('spec') or '')[:20], 'daysAgo': days,
                        '_price': float(p['price']), '_name': p['name']})
# 按用户把评价分组成订单（每单 3-5 件，订单日期取该单最新评价前 1-3 天）
from collections import defaultdict, Counter
by_user = defaultdict(list)
for r in reviews: by_user[r['reviewer']].append(r)
APPEAR = Counter(r['productId'] for r in reviews)
SALES_TARGET = {p['id']: int(p.get('sales') or 0) for p in products}
for key, rs in by_user.items():
    rs.sort(key=lambda x: -x['daysAgo'])
    import zlib
    rnd = random.Random(zlib.crc32(key.encode()))  # 不能用 hash()：Python 字符串哈希每进程随机，分组会漂移、seed 幂等就废了
    i = 0
    while i < len(rs):
        chunk = rs[i:i + rnd.randint(3, 5)]
        i += len(chunk)
        if not chunk: continue
        order_seq += 1
        order_days = max(c['daysAgo'] for c in chunk) + rnd.randint(1, 3)
        ono = f'VR{order_seq:05d}'
        items = []
        total = 0.0
        for c in chunk:
            # 件数按该商品目标销量分摊：服务端会按已支付订单重算 sales，这样落库销量≈数据文件里的销量
            target = SALES_TARGET.get(c['productId'], 100)
            appear = max(1, APPEAR.get(c['productId'], 1))
            qty = max(1, round(target / appear * rnd.uniform(0.7, 1.3)))
            total += c['_price'] * qty
            items.append({'productId': c['productId'], 'name': c['_name'], 'price': c['_price'], 'spec': c['spec'], 'quantity': qty})
        total = round(total, 2)
        orders.append({'orderNo': ono, 'reviewer': key, 'daysAgo': order_days,
                       'subtotal': total, 'total': total, 'items': items})
        for c in chunk: c['orderNo'] = ono
for r in reviews: r.pop('_price'); r.pop('_name')

enriched1 = [p for p in products if int(p['id'][1:]) <= 38]
enriched2 = [p for p in products if int(p['id'][1:]) > 38]
(OUT / 'products.json').write_text(json.dumps(enriched1, ensure_ascii=False, indent=2), encoding='utf-8')
(OUT / 'inspired-products.json').write_text(json.dumps(enriched2, ensure_ascii=False, indent=2), encoding='utf-8')
(OUT / 'virtual-reviews.json').write_text(json.dumps({'reviewers': reviewers, 'orders': orders, 'reviews': reviews}, ensure_ascii=False, indent=2), encoding='utf-8')
print(f"products {len(products)} | reviews {len(reviews)} | orders {len(orders)} | reviewers {len(reviewers)}")
s = enriched2[160]
print('SAMPLE', s['id'], s['name'], '| 好评率', s['positiveRate'], '| 评价数', s['reviewCount'], '| 收藏', s['favoriteCount'], '| 库存', s['stock'], '| 稀有度', s['rarity'])
print('  参数', s['attributes']); print('  卖点', s['sellingPoints']); print('  适合', s['suitableFor'])
print('  评价样例', [r for r in reviews if r['productId'] == s['id']][:3])

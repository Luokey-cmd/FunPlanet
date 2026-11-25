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
# 粉丝向评价引擎：谷圈/同担口吻，聚焦角色与柄图；片段组合 + 全局去重，1688 条不重样
import re as _re
CHARACTERS = {'星屿邮局': ['岚音', '祁舟', '小满', '团团'], '山海小食堂': ['阿泽', '麟麟', '阿九'],
              '月光马戏团': ['罗莎', '雪莉', '安珀'], '霓虹夜行': ['零七', '沈昼', '小电'],
              '深海观测站': ['汐月', '月月', '沧'], '时光钟表店': ['怀瑾', '时砚', '咔哒'],
              '樱庭花艺社': ['花梨', '青禾', '蜜蜜'], '极光观测队': ['极星', '凛冬', '霜霜']}
NOUN = {'收藏小卡': '小卡', '拍立得相卡': '拍立得', '吧唧徽章': '吧唧', '金属徽章': '吧唧', '亚克力立牌': '立牌',
        '亚克力挂件': '挂件', '色纸': '色纸', '比例手办': '手办', 'Q版手办': '手办', '桌面摆件': '摆件',
        '毛绒玩偶': '娃', '毛绒挂偶': '挂偶', '潮玩公仔': '公仔', '棉花娃娃与娃衣': '棉花娃娃'}
def series_of(p):
    m = _re.search(r'《(.+?)》', p.get('description') or '')
    return m.group(1) if m else ''
def char_of(p, rnd):
    chars = CHARACTERS.get(series_of(p), [])
    for c in chars:
        if c in (p.get('name') or ''): return c
    return rnd.choice(chars) if chars else ''
OPEN5 = ['貌美！！', '绝美', '啊啊啊到手了', '终于蹲到了', '我推来了', '神仙柄图', '一眼心动', '吃谷快乐拉满', '同担们快冲', '复数警告', '开箱那一刻我尖叫了', '等再贩等到了', '幸福', '太会出谷了', '一眼万年', '上头了']
CORE = ['{c}这个立绘我直接心动', '{c}的眼神太戳我了', '为{c}而来，看一眼就下单了', '{c}的新柄太会了', '推的笑颜就是我的命', '{s}这个系列就没有难看的柄', '{c}这套造型封神了', '柄图比官图还好看', '{c}厨狂喜', '这张脸我能看一整年', '{c}的配色太绝了', '同担诚不欺我', '这柄图真的太神了', '{c}厨的钱包不保']
DETAIL = {
 '小卡': ['卡面没划痕没白边，状态超好', '覆膜在灯下闪得绝美', '透卡那张是隐藏的快乐', '卡背设计也用心了', '尺寸收进卡册刚刚好'],
 '谷子': ['印刷超级清晰，实物颜色很正', '柄图印得一点不糊', '背面做工也干净', '覆膜手感好，搭痛包绝了', '包装用心，到手完好无损'],
 '手办': ['涂装没翻车，脸超正', '头发层次和衣服褶皱都做出来了', '底座稳，摆柜里气场全开', '面相还原，监修没白等', '细节多到想拿放大镜看'],
 '公仔': ['手感软乎乎，抱着不想撒手', '填充饱满，脸也没歪', '做工干净没线头', '比想象中大只，超治愈', '放床头每天看着心情好'],
 '玩具': ['和同担拼团玩了一晚上', '配件齐全，做工比预期结实', '规则简单但很上头', '摆着也好看，玩着也有意思', '宿舍/漫展聚会全靠它'],
 '文具': ['好看又实用，同担问我哪买的', '造型太戳了，放桌上每天用', '写感顺滑，颜值还高', '和我的手账本绝配', '用着都舍不得用'],
 '实用类周边': ['图案印得清晰，用了两周没掉', '日常真的用得上，不是摆设', '图案一露出来就被同担认出来了', '质感对得起价格', '带着出门回头率很高']}
BEHAVE = ['已经摆进展示柜了', '扎进痛包了，出门被同担问链接', '复数入了两套，一套收藏一套用', '和之前的谷摆了一个阵', '拍了返图发同担群了', '放办公桌上天天看', '卡册又满了一页', '准备再蹲一套送同担', '和官娃摆一起毫无违和感', '每天回家第一眼就看到它']
TAIL5 = ['冲就完了', '同担闭眼入', '今年最值的一单', '等再贩还要入', '幸福感拉满', '入股不亏', '快乐这不就来了', '']
NIT4 = ['就是盒角有点压', '美中不足是发货慢了点', '要是柄再多一张就完美了', '小贵但颜值扳回来了', '包装可以再扎实点']
MID3 = ['柄是好看的，就是实物比想象中小一点', '冲着{c}买的，做工中规中矩吧', '色差有一点，能接受', '喜欢的会很喜欢，我一般般', '质感对得起价格，但没有特别惊艳', '等活动入的，这个价还行']
MID_EXTRA = ['整体无功无过', '但冲着推还是留下了', '图个喜欢吧', '送同担她挺喜欢', '放着也不占地方', '等活动价再考虑复数', '拍照倒是挺上镜', '远看还行近看一般']
NEG_EXTRA = ['客服态度还行，就是东西不行', '退货又麻烦，唉', '同担们避雷吧', '希望品控好好查查', '不会回购了', '图个教训', '心疼我的钱', '品控真的要抓一抓']
NEG = ['柄图色差也太大了，跟官图不是一个色调', '卡面有划痕，收藏党真的会心梗', '背面有锈点，品控不行', '盒子压得厉害，吃谷最怕盒损', '等了半个月才发货，热情都等没了', '实物脸有点崩，推这么好看品控怎么这样', '印刷糊了一块，像盗版的一样', '到手有瑕疵，懒得退了将就吧']
SHORT = ['貌美', '我推！！', '绝了', '复购了', '同担冲', '好吃，太好吃了', '{c}太美了', '神仙柄', '入了不亏', '快乐']
def compose(p, stars, rnd, used):
    c = char_of(p, rnd); s = series_of(p); noun = NOUN.get(p.get('subCategory') or '', '')
    det_pool = DETAIL.get(p['majorCategory'], DETAIL['谷子'])
    for _ in range(40):
        if stars >= 5:
            if rnd.random() < 0.12:
                t = rnd.choice(SHORT).format(c=c)
                if rnd.random() < 0.5: t += rnd.choice(['！', '～', '，冲', '，同担快来'])
            else:
                det = rnd.choice(det_pool)
                bpool = BEHAVE if p['majorCategory'] in ('谷子', '小卡') else [b for b in BEHAVE if '卡册' not in b and '痛包' not in b]
                if p['majorCategory'] not in ('公仔', '手办', '玩具', '谷子'): bpool = [b for b in bpool if '官娃' not in b]
                if '痛包' in det: bpool = [b for b in bpool if '痛包' not in b]
                t = rnd.choice(OPEN5) + '，' + rnd.choice(CORE).format(c=c, s=s) + '。' + det + '，' + rnd.choice(bpool) + '。'
                tail = rnd.choice(TAIL5)
                if tail: t += tail + '。'
        elif stars == 4:
            t = rnd.choice(CORE).format(c=c, s=s) + '，' + rnd.choice(det_pool) + '；' + rnd.choice(NIT4) + '，整体还是满意的。'
        elif stars == 3:
            t = rnd.choice(MID3).format(c=c, s=s) + rnd.choice(['。', '，' + rnd.choice(MID_EXTRA) + '。', '，' + rnd.choice(MID_EXTRA) + '。'])
        else:
            t = rnd.choice(NEG) + rnd.choice(['。', '，' + rnd.choice(NEG_EXTRA) + '。', '，' + rnd.choice(NEG_EXTRA) + '。'])
        if t not in used:
            used.add(t); return t
    base = rnd.choice(CORE).format(c=c, s=s) + '，' + rnd.choice(det_pool) + '。'
    for suf in ['！', '～', '，真的！', '，呜呜', '，姐妹们冲', '（复数了）', '，已安利给同担', '，嘿嘿']:
        if base + suf not in used:
            used.add(base + suf); return base + suf
    used.add(base); return base

NAME_A = ['星', '月', '奶', '茶', '云', '柚', '桃', '莓', '猫', '兔', '鹿', '柠', '橘', '栗', '芋', '葵']
NAME_B = ['糖', '子', '酱', '喵', '丸', '团', '包', '卷', '饼', '冻', '露', '芽', '朵', '粒', '泡', '圈']
reviewers = []
nrnd = random.Random(42)
for i in range(120):
    reviewers.append({'key': f'vr{i+1:03d}', 'nickname': nrnd.choice(NAME_A) + nrnd.choice(NAME_B) + (nrnd.choice(['', '', '儿', '呀', str(nrnd.randint(1, 99))]))})

_seen_nick = {}
for r in reviewers:
    if r['nickname'] in _seen_nick:
        _seen_nick[r['nickname']] += 1
        r['nickname'] = r['nickname'] + str(_seen_nick[r['nickname']])
    else:
        _seen_nick[r['nickname']] = 1

for p in products: enrich_product(p)

orders, reviews = [], []
USED_TEXTS = set()  # 全店评价文本去重：任何两条评价不许一模一样
order_seq = 0
for p in products:
    n = p['reviewCount']; rate = p['positiveRate']; rnd = rng_for(p['id'])
    five_cut = rate - 13  # 5星占比；4星约9%、3星约3%、其余为1-2星差评，好评率≈5星+4星
    chosen = rnd.sample(reviewers, n)  # 同一商品不重复评价人：评价表有 (用户,订单,商品) 唯一约束，重复会被 upsert 吃掉一条
    for k in range(n):
        roll = rnd.random() * 100
        if roll < five_cut: stars = 5
        elif roll < five_cut + 9: stars = 4
        elif roll < five_cut + 12: stars = 3
        else: stars = rnd.choice([1, 2])
        if k == 0 and n >= 5: stars = 5  # 第一条保好评，详情页首屏好看
        text = compose(p, stars, rnd, USED_TEXTS)
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

from collections import defaultdict as _dd
_by_p = _dd(list)
for r in reviews: _by_p[r['productId']].append(r)
for p in products:
    rs = _by_p.get(p['id'], [])
    if rs: p['positiveRate'] = round(sum(1 for r in rs if r['rating'] >= 4) / len(rs) * 100)

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

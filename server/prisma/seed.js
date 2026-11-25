import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { PrismaClient } from '@prisma/client';
import { resetUserData } from '../src/utils/reset-user.js';
import { syncAllProductSales } from '../src/utils/product-sales.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.resolve(__dirname, '../.env') });
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const prisma = new PrismaClient();

function readJson(name) {
  const file = path.join(__dirname, 'data', name);
  return JSON.parse(fs.readFileSync(file, 'utf-8'));
}

// minAmount 是数字门槛（下单只认它），condition 只是给人看的文字，两边数值必须一致，改券时两个一起改
const couponTemplates = [
  { id: 'c1', title: '新人满30减5', discount: 5, condition: '满30可用', minAmount: 30, claimType: 'newcomer', expireAt: '2026-12-31' },
  { id: 'c2', title: '满140减30', discount: 30, condition: '满140可用', minAmount: 140, expireAt: '2026-12-31' },
  { id: 'c3', title: '满300减80', discount: 80, condition: '满300可用', minAmount: 300, expireAt: '2026-12-31' },
  { id: 'c4', title: '新人满50减10', discount: 10, condition: '满50可用', minAmount: 50, claimType: 'newcomer', expireAt: '2026-12-31' },
  { id: 'c5', title: '会员每月赠券', discount: 20, condition: '满99可用', minAmount: 99, claimType: 'member_monthly', expireAt: '2026-12-31' },
  { id: 'c6', title: '领券中心满120减25', discount: 25, condition: '满120可用', minAmount: 120, claimType: 'center', expireAt: '2026-12-31' },
  { id: 'c7', title: '积分兑换满66减10', discount: 10, condition: '满66可用', minAmount: 66, claimType: 'points', expireAt: '2026-12-31' },
];

async function seedDemoUserData(userId) {
  await resetUserData(userId);
}

// 系列名提取：商品数据文件里没有 series 字段，系列名只写在描述开头「原创系列《XXX》」里，
// 数据库的 series 列（详情页同系列图鉴、后台系列排行都读它）靠这里从描述提取回填。
// 输入：数据文件里的一条商品；输出：系列名或 null。
// 坑：update 时提取不到要传 undefined（Prisma 跳过该字段），不能传 null，
// 否则会把管理员在后台手动填好的系列冲掉。
function extractSeries(p) {
  if (p.series) return String(p.series);
  const m = /原创系列《([^》]+)》/.exec(p.description ?? '');
  return m ? m[1] : null;
}

// 虚拟评价与订单（2026-11-25 数据丰富化）：virtual-reviews.json 是生成好的
// 120 位虚拟买家、近半年的已完成订单与逐件评价。评价表有订单外键，所以顺序是
// 先建用户、再建订单与订单项、最后建评价；全部走 upsert，重复跑 seed 不翻倍。
// 输入：生成文件三段（reviewers/orders/reviews）；输出：灌好的评价条数。
// 坑：seed 结尾的 syncAllProductSales 会按已支付订单重算销量，生成器已按
// 数据文件里的目标销量分摊了每单件数，落库销量与文件口径基本一致。
async function seedVirtualReviews(pwdHash) {
  let data;
  try {
    data = readJson('virtual-reviews.json');
  } catch {
    return 0; // 没有生成文件就跳过（老数据目录兼容）
  }
  const userIdByKey = {};
  for (const [i, r] of data.reviewers.entries()) {
    const phone = `139${String(10000000 + i)}`;
    const user = await prisma.user.upsert({
      where: { phone },
      create: {
        phone,
        password: pwdHash,
        nickname: r.nickname,
        userId: String(88001 + i),
        profile: { create: {} },
      },
      update: { nickname: r.nickname },
    });
    userIdByKey[r.key] = user.id;
  }
  const orderIdByNo = {};
  for (const o of data.orders) {
    const when = new Date(Date.now() - o.daysAgo * 86400000);
    const order = await prisma.order.upsert({
      where: { orderNo: o.orderNo },
      create: {
        orderNo: o.orderNo,
        userId: userIdByKey[o.reviewer],
        status: 'completed',
        subtotal: o.subtotal,
        total: o.total,
        paymentStatus: 'paid',
        paymentMethod: '微信支付',
        paidAt: when,
        createdAt: when,
        items: {
          create: o.items.map((it) => ({
            productId: it.productId,
            name: it.name,
            quantity: it.quantity,
            spec: it.spec ?? '',
            unitPrice: it.price,
            subtotal: Math.round(it.price * it.quantity * 100) / 100,
          })),
        },
      },
      update: {},
    });
    orderIdByNo[o.orderNo] = order.id;
  }
  let count = 0;
  for (const r of data.reviews) {
    const when = new Date(Date.now() - r.daysAgo * 86400000);
    await prisma.productReview.upsert({
      where: {
        userId_orderId_productId: {
          userId: userIdByKey[r.reviewer],
          orderId: orderIdByNo[r.orderNo],
          productId: r.productId,
        },
      },
      create: {
        userId: userIdByKey[r.reviewer],
        orderId: orderIdByNo[r.orderNo],
        productId: r.productId,
        rating: r.rating,
        content: r.content,
        createdAt: when,
      },
      update: { rating: r.rating, content: r.content },
    });
    count++;
  }
  return count;
}

async function main() {
  const products = [...readJson('products.json'), ...readJson('inspired-products.json')];
  const banners = readJson('banners.json');

  for (const p of products) {
    await prisma.product.upsert({
      where: { id: p.id },
      create: {
        id: p.id,
        name: p.name,
        nameEn: p.nameEn,
        price: p.price,
        originalPrice: p.originalPrice ?? null,
        category: p.category,
        subCategory: p.subCategory,
        majorCategory: p.majorCategory,
        tag: p.tag ?? null,
        tagColor: p.tagColor ?? null,
        spec: p.spec ?? null,
        description: p.description,
        purchaseNotes: p.purchaseNotes,
        rating: p.rating,
        sales: 0,
        imagePath: p.imagePath,
        // 多图先用主图兜底成一张，后台补图后自然变多
        imagePaths: [p.imagePath],
        // 详情长图：数据文件里有就带上，没有就是空数组（后台可后续补）
        detailImages: Array.isArray(p.detailImages) ? p.detailImages : [],
        series: extractSeries(p),
        // 数据丰富化：库存/品牌/稀有度/适合人群/卖点/结构化参数/口碑统计，数据文件是准绳
        stock: p.stock ?? 100,
        brand: p.brand ?? null,
        rarity: p.rarity ?? null,
        suitableFor: p.suitableFor ?? null,
        sellingPoints: Array.isArray(p.sellingPoints) ? p.sellingPoints : [],
        attributes: p.attributes ?? null,
        reviewCount: p.reviewCount ?? 0,
        positiveRate: p.positiveRate ?? null,
        favoriteCount: p.favoriteCount ?? 0,
      },
      update: {
        name: p.name,
        nameEn: p.nameEn,
        price: p.price,
        originalPrice: p.originalPrice ?? null,
        category: p.category,
        subCategory: p.subCategory,
        majorCategory: p.majorCategory,
        tag: p.tag ?? null,
        tagColor: p.tagColor ?? null,
        spec: p.spec ?? null,
        description: p.description,
        purchaseNotes: p.purchaseNotes,
        rating: p.rating,
        imagePath: p.imagePath,
        imagePaths: [p.imagePath],
        detailImages: Array.isArray(p.detailImages) ? p.detailImages : [],
        // 提取不到传 undefined：保留后台手动维护的系列，不冲掉
        series: extractSeries(p) ?? undefined,
        // 数据丰富化字段：文件里有才覆盖（?? undefined），老数据文件不带这些键时不冲掉库里已有的
        stock: p.stock ?? undefined,
        brand: p.brand ?? undefined,
        rarity: p.rarity ?? undefined,
        suitableFor: p.suitableFor ?? undefined,
        sellingPoints: Array.isArray(p.sellingPoints) ? p.sellingPoints : undefined,
        attributes: p.attributes ?? undefined,
        reviewCount: p.reviewCount ?? undefined,
        positiveRate: p.positiveRate ?? undefined,
        favoriteCount: p.favoriteCount ?? undefined,
      },
    });
  }

  await prisma.banner.deleteMany();
  for (const b of banners) {
    await prisma.banner.create({
      data: {
        imagePath: b.imagePath,
        productId: b.productId,
        sortOrder: b.sortOrder,
      },
    });
  }

  for (const c of couponTemplates) {
    await prisma.couponTemplate.upsert({
      where: { id: c.id },
      create: {
        id: c.id,
        title: c.title,
        discount: c.discount,
        condition: c.condition,
        minAmount: c.minAmount,
        expireAt: new Date(c.expireAt),
        claimType: c.claimType ?? null,
      },
      update: {
        title: c.title,
        discount: c.discount,
        condition: c.condition,
        minAmount: c.minAmount,
        expireAt: new Date(c.expireAt),
        claimType: c.claimType ?? null,
      },
    });
  }

  const demoHash = await bcrypt.hash('123456', 10);
  const demoUser = await prisma.user.upsert({
    where: { phone: '13800138000' },
    create: {
      phone: '13800138000',
      password: demoHash,
      nickname: 'Luca123',
      userId: '1000',
      profile: { create: {} },
    },
    update: {
      password: demoHash,
      nickname: 'Luca123',
      userId: '1000',
    },
  });

  await seedDemoUserData(demoUser.id);

  const virtualReviewCount = await seedVirtualReviews(demoHash);
  console.log(`虚拟评价已灌入: ${virtualReviewCount} 条`);

  await syncAllProductSales(prisma);
  console.log('商品销量已同步为真实订单数据');

  console.log(`Seed 完成: ${products.length} 商品, ${banners.length} 轮播, ${couponTemplates.length} 券模板, 1 演示账号（空数据）`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

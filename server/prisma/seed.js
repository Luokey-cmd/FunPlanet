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

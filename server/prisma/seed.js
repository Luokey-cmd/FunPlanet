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

const couponTemplates = [
  { id: 'c1', title: '新人满30减5', discount: 5, condition: '满30可用', expireAt: '2026-12-31' },
  { id: 'c2', title: '满140减30', discount: 30, condition: '满140可用', expireAt: '2026-12-31' },
  { id: 'c3', title: '满300减80', discount: 80, condition: '满300可用', expireAt: '2026-12-31' },
  { id: 'c4', title: '新人满50减10', discount: 10, condition: '满50可用', expireAt: '2026-12-31' },
  { id: 'c5', title: '会员每月赠券', discount: 20, condition: '满99可用', expireAt: '2026-12-31' },
  { id: 'c6', title: '领券中心满120减25', discount: 25, condition: '满120可用', expireAt: '2026-12-31' },
  { id: 'c7', title: '积分兑换满66减10', discount: 10, condition: '满66可用', expireAt: '2026-12-31' },
];

async function seedDemoUserData(userId) {
  await resetUserData(userId);
}

async function main() {
  const products = readJson('products.json');
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
        expireAt: new Date(c.expireAt),
      },
      update: {
        title: c.title,
        discount: c.discount,
        condition: c.condition,
        expireAt: new Date(c.expireAt),
        claimType: null,
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
      userId: '1064453837',
      profile: { create: {} },
    },
    update: {
      password: demoHash,
      nickname: 'Luca123',
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

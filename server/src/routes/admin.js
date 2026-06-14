import { Router } from 'express';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { prisma } from '../db.js';
import { adminAuthRequired } from '../middleware/adminAuth.js';
import { signToken } from '../utils/jwt.js';
import { serializeProduct } from '../utils/product.js';
import { getPaidSalesMap, syncAllProductSales } from '../utils/product-sales.js';
import {
  changeAdminPassword,
  createAdminAccount,
  resolveAdminProfile,
  updateAdminAvatar,
  updateAdminDisplayName,
  verifyRegisteredAdmin,
} from '../utils/admin-auth.js';
import {
  getAdminUsername,
  verifyAdminPassword,
  writeAdminSettings,
} from '../utils/admin-settings.js';
import { isRegisteredAdmin } from '../utils/admin-accounts.js';
import {
  createChangelogEntry,
  deleteChangelogEntry,
  readChangelog,
  updateChangelogEntry,
} from '../utils/changelog.js';
import { formatChinaDate, formatChinaDateTime } from '../utils/datetime.js';
import { isDisplayableAvatarPath } from '../utils/avatar-media.js';
import { fail, ok } from '../utils/response.js';
import { saveAdminAssetImage } from '../utils/admin-asset-upload.js';
import adminSupportRoutes from './admin-support.js';

const router = Router();
const assetsRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../assets');

router.use('/support', adminSupportRoutes);

const AVATAR_MIME_EXT = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
};

function orderStatusLabel(status) {
  const map = {
    pending: '待付款',
    paid: '已付款',
    shipping: '配送中',
    completed: '已完成',
    returned: '已退货',
    cancelled: '已退货',
  };
  return map[status] ?? status;
}

const ORDER_STATUS_TRANSITIONS = {
  paid: 'shipping',
  shipping: 'completed',
};

router.post('/auth/login', async (req, res) => {
  const { username, password } = req.body ?? {};
  const u = String(username ?? '').trim();
  const p = String(password ?? '');

  const registered = await verifyRegisteredAdmin(u, p);
  if (registered) {
    const profile = resolveAdminProfile(registered.username);
    const token = signToken({ role: 'admin', username: registered.username, name: profile.name });
    ok(res, { token, admin: profile });
    return;
  }

  const adminUser = getAdminUsername();
  if (u === adminUser && verifyAdminPassword(p)) {
    const profile = resolveAdminProfile(adminUser);
    const token = signToken({ role: 'admin', username: adminUser, name: profile.name });
    ok(res, { token, admin: profile });
    return;
  }

  fail(res, 401, '账号或密码错误');
});

router.post('/auth/register', async (req, res) => {
  if (process.env.NODE_ENV === 'production' && process.env.ALLOW_ADMIN_REGISTER !== 'true') {
    fail(res, 403, '生产环境已关闭管理员自助注册');
    return;
  }

  const { username, password, confirmPassword, name } = req.body ?? {};
  const u = String(username ?? '').trim();
  const p = String(password ?? '');
  const n = String(name ?? '').trim() || u;

  if (u.length < 3) {
    fail(res, 400, '账号至少 3 位');
    return;
  }
  if (!/^[a-zA-Z0-9_]+$/.test(u)) {
    fail(res, 400, '账号仅支持字母、数字和下划线');
    return;
  }
  if (p.length < 6) {
    fail(res, 400, '密码至少 6 位');
    return;
  }
  if (p !== String(confirmPassword ?? '')) {
    fail(res, 400, '两次输入的密码不一致');
    return;
  }
  if (u === getAdminUsername()) {
    fail(res, 400, '该账号已被占用');
    return;
  }
  if (isRegisteredAdmin(u)) {
    fail(res, 400, '该账号已被注册');
    return;
  }

  try {
    await createAdminAccount({ username: u, password: p, name: n });
    const profile = resolveAdminProfile(u);
    const token = signToken({ role: 'admin', username: u, name: profile.name });
    ok(res, { token, admin: profile });
  } catch (err) {
    if (err.code === 'USERNAME_TAKEN') {
      fail(res, 400, '该账号已被注册');
      return;
    }
    fail(res, 500, '注册失败');
  }
});

router.get('/auth/me', adminAuthRequired, (req, res) => {
  ok(res, { admin: resolveAdminProfile(req.admin.username) });
});

router.get('/dashboard', adminAuthRequired, async (_req, res) => {
  const [productCount, userCount, orders, paidOrders, recentOrders, allProducts, salesMap] =
    await Promise.all([
      prisma.product.count(),
      prisma.user.count(),
      prisma.order.findMany({ include: { user: true, items: true }, orderBy: { createdAt: 'desc' } }),
      prisma.order.findMany({
        where: { paymentStatus: 'paid' },
        select: {
          total: true,
          createdAt: true,
          items: { select: { productId: true, subtotal: true } },
        },
      }),
      prisma.order.findMany({
        take: 8,
        orderBy: { createdAt: 'desc' },
        include: { user: true, items: true },
      }),
      prisma.product.findMany({ select: { id: true, name: true, price: true, majorCategory: true } }),
      getPaidSalesMap(),
    ]);

  const topProducts = [...allProducts]
    .sort((a, b) => (salesMap.get(b.id) ?? 0) - (salesMap.get(a.id) ?? 0))
    .slice(0, 5);

  const totalRevenue = paidOrders.reduce((sum, o) => sum + Number(o.total), 0);
  const dayMap = new Map();
  for (const o of paidOrders) {
    const key = formatChinaDate(o.createdAt);
    dayMap.set(key, (dayMap.get(key) ?? 0) + Number(o.total));
  }
  const revenueTrend = [];
  for (let i = 29; i >= 0; i -= 1) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const day = formatChinaDate(d);
    revenueTrend.push({ day, revenue: dayMap.get(day) ?? 0 });
  }

  const CATEGORY_COLORS = {
    玩具: '#9adbc5',
    文具: '#a1dee0',
    公仔: '#dfde6c',
    手办: '#fcc351',
    谷子: '#fd8d6e',
    小卡: '#fa86a9',
    其他: '#a1dee0',
  };
  const FALLBACK_COLORS = ['#9adbc5', '#a1dee0', '#dfde6c', '#fcc351', '#fd8d6e', '#fa86a9'];
  const categoryByProductId = new Map(allProducts.map((p) => [p.id, p.majorCategory]));
  const categoryRevenueMap = new Map();
  for (const order of paidOrders) {
    for (const item of order.items) {
      const category = categoryByProductId.get(item.productId) ?? '其他';
      categoryRevenueMap.set(
        category,
        (categoryRevenueMap.get(category) ?? 0) + Number(item.subtotal),
      );
    }
  }
  const categoryStats = [...categoryRevenueMap.entries()]
    .sort(([, a], [, b]) => b - a)
    .map(([name, value], index) => ({
      name,
      value,
      color: CATEGORY_COLORS[name] ?? FALLBACK_COLORS[index % FALLBACK_COLORS.length],
    }));

  ok(res, {
    stats: {
      totalRevenue,
      totalOrders: orders.length,
      totalUsers: userCount,
      totalProducts: productCount,
      pendingOrders: orders.filter((o) => o.status === 'pending' || o.status === 'paid').length,
    },
    revenueTrend,
    categoryStats,
    recentOrders: recentOrders.map((o) => ({
      id: o.orderNo,
      user: o.user.nickname,
      products: o.items.map((i) => i.name).join('、'),
      amount: Number(o.total),
      status: o.status,
      statusLabel: orderStatusLabel(o.status),
      date: formatChinaDateTime(o.createdAt),
      address: o.addressDetail ?? '',
    })),
    topProducts: topProducts.map((p) => ({
      id: p.id,
      name: p.name,
      sales: salesMap.get(p.id) ?? 0,
      price: Number(p.price),
      majorCategory: p.majorCategory,
    })),
  });
});

router.get('/products', adminAuthRequired, async (req, res) => {
  const keyword = String(req.query.keyword ?? '').trim();
  const category = String(req.query.category ?? '').trim();
  const where = {};
  if (category && category !== 'all') {
    where.majorCategory = category;
  }
  if (keyword) {
    where.OR = [
      { id: { contains: keyword } },
      { name: { contains: keyword } },
      { majorCategory: { contains: keyword } },
      { subCategory: { contains: keyword } },
    ];
  }
  const [products, salesMap] = await Promise.all([
    prisma.product.findMany({
      where,
      orderBy: { id: 'asc' },
      include: { _count: { select: { favorites: true } } },
    }),
    getPaidSalesMap(),
  ]);
  ok(res, {
    products: products.map((p) => ({
      ...serializeProduct(p),
      favoriteCount: p._count.favorites,
      sales: salesMap.get(p.id) ?? 0,
    })),
  });
});

router.post('/products', adminAuthRequired, async (req, res) => {
  const body = req.body ?? {};
  const id = String(body.id ?? '').trim();
  const name = String(body.name ?? '').trim();
  if (!id || !name) {
    fail(res, 400, '商品 ID 与名称不能为空');
    return;
  }
  const product = await prisma.product.create({
    data: {
      id,
      name,
      nameEn: String(body.nameEn ?? name),
      price: Number(body.price ?? 0),
      originalPrice: body.originalPrice == null ? null : Number(body.originalPrice),
      category: String(body.category ?? 'toy'),
      subCategory: String(body.subCategory ?? ''),
      majorCategory: String(body.majorCategory ?? '玩具'),
      tag: body.tag ?? null,
      tagColor: body.tagColor ?? null,
      spec: body.spec ?? null,
      description: String(body.description ?? ''),
      purchaseNotes: String(body.purchaseNotes ?? ''),
      rating: Number(body.rating ?? 5),
      sales: 0,
      imagePath: String(body.imagePath ?? ''),
    },
  });
  ok(res, { product: serializeProduct(product) });
});

router.put('/products/:id', adminAuthRequired, async (req, res) => {
  const body = req.body ?? {};
  try {
    const product = await prisma.product.update({
      where: { id: req.params.id },
      data: {
        name: body.name,
        nameEn: body.nameEn,
        price: body.price != null ? Number(body.price) : undefined,
        originalPrice: body.originalPrice != null ? Number(body.originalPrice) : undefined,
        category: body.category,
        subCategory: body.subCategory,
        majorCategory: body.majorCategory,
        tag: body.tag,
        tagColor: body.tagColor,
        spec: body.spec,
        description: body.description,
        purchaseNotes: body.purchaseNotes,
        rating: body.rating != null ? Number(body.rating) : undefined,
        imagePath: body.imagePath,
      },
    });
    ok(res, { product: serializeProduct(product) });
  } catch {
    fail(res, 404, '商品不存在');
  }
});

router.delete('/products/:id', adminAuthRequired, async (req, res) => {
  try {
    await prisma.product.delete({ where: { id: req.params.id } });
    ok(res, { deleted: true });
  } catch {
    fail(res, 404, '商品不存在');
  }
});

router.get('/orders', adminAuthRequired, async (req, res) => {
  const status = String(req.query.status ?? '').trim();
  const keyword = String(req.query.keyword ?? '').trim();
  const where = {};
  if (status && status !== 'all') {
    where.status = status === 'returned' ? { in: ['returned', 'cancelled'] } : status;
  }
  if (keyword) {
    where.OR = [
      { orderNo: { contains: keyword } },
      { user: { nickname: { contains: keyword } } },
      { user: { phone: { contains: keyword } } },
    ];
  }
  const orders = await prisma.order.findMany({
    where,
    include: { user: true, items: true },
    orderBy: { createdAt: 'desc' },
  });
  ok(res, {
    orders: orders.map((o) => ({
      id: o.id,
      orderNo: o.orderNo,
      user: o.user.nickname,
      phone: o.user.phone,
      products: o.items.map((i) => `${i.name} x${i.quantity}`).join('、'),
      amount: Number(o.total),
      status: o.status,
      statusLabel: orderStatusLabel(o.status),
      paymentStatus: o.paymentStatus,
      date: formatChinaDateTime(o.createdAt),
      address: o.addressDetail ?? '',
    })),
  });
});

router.patch('/orders/:id/status', adminAuthRequired, async (req, res) => {
  const status = String(req.body?.status ?? '').trim();
  const allowed = ['pending', 'paid', 'shipping', 'completed', 'returned'];
  if (!allowed.includes(status)) {
    fail(res, 400, '无效订单状态');
    return;
  }

  try {
    const current = await prisma.order.findUnique({ where: { id: req.params.id } });
    if (!current) {
      fail(res, 404, '订单不存在');
      return;
    }

    const expectedNext = ORDER_STATUS_TRANSITIONS[current.status];
    if (expectedNext !== status) {
      fail(res, 409, '当前状态不允许此操作');
      return;
    }

    const order = await prisma.$transaction(async (tx) => {
      const updated = await tx.order.update({
        where: { id: req.params.id },
        data: {
          status,
          ...(status === 'completed' ? { paymentStatus: 'paid' } : {}),
        },
      });

      if (status === 'shipping') {
        await tx.notification.create({
          data: {
            userId: updated.userId,
            title: '商品已发货',
            body: `订单 ${updated.orderNo} 已发货，正在配送中，请留意查收`,
            type: 'order',
          },
        });
      } else if (status === 'completed') {
        await tx.notification.create({
          data: {
            userId: updated.userId,
            title: '订单已送达',
            body: `订单 ${updated.orderNo} 已送达，感谢您的购买`,
            type: 'order',
          },
        });
      }

      return updated;
    });
    ok(res, { order: { id: order.id, status: order.status } });
  } catch {
    fail(res, 404, '订单不存在');
  }
});

router.get('/users', adminAuthRequired, async (req, res) => {
  const keyword = String(req.query.keyword ?? '').trim();
  const where = keyword
    ? {
        OR: [
          { nickname: { contains: keyword } },
          { phone: { contains: keyword } },
          { userId: { contains: keyword } },
        ],
      }
    : {};
  const users = await prisma.user.findMany({
    where,
    include: {
      profile: true,
      orders: { select: { total: true } },
    },
    orderBy: { createdAt: 'desc' },
  });
  ok(res, {
    users: users.map((u) => ({
      id: u.id,
      userId: u.userId,
      name: u.nickname,
      phone: u.phone,
      vipLevel: u.profile?.vipLevel ?? 1,
      points: u.profile?.points ?? 0,
      funCoins: u.profile?.funCoins ?? 0,
      orders: u.orders.length,
      totalSpend: u.orders.reduce((sum, o) => sum + Number(o.total), 0),
      joinDate: formatChinaDate(u.createdAt),
      status: 'active',
      avatarPath: isDisplayableAvatarPath(u.profile?.avatarPath) ? u.profile.avatarPath : null,
    })),
  });
});

router.patch('/users/:id/profile', adminAuthRequired, async (req, res) => {
  const { vipLevel, points, funCoins } = req.body ?? {};
  try {
    const profile = await prisma.userProfile.update({
      where: { userId: req.params.id },
      data: {
        vipLevel: vipLevel != null ? Number(vipLevel) : undefined,
        points: points != null ? Number(points) : undefined,
        funCoins: funCoins != null ? Number(funCoins) : undefined,
      },
    });
    ok(res, { profile });
  } catch {
    fail(res, 404, '用户不存在');
  }
});

router.get('/coupons', adminAuthRequired, async (_req, res) => {
  const coupons = await prisma.couponTemplate.findMany({ orderBy: { id: 'asc' } });
  ok(res, {
    coupons: coupons.map(serializeCouponTemplate),
  });
});

function serializeCouponTemplate(c) {
  return {
    id: c.id,
    title: c.title,
    discount: Number(c.discount),
    condition: c.condition,
    expireAt: c.expireAt.toISOString().slice(0, 10),
  };
}

async function generateCouponId() {
  const rows = await prisma.couponTemplate.findMany({ select: { id: true } });
  let max = 0;
  for (const row of rows) {
    const match = /^c(\d+)$/i.exec(row.id);
    if (match) max = Math.max(max, Number(match[1]));
  }
  return `c${max + 1}`;
}

router.post('/coupons', adminAuthRequired, async (req, res) => {
  const body = req.body ?? {};
  const title = String(body.title ?? '').trim();
  const condition = String(body.condition ?? '').trim();
  const discount = body.discount != null ? Number(body.discount) : NaN;
  const expireAtRaw = body.expireAt ? String(body.expireAt).trim() : '';
  const expireAt = expireAtRaw ? new Date(expireAtRaw) : null;

  if (!title || !condition || !Number.isFinite(discount) || discount <= 0 || !expireAt || Number.isNaN(expireAt.getTime())) {
    fail(res, 400, '请填写完整的优惠券信息');
    return;
  }

  const id = await generateCouponId();

  try {
    const coupon = await prisma.couponTemplate.create({
      data: { id, title, discount, condition, expireAt },
    });
    ok(res, { coupon: serializeCouponTemplate(coupon) });
  } catch (error) {
    if (error?.code === 'P2002') {
      fail(res, 400, '优惠券 ID 已存在');
      return;
    }
    fail(res, 400, '创建失败');
  }
});

router.put('/coupons/:id', adminAuthRequired, async (req, res) => {
  const body = req.body ?? {};
  try {
    const coupon = await prisma.couponTemplate.update({
      where: { id: req.params.id },
      data: {
        title: body.title,
        discount: body.discount != null ? Number(body.discount) : undefined,
        condition: body.condition,
        expireAt: body.expireAt ? new Date(body.expireAt) : undefined,
      },
    });
    ok(res, { coupon: serializeCouponTemplate(coupon) });
  } catch {
    fail(res, 404, '优惠券不存在');
  }
});

router.get('/banners', adminAuthRequired, async (_req, res) => {
  const banners = await prisma.banner.findMany({
    include: { product: true },
    orderBy: { sortOrder: 'asc' },
  });
  ok(res, {
    banners: banners.map((b) => ({
      id: b.id,
      imagePath: b.imagePath,
      productId: b.productId,
      productName: b.product.name,
      sortOrder: b.sortOrder,
    })),
  });
});

router.post('/banners', adminAuthRequired, async (req, res) => {
  const { imagePath, productId, sortOrder } = req.body ?? {};
  if (!imagePath || !productId) {
    fail(res, 400, '轮播图路径与关联商品不能为空');
    return;
  }
  const banner = await prisma.banner.create({
    data: {
      imagePath: String(imagePath),
      productId: String(productId),
      sortOrder: Number(sortOrder ?? 0),
    },
    include: { product: true },
  });
  ok(res, {
    banner: {
      id: banner.id,
      imagePath: banner.imagePath,
      productId: banner.productId,
      productName: banner.product.name,
      sortOrder: banner.sortOrder,
    },
  });
});

router.put('/banners/:id', adminAuthRequired, async (req, res) => {
  const body = req.body ?? {};
  try {
    const banner = await prisma.banner.update({
      where: { id: req.params.id },
      data: {
        imagePath: body.imagePath,
        productId: body.productId,
        sortOrder: body.sortOrder != null ? Number(body.sortOrder) : undefined,
      },
      include: { product: true },
    });
    ok(res, {
      banner: {
        id: banner.id,
        imagePath: banner.imagePath,
        productId: banner.productId,
        productName: banner.product.name,
        sortOrder: banner.sortOrder,
      },
    });
  } catch {
    fail(res, 404, '轮播不存在');
  }
});

router.delete('/banners/:id', adminAuthRequired, async (req, res) => {
  try {
    await prisma.banner.delete({ where: { id: req.params.id } });
    ok(res, { deleted: true });
  } catch {
    fail(res, 404, '轮播不存在');
  }
});

router.get('/settings', adminAuthRequired, (req, res) => {
  ok(res, { settings: resolveAdminProfile(req.admin.username) });
});

router.patch('/settings/profile', adminAuthRequired, (req, res) => {
  const { displayName, systemName } = req.body ?? {};
  const username = req.admin.username;
  if (displayName != null) {
    const name = String(displayName).trim();
    if (!name) {
      fail(res, 400, '管理员姓名不能为空');
      return;
    }
    if (!updateAdminDisplayName(username, name)) {
      fail(res, 400, '更新姓名失败');
      return;
    }
  }
  if (systemName != null) {
    const sysName = String(systemName).trim();
    if (!sysName) {
      fail(res, 400, '系统名称不能为空');
      return;
    }
    writeAdminSettings({ systemName: sysName });
  }
  if (displayName == null && systemName == null) {
    fail(res, 400, '没有可更新的字段');
    return;
  }
  ok(res, { admin: resolveAdminProfile(username) });
});

router.post('/settings/avatar', adminAuthRequired, (req, res) => {
  const { imageBase64, mimeType } = req.body ?? {};
  const type = String(mimeType ?? '');
  const ext = AVATAR_MIME_EXT[type];
  if (!ext || !imageBase64) {
    fail(res, 400, '请上传 JPG、PNG、WebP 或 GIF 图片');
    return;
  }

  let buffer;
  try {
    buffer = Buffer.from(String(imageBase64), 'base64');
  } catch {
    fail(res, 400, '图片数据无效');
    return;
  }

  if (buffer.length === 0) {
    fail(res, 400, '图片数据无效');
    return;
  }

  const username = req.admin.username;
  const dir = path.join(assetsRoot, 'images/admin-avatars');
  fs.mkdirSync(dir, { recursive: true });

  const safeName = username.replace(/[^a-zA-Z0-9_-]/g, '_');
  const filename = `${safeName}.${ext}`;
  fs.writeFileSync(path.join(dir, filename), buffer);

  const avatarPath = `assets/images/admin-avatars/${filename}`;
  if (!updateAdminAvatar(username, avatarPath)) {
    fail(res, 400, '头像保存失败');
    return;
  }

  ok(res, { admin: resolveAdminProfile(username) });
});

router.post('/upload/product-image', adminAuthRequired, (req, res) => {
  try {
    const imagePath = saveAdminAssetImage({
      imageBase64: req.body?.imageBase64,
      mimeType: req.body?.mimeType,
      subdir: 'images/products',
    });
    ok(res, { imagePath });
  } catch (error) {
    fail(res, 400, error.message || '上传失败');
  }
});

router.post('/upload/banner-image', adminAuthRequired, (req, res) => {
  try {
    const imagePath = saveAdminAssetImage({
      imageBase64: req.body?.imageBase64,
      mimeType: req.body?.mimeType,
      subdir: 'images/banners',
    });
    ok(res, { imagePath });
  } catch (error) {
    fail(res, 400, error.message || '上传失败');
  }
});

router.post('/settings/password', adminAuthRequired, async (req, res) => {
  const currentPassword = String(req.body?.currentPassword ?? '');
  const newPassword = String(req.body?.newPassword ?? '');
  if (!currentPassword || !newPassword) {
    fail(res, 400, '请填写当前密码和新密码');
    return;
  }
  if (newPassword.length < 6) {
    fail(res, 400, '新密码至少 6 位');
    return;
  }
  const updated = await changeAdminPassword(req.admin.username, currentPassword, newPassword);
  if (!updated) {
    fail(res, 400, '当前密码错误');
    return;
  }
  ok(res, { updated: true });
});

router.patch('/settings/notifications', adminAuthRequired, (req, res) => {
  const { orderNotify, userNotify, systemNotify } = req.body ?? {};
  const notifications = {};
  if (orderNotify != null) notifications.orderNotify = Boolean(orderNotify);
  if (userNotify != null) notifications.userNotify = Boolean(userNotify);
  if (systemNotify != null) notifications.systemNotify = Boolean(systemNotify);
  const next = writeAdminSettings({ notifications });
  ok(res, { notifications: next.notifications });
});

router.post('/settings/sync-sales', adminAuthRequired, async (_req, res) => {
  await syncAllProductSales();
  ok(res, { synced: true });
});

router.get('/settings/data-summary', adminAuthRequired, async (_req, res) => {
  const [productCount, userCount, orderCount, couponCount, bannerCount, paidOrders, pendingOrders] =
    await Promise.all([
      prisma.product.count(),
      prisma.user.count(),
      prisma.order.count(),
      prisma.couponTemplate.count(),
      prisma.banner.count(),
      prisma.order.findMany({ where: { paymentStatus: 'paid' }, select: { total: true } }),
      prisma.order.count({ where: { status: 'pending' } }),
    ]);
  const totalRevenue = paidOrders.reduce((sum, o) => sum + Number(o.total), 0);
  ok(res, {
    summary: {
      products: productCount,
      users: userCount,
      orders: orderCount,
      coupons: couponCount,
      banners: bannerCount,
      totalRevenue,
      pendingOrders,
    },
  });
});

router.get('/changelog', adminAuthRequired, (_req, res) => {
  ok(res, { entries: readChangelog() });
});

router.post('/changelog', adminAuthRequired, (req, res) => {
  try {
    const entry = createChangelogEntry(req.body ?? {});
    ok(res, { entry });
  } catch (err) {
    if (err.message === 'VERSION_REQUIRED') fail(res, 400, '版本号不能为空');
    else if (err.message === 'TITLE_REQUIRED') fail(res, 400, '标题不能为空');
    else if (err.message === 'ITEMS_REQUIRED') fail(res, 400, '至少填写一条更新内容');
    else fail(res, 400, '创建失败');
  }
});

router.put('/changelog/:id', adminAuthRequired, (req, res) => {
  try {
    const entry = updateChangelogEntry(req.params.id, req.body ?? {});
    if (!entry) {
      fail(res, 404, '日志不存在');
      return;
    }
    ok(res, { entry });
  } catch (err) {
    if (err.message === 'INVALID_ENTRY') fail(res, 400, '请填写完整的版本、标题与更新内容');
    else fail(res, 400, '更新失败');
  }
});

router.delete('/changelog/:id', adminAuthRequired, (req, res) => {
  const deleted = deleteChangelogEntry(req.params.id);
  if (!deleted) {
    fail(res, 404, '日志不存在');
    return;
  }
  ok(res, { deleted: true });
});

export default router;

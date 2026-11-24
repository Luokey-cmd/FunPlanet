import { Router } from 'express';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { prisma } from '../db.js';
import { adminAuthRequired } from '../middleware/adminAuth.js';
import { signToken, verifyToken } from '../utils/jwt.js';
import { serializeProduct } from '../utils/product.js';
import { log } from '../utils/log.js';
import { getPaidSalesMap, syncAllProductSales } from '../utils/product-sales.js';
import {
  changeAdminPassword,
  createAdminAccount,
  resolveAdminProfile,
  resolveAdminRole,
  updateAdminAvatar,
  updateAdminDisplayName,
  verifyRegisteredAdmin,
} from '../utils/admin-auth.js';
import {
  getAdminUsername,
  verifyAdminPassword,
  writeAdminSettings,
} from '../utils/admin-settings.js';
import {
  isRegisteredAdmin,
  listAdminAccountsSafe,
  setAdminAccountDisabled,
  updateAdminAccountRole,
} from '../utils/admin-accounts.js';
import { appendAuditLog, readAuditLog } from '../utils/audit-log.js';
import {
  createChangelogEntry,
  deleteChangelogEntry,
  readChangelog,
  updateChangelogEntry,
} from '../utils/changelog.js';
import {
  createCategory,
  deleteCategory,
  readCategories,
  updateCategory,
} from '../utils/categories.js';
import { formatChinaDate, formatChinaDateTime } from '../utils/datetime.js';
import { aggregateProvinceHeat } from '../utils/province.js';
import { isDisplayableAvatarPath } from '../utils/avatar-media.js';
import { fail, ok } from '../utils/response.js';
import { saveAdminAssetImage } from '../utils/admin-asset-upload.js';
import adminSupportRoutes from './admin-support.js';

const router = Router();
const assetsRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../assets');

// 仅超级管理员可访问的接口守卫
function superAdminRequired(req, res, next) {
  if (resolveAdminRole(req.admin?.username) !== 'super') {
    fail(res, 403, '只有超级管理员可以进行此操作');
    return;
  }
  next();
}

// 把请求路径翻译成操作日志里的人话
function auditActionLabel(method, p) {
  const seg = p.split('/').filter(Boolean);
  const head = seg[0] ?? '';
  const verb = method === 'POST' ? '新增' : method === 'DELETE' ? '删除' : '编辑';
  if (head === 'products') {
    if (p.includes('/shelf')) return '商品上下架';
    return `${verb}商品`;
  }
  if (head === 'categories') return `${verb}分类`;
  if (head === 'banners') return `${verb}轮播图`;
  if (head === 'coupons') return `${verb}优惠券`;
  if (head === 'changelog') return `${verb}更新日志`;
  if (head === 'orders') return '更新订单状态';
  if (head === 'after-sales') return '处理售后申请';
  if (head === 'moderation') {
    return method === 'DELETE' ? '内容审核：删除内容' : '内容审核：调整可见状态';
  }
  if (head === 'users') return '编辑用户资料';
  if (head === 'admins') return '调整管理员账号';
  if (head === 'support') return '客服中心操作';
  if (head === 'settings') {
    if (p.includes('password')) return '修改登录密码';
    if (p.includes('sync-sales')) return '同步商品销量';
    if (p.includes('notifications')) return '修改通知偏好';
    if (p.includes('avatar')) return '更换管理员头像';
    return '修改系统设置';
  }
  return null;
}

// 操作日志：所有写操作成功后自动记一条（登录在登录接口里单独记）
router.use((req, res, next) => {
  if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method) && !req.path.startsWith('/auth')) {
    res.on('finish', () => {
      if (res.statusCode >= 400 || !req.admin?.username) return;
      const action = auditActionLabel(req.method, req.path);
      if (!action) return;
      const profile = resolveAdminProfile(req.admin.username);
      appendAuditLog({
        username: req.admin.username,
        name: profile.name,
        action,
        detail: `${req.method} ${req.path}`,
      });
    });
  }
  next();
});

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

  let registered = null;
  try {
    registered = await verifyRegisteredAdmin(u, p);
  } catch (err) {
    if (err.code === 'ACCOUNT_DISABLED') {
      fail(res, 403, '该账号已被禁用，请联系超级管理员');
      return;
    }
    throw err;
  }
  if (registered) {
    const profile = resolveAdminProfile(registered.username);
    const token = signToken({ role: 'admin', username: registered.username, name: profile.name });
    appendAuditLog({ username: registered.username, name: profile.name, action: '登录后台', detail: '' });
    log.info('后台', `管理员登录成功：${registered.username}`);
    ok(res, { token, admin: profile });
    return;
  }

  const adminUser = getAdminUsername();
  if (u === adminUser && verifyAdminPassword(p)) {
    const profile = resolveAdminProfile(adminUser);
    const token = signToken({ role: 'admin', username: adminUser, name: profile.name });
    appendAuditLog({ username: adminUser, name: profile.name, action: '登录后台', detail: '' });
    log.info('后台', `管理员登录成功：${adminUser}（默认管理员）`);
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

// 管理员账号管理（仅超级管理员）：内置账号固定超级管理员，注册账号可调角色/禁用
router.get('/admins', adminAuthRequired, superAdminRequired, (_req, res) => {
  const builtinProfile = resolveAdminProfile(getAdminUsername());
  const builtin = {
    username: builtinProfile.username,
    name: builtinProfile.name,
    avatarPath: builtinProfile.avatarPath ?? null,
    role: 'super',
    disabled: false,
    createdAt: null,
    builtin: true,
  };
  ok(res, { admins: [builtin, ...listAdminAccountsSafe()] });
});

router.patch('/admins/:username/role', adminAuthRequired, superAdminRequired, (req, res) => {
  const target = req.params.username;
  if (target === getAdminUsername()) {
    fail(res, 400, '内置管理员固定为超级管理员，不能修改');
    return;
  }
  if (target === req.admin.username) {
    fail(res, 400, '不能修改自己当前的角色');
    return;
  }
  if (!updateAdminAccountRole(target, req.body?.role)) {
    fail(res, 404, '账号不存在');
    return;
  }
  ok(res, { updated: true });
});

router.patch('/admins/:username/disabled', adminAuthRequired, superAdminRequired, (req, res) => {
  const target = req.params.username;
  if (target === getAdminUsername()) {
    fail(res, 400, '内置管理员不能禁用');
    return;
  }
  if (target === req.admin.username) {
    fail(res, 400, '不能禁用自己');
    return;
  }
  if (!setAdminAccountDisabled(target, req.body?.disabled === true)) {
    fail(res, 404, '账号不存在');
    return;
  }
  ok(res, { updated: true });
});

// 操作日志（仅超级管理员查看）
router.get('/audit-logs', adminAuthRequired, superAdminRequired, (req, res) => {
  const username = String(req.query.username ?? '').trim();
  let entries = readAuditLog();
  if (username) entries = entries.filter((e) => e.username === username);
  ok(res, { entries: entries.slice(0, 200) });
});

// 客服专员的写操作收口：只能改订单状态、回复客服、改自己的资料，其余写操作一律拒绝
router.use((req, res, next) => {
  if (!['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)) {
    next();
    return;
  }
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    next();
    return;
  }
  let username = null;
  try {
    username = verifyToken(token).username;
  } catch {
    next();
    return;
  }
  if (resolveAdminRole(username) !== 'support') {
    next();
    return;
  }
  const p = req.path;
  const allowed =
    p.startsWith('/orders/') ||
    p.startsWith('/after-sales/') ||
    p.startsWith('/support/') ||
    p.startsWith('/settings/profile') ||
    p.startsWith('/settings/password') ||
    p.startsWith('/settings/avatar') ||
    p.startsWith('/settings/notifications');
  if (!allowed) {
    fail(res, 403, '客服专员没有此操作权限');
    return;
  }
  next();
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
    实用类周边: '#c4b5fd',
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

  const regionHeat = aggregateProvinceHeat(
    orders.map((o) => ({ addressDetail: o.addressDetail })),
  );

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
    regionHeat,
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
      stock: body.stock != null ? Math.max(0, Math.trunc(Number(body.stock)) || 0) : 100,
      isOnShelf: body.isOnShelf !== false,
      imagePath: String(body.imagePath ?? ''),
      // 多图与导购结构化字段（2026-11-20 新增）：后台传了才写；多图第一张默认与主图一致由前端保证
      imagePaths: Array.isArray(body.imagePaths) ? body.imagePaths.map((x) => String(x)).filter(Boolean).slice(0, 9) : [],
      // 详情长图组：详情页介绍区纵向长图，最多 20 张
      detailImages: Array.isArray(body.detailImages) ? body.detailImages.map((x) => String(x)).filter(Boolean).slice(0, 20) : [],
      videoPath: body.videoPath ? String(body.videoPath) : null,
      brand: body.brand ? String(body.brand) : null,
      series: body.series ? String(body.series) : null,
      rarity: body.rarity ? String(body.rarity) : null,
      suitableFor: body.suitableFor ? String(body.suitableFor) : null,
      sellingPoints: Array.isArray(body.sellingPoints)
        ? body.sellingPoints.map((x) => String(x).trim()).filter(Boolean).slice(0, 8)
        : [],
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
        stock: body.stock != null ? Math.max(0, Math.trunc(Number(body.stock)) || 0) : undefined,
        isOnShelf: typeof body.isOnShelf === 'boolean' ? body.isOnShelf : undefined,
        imagePath: body.imagePath,
        imagePaths: Array.isArray(body.imagePaths)
          ? body.imagePaths.map((x) => String(x)).filter(Boolean).slice(0, 9)
          : undefined,
        detailImages: Array.isArray(body.detailImages)
          ? body.detailImages.map((x) => String(x)).filter(Boolean).slice(0, 20)
          : undefined,
        videoPath: body.videoPath !== undefined ? (body.videoPath ? String(body.videoPath) : null) : undefined,
        brand: body.brand !== undefined ? (body.brand ? String(body.brand) : null) : undefined,
        series: body.series !== undefined ? (body.series ? String(body.series) : null) : undefined,
        rarity: body.rarity !== undefined ? (body.rarity ? String(body.rarity) : null) : undefined,
        suitableFor: body.suitableFor !== undefined ? (body.suitableFor ? String(body.suitableFor) : null) : undefined,
        sellingPoints: Array.isArray(body.sellingPoints)
          ? body.sellingPoints.map((x) => String(x).trim()).filter(Boolean).slice(0, 8)
          : undefined,
      },
    });
    ok(res, { product: serializeProduct(product) });
  } catch (error) {
    if (error?.code === 'P2025') return fail(res, 404, '商品不存在');
    log.error('后台', '更新商品失败', error);
    return fail(res, 500, '保存失败，请看服务端日志');
  }
});

router.patch('/products/:id/shelf', adminAuthRequired, async (req, res) => {
  try {
    const product = await prisma.product.update({
      where: { id: req.params.id },
      data: { isOnShelf: req.body?.isOnShelf !== false },
    });
    ok(res, { product: serializeProduct(product) });
  } catch (error) {
    // P2025 才是真的找不到记录；其他错误（如数据库还没加 is_on_shelf 列）
    // 不能再谎报「商品不存在」，把真实原因打进日志并如实返回
    if (error?.code === 'P2025') return fail(res, 404, '商品不存在');
    log.error('后台', '商品上下架失败', error);
    return fail(res, 500, '上下架失败，请看服务端日志');
  }
});

router.delete('/products/:id', adminAuthRequired, async (req, res) => {
  try {
    await prisma.product.delete({ where: { id: req.params.id } });
    ok(res, { deleted: true });
  } catch (error) {
    if (error?.code === 'P2025') return fail(res, 404, '商品不存在');
    log.error('后台', '删除商品失败', error);
    return fail(res, 500, '删除失败，请看服务端日志');
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
      freight: o.freight == null ? 0 : Number(o.freight),
      status: o.status,
      statusLabel: orderStatusLabel(o.status),
      paymentStatus: o.paymentStatus,
      date: formatChinaDateTime(o.createdAt),
      address: o.addressDetail ?? '',
      remark: o.remark ?? null,
      shippingCompany: o.shippingCompany ?? null,
      trackingNo: o.trackingNo ?? null,
      shippedAt: o.shippedAt ? o.shippedAt.toISOString() : null,
      receivedAt: o.receivedAt ? o.receivedAt.toISOString() : null,
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

    // 发货时可同时带物流公司和单号（后台发货弹窗传），一起落库并钉上发货时间
    const shippingCompany = String(req.body?.shippingCompany ?? '').trim() || null;
    const trackingNo = String(req.body?.trackingNo ?? '').trim() || null;
    const order = await prisma.$transaction(async (tx) => {
      const updated = await tx.order.update({
        where: { id: req.params.id },
        data: {
          status,
          ...(status === 'completed' ? { paymentStatus: 'paid', receivedAt: new Date() } : {}),
          ...(status === 'shipping'
            ? { shippedAt: new Date(), shippingCompany, trackingNo }
            : {}),
        },
      });

      if (status === 'shipping') {
        await tx.notification.create({
          data: {
            userId: updated.userId,
            title: '商品已发货',
            body: `订单 ${updated.orderNo} 已发货${trackingNo ? `，快递单号 ${trackingNo}` : ''}，正在配送中，请留意查收`,
            type: 'order',
            targetType: 'order',
            targetId: updated.id,
          },
        });
      } else if (status === 'completed') {
        await tx.notification.create({
          data: {
            userId: updated.userId,
            title: '订单已送达',
            body: `订单 ${updated.orderNo} 已送达，感谢您的购买`,
            type: 'order',
            targetType: 'order',
            targetId: updated.id,
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

// 订单筛选条件：列表、导出共用一处，保证「看到什么就导出什么」
function buildOrderWhere(req) {
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
  return where;
}

// 订单导出 CSV：按当前筛选导出，Excel 打开不乱码（加 BOM 头）；
// 字段带逗号/引号/换行时按 CSV 规则加引号转义
router.get('/orders/export', adminAuthRequired, async (req, res) => {
  const orders = await prisma.order.findMany({
    where: buildOrderWhere(req),
    include: { user: true, items: true },
    orderBy: { createdAt: 'desc' },
  });
  const esc = (v) => {
    const s = String(v ?? '');
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const header = [
    '订单号', '下单时间', '买家', '手机号', '商品明细', '商品总额', '优惠金额',
    '运费', '实付金额', '状态', '支付状态', '收货人', '收货电话', '收货地址',
    '物流公司', '快递单号', '发货时间', '买家备注',
  ];
  const lines = orders.map((o) =>
    [
      o.orderNo,
      formatChinaDateTime(o.createdAt),
      o.user.nickname,
      o.user.phone,
      o.items.map((i) => `${i.name}${i.spec ? `(${i.spec})` : ''} x${i.quantity}`).join('、'),
      Number(o.subtotal).toFixed(2),
      Number(o.discount).toFixed(2),
      Number(o.freight).toFixed(2),
      Number(o.total).toFixed(2),
      orderStatusLabel(o.status),
      o.paymentStatus,
      o.addressName ?? '',
      o.addressPhone ?? '',
      o.addressDetail ?? '',
      o.shippingCompany ?? '',
      o.trackingNo ?? '',
      o.shippedAt ? formatChinaDateTime(o.shippedAt) : '',
      o.remark ?? '',
    ]
      .map(esc)
      .join(','),
  );
  const stamp = formatChinaDate(new Date()).replace(/\//g, '-');
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="funplanet-orders-${stamp}.csv"`);
  res.send('\uFEFF' + [header.join(','), ...lines].join('\r\n'));
});

// 订单详情：列表只给概要，详情把金额拆分、收货信息、商品明细快照、
// 支付与时间线、关联售后一次给全，供后台详情弹窗展示
router.get('/orders/:id', adminAuthRequired, async (req, res) => {
  const order = await prisma.order.findUnique({
    where: { id: req.params.id },
    include: {
      user: true,
      items: true,
      afterSaleRequests: { orderBy: { createdAt: 'desc' } },
    },
  });
  if (!order) {
    fail(res, 404, '订单不存在');
    return;
  }
  ok(res, {
    order: {
      id: order.id,
      orderNo: order.orderNo,
      status: order.status,
      statusLabel: orderStatusLabel(order.status),
      paymentStatus: order.paymentStatus,
      paymentMethod: order.paymentMethod ?? null,
      user: order.user.nickname,
      phone: order.user.phone,
      subtotal: Number(order.subtotal),
      discount: Number(order.discount),
      freight: Number(order.freight),
      amount: Number(order.total),
      addressName: order.addressName ?? '',
      addressPhone: order.addressPhone ?? '',
      address: order.addressDetail ?? '',
      remark: order.remark ?? null,
      cancelReason: order.cancelReason ?? null,
      shippingCompany: order.shippingCompany ?? null,
      trackingNo: order.trackingNo ?? null,
      date: formatChinaDateTime(order.createdAt),
      paidAt: order.paidAt ? formatChinaDateTime(order.paidAt) : null,
      shippedAt: order.shippedAt ? formatChinaDateTime(order.shippedAt) : null,
      receivedAt: order.receivedAt ? formatChinaDateTime(order.receivedAt) : null,
      cancelledAt: order.cancelledAt ? formatChinaDateTime(order.cancelledAt) : null,
      items: order.items.map((i) => ({
        id: i.id,
        productId: i.productId,
        name: i.name,
        spec: i.spec,
        imagePath: i.imagePath ?? '',
        unitPrice: Number(i.unitPrice),
        quantity: i.quantity,
        subtotal: Number(i.subtotal),
      })),
      afterSales: order.afterSaleRequests.map((r) => ({
        id: r.id,
        type: r.type,
        reason: r.reason,
        description: r.description,
        amount: r.amount == null ? null : Number(r.amount),
        status: r.status,
        adminNote: r.adminNote ?? null,
        date: formatChinaDateTime(r.createdAt),
      })),
    },
  });
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
      joinDateTime: formatChinaDateTime(u.createdAt).replaceAll('-', '/'),
      // 状态读真实字段（之前这里写死 active，后台禁用了也显示正常）；老数据默认 active
      status: u.status ?? 'active',
      lastLoginAt: u.lastLoginAt ? u.lastLoginAt.toISOString() : null,
      growthPoints: u.profile?.growthPoints ?? 0,
      vipExpireAt: u.profile?.vipExpireAt ? u.profile.vipExpireAt.toISOString() : null,
      avatarPath: isDisplayableAvatarPath(u.profile?.avatarPath) ? u.profile.avatarPath : null,
    })),
  });
});

router.patch('/users/:id/profile', adminAuthRequired, async (req, res) => {
  const { vipLevel, points, funCoins, status, growthPoints, vipExpireAt } = req.body ?? {};
  try {
    // 账号状态在 User 表上，和资料分开改；只接受 active / disabled 两个值
    if (status != null) {
      if (!['active', 'disabled'].includes(status)) {
        fail(res, 400, '无效的账号状态');
        return;
      }
      await prisma.user.update({
        where: { id: req.params.id },
        data: { status },
      });
    }
    const profile = await prisma.userProfile.update({
      where: { userId: req.params.id },
      data: {
        vipLevel: vipLevel != null ? Number(vipLevel) : undefined,
        points: points != null ? Number(points) : undefined,
        funCoins: funCoins != null ? Number(funCoins) : undefined,
        growthPoints: growthPoints != null ? Number(growthPoints) : undefined,
        vipExpireAt:
          vipExpireAt !== undefined ? (vipExpireAt ? new Date(vipExpireAt) : null) : undefined,
      },
    });
    ok(res, { profile });
  } catch {
    fail(res, 404, '用户不存在');
  }
});

// 售后处理：列表 + 处理（同意/拒绝/完成）。售后单独立表后，后台不再拿「已取消」冒充售后
router.get('/after-sales', adminAuthRequired, async (req, res) => {
  const status = String(req.query.status ?? '').trim();
  const where = status && status !== 'all' ? { status } : {};
  const rows = await prisma.afterSaleRequest.findMany({
    where,
    orderBy: { createdAt: 'desc' },
    include: {
      order: { select: { orderNo: true, total: true, status: true } },
      user: { select: { nickname: true, phone: true } },
    },
  });
  ok(res, {
    requests: rows.map((r) => ({
      id: r.id,
      orderId: r.orderId,
      orderNo: r.order.orderNo,
      orderStatus: r.order.status,
      orderTotal: Number(r.order.total),
      user: r.user.nickname,
      phone: r.user.phone,
      type: r.type,
      reason: r.reason,
      description: r.description,
      amount: r.amount == null ? null : Number(r.amount),
      status: r.status,
      adminNote: r.adminNote ?? null,
      date: formatChinaDateTime(r.createdAt),
    })),
  });
});

router.patch('/after-sales/:id/status', adminAuthRequired, async (req, res) => {
  const status = String(req.body?.status ?? '').trim();
  if (!['approved', 'rejected', 'completed'].includes(status)) {
    fail(res, 400, '无效的售后状态');
    return;
  }
  const adminNote = String(req.body?.adminNote ?? '').trim().slice(0, 500) || null;
  try {
    const updated = await prisma.$transaction(async (tx) => {
      const row = await tx.afterSaleRequest.update({
        where: { id: req.params.id },
        data: { status, adminNote },
        include: { order: true },
      });
      // 售后完成且是退款类：把支付流水和订单支付状态标成已退款（模拟支付口径，即时生效）
      if (status === 'completed') {
        await tx.paymentTransaction.updateMany({
          where: { orderId: row.orderId, status: 'paid' },
          data: { status: 'refunded' },
        });
        await tx.order.update({
          where: { id: row.orderId },
          data: { paymentStatus: 'refunded' },
        });
      }
      await tx.notification.create({
        data: {
          userId: row.userId,
          title: '售后处理更新',
          body: `订单 ${row.order.orderNo} 的售后申请状态：${status === 'approved' ? '已同意' : status === 'rejected' ? '已拒绝' : '已完成'}${adminNote ? `。备注：${adminNote}` : ''}`,
          type: 'order',
          targetType: 'order',
          targetId: row.orderId,
        },
      });
      return row;
    });
    ok(res, { request: { id: updated.id, status: updated.status } });
  } catch {
    fail(res, 404, '售后申请不存在');
  }
});

// ===== 内容审核 =====
// 审核状态口径（字段是 2026-11-20 字段批备好的）：visible 可见 / hidden 已隐藏。
// 社区动态、AI 绘画、商品评价三类有状态字段：隐藏后 App 端不再展示（信息流、
// 评价列表、绘画列表都已按 visible 过滤），恢复即可见；删除是硬删除、不可恢复。
// 社区评论没有状态字段，只能删除；删帖会连带其评论与点赞（数据库级联删除）。

// 校验并读取目标审核状态，只接受 visible / hidden
function readModerationTarget(req, res) {
  const status = String(req.body?.status ?? '').trim();
  if (!['visible', 'hidden'].includes(status)) {
    fail(res, 400, '无效的审核状态');
    return null;
  }
  return status;
}

// 三类带状态字段的内容共用同一套「改状态 / 删除」逻辑
async function setModerationStatus(delegate, id, status, res, notFoundMessage) {
  try {
    await delegate.update({ where: { id }, data: { moderationStatus: status } });
    ok(res, { updated: true, status });
  } catch (error) {
    if (error?.code === 'P2025') return fail(res, 404, notFoundMessage);
    log.error('后台', '改审核状态失败', error);
    return fail(res, 500, '操作失败，请看服务端日志');
  }
}

async function deleteModerated(delegate, id, res, notFoundMessage) {
  try {
    await delegate.delete({ where: { id } });
    ok(res, { deleted: true });
  } catch (error) {
    if (error?.code === 'P2025') return fail(res, 404, notFoundMessage);
    log.error('后台', '删除待审内容失败', error);
    return fail(res, 500, '删除失败，请看服务端日志');
  }
}

// 内容作者展示名：真人用户取昵称，AI 好友取好友名
function moderationAuthor(row) {
  if (row.authorType === 'ai_friend') return { name: row.aiFriend?.name ?? 'AI好友', isAi: true };
  return { name: row.user?.nickname ?? '用户', isAi: false };
}

function moderationStatusFilter(req) {
  const s = String(req.query.status ?? '').trim();
  return ['visible', 'hidden'].includes(s) ? { moderationStatus: s } : {};
}

router.get('/moderation/posts', adminAuthRequired, async (req, res) => {
  const keyword = String(req.query.keyword ?? '').trim();
  const posts = await prisma.aiCommunityPost.findMany({
    where: {
      ...moderationStatusFilter(req),
      ...(keyword ? { content: { contains: keyword } } : {}),
    },
    include: {
      user: true,
      aiFriend: true,
      _count: { select: { comments: true, likes: true } },
    },
    orderBy: { createdAt: 'desc' },
    take: 200,
  });
  ok(res, {
    posts: posts.map((p) => ({
      id: p.id,
      author: moderationAuthor(p).name,
      isAi: moderationAuthor(p).isAi,
      content: p.content,
      images: p.imagePaths?.length ? p.imagePaths : p.imagePath ? [p.imagePath] : [],
      commentCount: p._count.comments,
      likeCount: p._count.likes,
      status: p.moderationStatus ?? 'visible',
      date: formatChinaDateTime(p.createdAt),
    })),
  });
});

router.patch('/moderation/posts/:id/status', adminAuthRequired, async (req, res) => {
  const status = readModerationTarget(req, res);
  if (!status) return;
  await setModerationStatus(prisma.aiCommunityPost, req.params.id, status, res, '动态不存在');
});

router.delete('/moderation/posts/:id', adminAuthRequired, async (req, res) => {
  await deleteModerated(prisma.aiCommunityPost, req.params.id, res, '动态不存在');
});

router.get('/moderation/comments', adminAuthRequired, async (req, res) => {
  const keyword = String(req.query.keyword ?? '').trim();
  const comments = await prisma.aiCommunityComment.findMany({
    where: keyword ? { content: { contains: keyword } } : {},
    include: { user: true, aiFriend: true, post: true },
    orderBy: { createdAt: 'desc' },
    take: 200,
  });
  ok(res, {
    comments: comments.map((c) => ({
      id: c.id,
      author: moderationAuthor(c).name,
      isAi: moderationAuthor(c).isAi,
      content: c.content,
      postContent: c.post?.content?.slice(0, 80) ?? '',
      replyToUserName: c.replyToUserName ?? '',
      date: formatChinaDateTime(c.createdAt),
    })),
  });
});

router.delete('/moderation/comments/:id', adminAuthRequired, async (req, res) => {
  await deleteModerated(prisma.aiCommunityComment, req.params.id, res, '评论不存在');
});

router.get('/moderation/artworks', adminAuthRequired, async (req, res) => {
  const keyword = String(req.query.keyword ?? '').trim();
  const rows = await prisma.aiArtwork.findMany({
    where: {
      ...moderationStatusFilter(req),
      ...(keyword ? { prompt: { contains: keyword } } : {}),
    },
    include: { user: true },
    orderBy: { createdAt: 'desc' },
    take: 200,
  });
  ok(res, {
    artworks: rows.map((a) => ({
      id: a.id,
      author: a.user?.nickname ?? '用户',
      prompt: a.prompt,
      style: a.style,
      image: a.imagePath,
      status: a.moderationStatus ?? 'visible',
      date: formatChinaDateTime(a.createdAt),
    })),
  });
});

router.patch('/moderation/artworks/:id/status', adminAuthRequired, async (req, res) => {
  const status = readModerationTarget(req, res);
  if (!status) return;
  await setModerationStatus(prisma.aiArtwork, req.params.id, status, res, '作品不存在');
});

router.delete('/moderation/artworks/:id', adminAuthRequired, async (req, res) => {
  await deleteModerated(prisma.aiArtwork, req.params.id, res, '作品不存在');
});

router.get('/moderation/reviews', adminAuthRequired, async (req, res) => {
  const keyword = String(req.query.keyword ?? '').trim();
  const rows = await prisma.productReview.findMany({
    where: {
      ...moderationStatusFilter(req),
      ...(keyword ? { content: { contains: keyword } } : {}),
    },
    include: { user: true, product: true },
    orderBy: { createdAt: 'desc' },
    take: 200,
  });
  ok(res, {
    reviews: rows.map((r) => ({
      id: r.id,
      author: r.user?.nickname ?? '用户',
      productName: r.product?.name ?? '',
      productId: r.productId,
      rating: r.rating,
      content: r.content,
      images: r.imagePaths ?? [],
      status: r.moderationStatus ?? 'visible',
      date: formatChinaDateTime(r.createdAt),
    })),
  });
});

router.patch('/moderation/reviews/:id/status', adminAuthRequired, async (req, res) => {
  const status = readModerationTarget(req, res);
  if (!status) return;
  await setModerationStatus(prisma.productReview, req.params.id, status, res, '评价不存在');
});

router.delete('/moderation/reviews/:id', adminAuthRequired, async (req, res) => {
  await deleteModerated(prisma.productReview, req.params.id, res, '评价不存在');
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
    // 门槛金额是数字字段，下单只认它；condition 只给人看
    minAmount: c.minAmount == null ? 0 : Number(c.minAmount),
    couponType: c.couponType ?? 'fixed',
    totalQuantity: c.totalQuantity ?? null,
    issuedCount: c.issuedCount ?? 0,
    perUserLimit: c.perUserLimit ?? 1,
    claimStartAt: c.claimStartAt ? c.claimStartAt.toISOString().slice(0, 10) : null,
    scope: c.scope ?? 'all',
    scopeValue: c.scopeValue ?? null,
    claimType: c.claimType ?? null,
    expireAt: c.expireAt.toISOString().slice(0, 10),
  };
}

// 后台保存券时取门槛：传了数字就用数字，没传就从 condition 文字里兜底解析一次（和服务端老兜底同口径）
function resolveCouponMinAmount(body) {
  if (body.minAmount != null && body.minAmount !== '') {
    const value = Number(body.minAmount);
    return Number.isFinite(value) && value >= 0 ? value : 0;
  }
  const match = String(body.condition ?? '').match(/满(\d+(?:\.\d+)?)/);
  return match ? Number(match[1]) : 0;
}

function readCouponExtraFields(body) {
  return {
    minAmount: resolveCouponMinAmount(body),
    couponType: body.couponType ? String(body.couponType) : undefined,
    totalQuantity:
      body.totalQuantity != null && body.totalQuantity !== '' ? Math.max(0, Math.trunc(Number(body.totalQuantity)) || 0) || null : undefined,
    perUserLimit:
      body.perUserLimit != null && body.perUserLimit !== '' ? Math.max(1, Math.trunc(Number(body.perUserLimit)) || 1) : undefined,
    claimStartAt: body.claimStartAt ? new Date(body.claimStartAt) : undefined,
    scope: body.scope ? String(body.scope) : undefined,
    scopeValue: body.scopeValue !== undefined ? (body.scopeValue ? String(body.scopeValue) : null) : undefined,
    claimType: body.claimType !== undefined ? (body.claimType ? String(body.claimType) : null) : undefined,
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
      data: {
        id,
        title,
        discount,
        condition,
        expireAt,
        ...Object.fromEntries(
          Object.entries(readCouponExtraFields(body)).filter(([, v]) => v !== undefined),
        ),
        issuedCount: 0,
      },
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
        // 改门槛时：body 没带 minAmount 且也没改 condition 就不动旧值，避免把门槛误清成解析值
        ...(body.minAmount != null || body.condition != null
          ? { minAmount: resolveCouponMinAmount(body) }
          : {}),
        ...Object.fromEntries(
          Object.entries(readCouponExtraFields(body))
            .filter(([k, v]) => v !== undefined && k !== 'minAmount'),
        ),
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
      title: b.title ?? null,
      linkType: b.linkType ?? 'product',
      linkTarget: b.linkTarget ?? null,
      isActive: b.isActive ?? true,
      startsAt: b.startsAt ? b.startsAt.toISOString() : null,
      endsAt: b.endsAt ? b.endsAt.toISOString() : null,
    })),
  });
});

router.post('/banners', adminAuthRequired, async (req, res) => {
  const { imagePath, productId, sortOrder } = req.body ?? {};
  if (!imagePath || !productId) {
    fail(res, 400, '轮播图路径与关联商品不能为空');
    return;
  }
  const body = req.body ?? {};
  const banner = await prisma.banner.create({
    data: {
      imagePath: String(imagePath),
      productId: String(productId),
      sortOrder: Number(sortOrder ?? 0),
      title: body.title ? String(body.title) : null,
      linkType: body.linkType ? String(body.linkType) : 'product',
      linkTarget: body.linkTarget ? String(body.linkTarget) : null,
      isActive: body.isActive !== false,
      startsAt: body.startsAt ? new Date(body.startsAt) : null,
      endsAt: body.endsAt ? new Date(body.endsAt) : null,
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
      title: banner.title ?? null,
      linkType: banner.linkType ?? 'product',
      linkTarget: banner.linkTarget ?? null,
      isActive: banner.isActive ?? true,
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
        title: body.title !== undefined ? (body.title ? String(body.title) : null) : undefined,
        linkType: body.linkType ? String(body.linkType) : undefined,
        linkTarget: body.linkTarget !== undefined ? (body.linkTarget ? String(body.linkTarget) : null) : undefined,
        isActive: typeof body.isActive === 'boolean' ? body.isActive : undefined,
        startsAt: body.startsAt !== undefined ? (body.startsAt ? new Date(body.startsAt) : null) : undefined,
        endsAt: body.endsAt !== undefined ? (body.endsAt ? new Date(body.endsAt) : null) : undefined,
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
        title: banner.title ?? null,
        linkType: banner.linkType ?? 'product',
        linkTarget: banner.linkTarget ?? null,
        isActive: banner.isActive ?? true,
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

async function categoriesWithCounts() {
  const categories = readCategories();
  const counts = await Promise.all(
    categories.map((c) => prisma.product.count({ where: { majorCategory: c.name } })),
  );
  return categories.map((c, i) => ({ ...c, productCount: counts[i] }));
}

router.get('/categories', adminAuthRequired, async (_req, res) => {
  ok(res, { categories: await categoriesWithCounts() });
});

router.post('/categories', adminAuthRequired, async (req, res) => {
  try {
    const category = createCategory(req.body ?? {});
    const categories = await categoriesWithCounts();
    ok(res, { category: categories.find((c) => c.id === category.id) ?? category, categories });
  } catch (err) {
    if (err.message === 'NAME_REQUIRED') fail(res, 400, '分类名称不能为空');
    else if (err.message === 'NAME_TAKEN') fail(res, 400, '已存在同名分类');
    else fail(res, 400, '创建失败');
  }
});

router.put('/categories/:id', adminAuthRequired, async (req, res) => {
  try {
    const result = updateCategory(req.params.id, req.body ?? {});
    if (!result) {
      fail(res, 404, '分类不存在');
      return;
    }
    // 改名时把该分类下商品的大类一起改掉，避免商品失去分类
    if (result.renamedFrom) {
      await prisma.product.updateMany({
        where: { majorCategory: result.renamedFrom },
        data: { majorCategory: result.category.name },
      });
    }
    const categories = await categoriesWithCounts();
    ok(res, {
      category: categories.find((c) => c.id === result.category.id) ?? result.category,
      categories,
    });
  } catch (err) {
    if (err.message === 'NAME_REQUIRED') fail(res, 400, '分类名称不能为空');
    else if (err.message === 'NAME_TAKEN') fail(res, 400, '已存在同名分类');
    else fail(res, 400, '更新失败');
  }
});

router.delete('/categories/:id', adminAuthRequired, async (req, res) => {
  const categories = readCategories();
  const target = categories.find((c) => c.id === req.params.id);
  if (!target) {
    fail(res, 404, '分类不存在');
    return;
  }
  const productCount = await prisma.product.count({ where: { majorCategory: target.name } });
  if (productCount > 0) {
    fail(res, 400, `该分类下还有 ${productCount} 件商品，请先把商品移到其他分类再删除`);
    return;
  }
  deleteCategory(req.params.id);
  ok(res, { deleted: true });
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

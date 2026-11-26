import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';
import { log } from '../utils/log.js';
import { generateOrderNo, parseCouponMinAmount, serializeOrder } from '../utils/order.js';
import { getFlashPriceMap, resolvePromotionDiscount } from '../utils/promotions.js';
import { markWeeklyTaskDone } from '../utils/daily-tasks.js';
import { recordWalletLedger } from '../utils/wallet-ledger.js';
import { AFTER_SALE_TYPES } from '../utils/status-values.js';

// 购物返积分/返币的唯一口径（2026-11-26 hx 拍板）：只在付款时发——
// 创建待付款订单不发，免得建单发一次、付款再发一次（旧版双发实锤，
// 且建单那次只改余额不写流水，账还对不上）。
// 输入：total 实付金额、vipLevel 会员等级
// 输出：{ points, coins }——基础积分 = 实付向下取整（1 分起、100 封顶）；
// 会员（VIP2 起）积分 ×1.5（卡面权益做真，倍率后最高 150）；返币 = 基础
// 积分 ×2，不吃倍率（权益文案只承诺积分 ×1.5）。
function orderReward(total, vipLevel) {
  const base = Math.min(100, Math.max(1, Math.floor(Number(total) || 0)));
  const points = vipLevel >= 2 ? Math.round(base * 1.5) : base;
  return { points, coins: base * 2 };
}

// 库存与销量联动（付款时扣、取消已付订单时回）
// 输入：tx 事务、items（带 productId / quantity）、direction（pay 付款扣库存 / restore 取消回补）
// 坑：销量回补时不能减成负数，先读现值再算；库存扣减前必须先查够不够，不够整单失败、不能先扣一半
async function adjustStockAndSales(tx, items, direction) {
  for (const item of items) {
    const product = await tx.product.findUnique({ where: { id: item.productId } });
    if (!product) continue;
    if (direction === 'pay') {
      await tx.product.update({
        where: { id: item.productId },
        data: {
          stock: Math.max(0, product.stock - item.quantity),
          sales: product.sales + item.quantity,
        },
      });
    } else {
      await tx.product.update({
        where: { id: item.productId },
        data: {
          stock: product.stock + item.quantity,
          sales: Math.max(0, product.sales - item.quantity),
        },
      });
    }
  }
}

// 下单前的库存检查：返回第一件不满足的商品错误信息，全满足返回 null
async function checkStockAndShelf(products, items) {
  const map = new Map(products.map((x) => [x.id, x]));
  for (const item of items) {
    const product = map.get(item.productId);
    if (!product) return '商品不存在';
    if (product.isOnShelf === false) return `商品「${product.name}」已下架`;
    if ((product.stock ?? 0) < item.quantity) return `商品「${product.name}」库存不足`;
  }
  return null;
}

// 拼收货地址展示文字：新地址拆了省市区，订单快照仍存一整段文字，老 App 和后台都按整段读
function composeAddressDetail(address) {
  if (!address) return null;
  const parts = [address.province, address.city, address.district].filter(Boolean).join('');
  const detail = address.detail ?? '';
  if (parts && detail && !detail.startsWith(parts)) return parts + detail;
  return detail || parts || null;
}

const router = Router();

export async function buildLineItemsFromRequest(requestedItems) {
  const normalized = requestedItems
    .map((item) => ({
      productId: String(item?.productId ?? '').trim(),
      quantity: Math.max(1, Number(item?.quantity) || 1),
    }))
    .filter((item) => item.productId);

  if (normalized.length === 0) {
    return { error: { status: 400, message: '商品信息无效' } };
  }

  const products = await prisma.product.findMany({
    where: { id: { in: normalized.map((item) => item.productId) } },
  });
  const productMap = new Map(products.map((product) => [product.id, product]));
  // 限时特价：单价在组行时就换成特价，后面的小计、券门槛、满减门槛
  // 全部自然按特价口径走，不用在每个算钱的地方再想一次
  const flashMap = await getFlashPriceMap(normalized.map((item) => item.productId));

  const lineItems = [];
  for (const item of normalized) {
    const product = productMap.get(item.productId);
    if (!product) {
      return { error: { status: 400, message: '商品不存在' } };
    }
    // 直接下单也要查上架和库存（旧 bug：这条路径只查存不存在，下架和无库存都能买走）
    if (product.isOnShelf === false) {
      return { error: { status: 400, message: `商品「${product.name}」已下架` } };
    }
    if ((product.stock ?? 0) < item.quantity) {
      return { error: { status: 400, message: `商品「${product.name}」库存不足` } };
    }
    const unitPrice = flashMap.get(product.id)?.price ?? Number(product.price);
    lineItems.push({
      productId: product.id,
      name: product.name,
      quantity: item.quantity,
      spec: product.spec ?? '',
      imagePath: product.imagePath,
      majorCategory: product.majorCategory,
      unitPrice,
      subtotal: unitPrice * item.quantity,
    });
  }

  return { lineItems };
}

export async function resolveAddress(userId, addressId) {
  if (addressId) {
    return prisma.address.findFirst({ where: { id: addressId, userId } });
  }
  return prisma.address.findFirst({
    where: { userId, isDefault: true },
    orderBy: { updatedAt: 'desc' },
  });
}

// 下面三个函数除了下单路由自己用，小豆的办事工具（生成待付款订单）也 import 它们，
// 保证 Agent 下单与用户自己下单是同一套库存/地址/用券口径，不要在工具里另写一份。
export async function resolveDiscount(userId, couponTemplateId, subtotal, lineItems = []) {
  if (!couponTemplateId) return { discount: 0, templateId: null };

  const userCoupon = await prisma.userCoupon.findUnique({
    where: { userId_templateId: { userId, templateId: couponTemplateId } },
    include: { template: true },
  });
  if (!userCoupon || userCoupon.used) {
    return { error: { status: 400, message: '优惠券不可用' } };
  }
  if (userCoupon.template.expireAt && new Date() > userCoupon.template.expireAt) {
    return { error: { status: 400, message: '优惠券已过期' } };
  }

  // 门槛只认数字字段 minAmount；只有老数据 minAmount 还是 0 时，才兜底解析一次 condition 文字
  const fieldMin = userCoupon.template.minAmount == null ? 0 : Number(userCoupon.template.minAmount);
  const minAmount = fieldMin > 0 ? fieldMin : parseCouponMinAmount(userCoupon.template.condition);
  const discount = Number(userCoupon.template.discount);

  // 适用范围：scope 为 category / product 时，门槛按命中的那部分商品小计算，不再按整单算
  const scope = userCoupon.template.scope ?? 'all';
  let effectiveSubtotal = subtotal;
  if (scope === 'category' || scope === 'product') {
    const targets = String(userCoupon.template.scopeValue ?? '')
      .split(',')
      .map((x) => x.trim())
      .filter(Boolean);
    const matched = lineItems.filter((item) =>
      scope === 'category' ? targets.includes(item.majorCategory) : targets.includes(item.productId),
    );
    if (matched.length === 0) {
      return { error: { status: 400, message: '优惠券不适用于所选商品' } };
    }
    effectiveSubtotal = matched.reduce((sum, item) => sum + item.subtotal, 0);
  }

  if (effectiveSubtotal < minAmount) {
    return { error: { status: 400, message: `未满 ${minAmount} 元，无法使用该优惠券` } };
  }

  return { discount, templateId: couponTemplateId };
}

router.get('/', authRequired, async (req, res) => {
  const orders = await prisma.order.findMany({
    where: { userId: req.user.sub },
    include: { items: true, reviews: { select: { productId: true } } },
    orderBy: { createdAt: 'desc' },
  });
  ok(res, { orders: orders.map(serializeOrder) });
});

// 我的售后申请列表（必须写在 /:id 前面，不然 after-sales 会被当成订单 id）
router.get('/after-sales', authRequired, async (req, res) => {
  const rows = await prisma.afterSaleRequest.findMany({
    where: { userId: req.user.sub },
    orderBy: { createdAt: 'desc' },
    include: { order: { select: { orderNo: true, total: true } } },
  });
  ok(res, {
    requests: rows.map((r) => ({
      id: r.id,
      orderId: r.orderId,
      orderNo: r.order.orderNo,
      type: r.type,
      reason: r.reason,
      description: r.description,
      amount: r.amount == null ? null : Number(r.amount),
      status: r.status,
      adminNote: r.adminNote ?? null,
      createdAt: r.createdAt.toISOString(),
    })),
  });
});

// 申请售后：仅退款 refund / 退货退款 return；同一订单同时只能有一条待处理的
// 申请售后的核心逻辑：订单路由和小豆办事工具共用一份，规则只许有一处。
// 输入：userId、orderId、{ type, reason, description, amount }
// 输出：{ ok: true, request, order } 或 { ok: false, status, error }
// 坑：同一订单同时只能有一条待处理申请；金额为空 = 按实付全额退，审核时核定。
export async function createAfterSaleForUser(userId, orderId, input = {}) {
  const order = await prisma.order.findFirst({
    where: { id: orderId, userId },
  });
  if (!order) return { ok: false, status: 404, error: '订单不存在' };
  if (!['paid', 'shipping', 'completed'].includes(order.status)) {
    return { ok: false, status: 400, error: '当前订单状态不能申请售后' };
  }
  const type = AFTER_SALE_TYPES.includes(input.type) ? input.type : 'refund';
  const reason = String(input.reason ?? '').trim();
  if (!reason) return { ok: false, status: 400, error: '请填写售后原因' };
  const description = String(input.description ?? '').trim().slice(0, 500);
  const amountRaw = input.amount;
  const amount = amountRaw == null || amountRaw === '' ? null : Number(amountRaw);
  if (amount != null && (!Number.isFinite(amount) || amount <= 0)) {
    return { ok: false, status: 400, error: '退款金额不正确' };
  }
  const pending = await prisma.afterSaleRequest.findFirst({
    where: { orderId: order.id, userId, status: 'pending' },
  });
  if (pending) return { ok: false, status: 409, error: '该订单已有待处理的售后申请' };

  const row = await prisma.afterSaleRequest.create({
    data: { orderId: order.id, userId, type, reason, description, amount },
  });
  await prisma.notification.create({
    data: {
      userId,
      title: '售后申请已提交',
      body: `订单 ${order.orderNo} 的售后申请已提交，等待处理`,
      type: 'order',
      targetType: 'order',
      targetId: order.id,
    },
  });
  log.info('订单', `收到售后申请，订单 id ${orderId}，售后单 id ${row.id}`);
  return { ok: true, request: row, order };
}

router.post('/:id/after-sale', authRequired, async (req, res) => {
  const result = await createAfterSaleForUser(req.user.sub, req.params.id, req.body ?? {});
  if (!result.ok) return fail(res, result.status, result.error);
  const row = result.request;
  ok(res, { request: { id: row.id, status: row.status, type: row.type } });
});

router.get('/:id', authRequired, async (req, res) => {
  const order = await prisma.order.findFirst({
    where: { id: req.params.id, userId: req.user.sub },
    include: { items: true, reviews: { select: { productId: true } } },
  });
  if (!order) return fail(res, 404, '订单不存在');
  ok(res, { order: serializeOrder(order) });
});

router.post('/', authRequired, async (req, res) => {
  const addressId = String(req.body?.addressId ?? '').trim() || null;
  const couponTemplateId = String(req.body?.couponTemplateId ?? '').trim() || null;
  const payNow = req.body?.payNow !== false;
  const requestedLineItems = Array.isArray(req.body?.lineItems) ? req.body.lineItems : null;
  const partialCheckout = requestedLineItems != null && requestedLineItems.length > 0;

  let lineItems;
  if (partialCheckout) {
    const built = await buildLineItemsFromRequest(requestedLineItems);
    if (built.error) return fail(res, built.error.status, built.error.message);
    lineItems = built.lineItems;
  } else {
    const cartItems = await prisma.cartItem.findMany({
      where: { userId: req.user.sub },
      include: { product: true },
    });
    if (cartItems.length === 0) return fail(res, 400, '购物车为空');

    const stockError = await checkStockAndShelf(
      cartItems.map((item) => item.product),
      cartItems.map((item) => ({ productId: item.productId, quantity: item.quantity })),
    );
    if (stockError) return fail(res, 400, stockError);
    const flashMap = await getFlashPriceMap(cartItems.map((item) => item.productId));
    lineItems = cartItems.map((item) => {
      const unitPrice = flashMap.get(item.productId)?.price ?? Number(item.product.price);
      const subtotal = unitPrice * item.quantity;
      return {
        productId: item.productId,
        name: item.product.name,
        quantity: item.quantity,
        spec: item.spec || (item.product.spec ?? ''),
        imagePath: item.product.imagePath,
        majorCategory: item.product.majorCategory,
        unitPrice,
        subtotal,
      };
    });
  }

  const subtotal = lineItems.reduce((sum, item) => sum + item.subtotal, 0);
  // 会员等级这一单要用两次：95 折计价与付款时的积分倍率，开头查一次
  const buyerProfile = await prisma.userProfile.findUnique({
    where: { userId: req.user.sub },
    select: { vipLevel: true },
  });
  const vipLevel = buyerProfile?.vipLevel ?? 1;
  // 小豆代买（聊天卡片「立即购买」）会带 autoCoupon：没指定券时按工具代下单
  // 同一口径，把未用的券挨个用 resolveDiscount 试算、挑减得最多的一张。
  let chosenCouponTemplateId = couponTemplateId;
  if (!chosenCouponTemplateId && req.body?.autoCoupon === true) {
    const unusedCoupons = await prisma.userCoupon.findMany({
      where: { userId: req.user.sub, used: false },
      include: { template: true },
    });
    let bestDiscount = 0;
    for (const row of unusedCoupons) {
      if (row.template.expireAt && new Date() > row.template.expireAt) continue;
      const trial = await resolveDiscount(req.user.sub, row.templateId, subtotal, lineItems);
      if (!trial.error && (trial.discount ?? 0) > bestDiscount) {
        bestDiscount = trial.discount ?? 0;
        chosenCouponTemplateId = trial.templateId ?? null;
      }
    }
  }
  const discountResult = await resolveDiscount(req.user.sub, chosenCouponTemplateId, subtotal, lineItems);
  if (discountResult.error) {
    return fail(res, discountResult.error.status, discountResult.error.message);
  }
  const discount = discountResult?.discount ?? 0;
  // 满减：门槛按小计（已含特价）判，与券可叠加，单独记账到 promotionDiscount
  const promotion = await resolvePromotionDiscount(subtotal);
  // 会员 95 折（2026-11-26 做真）：VIP2 起，券与满减先减，剩下的商品款
  // 再打 95 折；单独记 memberDiscount 一列（订单详情能拆出这笔账），
  // 运费不打折。非会员为 0，计价与旧版完全一致。
  const memberBase = Math.max(0, subtotal - discount - promotion.amount);
  const memberDiscount = vipLevel >= 2 ? Math.round(memberBase * 0.05 * 100) / 100 : 0;
  // 运费：前端不传就是 0（包邮）；total 保持「最终实付」口径 = 小计 - 优惠 + 运费
  const freight = Math.max(0, Number(req.body?.freight) || 0);
  const remark = String(req.body?.remark ?? '').trim().slice(0, 200) || null;
  const total = Math.max(0, memberBase - memberDiscount + freight);

  const address = await resolveAddress(req.user.sub, addressId);
  if (!address) return fail(res, 400, '请先添加收货地址');

  const orderNo = generateOrderNo();
  const now = new Date();

  const order = await prisma.$transaction(async (tx) => {
    const created = await tx.order.create({
      data: {
        userId: req.user.sub,
        orderNo,
        status: payNow ? 'paid' : 'pending',
        subtotal,
        discount,
        promotionDiscount: promotion.amount,
        promotionName: promotion.name,
        memberDiscount,
        total,
        addressName: address.name,
        addressPhone: address.phone,
        addressDetail: composeAddressDetail(address),
        couponTemplateId: discountResult?.templateId ?? null,
        paymentMethod: payNow ? 'mock' : null,
        paymentStatus: payNow ? 'paid' : 'pending',
        paidAt: payNow ? now : null,
        freight,
        remark,
        items: {
          create: lineItems.map((item) => ({
            productId: item.productId,
            name: item.name,
            quantity: item.quantity,
            spec: item.spec ?? '',
            imagePath: item.imagePath ?? null,
            unitPrice: item.unitPrice,
            subtotal: item.subtotal,
          })),
        },
      },
      include: { items: true },
    });

    await tx.cartItem.deleteMany(
      partialCheckout
        ? {
            where: {
              userId: req.user.sub,
              productId: { in: lineItems.map((item) => item.productId) },
            },
          }
        : { where: { userId: req.user.sub } },
    );

    if (discountResult?.templateId) {
      await tx.userCoupon.update({
        where: {
          userId_templateId: {
            userId: req.user.sub,
            templateId: discountResult.templateId,
          },
        },
        // 用券要留下使用时间和订单号，客服查账靠它
        data: { used: true, usedAt: now, orderId: created.id },
      });
    }

    // 付款才动库存和销量：创建时已付款就立刻扣；待付款的等支付接口里再扣
    if (payNow) {
      await adjustStockAndSales(tx, lineItems, 'pay');
    }

    // 支付流水：每笔订单的支付动作单独落表，不再只靠订单上的 paymentMethod 文字
    await tx.paymentTransaction.create({
      data: {
        orderId: created.id,
        userId: req.user.sub,
        method: 'mock',
        transactionNo: `MOCK${now.getTime()}${created.orderNo}`,
        amount: total,
        status: payNow ? 'paid' : 'pending',
        paidAt: payNow ? now : null,
      },
    });

    // 导购推荐结果回填：买了小豆推荐过的商品，把那条推荐记录标成 ordered（失败不挡下单）
    try {
      await tx.guideRecommendation.updateMany({
        where: {
          userId: req.user.sub,
          productId: { in: lineItems.map((item) => item.productId) },
          outcome: { in: ['recommended', 'clicked'] },
        },
        data: { outcome: 'ordered' },
      });
    } catch {
      // 推荐记录是统计用途，写不上不回滚订单
    }

    await tx.notification.create({
      data: {
        userId: req.user.sub,
        title: payNow ? '下单成功' : '待付款订单',
        body: payNow
          ? `订单 ${orderNo} 已支付，预计 2-3 天送达`
          : `订单 ${orderNo} 待支付，请尽快完成付款`,
        type: 'order',
        targetType: 'order',
        targetId: created.id,
      },
    });

    // 积分/返币只在付款时发（2026-11-26 hx 拍板修双发）：payNow 的单创建
    // 即已付，在这里发；待付款单这里不发，等 /pay 支付成功再发。
    if (payNow) {
      const reward = orderReward(total, vipLevel);
      await tx.userProfile.upsert({
        where: { userId: req.user.sub },
        create: {
          userId: req.user.sub,
          points: reward.points,
          funCoins: reward.coins,
        },
        update: {
          points: { increment: reward.points },
          funCoins: { increment: reward.coins },
        },
      });
      await recordWalletLedger(tx, {
        userId: req.user.sub,
        walletType: 'points',
        amount: reward.points,
        title: '购物返积分',
        refType: 'order',
        refId: created.id,
      });
      await recordWalletLedger(tx, {
        userId: req.user.sub,
        walletType: 'coins',
        amount: reward.coins,
        title: '购物返币',
        refType: 'order',
        refId: created.id,
      });
    }

    return created;
  });

  if (payNow) await markWeeklyTaskDone(req.user.sub, 'weeklyOrderDone');
  log.info('订单', `创建订单成功，订单号 ${order.orderNo}，应付 ¥${order.total}${payNow ? '，已直接支付' : '，待付款'}`);
  ok(res, { order: serializeOrder(order) });
});

router.post('/:id/pay', authRequired, async (req, res) => {
  const order = await prisma.order.findFirst({
    where: { id: req.params.id, userId: req.user.sub },
    include: { items: true },
  });
  if (!order) return fail(res, 404, '订单不存在');
  if (order.status !== 'pending') return fail(res, 409, '订单状态不可支付');

  // 支付前再查一次库存：下单到付款之间可能被买空，查不过就整笔支付失败、不要扣一半
  const payProducts = await prisma.product.findMany({
    where: { id: { in: order.items.map((item) => item.productId) } },
  });
  const payStockError = await checkStockAndShelf(payProducts, order.items);
  if (payStockError) return fail(res, 400, payStockError);

  const updated = await prisma.$transaction(async (tx) => {
    const next = await tx.order.update({
      where: { id: order.id },
      data: {
        status: 'paid',
        paymentMethod: 'mock',
        paymentStatus: 'paid',
        paidAt: new Date(),
      },
      include: { items: true },
    });

    await tx.paymentTransaction.create({
      data: {
        orderId: order.id,
        userId: req.user.sub,
        method: 'mock',
        transactionNo: `MOCK${Date.now()}${order.orderNo}`,
        amount: order.total,
        status: 'paid',
        paidAt: new Date(),
      },
    });

    // 付款才发积分/返币（与创建路由共用 orderReward 口径，会员积分 ×1.5）
    const payerProfile = await tx.userProfile.findUnique({
      where: { userId: req.user.sub },
      select: { vipLevel: true },
    });
    const reward = orderReward(order.total, payerProfile?.vipLevel ?? 1);
    await tx.userProfile.upsert({
      where: { userId: req.user.sub },
      create: { userId: req.user.sub, points: reward.points, funCoins: reward.coins },
      update: { points: { increment: reward.points }, funCoins: { increment: reward.coins } },
    });
    await recordWalletLedger(tx, {
      userId: req.user.sub,
      walletType: 'points',
      amount: reward.points,
      title: '购物返积分',
      refType: 'order',
      refId: order.id,
    });
    await recordWalletLedger(tx, {
      userId: req.user.sub,
      walletType: 'coins',
      amount: reward.coins,
      title: '购物返币',
      refType: 'order',
      refId: order.id,
    });

    await adjustStockAndSales(tx, order.items, 'pay');

    return next;
  });

  await markWeeklyTaskDone(req.user.sub, 'weeklyOrderDone');
  log.info('订单', `订单支付成功，订单号 ${updated.orderNo ?? updated.id}`);
  ok(res, { order: serializeOrder(updated) });
});

// 取消订单的核心逻辑：订单路由和小豆办事工具共用一份，规则只许有一处。
// 输入：userId、orderId、reason（可空）
// 输出：{ ok: true, order, wasPaid } 或 { ok: false, status, error }
// 坑：只有已付款订单取消时才回补库存销量——待付款订单根本没扣过，
// 回补会把库存越加越多（路由老口径，别改）。
export async function cancelOrderForUser(userId, orderId, reason) {
  const order = await prisma.order.findFirst({
    where: { id: orderId, userId },
    include: { items: true },
  });
  if (!order) return { ok: false, status: 404, error: '订单不存在' };
  if (!['pending', 'paid'].includes(order.status)) {
    return { ok: false, status: 409, error: '当前状态不可取消' };
  }

  const cancelReason = String(reason ?? '').trim().slice(0, 200) || null;
  const wasPaid = order.paymentStatus === 'paid';
  const updated = await prisma.$transaction(async (tx) => {
    const next = await tx.order.update({
      where: { id: order.id },
      data: {
        status: 'cancelled',
        cancelledAt: new Date(),
        cancelReason,
        // 已付款订单取消后支付状态标成 refunded（模拟支付即时退回）；未付款的不动
        paymentStatus: wasPaid ? 'refunded' : order.paymentStatus,
      },
      include: { items: true },
    });
    // 已付款才回补库存和销量；待付款订单没扣过，不能回补（会把库存越加越多）
    if (wasPaid) {
      await adjustStockAndSales(tx, order.items, 'restore');
      await tx.paymentTransaction.updateMany({
        where: { orderId: order.id, status: 'paid' },
        data: { status: 'refunded' },
      });
    }
    return next;
  });
  log.info('订单', `订单已取消，订单号 ${updated.orderNo ?? updated.id}`);
  return { ok: true, order: updated, wasPaid };
}

router.put('/:id/cancel', authRequired, async (req, res) => {
  const result = await cancelOrderForUser(req.user.sub, req.params.id, req.body?.reason);
  if (!result.ok) return fail(res, result.status, result.error);
  ok(res, { order: serializeOrder(result.order) });
});

router.put('/:id/confirm', authRequired, async (req, res) => {
  const order = await prisma.order.findFirst({
    where: { id: req.params.id, userId: req.user.sub },
    include: { items: true },
  });
  if (!order) return fail(res, 404, '订单不存在');
  if (order.status !== 'shipping') return fail(res, 409, '当前状态不可确认收货');

  const updated = await prisma.order.update({
    where: { id: order.id },
    data: { status: 'completed', receivedAt: new Date() },
    include: { items: true },
  });
  log.info('订单', `用户确认收货，订单号 ${updated.orderNo ?? updated.id}`);
  ok(res, { order: serializeOrder(updated) });
});

export default router;

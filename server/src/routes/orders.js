import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';
import { generateOrderNo, parseCouponMinAmount, serializeOrder } from '../utils/order.js';
import { recordWalletLedger } from '../utils/wallet-ledger.js';

const router = Router();

async function buildLineItemsFromRequest(requestedItems) {
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

  const lineItems = [];
  for (const item of normalized) {
    const product = productMap.get(item.productId);
    if (!product) {
      return { error: { status: 400, message: '商品不存在或已下架' } };
    }
    const unitPrice = Number(product.price);
    lineItems.push({
      productId: product.id,
      name: product.name,
      quantity: item.quantity,
      spec: product.spec,
      unitPrice,
      subtotal: unitPrice * item.quantity,
    });
  }

  return { lineItems };
}

async function resolveAddress(userId, addressId) {
  if (addressId) {
    return prisma.address.findFirst({ where: { id: addressId, userId } });
  }
  return prisma.address.findFirst({
    where: { userId, isDefault: true },
    orderBy: { updatedAt: 'desc' },
  });
}

async function resolveDiscount(userId, couponTemplateId, subtotal) {
  if (!couponTemplateId) return { discount: 0, templateId: null };

  const userCoupon = await prisma.userCoupon.findUnique({
    where: { userId_templateId: { userId, templateId: couponTemplateId } },
    include: { template: true },
  });
  if (!userCoupon || userCoupon.used) {
    return { error: { status: 400, message: '优惠券不可用' } };
  }

  const minAmount = parseCouponMinAmount(userCoupon.template.condition);
  const discount = Number(userCoupon.template.discount);
  if (subtotal < minAmount) {
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

    lineItems = cartItems.map((item) => {
      const unitPrice = Number(item.product.price);
      const subtotal = unitPrice * item.quantity;
      return {
        productId: item.productId,
        name: item.product.name,
        quantity: item.quantity,
        spec: item.spec ?? item.product.spec,
        unitPrice,
        subtotal,
      };
    });
  }

  const subtotal = lineItems.reduce((sum, item) => sum + item.subtotal, 0);
  const discountResult = await resolveDiscount(req.user.sub, couponTemplateId, subtotal);
  if (discountResult.error) {
    return fail(res, discountResult.error.status, discountResult.error.message);
  }
  const discount = discountResult?.discount ?? 0;
  const total = Math.max(0, subtotal - discount);

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
        total,
        addressName: address.name,
        addressPhone: address.phone,
        addressDetail: address.detail,
        couponTemplateId: discountResult?.templateId ?? null,
        paymentMethod: payNow ? 'mock' : null,
        paymentStatus: payNow ? 'paid' : 'pending',
        paidAt: payNow ? now : null,
        items: {
          create: lineItems.map((item) => ({
            productId: item.productId,
            name: item.name,
            quantity: item.quantity,
            spec: item.spec,
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
        data: { used: true },
      });
    }

    for (const item of lineItems) {
      if (payNow) {
        await tx.product.update({
          where: { id: item.productId },
          data: { sales: { increment: item.quantity } },
        });
      }
    }

    await tx.notification.create({
      data: {
        userId: req.user.sub,
        title: payNow ? '下单成功' : '待付款订单',
        body: payNow
          ? `订单 ${orderNo} 已支付，预计 2-3 天送达`
          : `订单 ${orderNo} 待支付，请尽快完成付款`,
        type: 'order',
      },
    });

    const earned = Math.min(100, Math.max(1, Math.floor(total)));
    const coinEarned = earned * 2;
    await tx.userProfile.upsert({
      where: { userId: req.user.sub },
      create: {
        userId: req.user.sub,
        points: earned,
        funCoins: coinEarned,
      },
      update: {
        points: { increment: earned },
        funCoins: { increment: coinEarned },
      },
    });

    if (payNow) {
      await recordWalletLedger(tx, {
        userId: req.user.sub,
        walletType: 'points',
        amount: earned,
        title: '购物返积分',
      });
      await recordWalletLedger(tx, {
        userId: req.user.sub,
        walletType: 'coins',
        amount: coinEarned,
        title: '购物返币',
      });
    }

    return created;
  });

  ok(res, { order: serializeOrder(order) });
});

router.post('/:id/pay', authRequired, async (req, res) => {
  const order = await prisma.order.findFirst({
    where: { id: req.params.id, userId: req.user.sub },
    include: { items: true },
  });
  if (!order) return fail(res, 404, '订单不存在');
  if (order.status !== 'pending') return fail(res, 409, '订单状态不可支付');

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

    const earned = Math.min(100, Math.max(1, Math.floor(Number(order.total))));
    const coinEarned = earned * 2;
    await tx.userProfile.upsert({
      where: { userId: req.user.sub },
      create: { userId: req.user.sub, points: earned, funCoins: coinEarned },
      update: { points: { increment: earned }, funCoins: { increment: coinEarned } },
    });
    await recordWalletLedger(tx, {
      userId: req.user.sub,
      walletType: 'points',
      amount: earned,
      title: '购物返积分',
    });
    await recordWalletLedger(tx, {
      userId: req.user.sub,
      walletType: 'coins',
      amount: coinEarned,
      title: '购物返币',
    });

    for (const item of order.items) {
      await tx.product.update({
        where: { id: item.productId },
        data: { sales: { increment: item.quantity } },
      });
    }

    return next;
  });

  ok(res, { order: serializeOrder(updated) });
});

router.put('/:id/cancel', authRequired, async (req, res) => {
  const order = await prisma.order.findFirst({
    where: { id: req.params.id, userId: req.user.sub },
    include: { items: true },
  });
  if (!order) return fail(res, 404, '订单不存在');
  if (!['pending', 'paid'].includes(order.status)) {
    return fail(res, 409, '当前状态不可取消');
  }

  const updated = await prisma.order.update({
    where: { id: order.id },
    data: { status: 'cancelled' },
    include: { items: true },
  });
  ok(res, { order: serializeOrder(updated) });
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
    data: { status: 'completed' },
    include: { items: true },
  });
  ok(res, { order: serializeOrder(updated) });
});

export default router;

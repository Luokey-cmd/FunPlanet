import { formatChinaDateTime } from './datetime.js';

export function parseCouponMinAmount(condition) {
  const match = String(condition ?? '').match(/满(\d+(?:\.\d+)?)/);
  return match ? Number(match[1]) : 0;
}

export function generateOrderNo() {
  return `QW${Date.now().toString().slice(-10)}`;
}

export function formatOrderTime(date) {
  return formatChinaDateTime(date);
}

export function serializeOrder(order) {
  const reviewedProductIds = (order.reviews ?? []).map((r) => r.productId);
  return {
    id: order.id,
    orderNo: order.orderNo,
    items: order.items.map((item) => ({
      productId: item.productId,
      name: item.name,
      quantity: item.quantity,
      spec: item.spec ?? '',
      // 商品图快照：下单时抄的主图，老订单展示用它，不再跟着商品现图变
      imagePath: item.imagePath ?? null,
      unitPrice: Number(item.unitPrice),
      subtotal: Number(item.subtotal),
    })),
    subtotal: Number(order.subtotal),
    discount: Number(order.discount),
    // 运费单独给出：total 是含运费的最终实付，freight 让前端能把运费拆出来显示
    freight: order.freight == null ? 0 : Number(order.freight),
    total: Number(order.total),
    status: order.status,
    time: formatOrderTime(order.createdAt),
    address: order.addressName
      ? {
          name: order.addressName,
          phone: order.addressPhone,
          detail: order.addressDetail,
        }
      : null,
    paymentMethod: order.paymentMethod,
    paymentStatus: order.paymentStatus,
    // 物流与备注：没发货 / 没留言时就是 null，前端按空处理
    remark: order.remark ?? null,
    shippingCompany: order.shippingCompany ?? null,
    trackingNo: order.trackingNo ?? null,
    shippedAt: order.shippedAt ? order.shippedAt.toISOString() : null,
    receivedAt: order.receivedAt ? order.receivedAt.toISOString() : null,
    cancelledAt: order.cancelledAt ? order.cancelledAt.toISOString() : null,
    cancelReason: order.cancelReason ?? null,
    reviewedProductIds,
  };
}

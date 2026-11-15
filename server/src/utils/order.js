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
      spec: item.spec,
      unitPrice: Number(item.unitPrice),
      subtotal: Number(item.subtotal),
    })),
    subtotal: Number(order.subtotal),
    discount: Number(order.discount),
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
    reviewedProductIds,
  };
}

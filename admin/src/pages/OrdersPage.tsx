import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { DownloadIcon, SearchIcon, XIcon } from "lucide-react";
import { toast } from "sonner";
import { adminApi } from "../lib/api";

const statusMap: Record<string, { label: string; color: string }> = {
  pending: { label: "待付款", color: "#ffb74d" },
  paid: { label: "已付款", color: "#4cb9d6" },
  shipping: { label: "配送中", color: "#2e9bb8" },
  completed: { label: "已完成", color: "#66bb6a" },
  returned: { label: "已退货", color: "#e57373" },
  cancelled: { label: "已退货", color: "#e57373" },
};

const summaryCards = [
  { key: "all", label: "全部", color: "#4cb9d6" },
  { key: "pending", label: "待付款", color: "#ffb74d" },
  { key: "paid", label: "已付款", color: "#7ec8de" },
  { key: "shipping", label: "配送中", color: "#2e9bb8" },
  { key: "completed", label: "已完成", color: "#66bb6a" },
  { key: "returned", label: "已退货", color: "#e57373" },
] as const;

const statusFilters = [
  { label: "全部", value: "" },
  { label: "待付款", value: "pending" },
  { label: "已付款", value: "paid" },
  { label: "配送中", value: "shipping" },
  { label: "已完成", value: "completed" },
  { label: "已退货", value: "returned" },
];

function isReturnedStatus(status: string) {
  return status === "returned" || status === "cancelled";
}

function OrderActionButton({
  status,
  disabled,
  onAction,
}: {
  status: string;
  disabled: boolean;
  onAction: (nextStatus: string, message: string) => void;
}) {
  if (status === "paid") {
    return (
      <button
        type="button"
        disabled={disabled}
        onClick={() => onAction("shipping", "是否确认发货？")}
        className="text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground font-medium hover:opacity-90 disabled:opacity-50"
      >
        发货
      </button>
    );
  }

  if (status === "shipping") {
    return (
      <button
        type="button"
        disabled={disabled}
        onClick={() => onAction("completed", "是否确认送达？")}
        className="text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground font-medium hover:opacity-90 disabled:opacity-50"
      >
        确认送达
      </button>
    );
  }

  if (status === "completed") {
    return (
      <button
        type="button"
        disabled
        className="text-xs px-3 py-1.5 rounded-lg bg-muted text-muted-foreground font-medium cursor-not-allowed"
      >
        已完成
      </button>
    );
  }

  if (isReturnedStatus(status)) {
    return (
      <button
        type="button"
        disabled
        className="text-xs px-3 py-1.5 rounded-lg bg-muted text-muted-foreground font-medium cursor-not-allowed"
      >
        已退货
      </button>
    );
  }

  return <span className="text-xs text-muted-foreground">—</span>;
}

// 订单详情弹窗：金额拆分、收货信息、商品明细快照、物流与时间线、关联售后一屏看全
function OrderDetailModal({ orderId, onClose }: { orderId: string; onClose: () => void }) {
  const { data, isLoading } = useQuery({
    queryKey: ["admin-order-detail", orderId],
    queryFn: () => adminApi.orderDetail(orderId),
  });

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  const o = data?.order;
  const row = (label: string, value: React.ReactNode) => (
    <div className="flex gap-3 py-1.5">
      <span className="text-xs text-muted-foreground w-20 shrink-0 pt-0.5">{label}</span>
      <span className="text-sm text-foreground flex-1">{value || "—"}</span>
    </div>
  );

  return (
    <div
      className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4"
      onClick={onClose}
    >
      <div
        className="bg-card rounded-2xl shadow-custom w-full max-w-2xl max-h-[88vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-6 py-4 border-b border-border sticky top-0 bg-card">
          <h3 className="text-base font-semibold text-foreground">订单详情</h3>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg hover:bg-accent text-muted-foreground"
            aria-label="关闭"
          >
            <XIcon size={16} />
          </button>
        </div>
        {isLoading || !o ? (
          <p className="p-8 text-center text-muted-foreground">加载中…</p>
        ) : (
          <div className="px-6 py-4 flex flex-col gap-5">
            <div>
              {row("订单号", <span className="font-mono text-xs">{o.orderNo}</span>)}
              {row("状态", `${o.statusLabel}（支付：${o.paymentStatus}）`)}
              {row("买家", `${o.user} · ${o.phone}`)}
              {row("下单时间", o.date)}
              {o.paidAt && row("付款时间", o.paidAt)}
            </div>

            <div className="border-t border-border pt-3">
              <p className="text-xs font-semibold text-muted-foreground mb-1">商品明细</p>
              {o.items.map((i) => (
                <div key={i.id} className="flex items-center gap-3 py-2">
                  {i.imagePath ? (
                    <img src={i.imagePath} alt="" className="w-10 h-10 rounded-lg object-cover border border-border" />
                  ) : (
                    <div className="w-10 h-10 rounded-lg bg-muted" />
                  )}
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-foreground truncate">{i.name}</p>
                    {i.spec && <p className="text-xs text-muted-foreground">规格：{i.spec}</p>}
                  </div>
                  <span className="text-sm text-muted-foreground">¥{i.unitPrice} × {i.quantity}</span>
                  <span className="text-sm font-medium text-foreground w-20 text-right">¥{i.subtotal}</span>
                </div>
              ))}
              <div className="border-t border-border mt-2 pt-2">
                {row("商品总额", `¥${o.subtotal}`)}
                {row("优惠", o.discount > 0 ? `-¥${o.discount}` : "¥0")}
                {row("运费", o.freight > 0 ? `¥${o.freight}` : "包邮")}
                {row("实付", <span className="font-semibold">¥{o.amount}</span>)}
              </div>
            </div>

            <div className="border-t border-border pt-3">
              <p className="text-xs font-semibold text-muted-foreground mb-1">收货与物流</p>
              {row("收货人", `${o.addressName} · ${o.addressPhone}`)}
              {row("收货地址", o.address)}
              {o.remark && row("买家备注", o.remark)}
              {row("物流", o.trackingNo ? `${o.shippingCompany ? `${o.shippingCompany} ` : ""}${o.trackingNo}` : "未发货")}
              {o.shippedAt && row("发货时间", o.shippedAt)}
              {o.receivedAt && row("收货时间", o.receivedAt)}
              {o.cancelReason && row("取消原因", o.cancelReason)}
            </div>

            {o.afterSales.length > 0 && (
              <div className="border-t border-border pt-3">
                <p className="text-xs font-semibold text-muted-foreground mb-1">售后记录</p>
                {o.afterSales.map((r) => (
                  <div key={r.id} className="py-1.5">
                    <p className="text-sm text-foreground">
                      {r.type === "return" ? "退货退款" : "仅退款"} · {r.reason}
                      <span className="text-xs text-muted-foreground ml-2">
                        {r.date} ·{" "}
                        {{ pending: "待处理", approved: "已同意", rejected: "已拒绝", completed: "已完成" }[r.status] ?? r.status}
                      </span>
                    </p>
                    {r.description && <p className="text-xs text-muted-foreground">{r.description}</p>}
                    {r.adminNote && <p className="text-xs text-muted-foreground">处理备注：{r.adminNote}</p>}
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

export default function OrdersPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [detailOrderId, setDetailOrderId] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);

  const handleExport = async () => {
    setExporting(true);
    try {
      await adminApi.exportOrders({
        status: statusFilter || undefined,
        keyword: search || undefined,
      });
      toast.success("订单已导出为 CSV");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "导出失败");
    } finally {
      setExporting(false);
    }
  };

  const { data, isLoading } = useQuery({
    queryKey: ["admin-orders", search, statusFilter],
    queryFn: () =>
      adminApi.orders({
        keyword: search || undefined,
        status: statusFilter || undefined,
      }),
  });

  const { data: allData } = useQuery({
    queryKey: ["admin-orders-all"],
    queryFn: () => adminApi.orders(),
  });

  const updateMutation = useMutation({
    mutationFn: ({
      id,
      status,
      shippingCompany,
      trackingNo,
    }: {
      id: string;
      status: string;
      shippingCompany?: string;
      trackingNo?: string;
    }) => adminApi.updateOrderStatus(id, status, { shippingCompany, trackingNo }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-orders"] });
      queryClient.invalidateQueries({ queryKey: ["admin-orders-all"] });
      queryClient.invalidateQueries({ queryKey: ["admin-dashboard"] });
      toast.success("订单状态已更新");
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const orders = data?.orders ?? [];
  const allOrders = allData?.orders ?? orders;
  const counts = {
    all: allOrders.length,
    pending: allOrders.filter((o) => o.status === "pending").length,
    paid: allOrders.filter((o) => o.status === "paid").length,
    shipping: allOrders.filter((o) => o.status === "shipping").length,
    completed: allOrders.filter((o) => o.status === "completed").length,
    returned: allOrders.filter((o) => isReturnedStatus(o.status)).length,
  };

  const handleAction = (orderId: string, nextStatus: string, confirmMessage: string) => {
    if (updateMutation.isPending) return;
    if (!window.confirm(confirmMessage)) return;
    // 发货时顺手把物流公司和单号填了，一起存进订单（用户在 App 里能查到包裹）
    if (nextStatus === "shipping") {
      const shippingCompany = window.prompt("物流公司（可留空）：", "") ?? "";
      const trackingNo = window.prompt("快递单号（可留空）：", "") ?? "";
      updateMutation.mutate({
        id: orderId,
        status: nextStatus,
        shippingCompany: shippingCompany || undefined,
        trackingNo: trackingNo || undefined,
      });
      return;
    }
    updateMutation.mutate({ id: orderId, status: nextStatus });
  };

  return (
    <div data-cmp="OrdersPage" className="p-6 flex flex-col gap-5">
      <div>
        <h2 className="text-lg font-semibold text-foreground">订单管理</h2>
        <p className="text-sm text-muted-foreground">共 {orders.length} 条订单</p>
      </div>

      <div className="flex gap-3 flex-wrap">
        {summaryCards.map((item) => (
          <div key={item.key} className="flex-1 min-w-[100px] rounded-2xl p-4 border border-border bg-card shadow-custom">
            <p className="text-xs text-muted-foreground mb-1">{item.label}</p>
            <p className="text-2xl font-bold" style={{ color: item.color }}>
              {counts[item.key]}
            </p>
          </div>
        ))}
      </div>

      <div className="flex items-center gap-3 flex-wrap">
        <div className="relative">
          <SearchIcon size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <input
            type="text"
            placeholder="搜索订单……"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9 pr-4 py-2 text-sm bg-card border border-border rounded-xl focus:outline-none focus:ring-2 focus:ring-ring w-56"
          />
        </div>
        <div className="flex gap-2 flex-wrap">
          {statusFilters.map((s) => (
            <button
              key={s.label}
              type="button"
              onClick={() => setStatusFilter(s.value)}
              className={`text-xs px-3 py-2 rounded-xl transition-colors font-medium ${
                statusFilter === s.value
                  ? "bg-primary text-primary-foreground"
                  : "bg-card border border-border text-muted-foreground hover:bg-accent"
              }`}
            >
              {s.label}
            </button>
          ))}
        </div>
        <button
          type="button"
          onClick={handleExport}
          disabled={exporting}
          className="ml-auto inline-flex items-center gap-1.5 text-xs px-3.5 py-2 rounded-xl bg-card border border-border text-foreground font-medium hover:bg-accent disabled:opacity-60"
        >
          <DownloadIcon size={14} />
          {exporting ? "导出中…" : "导出 CSV"}
        </button>
      </div>

      <div className="bg-card rounded-2xl border border-border shadow-custom overflow-hidden">
        {isLoading ? (
          <p className="p-8 text-center text-muted-foreground">加载中…</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-border bg-muted/50">
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">订单号</th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">买家</th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">商品</th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">金额</th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">状态</th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">下单时间</th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">操作</th>
                </tr>
              </thead>
              <tbody>
                {orders.map((order, idx) => {
                  const st = statusMap[order.status] ?? { label: order.statusLabel, color: "#8bb4c4" };
                  return (
                    <tr
                      key={order.id}
                      className={`border-b border-border last:border-0 hover:bg-muted/30 transition-colors ${
                        idx % 2 === 0 ? "" : "bg-muted/10"
                      }`}
                    >
                      <td className="px-5 py-4 text-xs font-mono text-muted-foreground">{order.orderNo}</td>
                      <td className="px-5 py-4">
                        <p className="text-sm font-medium text-foreground">{order.user}</p>
                        <p className="text-xs text-muted-foreground">{order.phone}</p>
                      </td>
                      <td className="px-5 py-4">
                        <p className="text-xs text-muted-foreground max-w-48 truncate">{order.products}</p>
                        {order.trackingNo && (
                          <p className="text-xs text-muted-foreground mt-0.5">
                            {order.shippingCompany ? `${order.shippingCompany} ` : ""}{order.trackingNo}
                          </p>
                        )}
                        {order.remark && (
                          <p className="text-xs text-muted-foreground mt-0.5 max-w-48 truncate" title={order.remark}>
                            备注：{order.remark}
                          </p>
                        )}
                      </td>
                      <td className="px-5 py-4 text-sm font-semibold text-foreground">¥{order.amount}</td>
                      <td className="px-5 py-4">
                        <span
                          className="text-xs px-2.5 py-1 rounded-full font-medium"
                          style={{ color: st.color, backgroundColor: `${st.color}22` }}
                        >
                          {st.label}
                        </span>
                      </td>
                      <td className="px-5 py-4 text-xs text-muted-foreground">{order.date}</td>
                      <td className="px-5 py-4">
                        <div className="flex items-center gap-2">
                          <button
                            type="button"
                            onClick={() => setDetailOrderId(order.id)}
                            className="text-xs px-3 py-1.5 rounded-lg border border-border text-foreground font-medium hover:bg-accent"
                          >
                            详情
                          </button>
                          <OrderActionButton
                            status={order.status}
                            disabled={updateMutation.isPending}
                            onAction={(nextStatus, message) => handleAction(order.id, nextStatus, message)}
                          />
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {detailOrderId && (
        <OrderDetailModal orderId={detailOrderId} onClose={() => setDetailOrderId(null)} />
      )}
    </div>
  );
}

import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { SearchIcon } from "lucide-react";
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

export default function OrdersPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("");

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
    mutationFn: ({ id, status }: { id: string; status: string }) => adminApi.updateOrderStatus(id, status),
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
                        <OrderActionButton
                          status={order.status}
                          disabled={updateMutation.isPending}
                          onAction={(nextStatus, message) => handleAction(order.id, nextStatus, message)}
                        />
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { adminApi, type AdminAfterSale } from "../lib/api";

// 售后处理页：数据来自独立的售后表（AfterSaleRequest），不再拿订单的「已取消」冒充售后。
// 处理动作：待处理 → 已同意 / 已拒绝；已同意 → 已完成（完成时服务端会把支付状态标成已退款）。

const statusFilters = [
  { label: "全部", value: "" },
  { label: "待处理", value: "pending" },
  { label: "已同意", value: "approved" },
  { label: "已拒绝", value: "rejected" },
  { label: "已完成", value: "completed" },
];

const statusLabel: Record<string, string> = {
  pending: "待处理",
  approved: "已同意",
  rejected: "已拒绝",
  completed: "已完成",
};

export default function AfterSalesPage() {
  const queryClient = useQueryClient();
  const [statusFilter, setStatusFilter] = useState("");

  const { data, isLoading } = useQuery({
    queryKey: ["admin-after-sales", statusFilter],
    queryFn: () => adminApi.afterSales(statusFilter || undefined),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, status, adminNote }: { id: string; status: string; adminNote?: string }) =>
      adminApi.updateAfterSaleStatus(id, { status, adminNote }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-after-sales"] });
      toast.success("售后状态已更新，已通知用户");
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const handleAction = (row: AdminAfterSale, status: string) => {
    const verb = status === "approved" ? "同意" : status === "rejected" ? "拒绝" : "完成";
    if (!window.confirm(`确定要${verb}这条售后申请吗？`)) return;
    const adminNote = window.prompt("处理备注（可留空，会展示给用户）：", "") ?? "";
    updateMutation.mutate({ id: row.id, status, adminNote: adminNote || undefined });
  };

  const requests = data?.requests ?? [];

  return (
    <div data-cmp="AfterSalesPage" className="p-6 flex flex-col gap-5">
      <div>
        <h2 className="text-lg font-semibold text-foreground">售后处理</h2>
        <p className="text-sm text-muted-foreground">共 {requests.length} 条申请</p>
      </div>

      <div className="flex gap-2 flex-wrap">
        {statusFilters.map((s) => (
          <button
            key={s.value}
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

      <div className="bg-card rounded-2xl border border-border shadow-custom overflow-hidden">
        {isLoading ? (
          <p className="p-8 text-center text-muted-foreground">加载中…</p>
        ) : requests.length === 0 ? (
          <p className="p-8 text-center text-muted-foreground">暂无售后申请</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-border bg-muted/50">
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">订单 / 用户</th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">类型 / 原因</th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">退款金额</th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">状态</th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">申请时间</th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">操作</th>
                </tr>
              </thead>
              <tbody>
                {requests.map((row) => (
                  <tr key={row.id} className="border-b border-border last:border-0 hover:bg-muted/30">
                    <td className="px-5 py-4">
                      <p className="text-sm font-medium text-foreground">{row.orderNo}</p>
                      <p className="text-xs text-muted-foreground">
                        {row.user} · {row.phone}
                      </p>
                    </td>
                    <td className="px-5 py-4">
                      <p className="text-sm text-foreground">{row.type === "return" ? "退货退款" : "仅退款"}</p>
                      <p className="text-xs text-muted-foreground max-w-[220px] truncate" title={row.description || row.reason}>
                        {row.reason}
                        {row.description ? `：${row.description}` : ""}
                      </p>
                    </td>
                    <td className="px-5 py-4 text-sm text-foreground">
                      {row.amount != null ? `¥${row.amount}` : `¥${row.orderTotal}（全额）`}
                    </td>
                    <td className="px-5 py-4">
                      <span className="text-xs px-2.5 py-1 rounded-lg bg-secondary text-secondary-foreground font-medium">
                        {statusLabel[row.status] ?? row.status}
                      </span>
                      {row.adminNote && (
                        <p className="text-xs text-muted-foreground mt-1 max-w-[160px] truncate" title={row.adminNote}>
                          {row.adminNote}
                        </p>
                      )}
                    </td>
                    <td className="px-5 py-4 text-sm text-muted-foreground whitespace-nowrap">{row.date}</td>
                    <td className="px-5 py-4">
                      <div className="flex gap-2">
                        {row.status === "pending" && (
                          <>
                            <button
                              onClick={() => handleAction(row, "approved")}
                              disabled={updateMutation.isPending}
                              className="text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground font-medium disabled:opacity-60"
                            >
                              同意
                            </button>
                            <button
                              onClick={() => handleAction(row, "rejected")}
                              disabled={updateMutation.isPending}
                              className="text-xs px-3 py-1.5 rounded-lg border border-border text-muted-foreground font-medium disabled:opacity-60"
                            >
                              拒绝
                            </button>
                          </>
                        )}
                        {row.status === "approved" && (
                          <button
                            onClick={() => handleAction(row, "completed")}
                            disabled={updateMutation.isPending}
                            className="text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground font-medium disabled:opacity-60"
                          >
                            完成退款
                          </button>
                        )}
                        {(row.status === "rejected" || row.status === "completed") && (
                          <span className="text-xs text-muted-foreground">—</span>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

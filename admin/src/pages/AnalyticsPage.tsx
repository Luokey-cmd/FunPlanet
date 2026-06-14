import { useQuery } from "@tanstack/react-query";
import RevenueChart from "../components/RevenueChart";
import CategoryPieChart from "../components/CategoryPieChart";
import { adminApi } from "../lib/api";

export default function AnalyticsPage() {
  const { data, isLoading } = useQuery({
    queryKey: ["admin-dashboard"],
    queryFn: () => adminApi.dashboard(),
  });

  if (isLoading) {
    return <div className="p-6 text-muted-foreground">加载中…</div>;
  }

  return (
    <div data-cmp="AnalyticsPage" className="p-6 flex flex-col gap-6">
      <div>
        <h2 className="text-lg font-semibold text-foreground">营收分析</h2>
        <p className="text-sm text-muted-foreground">多维度数据可视化分析</p>
      </div>

      <RevenueChart data={data?.revenueTrend} />

      <div className="flex gap-4 flex-wrap">
        <div className="flex-[1_1_400px] min-w-0">
          <CategoryPieChart data={data?.categoryStats} />
        </div>
        <div className="flex-[1_1_400px] min-w-0 bg-card rounded-2xl p-5 border border-border shadow-custom">
          <h3 className="font-semibold text-foreground mb-4">核心指标</h3>
          <div className="grid grid-cols-2 gap-4">
            {[
              { label: "总营收", value: `¥${(data?.stats.totalRevenue ?? 0).toLocaleString()}`, color: "#4cb9d6" },
              { label: "总订单", value: data?.stats.totalOrders ?? 0, color: "#7ec8de" },
              { label: "注册用户", value: data?.stats.totalUsers ?? 0, color: "#2e9bb8" },
              { label: "待处理订单", value: data?.stats.pendingOrders ?? 0, color: "#5bc0de" },
            ].map((item) => (
              <div key={item.label} className="rounded-xl bg-muted p-4">
                <p className="text-xs text-muted-foreground">{item.label}</p>
                <p className="text-xl font-bold mt-1" style={{ color: item.color }}>
                  {item.value}
                </p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

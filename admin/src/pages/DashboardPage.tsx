import { useQuery } from "@tanstack/react-query";
import StatCard from "../components/StatCard";
import RevenueChart from "../components/RevenueChart";
import CategoryPieChart from "../components/CategoryPieChart";
import RecentOrders from "../components/RecentOrders";
import TopProducts from "../components/TopProducts";
import { adminApi } from "../lib/api";

export default function DashboardPage() {
  const { data, isLoading, isError } = useQuery({
    queryKey: ["admin-dashboard"],
    queryFn: () => adminApi.dashboard(),
  });

  if (isLoading) {
    return (
      <div className="p-6 text-muted-foreground" data-cmp="DashboardPage">
        加载中…
      </div>
    );
  }

  if (isError || !data) {
    return (
      <div className="p-6 text-destructive" data-cmp="DashboardPage">
        数据加载失败，请确认后端已启动
      </div>
    );
  }

  const { stats, revenueTrend, categoryStats, recentOrders, topProducts } = data;

  return (
    <div data-cmp="DashboardPage" className="p-6 flex flex-col gap-6">
      <div className="flex gap-4 flex-wrap">
        <div className="flex-1 min-w-[200px]">
          <StatCard title="总营收" value={stats.totalRevenue} growth={0} icon="💰" color="#4cb9d6" prefix="¥" />
        </div>
        <div className="flex-1 min-w-[200px]">
          <StatCard title="总订单数" value={stats.totalOrders} growth={0} icon="📦" color="#7ec8de" />
        </div>
        <div className="flex-1 min-w-[200px]">
          <StatCard title="注册用户" value={stats.totalUsers} growth={0} icon="👥" color="#2e9bb8" />
        </div>
        <div className="flex-1 min-w-[200px]">
          <StatCard title="商品总数" value={stats.totalProducts} growth={0} icon="🛍️" color="#5bc0de" />
        </div>
      </div>

      <div className="flex gap-4 flex-wrap">
        <div className="flex-[2_1_400px] min-w-0">
          <RevenueChart data={revenueTrend} />
        </div>
        <div className="flex-[1_1_280px] min-w-0">
          <CategoryPieChart data={categoryStats} />
        </div>
      </div>

      <div className="flex gap-4 flex-wrap">
        <div className="flex-[1_1_320px] min-w-0">
          <TopProducts products={topProducts} />
        </div>
        <div className="flex-[2_1_480px] min-w-0">
          <RecentOrders orders={recentOrders} />
        </div>
      </div>
    </div>
  );
}

import { useQuery } from "@tanstack/react-query";
import StatCard from "../components/StatCard";
import RevenueChart from "../components/RevenueChart";
import CategoryPieChart from "../components/CategoryPieChart";
import ProvinceHeatMap from "../components/ProvinceHeatMap";
import RecentOrders from "../components/RecentOrders";
import ConversionFunnel from "../components/ConversionFunnel";
import ActivityTrendChart from "../components/ActivityTrendChart";
import SeriesRanking from "../components/SeriesRanking";
import TopProducts from "../components/TopProducts";
import { adminApi } from "../lib/api";
import type { NavPage } from "../types";

interface DashboardPageProps {
  onNavigate?: (page: NavPage) => void;
}

export default function DashboardPage({ onNavigate }: DashboardPageProps) {
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

  const { stats, revenueTrend, categoryStats, regionHeat = [], recentOrders, topProducts, funnel = [], dailyActivity = [], seriesRanking = [] } = data;

  return (
    <div data-cmp="DashboardPage" className="p-6 flex flex-col gap-6">
      <div className="flex gap-4 flex-wrap">
        <div className="flex-1 min-w-[200px]">
          <StatCard
            title="总营收"
            value={stats.totalRevenue}
            growth={0}
            iconSrc="/images/dashboard-icon-1.png"
            prefix="¥"
            onClick={onNavigate ? () => onNavigate("analytics") : undefined}
          />
        </div>
        <div className="flex-1 min-w-[200px]">
          <StatCard
            title="总订单数"
            value={stats.totalOrders}
            growth={0}
            iconSrc="/images/dashboard-icon-2.png"
            onClick={onNavigate ? () => onNavigate("orders") : undefined}
          />
        </div>
        <div className="flex-1 min-w-[200px]">
          <StatCard
            title="注册用户"
            value={stats.totalUsers}
            growth={0}
            iconSrc="/images/dashboard-icon-3.png"
            onClick={onNavigate ? () => onNavigate("users") : undefined}
          />
        </div>
        <div className="flex-1 min-w-[200px]">
          <StatCard
            title="商品总数"
            value={stats.totalProducts}
            growth={0}
            iconSrc="/images/dashboard-icon-4.png"
            onClick={onNavigate ? () => onNavigate("products") : undefined}
          />
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

      <div className="flex gap-4 flex-wrap items-stretch">
        <div className="flex-1 min-w-[280px] basis-[48%]">
          <ConversionFunnel data={funnel} />
        </div>
        <div className="flex-1 min-w-[280px] basis-[48%]">
          <SeriesRanking data={seriesRanking} />
        </div>
      </div>

      <ActivityTrendChart data={dailyActivity} />

      <div className="flex gap-4 flex-wrap items-stretch">
        <div className="flex-1 min-w-[280px] basis-[48%]">
          <ProvinceHeatMap data={regionHeat} />
        </div>
        <div className="flex-1 min-w-[280px] basis-[48%]">
          <TopProducts products={topProducts} />
        </div>
      </div>

      <RecentOrders orders={recentOrders} />
    </div>
  );
}

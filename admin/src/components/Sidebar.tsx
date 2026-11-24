import {
  LayoutDashboardIcon,
  PackageIcon,
  ShoppingCartIcon,
  UsersIcon,
  TrendingUpIcon,
  SettingsIcon,
  TicketIcon,
  MegaphoneIcon,
  WalletIcon,
  ImageIcon,
  ScrollTextIcon,
  HeadphonesIcon,
  FolderTreeIcon,
  ShieldCheckIcon,
  ShieldAlertIcon,
  HistoryIcon,
} from "lucide-react";
import type { NavPage } from "../types";
import type { AdminRole } from "../lib/api";
import { canAccess } from "../lib/permissions";

interface SidebarProps {
  activePage?: NavPage;
  onNavigate?: (page: NavPage) => void;
  role?: AdminRole;
}

const navItems: { key: NavPage; label: string; icon: React.ReactNode }[] = [
  { key: "dashboard", label: "数据看板", icon: <LayoutDashboardIcon size={15} /> },
  { key: "analytics", label: "营收分析", icon: <TrendingUpIcon size={15} /> },
  { key: "products", label: "商品管理", icon: <PackageIcon size={15} /> },
  { key: "categories", label: "分类管理", icon: <FolderTreeIcon size={15} /> },
  { key: "orders", label: "订单管理", icon: <ShoppingCartIcon size={15} /> },
  { key: "afterSales", label: "售后处理", icon: <HistoryIcon size={15} /> },
  { key: "moderation", label: "内容审核", icon: <ShieldAlertIcon size={15} /> },
  { key: "users", label: "用户管理", icon: <UsersIcon size={15} /> },
  { key: "coupons", label: "优惠券管理", icon: <TicketIcon size={15} /> },
  { key: "marketing", label: "营销中心", icon: <MegaphoneIcon size={15} /> },
  { key: "finance", label: "财务账单", icon: <WalletIcon size={15} /> },
  { key: "banners", label: "轮播图管理", icon: <ImageIcon size={15} /> },
  { key: "support", label: "客服中心", icon: <HeadphonesIcon size={15} /> },
  { key: "changelog", label: "更新日志", icon: <ScrollTextIcon size={15} /> },
  { key: "admins", label: "管理员管理", icon: <ShieldCheckIcon size={15} /> },
  { key: "audit", label: "操作日志", icon: <HistoryIcon size={15} /> },
  { key: "settings", label: "系统设置", icon: <SettingsIcon size={15} /> },
];

export default function Sidebar({
  activePage = "dashboard",
  onNavigate = () => {},
  role = "super",
}: SidebarProps) {
  const visibleItems = navItems.filter((item) => canAccess(role, item.key));
  return (
    <div
      data-cmp="Sidebar"
      className="flex flex-col h-screen w-[188px] flex-shrink-0 bg-sidebar border-r border-sidebar-border"
    >
      <div className="flex items-center gap-2 px-3 py-3.5 border-b border-sidebar-border">
        <img
          src="/assets/icon/app_icon.png"
          alt="趣玩星球"
          className="w-9 h-9 rounded-lg object-cover flex-shrink-0"
        />
        <span className="font-bold text-sm text-foreground whitespace-nowrap">趣玩星球</span>
      </div>

      <nav className="flex-1 py-2.5 px-2 flex flex-col gap-0.5 overflow-y-auto">
        {visibleItems.map((item) => {
          const isActive = activePage === item.key;
          return (
            <button
              key={item.key}
              onClick={() => onNavigate(item.key)}
              className={`flex items-center gap-2 px-2.5 py-1.5 rounded-lg text-[13px] font-medium transition-colors w-full text-left ${
                isActive
                  ? "bg-primary text-primary-foreground shadow-custom"
                  : "text-muted-foreground hover:bg-sidebar-accent hover:text-foreground"
              }`}
            >
              <span className="flex-shrink-0">{item.icon}</span>
              <span className="whitespace-nowrap">{item.label}</span>
            </button>
          );
        })}
      </nav>

      <div className="mt-auto px-0.5 pb-0.5 pt-1 flex items-end justify-start">
        <img
          src="/images/trend-brand-icon.png"
          alt="潮流品牌"
          className="w-[148px] h-auto object-contain select-none pointer-events-none drop-shadow-sm -ml-0.5"
        />
      </div>
    </div>
  );
}

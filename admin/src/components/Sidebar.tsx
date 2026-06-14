import {
  LayoutDashboardIcon,
  PackageIcon,
  ShoppingCartIcon,
  UsersIcon,
  TrendingUpIcon,
  SettingsIcon,
  LogOutIcon,
  TicketIcon,
  ImageIcon,
  ScrollTextIcon,
  HeadphonesIcon,
} from "lucide-react";
import type { NavPage } from "../types";

interface SidebarProps {
  activePage?: NavPage;
  onNavigate?: (page: NavPage) => void;
  onLogout?: () => void;
}

const navItems: { key: NavPage; label: string; icon: React.ReactNode }[] = [
  { key: "dashboard", label: "数据看板", icon: <LayoutDashboardIcon size={18} /> },
  { key: "analytics", label: "营收分析", icon: <TrendingUpIcon size={18} /> },
  { key: "products", label: "商品管理", icon: <PackageIcon size={18} /> },
  { key: "orders", label: "订单管理", icon: <ShoppingCartIcon size={18} /> },
  { key: "users", label: "用户管理", icon: <UsersIcon size={18} /> },
  { key: "coupons", label: "优惠券管理", icon: <TicketIcon size={18} /> },
  { key: "banners", label: "轮播图管理", icon: <ImageIcon size={18} /> },
  { key: "support", label: "客服中心", icon: <HeadphonesIcon size={18} /> },
  { key: "changelog", label: "更新日志", icon: <ScrollTextIcon size={18} /> },
  { key: "settings", label: "系统设置", icon: <SettingsIcon size={18} /> },
];

export default function Sidebar({
  activePage = "dashboard",
  onNavigate = () => {},
  onLogout = () => {},
}: SidebarProps) {
  return (
    <div
      data-cmp="Sidebar"
      className="flex flex-col h-screen w-[220px] flex-shrink-0 bg-sidebar border-r border-sidebar-border"
    >
      <div className="flex items-center gap-2.5 px-4 py-5 border-b border-sidebar-border min-h-16">
        <img
          src="/assets/icon/app_icon.png"
          alt="趣玩星球"
          className="w-[2.8rem] h-[2.8rem] rounded-xl object-cover flex-shrink-0"
        />
        <span className="font-bold text-base text-foreground whitespace-nowrap">趣玩星球</span>
      </div>

      <nav className="flex-1 py-4 px-2 flex flex-col gap-1 overflow-y-auto">
        {navItems.map((item) => {
          const isActive = activePage === item.key;
          return (
            <button
              key={item.key}
              onClick={() => onNavigate(item.key)}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-colors w-full text-left ${
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

      <div className="px-2 pb-4 border-t border-sidebar-border pt-4">
        <button
          onClick={onLogout}
          className="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm text-muted-foreground hover:bg-sidebar-accent hover:text-foreground transition-colors w-full"
        >
          <LogOutIcon size={18} className="flex-shrink-0" />
          <span className="whitespace-nowrap">退出登录</span>
        </button>
      </div>
    </div>
  );
}

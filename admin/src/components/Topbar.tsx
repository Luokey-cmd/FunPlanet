import { useEffect, useRef, useState } from "react";
import {
  BellIcon,
  ChevronDownIcon,
  LogOutIcon,
  UserCogIcon,
} from "lucide-react";
import type { NavPage } from "../types";
import type { Notification } from "../types";
import SunMoonToggle from "./SunMoonToggle";
import AdminAvatar from "./AdminAvatar";

const pageTitles: Record<NavPage, string> = {
  dashboard: "数据看板",
  analytics: "营收分析",
  products: "商品管理",
  orders: "订单管理",
  users: "用户管理",
  coupons: "优惠券管理",
  banners: "轮播图管理",
  changelog: "更新日志",
  support: "客服中心",
  settings: "系统设置",
};

interface TopbarProps {
  activePage?: NavPage;
  adminName?: string;
  adminUsername?: string;
  adminAvatarPath?: string | null;
  adminRole?: string;
  notifications?: Notification[];
  onNavigate?: (page: NavPage) => void;
  onNotificationClick?: (notification: Notification) => void;
  onLogout?: () => void;
}

export default function Topbar({
  activePage = "dashboard",
  adminName = "管理员",
  adminUsername = "admin",
  adminAvatarPath = null,
  adminRole = "超级管理员",
  notifications = [],
  onNavigate = () => {},
  onNotificationClick,
  onLogout = () => {},
}: TopbarProps) {
  const [showNotif, setShowNotif] = useState(false);
  const [showMenu, setShowMenu] = useState(false);
  const notifRef = useRef<HTMLDivElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const unread = notifications.filter((n) => !n.read).length;

  useEffect(() => {
    const onDocClick = (e: MouseEvent) => {
      if (notifRef.current && !notifRef.current.contains(e.target as Node)) {
        setShowNotif(false);
      }
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setShowMenu(false);
      }
    };
    document.addEventListener("mousedown", onDocClick);
    return () => document.removeEventListener("mousedown", onDocClick);
  }, []);

  const openSettings = () => {
    setShowMenu(false);
    onNavigate("settings");
  };

  const handleLogout = () => {
    setShowMenu(false);
    onLogout();
  };

  return (
    <div data-cmp="Topbar" className="h-16 bg-card border-b border-border flex items-center px-6 gap-4 flex-shrink-0">
      <div className="flex-1">
        <h1 className="text-lg font-semibold text-foreground">{pageTitles[activePage]}</h1>
        <p className="text-xs text-muted-foreground">欢迎回来，趣玩星球管理后台</p>
      </div>

      <div className="relative" ref={notifRef}>
        <button
          type="button"
          onClick={() => {
            setShowNotif(!showNotif);
            setShowMenu(false);
          }}
          className="relative w-9 h-9 rounded-xl bg-muted flex items-center justify-center hover:bg-accent transition-colors"
        >
          <BellIcon size={18} className="text-muted-foreground" />
          {unread > 0 && (
            <span className="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-destructive text-destructive-foreground text-xs flex items-center justify-center">
              {unread}
            </span>
          )}
        </button>

        <div
          className={`absolute right-0 top-12 w-80 bg-card rounded-2xl border border-border shadow-custom z-50 transition-all duration-200 ${
            showNotif ? "opacity-100 translate-y-0" : "opacity-0 -translate-y-2 pointer-events-none"
          }`}
        >
          <div className="px-4 py-3 border-b border-border flex items-center justify-between">
            <span className="font-semibold text-sm">消息通知</span>
            <span className="text-xs text-muted-foreground">{unread} 条未读</span>
          </div>
          <div className="max-h-72 overflow-y-auto">
            {notifications.length === 0 ? (
              <p className="px-4 py-8 text-sm text-muted-foreground text-center">暂无通知</p>
            ) : (
              notifications.map((n) => (
                <button
                  key={n.id}
                  type="button"
                  onClick={() => {
                    onNotificationClick?.(n);
                    setShowNotif(false);
                  }}
                  className={`w-full text-left px-4 py-3 border-b border-border last:border-0 hover:bg-muted transition-colors ${
                    !n.read ? "bg-secondary/30" : ""
                  }`}
                >
                  <p className="text-sm text-foreground leading-relaxed">{n.message}</p>
                  <p className="text-xs text-muted-foreground mt-1">{n.time}</p>
                </button>
              ))
            )}
          </div>
        </div>
      </div>

      <SunMoonToggle />

      <div className="relative pl-4 border-l border-border" ref={menuRef}>
        <button
          type="button"
          onClick={() => {
            setShowMenu(!showMenu);
            setShowNotif(false);
          }}
          className="flex items-center gap-3 rounded-xl px-2 py-1.5 hover:bg-muted transition-colors"
        >
          <AdminAvatar avatarPath={adminAvatarPath} name={adminName} size="sm" />
          <div className="hidden sm:block text-left">
            <p className="text-sm font-medium text-foreground leading-tight">{adminName}</p>
            <p className="text-xs text-muted-foreground">{adminRole}</p>
          </div>
          <ChevronDownIcon
            size={14}
            className={`text-muted-foreground transition-transform ${showMenu ? "rotate-180" : ""}`}
          />
        </button>

        <div
          className={`absolute right-0 top-12 w-56 bg-card rounded-2xl border border-border shadow-custom z-50 overflow-hidden transition-all duration-200 ${
            showMenu ? "opacity-100 translate-y-0" : "opacity-0 -translate-y-2 pointer-events-none"
          }`}
        >
          <div className="px-4 py-3 border-b border-border bg-muted/30">
            <p className="text-sm font-semibold text-foreground">{adminName}</p>
            <p className="text-xs text-muted-foreground mt-0.5">账号 {adminUsername}</p>
          </div>
          <div className="py-1">
            <button
              type="button"
              onClick={openSettings}
              className="w-full flex items-center gap-3 px-4 py-2.5 text-sm text-foreground hover:bg-muted transition-colors text-left"
            >
              <UserCogIcon size={16} className="text-muted-foreground" />
              账户信息
            </button>
          </div>
          <div className="border-t border-border py-1">
            <button
              type="button"
              onClick={handleLogout}
              className="w-full flex items-center gap-3 px-4 py-2.5 text-sm text-destructive hover:bg-destructive/10 transition-colors text-left"
            >
              <LogOutIcon size={16} />
              退出登录
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

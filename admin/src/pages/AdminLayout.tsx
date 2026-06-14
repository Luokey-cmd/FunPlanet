import { useState } from "react";

import { useQuery } from "@tanstack/react-query";

import Sidebar from "../components/Sidebar";

import Topbar from "../components/Topbar";

import { useAuth } from "../contexts/AuthContext";

import { adminApi } from "../lib/api";

import AnalyticsPage from "./AnalyticsPage";

import BannersPage from "./BannersPage";

import CouponsPage from "./CouponsPage";

import DashboardPage from "./DashboardPage";

import OrdersPage from "./OrdersPage";

import ProductsPage from "./ProductsPage";

import ChangelogPage from "./ChangelogPage";

import SettingsPage from "./SettingsPage";

import SupportPage from "./SupportPage";

import UsersPage from "./UsersPage";

import type { NavPage, Notification } from "../types";



function formatNotifTime(iso: string) {

  const d = new Date(iso);

  const now = new Date();

  const diffMs = now.getTime() - d.getTime();

  if (diffMs < 60_000) return "刚刚";

  if (diffMs < 3_600_000) return `${Math.floor(diffMs / 60_000)} 分钟前`;

  if (diffMs < 86_400_000) return `${Math.floor(diffMs / 3_600_000)} 小时前`;

  return d.toLocaleString("zh-CN", { month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit" });

}



export default function AdminLayout() {

  const { admin, logout } = useAuth();

  const [activePage, setActivePage] = useState<NavPage>("dashboard");

  const [supportConversationId, setSupportConversationId] = useState<string | null>(null);



  const notificationsQuery = useQuery({

    queryKey: ["admin-support-notifications"],

    queryFn: () => adminApi.supportNotifications(),

    refetchInterval: 5000,

  });



  const notifications: Notification[] = (notificationsQuery.data?.notifications ?? []).map((n) => ({

    id: n.id,

    message: n.message,

    time: formatNotifTime(n.time),

    read: n.read,

    conversationId: n.conversationId,

  }));



  const handleNotificationClick = (notification: Notification) => {

    if (notification.conversationId) {

      setSupportConversationId(notification.conversationId);

    }

    setActivePage("support");

  };



  return (

    <div className="flex h-screen overflow-hidden bg-background" data-cmp="AdminLayout">

      <Sidebar activePage={activePage} onNavigate={setActivePage} onLogout={logout} />

      <div className="flex flex-col flex-1 overflow-hidden">

        <Topbar

          activePage={activePage}

          adminName={admin?.name ?? "管理员"}

          adminUsername={admin?.username ?? "admin"}

          adminAvatarPath={admin?.avatarPath}

          adminRole="超级管理员"

          notifications={notifications}

          onNavigate={setActivePage}

          onNotificationClick={handleNotificationClick}

          onLogout={logout}

        />

        <main className="flex-1 overflow-y-auto">

          {activePage === "dashboard" && <DashboardPage />}

          {activePage === "analytics" && <AnalyticsPage />}

          {activePage === "products" && <ProductsPage />}

          {activePage === "orders" && <OrdersPage />}

          {activePage === "users" && <UsersPage />}

          {activePage === "coupons" && <CouponsPage />}

          {activePage === "banners" && <BannersPage />}

          {activePage === "support" && (

            <SupportPage

              initialConversationId={supportConversationId}

              onInitialConversationHandled={() => setSupportConversationId(null)}

            />

          )}

          {activePage === "changelog" && <ChangelogPage />}

          {activePage === "settings" && <SettingsPage />}

        </main>

      </div>

    </div>

  );

}


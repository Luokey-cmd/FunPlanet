import type { AdminRole } from "./api";
import type { NavPage } from "../types";

// 每个角色能进的页面：超级管理员全部；运营管理员除账号与日志外全部；
// 客服专员只保留看板、订单、用户与客服中心（外加改自己资料的系统设置）
export const PAGE_PERMISSIONS: Record<AdminRole, NavPage[]> = {
  super: [
    "dashboard",
    "analytics",
    "products",
    "categories",
    "orders",
    "afterSales",
    "users",
    "coupons",
    "banners",
    "support",
    "changelog",
    "admins",
    "audit",
    "settings",
  ],
  operator: [
    "dashboard",
    "analytics",
    "products",
    "categories",
    "orders",
    "afterSales",
    "users",
    "coupons",
    "banners",
    "support",
    "changelog",
    "settings",
  ],
  support: ["dashboard", "orders", "afterSales", "users", "support", "settings"],
};

export function canAccess(role: AdminRole | undefined, page: NavPage): boolean {
  return PAGE_PERMISSIONS[role ?? "super"].includes(page);
}

export type NavPage =
  | "dashboard"
  | "products"
  | "categories"
  | "afterSales"
  | "orders"
  | "users"
  | "analytics"
  | "coupons"
  | "banners"
  | "settings"
  | "changelog"
  | "admins"
  | "audit"
  | "support";

export interface Notification {
  id: string;
  message: string;
  time: string;
  read: boolean;
  conversationId?: string;
}

export interface StatCard {
  title: string;
  value: string | number;
  growth: number;
  icon: string;
  color: string;
}

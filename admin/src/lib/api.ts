const TOKEN_KEY = "funplanet_admin_token";

export function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string) {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
}

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
  ) {
    super(message);
  }
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = getToken();
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string> | undefined),
  };
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(`/api/admin${path}`, { ...options, headers });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new ApiError(json.message || "请求失败", res.status);
  }
  return json.data as T;
}

export const adminApi = {
  login: (username: string, password: string) =>
    request<{ token: string; admin: AdminInfo }>("/auth/login", {
      method: "POST",
      body: JSON.stringify({ username, password }),
    }),
  register: (body: { username: string; password: string; confirmPassword: string; name?: string }) =>
    request<{ token: string; admin: AdminInfo }>("/auth/register", {
      method: "POST",
      body: JSON.stringify(body),
    }),
  me: () => request<{ admin: AdminInfo }>("/auth/me"),
  dashboard: () => request<DashboardData>("/dashboard"),
  products: (params?: { keyword?: string; category?: string }) => {
    const q = new URLSearchParams();
    if (params?.keyword) q.set("keyword", params.keyword);
    if (params?.category) q.set("category", params.category);
    const qs = q.toString();
    return request<{ products: AdminProduct[] }>(`/products${qs ? `?${qs}` : ""}`);
  },
  createProduct: (body: Partial<AdminProduct> & { id: string; name: string }) =>
    request<{ product: AdminProduct }>("/products", { method: "POST", body: JSON.stringify(body) }),
  updateProduct: (id: string, body: Partial<AdminProduct>) =>
    request<{ product: AdminProduct }>(`/products/${id}`, { method: "PUT", body: JSON.stringify(body) }),
  deleteProduct: (id: string) => request<{ deleted: boolean }>(`/products/${id}`, { method: "DELETE" }),
  orders: (params?: { status?: string; keyword?: string }) => {
    const q = new URLSearchParams();
    if (params?.status) q.set("status", params.status);
    if (params?.keyword) q.set("keyword", params.keyword);
    const qs = q.toString();
    return request<{ orders: AdminOrder[] }>(`/orders${qs ? `?${qs}` : ""}`);
  },
  updateOrderStatus: (id: string, status: string) =>
    request(`/orders/${id}/status`, { method: "PATCH", body: JSON.stringify({ status }) }),
  users: (keyword?: string) => {
    const qs = keyword ? `?keyword=${encodeURIComponent(keyword)}` : "";
    return request<{ users: AdminUser[] }>(`/users${qs}`);
  },
  updateUserProfile: (id: string, body: { vipLevel?: number; points?: number; funCoins?: number }) =>
    request(`/users/${id}/profile`, { method: "PATCH", body: JSON.stringify(body) }),
  coupons: () => request<{ coupons: AdminCoupon[] }>("/coupons"),
  createCoupon: (body: AdminCouponCreate) =>
    request<{ coupon: AdminCoupon }>("/coupons", { method: "POST", body: JSON.stringify(body) }),
  updateCoupon: (id: string, body: AdminCouponCreate) =>
    request<{ coupon: AdminCoupon }>(`/coupons/${id}`, { method: "PUT", body: JSON.stringify(body) }),
  banners: () => request<{ banners: AdminBanner[] }>("/banners"),
  createBanner: (body: { imagePath: string; productId: string; sortOrder?: number }) =>
    request<{ banner: AdminBanner }>("/banners", { method: "POST", body: JSON.stringify(body) }),
  updateBanner: (id: string, body: Partial<AdminBanner>) =>
    request<{ banner: AdminBanner }>(`/banners/${id}`, { method: "PUT", body: JSON.stringify(body) }),
  deleteBanner: (id: string) => request<{ deleted: boolean }>(`/banners/${id}`, { method: "DELETE" }),
  settings: () => request<{ settings: AdminInfo }>("/settings"),
  updateProfile: (body: { displayName?: string; systemName?: string }) =>
    request<{ admin: AdminInfo }>("/settings/profile", { method: "PATCH", body: JSON.stringify(body) }),
  uploadAvatar: (body: { imageBase64: string; mimeType: string }) =>
    request<{ admin: AdminInfo }>("/settings/avatar", { method: "POST", body: JSON.stringify(body) }),
  uploadProductImage: (body: { imageBase64: string; mimeType: string }) =>
    request<{ imagePath: string }>("/upload/product-image", { method: "POST", body: JSON.stringify(body) }),
  uploadBannerImage: (body: { imageBase64: string; mimeType: string }) =>
    request<{ imagePath: string }>("/upload/banner-image", { method: "POST", body: JSON.stringify(body) }),
  changePassword: (body: { currentPassword: string; newPassword: string }) =>
    request<{ updated: boolean }>("/settings/password", { method: "POST", body: JSON.stringify(body) }),
  updateNotifications: (body: Partial<AdminNotifications>) =>
    request<{ notifications: AdminNotifications }>("/settings/notifications", {
      method: "PATCH",
      body: JSON.stringify(body),
    }),
  syncProductSales: () => request<{ synced: boolean }>("/settings/sync-sales", { method: "POST" }),
  dataSummary: () => request<{ summary: AdminDataSummary }>("/settings/data-summary"),
  changelog: () => request<{ entries: ChangelogEntry[] }>("/changelog"),
  createChangelog: (body: ChangelogInput) =>
    request<{ entry: ChangelogEntry }>("/changelog", { method: "POST", body: JSON.stringify(body) }),
  updateChangelog: (id: string, body: ChangelogInput) =>
    request<{ entry: ChangelogEntry }>(`/changelog/${id}`, { method: "PUT", body: JSON.stringify(body) }),
  deleteChangelog: (id: string) => request<{ deleted: boolean }>(`/changelog/${id}`, { method: "DELETE" }),
  supportNotifications: () =>
    request<{ notifications: AdminSupportNotification[] }>("/support/notifications"),
  supportConversations: (status?: string) => {
    const qs = status ? `?status=${encodeURIComponent(status)}` : "";
    return request<{ conversations: SupportConversation[] }>(`/support/conversations${qs}`);
  },
  supportMessages: (id: string, after?: string) => {
    const qs = after ? `?after=${encodeURIComponent(after)}` : "";
    return request<{ conversation: SupportConversation; messages: SupportMessage[] }>(
      `/support/conversations/${id}/messages${qs}`,
    );
  },
  sendSupportMessage: (
    id: string,
    payload: {
      content?: string;
      messageType?: "text" | "image" | "sticker";
      mediaUrl?: string;
      stickerId?: string;
    },
  ) =>
    request<{ message: SupportMessage; conversation: SupportConversation }>(
      `/support/conversations/${id}/messages`,
      { method: "POST", body: JSON.stringify(payload) },
    ),
  uploadSupportImage: (imageBase64: string, mimeType: string) =>
    request<{ mediaUrl: string }>("/support/upload", {
      method: "POST",
      body: JSON.stringify({ imageBase64, mimeType }),
    }),
  markSupportRead: (id: string) =>
    request<{ conversation: SupportConversation }>(`/support/conversations/${id}/read`, {
      method: "POST",
    }),
};

export interface AdminSupportNotification {
  id: string;
  conversationId: string;
  message: string;
  time: string;
  read: boolean;
  userNickname?: string;
  productName?: string | null;
}

export interface SupportConversation {
  id: string;
  userId: string;
  status: string;
  subject: string | null;
  productId: string | null;
  productName: string | null;
  lastMessageAt: string;
  lastMessagePreview: string | null;
  unreadAdmin: number;
  unreadUser: number;
  createdAt: string;
  userNickname: string | null;
  userPhone: string | null;
  userAvatarPath?: string | null;
}

export interface SupportMessage {
  id: string;
  conversationId: string;
  senderRole: "user" | "admin" | string;
  senderName: string | null;
  messageType: "text" | "image" | "sticker" | string;
  content: string;
  mediaUrl: string | null;
  stickerId: string | null;
  createdAt: string;
}

export interface AdminInfo {
  username: string;
  name: string;
  systemName?: string;
  avatarPath?: string | null;
  notifications?: AdminNotifications;
}

export interface AdminNotifications {
  orderNotify: boolean;
  userNotify: boolean;
  systemNotify: boolean;
}

export interface AdminDataSummary {
  products: number;
  users: number;
  orders: number;
  coupons: number;
  banners: number;
  totalRevenue: number;
  pendingOrders: number;
}

export type ChangelogTag = "feature" | "fix" | "improve";

export interface ChangelogEntry {
  id: string;
  version: string;
  title: string;
  date: string;
  tag: ChangelogTag;
  items: string[];
}

export interface ChangelogInput {
  version: string;
  title: string;
  date?: string;
  tag?: ChangelogTag;
  items: string[] | string;
}

export interface AdminProduct {
  id: string;
  name: string;
  nameEn: string;
  price: number;
  originalPrice: number | null;
  category: string;
  subCategory: string;
  majorCategory: string;
  tag: string | null;
  tagColor: string | null;
  spec: string | null;
  description: string;
  purchaseNotes: string;
  rating: number;
  sales: number;
  imagePath: string;
  favoriteCount?: number;
}

export interface AdminOrder {
  id: string;
  orderNo: string;
  user: string;
  phone: string;
  products: string;
  amount: number;
  status: string;
  statusLabel: string;
  paymentStatus: string;
  date: string;
  address: string;
}

export interface AdminUser {
  id: string;
  userId: string;
  name: string;
  phone: string;
  vipLevel: number;
  points: number;
  funCoins: number;
  orders: number;
  totalSpend: number;
  joinDate: string;
  status: string;
  avatarPath?: string | null;
}

export interface AdminCoupon {
  id: string;
  title: string;
  discount: number;
  condition: string;
  expireAt: string;
}

export interface AdminCouponCreate {
  title: string;
  discount: number;
  condition: string;
  expireAt: string;
}

export interface AdminBanner {
  id: string;
  imagePath: string;
  productId: string;
  productName: string;
  sortOrder: number;
}

export interface DashboardData {
  stats: {
    totalRevenue: number;
    totalOrders: number;
    totalUsers: number;
    totalProducts: number;
    pendingOrders: number;
  };
  revenueTrend: { day: string; revenue: number }[];
  categoryStats: { name: string; value: number; color: string }[];
  recentOrders: {
    id: string;
    user: string;
    products: string;
    amount: number;
    status: string;
    statusLabel: string;
    date: string;
    address: string;
  }[];
  topProducts: { id: string; name: string; sales: number; price: number; majorCategory: string }[];
}

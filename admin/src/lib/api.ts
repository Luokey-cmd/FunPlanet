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

// 订单导出走文件下载（响应是 CSV 不是 JSON），单独用 fetch 拿 blob 再触发浏览器下载
async function downloadOrdersCsv(params?: { status?: string; keyword?: string }): Promise<void> {
  const q = new URLSearchParams();
  if (params?.status) q.set("status", params.status);
  if (params?.keyword) q.set("keyword", params.keyword);
  const qs = q.toString();
  const token = getToken();
  const res = await fetch(`/api/admin/orders/export${qs ? `?${qs}` : ""}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  if (!res.ok) {
    const json = await res.json().catch(() => ({}));
    throw new ApiError(json.message || "导出失败", res.status);
  }
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `funplanet-orders-${new Date().toISOString().slice(0, 10)}.csv`;
  a.click();
  URL.revokeObjectURL(url);
}

async function downloadFinanceCsv(params?: { from?: string; to?: string }): Promise<void> {
  const q = new URLSearchParams();
  if (params?.from) q.set("from", params.from);
  if (params?.to) q.set("to", params.to);
  const qs = q.toString();
  const token = getToken();
  const res = await fetch(`/api/admin/finance/export${qs ? `?${qs}` : ""}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  if (!res.ok) {
    const json = await res.json().catch(() => ({}));
    throw new ApiError(json.message || "导出失败", res.status);
  }
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `funplanet-finance-${new Date().toISOString().slice(0, 10)}.csv`;
  a.click();
  URL.revokeObjectURL(url);
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
  toggleProductShelf: (id: string, isOnShelf: boolean) =>
    request<{ product: AdminProduct }>(`/products/${id}/shelf`, {
      method: "PATCH",
      body: JSON.stringify({ isOnShelf }),
    }),
  orders: (params?: { status?: string; keyword?: string }) => {
    const q = new URLSearchParams();
    if (params?.status) q.set("status", params.status);
    if (params?.keyword) q.set("keyword", params.keyword);
    const qs = q.toString();
    return request<{ orders: AdminOrder[] }>(`/orders${qs ? `?${qs}` : ""}`);
  },
  updateOrderStatus: (
    id: string,
    status: string,
    extra?: { shippingCompany?: string; trackingNo?: string },
  ) =>
    request(`/orders/${id}/status`, {
      method: "PATCH",
      body: JSON.stringify({ status, ...(extra ?? {}) }),
    }),
  orderDetail: (id: string) => request<{ order: AdminOrderDetail }>(`/orders/${id}`),
  exportOrders: downloadOrdersCsv,
  afterSales: (status?: string) => {
    const qs = status ? `?status=${encodeURIComponent(status)}` : "";
    return request<{ requests: AdminAfterSale[] }>(`/after-sales${qs}`);
  },
  moderationPosts: (params?: { status?: string; keyword?: string }) => {
    const q = new URLSearchParams();
    if (params?.status) q.set("status", params.status);
    if (params?.keyword) q.set("keyword", params.keyword);
    const qs = q.toString();
    return request<{ posts: ModerationPost[] }>(`/moderation/posts${qs ? `?${qs}` : ""}`);
  },
  moderationComments: (keyword?: string) => {
    const qs = keyword ? `?keyword=${encodeURIComponent(keyword)}` : "";
    return request<{ comments: ModerationComment[] }>(`/moderation/comments${qs}`);
  },
  moderationArtworks: (params?: { status?: string; keyword?: string }) => {
    const q = new URLSearchParams();
    if (params?.status) q.set("status", params.status);
    if (params?.keyword) q.set("keyword", params.keyword);
    const qs = q.toString();
    return request<{ artworks: ModerationArtwork[] }>(`/moderation/artworks${qs ? `?${qs}` : ""}`);
  },
  moderationReviews: (params?: { status?: string; keyword?: string }) => {
    const q = new URLSearchParams();
    if (params?.status) q.set("status", params.status);
    if (params?.keyword) q.set("keyword", params.keyword);
    const qs = q.toString();
    return request<{ reviews: ModerationReview[] }>(`/moderation/reviews${qs ? `?${qs}` : ""}`);
  },
  setModerationStatus: (
    kind: "posts" | "artworks" | "reviews",
    id: string,
    status: "visible" | "hidden",
  ) =>
    request<{ updated: boolean }>(`/moderation/${kind}/${id}/status`, {
      method: "PATCH",
      body: JSON.stringify({ status }),
    }),
  deleteModeration: (kind: "posts" | "comments" | "artworks" | "reviews", id: string) =>
    request<{ deleted: boolean }>(`/moderation/${kind}/${id}`, { method: "DELETE" }),
  updateAfterSaleStatus: (id: string, body: { status: string; adminNote?: string }) =>
    request(`/after-sales/${id}/status`, { method: "PATCH", body: JSON.stringify(body) }),
  users: (keyword?: string) => {
    const qs = keyword ? `?keyword=${encodeURIComponent(keyword)}` : "";
    return request<{ users: AdminUser[] }>(`/users${qs}`);
  },
  updateUserProfile: (
    id: string,
    body: {
      vipLevel?: number;
      points?: number;
      funCoins?: number;
      status?: string;
      growthPoints?: number;
      vipExpireAt?: string | null;
    },
  ) => request(`/users/${id}/profile`, { method: "PATCH", body: JSON.stringify(body) }),
  coupons: () => request<{ coupons: AdminCoupon[] }>("/coupons"),
  promotions: () => request<{ promotions: AdminPromotion[] }>("/promotions"),
  createPromotion: (body: PromotionInput) =>
    request<{ promotion: AdminPromotion }>("/promotions", { method: "POST", body: JSON.stringify(body) }),
  updatePromotion: (id: string, body: PromotionInput) =>
    request<{ promotion: AdminPromotion }>(`/promotions/${id}`, { method: "PUT", body: JSON.stringify(body) }),
  deletePromotion: (id: string) => request<{ deleted: boolean }>(`/promotions/${id}`, { method: "DELETE" }),
  financeSummary: (params?: { from?: string; to?: string }) => {
    const q = new URLSearchParams();
    if (params?.from) q.set("from", params.from);
    if (params?.to) q.set("to", params.to);
    const qs = q.toString();
    return request<{ summary: AdminFinanceSummary }>(`/finance/summary${qs ? `?${qs}` : ""}`);
  },
  financeTransactions: (params?: { from?: string; to?: string; type?: string; page?: number; pageSize?: number }) => {
    const q = new URLSearchParams();
    if (params?.from) q.set("from", params.from);
    if (params?.to) q.set("to", params.to);
    if (params?.type) q.set("type", params.type);
    if (params?.page) q.set("page", String(params.page));
    if (params?.pageSize) q.set("pageSize", String(params.pageSize));
    const qs = q.toString();
    return request<{ transactions: AdminFinanceEntry[]; total: number; page: number; pageSize: number }>(
      `/finance/transactions${qs ? `?${qs}` : ""}`,
    );
  },
  exportFinance: downloadFinanceCsv,
  createCoupon: (body: AdminCouponCreate) =>
    request<{ coupon: AdminCoupon }>("/coupons", { method: "POST", body: JSON.stringify(body) }),
  updateCoupon: (id: string, body: AdminCouponCreate) =>
    request<{ coupon: AdminCoupon }>(`/coupons/${id}`, { method: "PUT", body: JSON.stringify(body) }),
  banners: () => request<{ banners: AdminBanner[] }>("/banners"),
  createBanner: (
    body: {
      imagePath: string;
      productId: string;
      sortOrder?: number;
      title?: string;
      linkType?: string;
      linkTarget?: string;
      isActive?: boolean;
    },
  ) =>
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
  admins: () => request<{ admins: AdminAccountItem[] }>("/admins"),
  updateAdminRole: (username: string, role: AdminRole) =>
    request<{ updated: boolean }>(`/admins/${username}/role`, {
      method: "PATCH",
      body: JSON.stringify({ role }),
    }),
  updateAdminDisabled: (username: string, disabled: boolean) =>
    request<{ updated: boolean }>(`/admins/${username}/disabled`, {
      method: "PATCH",
      body: JSON.stringify({ disabled }),
    }),
  auditLogs: (username?: string) =>
    request<{ entries: AuditLogEntry[] }>(`/audit-logs${username ? `?username=${encodeURIComponent(username)}` : ""}`),
  categories: () => request<{ categories: AdminCategory[] }>("/categories"),
  createCategory: (body: CategoryInput) =>
    request<{ category: AdminCategory; categories: AdminCategory[] }>("/categories", {
      method: "POST",
      body: JSON.stringify(body),
    }),
  updateCategory: (id: string, body: CategoryInput) =>
    request<{ category: AdminCategory; categories: AdminCategory[] }>(`/categories/${id}`, {
      method: "PUT",
      body: JSON.stringify(body),
    }),
  deleteCategory: (id: string) => request<{ deleted: boolean }>(`/categories/${id}`, { method: "DELETE" }),
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

export type AdminRole = "super" | "operator" | "support";

export const ADMIN_ROLE_LABEL: Record<AdminRole, string> = {
  super: "超级管理员",
  operator: "运营管理员",
  support: "客服专员",
};

export interface AdminInfo {
  username: string;
  name: string;
  systemName?: string;
  avatarPath?: string | null;
  notifications?: AdminNotifications;
  role?: AdminRole;
}

export interface AdminAccountItem {
  username: string;
  name: string;
  avatarPath: string | null;
  role: AdminRole;
  disabled: boolean;
  createdAt: string | null;
  builtin: boolean;
}

export interface AuditLogEntry {
  id: string;
  time: string;
  username: string;
  name: string;
  action: string;
  detail: string;
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

export interface AdminCategory {
  id: string;
  name: string;
  sortOrder: number;
  productCount: number;
}

export interface CategoryInput {
  name: string;
  sortOrder?: number;
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
  stock: number;
  isOnShelf: boolean;
  imagePath: string;
  // 2026-11-20 后端新增：多图、视频、品牌/系列、稀有度、导购结构化卖点
  imagePaths?: string[];
  detailImages?: string[];
  videoPath?: string | null;
  brand?: string | null;
  series?: string | null;
  rarity?: string | null;
  suitableFor?: string | null;
  sellingPoints?: string[];
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
  freight?: number;
  remark?: string | null;
  shippingCompany?: string | null;
  trackingNo?: string | null;
  shippedAt?: string | null;
  receivedAt?: string | null;
}

export interface AdminOrderDetail {
  id: string;
  orderNo: string;
  status: string;
  statusLabel: string;
  paymentStatus: string;
  paymentMethod: string | null;
  user: string;
  phone: string;
  subtotal: number;
  discount: number;
  freight: number;
  amount: number;
  addressName: string;
  addressPhone: string;
  address: string;
  remark: string | null;
  cancelReason: string | null;
  shippingCompany: string | null;
  trackingNo: string | null;
  date: string;
  paidAt: string | null;
  shippedAt: string | null;
  receivedAt: string | null;
  cancelledAt: string | null;
  items: {
    id: string;
    productId: string;
    name: string;
    spec: string;
    imagePath: string;
    unitPrice: number;
    quantity: number;
    subtotal: number;
  }[];
  afterSales: {
    id: string;
    type: string;
    reason: string;
    description: string;
    amount: number | null;
    status: string;
    adminNote: string | null;
    date: string;
  }[];
}

export interface ModerationPost {
  id: string;
  author: string;
  isAi: boolean;
  content: string;
  images: string[];
  commentCount: number;
  likeCount: number;
  status: string;
  date: string;
}

export interface ModerationComment {
  id: string;
  author: string;
  isAi: boolean;
  content: string;
  postContent: string;
  replyToUserName: string;
  date: string;
}

export interface ModerationArtwork {
  id: string;
  author: string;
  prompt: string;
  style: string;
  image: string;
  status: string;
  date: string;
}

export interface ModerationReview {
  id: string;
  author: string;
  productName: string;
  productId: string;
  rating: number;
  content: string;
  images: string[];
  status: string;
  date: string;
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
  joinDateTime?: string;
  status: string;
  avatarPath?: string | null;
  lastLoginAt?: string | null;
  growthPoints?: number;
  vipExpireAt?: string | null;
}

export interface AdminCoupon {
  id: string;
  title: string;
  discount: number;
  condition: string;
  expireAt: string;
  // 2026-11-20 后端新增：数字门槛（下单只认它）、发行量与已领数、适用范围
  minAmount?: number;
  couponType?: string;
  totalQuantity?: number | null;
  issuedCount?: number;
  perUserLimit?: number;
  claimStartAt?: string | null;
  scope?: string;
  scopeValue?: string | null;
  claimType?: string | null;
}

export interface AdminPromotionItem {
  id?: string;
  productId: string;
  productName?: string;
  productPrice?: number | null;
  promoPrice: number;
}

export interface AdminPromotion {
  id: string;
  name: string;
  type: "threshold" | "flash";
  thresholdAmount: number | null;
  discountAmount: number | null;
  startsAt: string;
  endsAt: string;
  isActive: boolean;
  items: AdminPromotionItem[];
  createdAt: string;
}

export interface PromotionInput {
  name: string;
  type: "threshold" | "flash";
  thresholdAmount?: number;
  discountAmount?: number;
  startsAt: string;
  endsAt: string;
  isActive: boolean;
  items?: { productId: string; promoPrice: number }[];
}

export interface AdminFinanceSummary {
  income: number;
  refunds: number;
  net: number;
  paidCount: number;
  refundCount: number;
  from: string;
  to: string;
}

export interface AdminFinanceEntry {
  id: string;
  kind: "payment" | "refund";
  at: string;
  amount: number;
  orderNo: string;
  method: string;
  userName: string;
  userPhone: string;
}

export interface AdminCouponCreate {
  title: string;
  discount: number;
  condition: string;
  expireAt: string;
  minAmount?: number;
  totalQuantity?: number | null;
  claimStartAt?: string | null;
}

export interface AdminAfterSale {
  id: string;
  orderId: string;
  orderNo: string;
  orderStatus: string;
  orderTotal: number;
  user: string;
  phone: string;
  type: string;
  reason: string;
  description: string;
  amount: number | null;
  status: string;
  adminNote: string | null;
  date: string;
}

export interface AdminBanner {
  id: string;
  imagePath: string;
  productId: string;
  productName: string;
  sortOrder: number;
  title?: string | null;
  linkType?: string;
  linkTarget?: string | null;
  isActive?: boolean;
  startsAt?: string | null;
  endsAt?: string | null;
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
  regionHeat: { name: string; value: number }[];
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

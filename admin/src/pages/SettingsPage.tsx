import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { BellIcon, DatabaseIcon, ShieldIcon, UserCogIcon } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import AdminAvatar from "../components/AdminAvatar";
import { Switch } from "../components/ui/switch";
import { useAuth } from "../contexts/AuthContext";
import { adminApi, ApiError, type AdminNotifications } from "../lib/api";
import { resolveAssetUrl } from "../lib/assets";

type SettingsTab = "account" | "security" | "notifications" | "data";

const NAV_ITEMS: { key: SettingsTab; icon: React.ReactNode; label: string }[] = [
  { key: "account", icon: <UserCogIcon size={16} />, label: "账户信息" },
  { key: "security", icon: <ShieldIcon size={16} />, label: "安全设置" },
  { key: "notifications", icon: <BellIcon size={16} />, label: "通知设置" },
  { key: "data", icon: <DatabaseIcon size={16} />, label: "数据管理" },
];

const DEFAULT_NOTIFICATIONS: AdminNotifications = {
  orderNotify: true,
  userNotify: true,
  systemNotify: true,
};

export default function SettingsPage() {
  const { admin, refreshAdmin } = useAuth();
  const queryClient = useQueryClient();
  const [tab, setTab] = useState<SettingsTab>("account");

  const [displayName, setDisplayName] = useState("");
  const [systemName, setSystemName] = useState("");
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [notifications, setNotifications] = useState<AdminNotifications>(DEFAULT_NOTIFICATIONS);
  const [avatarPath, setAvatarPath] = useState<string | null>(null);
  const [avatarPreviewOpen, setAvatarPreviewOpen] = useState(false);
  const avatarInputRef = useRef<HTMLInputElement>(null);

  const { data: settingsData, isLoading } = useQuery({
    queryKey: ["admin-settings"],
    queryFn: () => adminApi.settings(),
  });

  const { data: dataSummary, isLoading: summaryLoading } = useQuery({
    queryKey: ["admin-data-summary"],
    queryFn: () => adminApi.dataSummary(),
    enabled: tab === "data",
  });

  useEffect(() => {
    const s = settingsData?.settings ?? admin;
    if (!s) return;
    setDisplayName(s.name ?? "");
    setSystemName(s.systemName ?? "趣玩星球管理后台");
    setAvatarPath(s.avatarPath ?? null);
    if (s.notifications) setNotifications(s.notifications);
  }, [settingsData, admin]);

  const avatarMutation = useMutation({
    mutationFn: (body: { imageBase64: string; mimeType: string }) => adminApi.uploadAvatar(body),
    onSuccess: async (res) => {
      setAvatarPath(res.admin.avatarPath ?? null);
      await refreshAdmin();
      queryClient.invalidateQueries({ queryKey: ["admin-settings"] });
      toast.success("头像已更新");
    },
    onError: (e: Error) => toast.error(e instanceof ApiError ? e.message : "头像上传失败"),
  });

  const onSelectAvatar = async (file: File) => {
    const allowed = ["image/jpeg", "image/png", "image/webp", "image/gif"];
    if (!allowed.includes(file.type)) {
      toast.error("仅支持 JPG、PNG、WebP、GIF");
      return;
    }
    const dataUrl = await new Promise<string>((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(String(reader.result));
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
    const base64 = dataUrl.split(",")[1];
    if (!base64) {
      toast.error("图片读取失败");
      return;
    }
    avatarMutation.mutate({ imageBase64: base64, mimeType: file.type });
  };

  const profileMutation = useMutation({
    mutationFn: () => adminApi.updateProfile({ displayName, systemName }),
    onSuccess: async (res) => {
      await refreshAdmin();
      queryClient.invalidateQueries({ queryKey: ["admin-settings"] });
      toast.success("账户信息已保存");
      setDisplayName(res.admin.name);
      setSystemName(res.admin.systemName ?? systemName);
    },
    onError: (e: Error) => toast.error(e instanceof ApiError ? e.message : "保存失败"),
  });

  const passwordMutation = useMutation({
    mutationFn: () => adminApi.changePassword({ currentPassword, newPassword }),
    onSuccess: () => {
      toast.success("密码已更新");
      setCurrentPassword("");
      setNewPassword("");
      setConfirmPassword("");
    },
    onError: (e: Error) => toast.error(e instanceof ApiError ? e.message : "修改失败"),
  });

  const notifyMutation = useMutation({
    mutationFn: (next: AdminNotifications) => adminApi.updateNotifications(next),
    onSuccess: (res) => {
      setNotifications(res.notifications);
      queryClient.invalidateQueries({ queryKey: ["admin-settings"] });
      toast.success("通知偏好已保存");
    },
    onError: (e: Error) => toast.error(e instanceof ApiError ? e.message : "保存失败"),
  });

  const syncMutation = useMutation({
    mutationFn: () => adminApi.syncProductSales(),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-dashboard"] });
      queryClient.invalidateQueries({ queryKey: ["admin-products"] });
      queryClient.invalidateQueries({ queryKey: ["admin-data-summary"] });
      toast.success("商品销量已同步");
    },
    onError: (e: Error) => toast.error(e instanceof ApiError ? e.message : "同步失败"),
  });

  const onSavePassword = (e: React.FormEvent) => {
    e.preventDefault();
    if (newPassword !== confirmPassword) {
      toast.error("两次输入的新密码不一致");
      return;
    }
    passwordMutation.mutate();
  };

  const onToggleNotify = (key: keyof AdminNotifications, checked: boolean) => {
    const next = { ...notifications, [key]: checked };
    setNotifications(next);
    notifyMutation.mutate(next);
  };

  return (
    <div data-cmp="SettingsPage" className="p-6 flex flex-col gap-6">
      <div>
        <h2 className="text-lg font-semibold text-foreground">系统设置</h2>
        <p className="text-sm text-muted-foreground">管理账户与系统偏好配置</p>
      </div>

      <div className="flex gap-6 flex-wrap">
        <div className="w-48 flex-shrink-0 flex flex-col gap-1">
          {NAV_ITEMS.map((item) => (
            <button
              key={item.key}
              type="button"
              onClick={() => setTab(item.key)}
              className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-colors text-left ${
                tab === item.key
                  ? "bg-primary text-primary-foreground shadow-custom"
                  : "text-muted-foreground hover:bg-accent"
              }`}
            >
              {item.icon}
              {item.label}
            </button>
          ))}
        </div>

        <div className="flex-1 flex flex-col gap-5 min-w-0">
          {isLoading && tab === "account" ? (
            <p className="text-muted-foreground text-sm">加载中…</p>
          ) : null}

          {tab === "account" && (
            <div className="bg-card rounded-2xl p-6 border border-border shadow-custom">
              <div className="flex items-center gap-5 mb-6">
                <AdminAvatar
                  avatarPath={avatarPath}
                  name={displayName || admin?.name}
                  size="md"
                  uploading={avatarMutation.isPending}
                  onClick={() => avatarPath && setAvatarPreviewOpen(true)}
                />
                <div className="flex-1 min-w-0">
                  <h3 className="font-semibold text-foreground text-base">{displayName || admin?.name}</h3>
                  <p className="text-sm text-muted-foreground">账号 {admin?.username ?? "admin"}</p>
                </div>
                <button
                  type="button"
                  onClick={() => avatarInputRef.current?.click()}
                  disabled={avatarMutation.isPending}
                  className="px-4 py-2 rounded-xl border border-border bg-background text-sm font-medium text-foreground hover:bg-accent transition-colors flex-shrink-0 disabled:opacity-60"
                >
                  更改头像
                </button>
                <input
                  ref={avatarInputRef}
                  type="file"
                  accept="image/jpeg,image/png,image/webp,image/gif"
                  className="hidden"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) onSelectAvatar(file);
                    e.target.value = "";
                  }}
                />
              </div>

              {avatarPreviewOpen && avatarPath && (
                <div
                  className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-6"
                  onClick={() => setAvatarPreviewOpen(false)}
                >
                  <img
                    src={resolveAssetUrl(avatarPath)}
                    alt={displayName || admin?.name || "管理员头像"}
                    className="max-w-full max-h-full rounded-2xl object-contain shadow-custom"
                    onClick={(e) => e.stopPropagation()}
                  />
                </div>
              )}

              <form
                className="flex flex-col gap-4"
                onSubmit={(e) => {
                  e.preventDefault();
                  profileMutation.mutate();
                }}
              >
                <div className="flex items-center gap-4 flex-wrap">
                  <label className="w-24 text-sm text-muted-foreground flex-shrink-0">管理员姓名</label>
                  <input
                    type="text"
                    value={displayName}
                    onChange={(e) => setDisplayName(e.target.value)}
                    className="flex-1 min-w-[200px] px-3 py-2 text-sm bg-background border border-border rounded-xl focus:outline-none focus:ring-2 focus:ring-ring"
                  />
                </div>
                <div className="flex items-center gap-4 flex-wrap">
                  <label className="w-24 text-sm text-muted-foreground flex-shrink-0">登录账号</label>
                  <input
                    type="text"
                    readOnly
                    value={admin?.username ?? "admin"}
                    className="flex-1 min-w-[200px] px-3 py-2 text-sm bg-muted border border-border rounded-xl text-muted-foreground"
                  />
                </div>
                <div className="flex items-center gap-4 flex-wrap">
                  <label className="w-24 text-sm text-muted-foreground flex-shrink-0">系统名称</label>
                  <input
                    type="text"
                    value={systemName}
                    onChange={(e) => setSystemName(e.target.value)}
                    className="flex-1 min-w-[200px] px-3 py-2 text-sm bg-background border border-border rounded-xl focus:outline-none focus:ring-2 focus:ring-ring"
                  />
                </div>
                <div className="pt-2">
                  <button
                    type="submit"
                    disabled={profileMutation.isPending}
                    className="px-5 py-2.5 rounded-xl bg-primary text-primary-foreground text-sm font-medium hover:opacity-90 disabled:opacity-60"
                  >
                    {profileMutation.isPending ? "保存中…" : "保存账户信息"}
                  </button>
                </div>
              </form>
            </div>
          )}

          {tab === "security" && (
            <div className="bg-card rounded-2xl p-6 border border-border shadow-custom">
              <h3 className="font-semibold text-foreground mb-1">修改登录密码</h3>
              <p className="text-sm text-muted-foreground mb-5">新密码至少 6 位，修改后立即生效</p>
              <form className="flex flex-col gap-4 max-w-md" onSubmit={onSavePassword}>
                <label className="flex flex-col gap-1.5 text-sm">
                  <span className="text-muted-foreground">当前密码</span>
                  <input
                    type="password"
                    value={currentPassword}
                    onChange={(e) => setCurrentPassword(e.target.value)}
                    className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                    autoComplete="current-password"
                  />
                </label>
                <label className="flex flex-col gap-1.5 text-sm">
                  <span className="text-muted-foreground">新密码</span>
                  <input
                    type="password"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                    autoComplete="new-password"
                  />
                </label>
                <label className="flex flex-col gap-1.5 text-sm">
                  <span className="text-muted-foreground">确认新密码</span>
                  <input
                    type="password"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                    autoComplete="new-password"
                  />
                </label>
                <button
                  type="submit"
                  disabled={passwordMutation.isPending}
                  className="mt-2 px-5 py-2.5 rounded-xl bg-primary text-primary-foreground text-sm font-medium hover:opacity-90 disabled:opacity-60 w-fit"
                >
                  {passwordMutation.isPending ? "提交中…" : "更新密码"}
                </button>
              </form>
            </div>
          )}

          {tab === "notifications" && (
            <div className="bg-card rounded-2xl p-6 border border-border shadow-custom">
              <h3 className="font-semibold text-foreground mb-1">通知偏好</h3>
              <p className="text-sm text-muted-foreground mb-5">控制管理后台接收的消息类型</p>
              <div className="flex flex-col gap-4">
                {[
                  { key: "orderNotify" as const, label: "订单通知", desc: "新订单、待付款、状态变更提醒" },
                  { key: "userNotify" as const, label: "用户通知", desc: "App 客服咨询、新用户注册等提醒" },
                  { key: "systemNotify" as const, label: "系统通知", desc: "维护公告、数据同步完成提醒" },
                ].map((item) => (
                  <div
                    key={item.key}
                    className="flex items-center justify-between gap-4 p-4 rounded-xl bg-muted/40 border border-border"
                  >
                    <div>
                      <p className="text-sm font-medium text-foreground">{item.label}</p>
                      <p className="text-xs text-muted-foreground mt-0.5">{item.desc}</p>
                    </div>
                    <Switch
                      checked={notifications[item.key]}
                      onCheckedChange={(checked) => onToggleNotify(item.key, checked)}
                      disabled={notifyMutation.isPending}
                    />
                  </div>
                ))}
              </div>
            </div>
          )}

          {tab === "data" && (
            <>
              <div className="bg-card rounded-2xl p-6 border border-border shadow-custom">
                <h3 className="font-semibold text-foreground mb-4">数据概览</h3>
                {summaryLoading ? (
                  <p className="text-sm text-muted-foreground">加载中…</p>
                ) : (
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                    {[
                      { label: "商品", value: dataSummary?.summary.products ?? "—" },
                      { label: "用户", value: dataSummary?.summary.users ?? "—" },
                      { label: "订单", value: dataSummary?.summary.orders ?? "—" },
                      { label: "总营收", value: dataSummary ? `¥${dataSummary.summary.totalRevenue.toLocaleString()}` : "—" },
                      { label: "优惠券", value: dataSummary?.summary.coupons ?? "—" },
                      { label: "轮播图", value: dataSummary?.summary.banners ?? "—" },
                      { label: "待付款", value: dataSummary?.summary.pendingOrders ?? "—" },
                    ].map((item) => (
                      <div key={item.label} className="rounded-xl bg-muted p-4 text-center">
                        <p className="text-xs text-muted-foreground">{item.label}</p>
                        <p className="text-lg font-bold text-primary mt-1">{item.value}</p>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              <div className="bg-card rounded-2xl p-6 border border-border shadow-custom">
                <h3 className="font-semibold text-foreground mb-1">数据维护</h3>
                <p className="text-sm text-muted-foreground mb-4">
                  根据已付款订单重新计算并写入各商品销量，清除历史假数据
                </p>
                <button
                  type="button"
                  onClick={() => syncMutation.mutate()}
                  disabled={syncMutation.isPending}
                  className="px-5 py-2.5 rounded-xl bg-primary text-primary-foreground text-sm font-medium hover:opacity-90 disabled:opacity-60"
                >
                  {syncMutation.isPending ? "同步中…" : "同步商品销量"}
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

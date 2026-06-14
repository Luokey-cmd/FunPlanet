import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { SearchIcon, PhoneIcon, EditIcon, XIcon } from "lucide-react";
import { toast } from "sonner";
import { adminApi, type AdminUser } from "../lib/api";
import AdminAvatar from "../components/AdminAvatar";

const vipColors = ["#c0e3f0", "#7ec8de", "#4cb9d6", "#2e9bb8", "#1a7a94"];

export default function UsersPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState("");
  const [editing, setEditing] = useState<AdminUser | null>(null);
  const [form, setForm] = useState({ vipLevel: 1, points: 0, funCoins: 0 });

  const { data, isLoading } = useQuery({
    queryKey: ["admin-users", search],
    queryFn: () => adminApi.users(search || undefined),
  });

  const saveMutation = useMutation({
    mutationFn: () =>
      adminApi.updateUserProfile(editing!.id, {
        vipLevel: form.vipLevel,
        points: form.points,
        funCoins: form.funCoins,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-users"] });
      toast.success("用户信息已更新");
      setEditing(null);
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const users = data?.users ?? [];

  const openEdit = (u: AdminUser) => {
    setEditing(u);
    setForm({ vipLevel: u.vipLevel, points: u.points, funCoins: u.funCoins });
  };

  return (
    <div data-cmp="UsersPage" className="p-6 flex flex-col gap-5">
      <div>
        <h2 className="text-lg font-semibold text-foreground">用户管理</h2>
        <p className="text-sm text-muted-foreground">共 {users.length} 位用户</p>
      </div>

      <div className="flex gap-4 flex-wrap">
        {[
          { label: "总用户数", value: users.length, color: "#4cb9d6" },
          { label: "VIP 用户", value: users.filter((u) => u.vipLevel > 1).length, color: "#2e9bb8" },
        ].map((item) => (
          <div key={item.label} className="flex-1 min-w-[140px] bg-card rounded-2xl p-4 border border-border shadow-custom">
            <p className="text-xs text-muted-foreground mb-1">{item.label}</p>
            <p className="text-2xl font-bold" style={{ color: item.color }}>
              {item.value.toLocaleString()}
            </p>
          </div>
        ))}
      </div>

      <div className="relative w-56">
        <SearchIcon size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
        <input
          type="text"
          placeholder="搜索用户……"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="pl-9 pr-4 py-2 text-sm bg-card border border-border rounded-xl focus:outline-none focus:ring-2 focus:ring-ring w-full"
        />
      </div>

      {isLoading ? (
        <p className="text-muted-foreground">加载中…</p>
      ) : (
        <div className="flex flex-col gap-3">
          {users.map((user) => (
            <div
              key={user.id}
              className="bg-card rounded-2xl p-5 border border-border shadow-custom hover:border-primary/40 transition-colors"
            >
              <div className="flex items-center gap-4 flex-wrap">
                <AdminAvatar avatarPath={user.avatarPath} name={user.name} size="sm" fallback="👤" />
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-3 flex-wrap">
                    <span className="font-semibold text-foreground">{user.name}</span>
                    <span
                      className="text-xs px-2 py-0.5 rounded-full font-medium text-white"
                      style={{ backgroundColor: vipColors[Math.min(user.vipLevel - 1, 4)] }}
                    >
                      VIP{user.vipLevel}
                    </span>
                    <span className="text-xs text-muted-foreground">{user.userId}</span>
                  </div>
                  <div className="flex items-center gap-4 mt-2 flex-wrap text-xs text-muted-foreground">
                    <div className="flex items-center gap-1">
                      <PhoneIcon size={12} />
                      {user.phone}
                    </div>
                    <span>注册于 {user.joinDate}</span>
                    <span>积分 {user.points}</span>
                    <span>趣玩币 {user.funCoins}</span>
                  </div>
                </div>
                <div className="flex gap-8 flex-shrink-0 items-center">
                  <div className="text-center">
                    <p className="text-lg font-bold text-foreground">{user.orders}</p>
                    <p className="text-xs text-muted-foreground">订单数</p>
                  </div>
                  <div className="text-center">
                    <p className="text-lg font-bold text-foreground">¥{user.totalSpend.toLocaleString()}</p>
                    <p className="text-xs text-muted-foreground">累计消费</p>
                  </div>
                  <button
                    onClick={() => openEdit(user)}
                    className="w-8 h-8 rounded-lg bg-accent flex items-center justify-center hover:bg-primary/20 transition-colors"
                  >
                    <EditIcon size={14} className="text-muted-foreground" />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {editing && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 p-4">
          <div className="bg-card rounded-2xl border border-border shadow-custom w-full max-w-sm p-6">
            <div className="flex items-center justify-between mb-5">
              <h3 className="font-semibold text-foreground">编辑 {editing.name}</h3>
              <button onClick={() => setEditing(null)}>
                <XIcon size={18} className="text-muted-foreground" />
              </button>
            </div>
            <form
              className="flex flex-col gap-3"
              onSubmit={(e) => {
                e.preventDefault();
                saveMutation.mutate();
              }}
            >
              {[
                { key: "vipLevel", label: "VIP 等级", min: 1, max: 5 },
                { key: "points", label: "积分", min: 0 },
                { key: "funCoins", label: "趣玩币", min: 0 },
              ].map(({ key, label, min, max }) => (
                <label key={key} className="flex flex-col gap-1 text-sm">
                  <span className="text-muted-foreground">{label}</span>
                  <input
                    type="number"
                    min={min}
                    max={max}
                    value={form[key as keyof typeof form]}
                    onChange={(e) => setForm({ ...form, [key]: Number(e.target.value) })}
                    className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                  />
                </label>
              ))}
              <button
                type="submit"
                disabled={saveMutation.isPending}
                className="mt-2 py-2.5 rounded-xl bg-primary text-primary-foreground text-sm font-medium disabled:opacity-60"
              >
                {saveMutation.isPending ? "保存中…" : "保存"}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

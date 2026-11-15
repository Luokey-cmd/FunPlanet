import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { SearchIcon, RotateCcwIcon, XIcon } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import { adminApi, type AdminUser } from "../lib/api";
import AdminAvatar from "../components/AdminAvatar";

const QUERY_FIELDS = [
  { value: "all", label: "全部查询项" },
  { value: "name", label: "用户名" },
  { value: "userId", label: "账号ID" },
  { value: "phone", label: "手机号" },
] as const;

type QueryField = (typeof QUERY_FIELDS)[number]["value"];

const inputClass =
  "h-9 px-3 text-sm bg-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring min-w-[140px]";

function DateInput({
  value,
  onChange,
  title,
}: {
  value: string;
  onChange: (value: string) => void;
  title: string;
}) {
  return (
    <input
      type={value ? "date" : "text"}
      placeholder="年/月/日"
      title={title}
      value={value}
      onFocus={(e) => {
        e.currentTarget.type = "date";
      }}
      onBlur={(e) => {
        if (!e.currentTarget.value) e.currentTarget.type = "text";
      }}
      onChange={(e) => onChange(e.target.value)}
      className={inputClass}
    />
  );
}

function matchesQuery(user: AdminUser, field: QueryField, keyword: string) {
  if (!keyword) return true;
  const q = keyword.toLowerCase();
  const name = user.name.toLowerCase();
  const userId = user.userId.toLowerCase();
  const phone = user.phone.toLowerCase();
  if (field === "name") return name.includes(q);
  if (field === "userId") return userId.includes(q);
  if (field === "phone") return phone.includes(q);
  return name.includes(q) || userId.includes(q) || phone.includes(q);
}

function inDateRange(user: AdminUser, start: string, end: string) {
  const day = (user.joinDateTime ?? user.joinDate).slice(0, 10).replaceAll("/", "-");
  if (start && day < start) return false;
  if (end && day > end) return false;
  return true;
}

function statusLabel(status: string) {
  return status === "active" ? "正常" : status;
}

export default function UsersPage() {
  const queryClient = useQueryClient();
  const [queryField, setQueryField] = useState<QueryField>("all");
  const [keyword, setKeyword] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [dateStart, setDateStart] = useState("");
  const [dateEnd, setDateEnd] = useState("");
  const [applied, setApplied] = useState({
    queryField: "all" as QueryField,
    keyword: "",
    statusFilter: "",
    dateStart: "",
    dateEnd: "",
  });
  const [detail, setDetail] = useState<AdminUser | null>(null);
  const [form, setForm] = useState({ vipLevel: 1, points: 0, funCoins: 0 });

  const { data, isLoading } = useQuery({
    queryKey: ["admin-users"],
    queryFn: () => adminApi.users(),
  });

  const saveMutation = useMutation({
    mutationFn: () =>
      adminApi.updateUserProfile(detail!.id, {
        vipLevel: form.vipLevel,
        points: form.points,
        funCoins: form.funCoins,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-users"] });
      toast.success("用户信息已更新");
      setDetail(null);
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const users = data?.users ?? [];
  const filtered = users.filter((user) => {
    if (!matchesQuery(user, applied.queryField, applied.keyword.trim())) return false;
    if (applied.statusFilter && user.status !== applied.statusFilter) return false;
    if (!inDateRange(user, applied.dateStart, applied.dateEnd)) return false;
    return true;
  });

  const applySearch = () => {
    setApplied({ queryField, keyword, statusFilter, dateStart, dateEnd });
  };

  const resetSearch = () => {
    setQueryField("all");
    setKeyword("");
    setStatusFilter("");
    setDateStart("");
    setDateEnd("");
    setApplied({
      queryField: "all",
      keyword: "",
      statusFilter: "",
      dateStart: "",
      dateEnd: "",
    });
  };

  const openDetail = (u: AdminUser) => {
    setDetail(u);
    setForm({ vipLevel: u.vipLevel, points: u.points, funCoins: u.funCoins });
  };

  return (
    <div data-cmp="UsersPage" className="p-6 flex flex-col gap-4">
      <div>
        <h2 className="text-lg font-semibold text-foreground">用户综合信息</h2>
        <p className="text-sm text-muted-foreground">共 {filtered.length} 位用户</p>
      </div>

      <div className="bg-card rounded-2xl border border-border shadow-custom p-4">
        <div className="flex flex-wrap gap-3 items-center">
          <select value={queryField} onChange={(e) => setQueryField(e.target.value as QueryField)} className={inputClass}>
            {QUERY_FIELDS.map((item) => (
              <option key={item.value} value={item.value}>
                {item.label}
              </option>
            ))}
          </select>
          <input
            type="text"
            placeholder="请输入查询内容"
            value={keyword}
            onChange={(e) => setKeyword(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && applySearch()}
            className={`${inputClass} flex-1 min-w-[180px]`}
          />
          <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} className={inputClass}>
            <option value="">全部状态</option>
            <option value="active">正常</option>
          </select>
          <DateInput value={dateStart} onChange={setDateStart} title="注册开始日期" />
          <DateInput value={dateEnd} onChange={setDateEnd} title="注册结束日期" />
          <button
            type="button"
            onClick={applySearch}
            className="h-9 px-4 rounded-lg bg-primary text-primary-foreground text-sm font-medium inline-flex items-center gap-1.5 hover:opacity-90"
          >
            <SearchIcon size={14} />
            查询
          </button>
          <button
            type="button"
            onClick={resetSearch}
            className="h-9 px-4 rounded-lg bg-muted text-foreground text-sm font-medium inline-flex items-center gap-1.5 hover:bg-accent"
          >
            <RotateCcwIcon size={14} />
            重置
          </button>
        </div>
      </div>

      {isLoading ? (
        <p className="text-muted-foreground">加载中…</p>
      ) : (
        <div className="bg-card rounded-2xl border border-border shadow-custom overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm min-w-[1100px]">
              <thead>
                <tr className="bg-muted/60 text-muted-foreground text-left">
                  {[
                    "账号ID",
                    "头像",
                    "用户名",
                    "手机号",
                    "VIP等级",
                    "积分",
                    "趣玩币",
                    "订单数",
                    "累计消费",
                    "注册时间",
                    "状态",
                    "操作",
                  ].map((col) => (
                    <th key={col} className="px-3 py-3 font-medium whitespace-nowrap">
                      {col}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan={12} className="px-3 py-10 text-center text-muted-foreground">
                      暂无用户数据
                    </td>
                  </tr>
                ) : (
                  filtered.map((user) => (
                    <tr key={user.id} className="border-t border-border hover:bg-accent/40">
                      <td className="px-3 py-2.5 text-muted-foreground whitespace-nowrap">{user.userId}</td>
                      <td className="px-3 py-2.5">
                        <AdminAvatar avatarPath={user.avatarPath} name={user.name} size="sm" silhouette circle />
                      </td>
                      <td className="px-3 py-2.5">
                        <button type="button" onClick={() => openDetail(user)} className="text-primary hover:underline font-medium">
                          {user.name}
                        </button>
                      </td>
                      <td className="px-3 py-2.5 whitespace-nowrap">{user.phone}</td>
                      <td className="px-3 py-2.5 whitespace-nowrap">VIP{user.vipLevel}</td>
                      <td className="px-3 py-2.5">{user.points}</td>
                      <td className="px-3 py-2.5">{user.funCoins}</td>
                      <td className="px-3 py-2.5">{user.orders}</td>
                      <td className="px-3 py-2.5 whitespace-nowrap">¥{user.totalSpend.toLocaleString()}</td>
                      <td className="px-3 py-2.5 whitespace-nowrap">{user.joinDateTime ?? user.joinDate}</td>
                      <td className="px-3 py-2.5">
                        <span className="inline-flex px-2 py-0.5 rounded text-xs font-medium bg-emerald-500/15 text-emerald-700 dark:text-emerald-400">
                          {statusLabel(user.status)}
                        </span>
                      </td>
                      <td className="px-3 py-2.5">
                        <button
                          type="button"
                          onClick={() => openDetail(user)}
                          className="h-8 px-3 rounded-md bg-primary text-primary-foreground text-xs font-medium hover:opacity-90 whitespace-nowrap"
                        >
                          查看详情
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {detail && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 p-4">
          <div className="bg-card rounded-2xl border border-border shadow-custom w-full max-w-md p-6">
            <div className="flex items-center justify-between mb-5">
              <h3 className="font-semibold text-foreground">用户详情</h3>
              <button type="button" onClick={() => setDetail(null)}>
                <XIcon size={18} className="text-muted-foreground" />
              </button>
            </div>
            <div className="flex items-center gap-3 mb-5">
              <AdminAvatar avatarPath={detail.avatarPath} name={detail.name} size="md" silhouette circle />
              <div>
                <p className="font-semibold text-foreground">{detail.name}</p>
                <p className="text-xs text-muted-foreground">账号ID {detail.userId}</p>
                <p className="text-xs text-muted-foreground">手机号 {detail.phone}</p>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-2 text-xs text-muted-foreground mb-5">
              <span>订单数 {detail.orders}</span>
              <span>累计消费 ¥{detail.totalSpend.toLocaleString()}</span>
              <span>注册时间 {detail.joinDateTime ?? detail.joinDate}</span>
              <span>状态 {statusLabel(detail.status)}</span>
            </div>
            <form
              className="flex flex-col gap-3"
              onSubmit={(e) => {
                e.preventDefault();
                saveMutation.mutate();
              }}
            >
              {[
                { key: "vipLevel" as const, label: "VIP等级", min: 1 },
                { key: "points" as const, label: "积分", min: 0 },
                { key: "funCoins" as const, label: "趣玩币", min: 0 },
              ].map(({ key, label, min }) => (
                <label key={key} className="flex flex-col gap-1 text-sm">
                  <span className="text-muted-foreground">{label}</span>
                  <input
                    type="number"
                    min={min}
                    value={form[key]}
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

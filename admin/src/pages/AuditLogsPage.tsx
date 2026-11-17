import { useQuery } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { adminApi, ADMIN_ROLE_LABEL } from "../lib/api";

function formatTime(iso: string) {
  const d = new Date(iso);
  return d.toLocaleString("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

export default function AuditLogsPage() {
  const [usernameFilter, setUsernameFilter] = useState("");
  const [actionFilter, setActionFilter] = useState("全部");

  const { data, isLoading } = useQuery({
    queryKey: ["admin-audit-logs", usernameFilter],
    queryFn: () => adminApi.auditLogs(usernameFilter || undefined),
    refetchInterval: 10000,
  });

  const entries = data?.entries ?? [];

  const usernames = useMemo(
    () => [...new Set(entries.map((e) => e.username))],
    [entries],
  );
  const actions = useMemo(() => ["全部", ...new Set(entries.map((e) => e.action))], [entries]);

  const visible = entries.filter((e) => actionFilter === "全部" || e.action === actionFilter);

  return (
    <div data-cmp="AuditLogsPage" className="p-6 flex flex-col gap-5">
      <div>
        <h2 className="text-lg font-semibold text-foreground">操作日志</h2>
        <p className="text-sm text-muted-foreground">
          后台所有写操作与登录都会自动记录，最多保留最近 500 条，这里显示最近 200 条。只有超级管理员能看这一页。
        </p>
      </div>

      <div className="flex items-center gap-3 flex-wrap">
        <select
          value={usernameFilter}
          onChange={(e) => setUsernameFilter(e.target.value)}
          className="px-3 py-2 text-sm bg-card border border-border rounded-xl focus:outline-none focus:ring-2 focus:ring-ring"
        >
          <option value="">全部管理员</option>
          {usernames.map((u) => (
            <option key={u} value={u}>
              {u}
            </option>
          ))}
        </select>
        <div className="flex gap-2 flex-wrap">
          {actions.map((a) => (
            <button
              key={a}
              onClick={() => setActionFilter(a)}
              className={`text-xs px-3 py-2 rounded-xl transition-colors font-medium ${
                actionFilter === a
                  ? "bg-primary text-primary-foreground"
                  : "bg-card border border-border text-muted-foreground hover:bg-accent"
              }`}
            >
              {a}
            </button>
          ))}
        </div>
      </div>

      <div className="bg-card rounded-2xl border border-border shadow-custom overflow-hidden">
        {isLoading ? (
          <p className="p-8 text-center text-muted-foreground">加载中…</p>
        ) : visible.length === 0 ? (
          <p className="p-8 text-center text-muted-foreground">暂无记录。做一次新增、编辑或删除操作后，这里就会出现。</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-muted-foreground">
                <th className="px-5 py-3 font-medium">时间</th>
                <th className="px-5 py-3 font-medium">管理员</th>
                <th className="px-5 py-3 font-medium">操作</th>
                <th className="px-5 py-3 font-medium">详情</th>
              </tr>
            </thead>
            <tbody>
              {visible.map((e) => (
                <tr key={e.id} className="border-b border-border/60 last:border-0 hover:bg-accent/40 transition-colors">
                  <td className="px-5 py-3 text-muted-foreground whitespace-nowrap">{formatTime(e.time)}</td>
                  <td className="px-5 py-3">
                    <span className="font-medium text-foreground">{e.name}</span>
                    <span className="ml-1.5 text-xs text-muted-foreground">{e.username}</span>
                  </td>
                  <td className="px-5 py-3">
                    <span className="text-xs px-2.5 py-1 rounded-lg bg-secondary text-secondary-foreground font-medium">
                      {e.action}
                    </span>
                  </td>
                  <td className="px-5 py-3 text-xs text-muted-foreground">{e.detail || "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      <p className="text-xs text-muted-foreground">角色说明：{ADMIN_ROLE_LABEL.super}可查看本页；其他角色的操作同样会被记录。</p>
    </div>
  );
}

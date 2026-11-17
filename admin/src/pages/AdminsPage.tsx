import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ShieldCheckIcon } from "lucide-react";
import { toast } from "sonner";
import { adminApi, ApiError, ADMIN_ROLE_LABEL, type AdminRole } from "../lib/api";
import AdminAvatar from "../components/AdminAvatar";

const ROLE_OPTIONS: AdminRole[] = ["super", "operator", "support"];

const ROLE_HINT: Record<AdminRole, string> = {
  super: "全部页面与全部操作，包括管理员管理与操作日志",
  operator: "除管理员管理、操作日志外的全部业务页面与操作",
  support: "只看数据看板、订单、用户与客服中心，写操作仅限订单状态与客服回复",
};

export default function AdminsPage({ currentUsername }: { currentUsername: string }) {
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ["admin-admins"],
    queryFn: () => adminApi.admins(),
  });

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ["admin-admins"] });

  const roleMutation = useMutation({
    mutationFn: ({ username, role }: { username: string; role: AdminRole }) =>
      adminApi.updateAdminRole(username, role),
    onSuccess: () => {
      invalidate();
      toast.success("角色已更新");
    },
    onError: (e: Error) => toast.error(e instanceof ApiError ? e.message : "更新失败"),
  });

  const disabledMutation = useMutation({
    mutationFn: ({ username, disabled }: { username: string; disabled: boolean }) =>
      adminApi.updateAdminDisabled(username, disabled),
    onSuccess: (_d, vars) => {
      invalidate();
      toast.success(vars.disabled ? "账号已禁用，该账号将无法登录" : "账号已启用");
    },
    onError: (e: Error) => toast.error(e instanceof ApiError ? e.message : "更新失败"),
  });

  const admins = data?.admins ?? [];

  return (
    <div data-cmp="AdminsPage" className="p-6 flex flex-col gap-5">
      <div>
        <h2 className="text-lg font-semibold text-foreground">管理员管理</h2>
        <p className="text-sm text-muted-foreground">
          共 {admins.length} 个管理员账号。内置账号固定为超级管理员；新注册的账号默认为运营管理员，可在这里调整角色或禁用。
        </p>
      </div>

      <div className="bg-card rounded-2xl border border-border shadow-custom p-4 flex flex-col gap-2">
        {ROLE_OPTIONS.map((r) => (
          <p key={r} className="text-xs text-muted-foreground flex items-center gap-2">
            <ShieldCheckIcon size={13} className="text-primary flex-shrink-0" />
            <span className="font-medium text-foreground">{ADMIN_ROLE_LABEL[r]}：</span>
            {ROLE_HINT[r]}
          </p>
        ))}
      </div>

      <div className="bg-card rounded-2xl border border-border shadow-custom overflow-hidden">
        {isLoading ? (
          <p className="p-8 text-center text-muted-foreground">加载中…</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-muted-foreground">
                <th className="px-5 py-3 font-medium">管理员</th>
                <th className="px-5 py-3 font-medium">角色</th>
                <th className="px-5 py-3 font-medium">状态</th>
                <th className="px-5 py-3 font-medium">创建时间</th>
                <th className="px-5 py-3 font-medium text-right">操作</th>
              </tr>
            </thead>
            <tbody>
              {admins.map((a) => {
                const isSelf = a.username === currentUsername;
                const locked = a.builtin || isSelf;
                return (
                  <tr key={a.username} className="border-b border-border/60 last:border-0 hover:bg-accent/40 transition-colors">
                    <td className="px-5 py-3">
                      <div className="flex items-center gap-3">
                        <AdminAvatar name={a.name} avatarPath={a.avatarPath} size="sm" />
                        <div>
                          <p className="font-medium text-foreground">
                            {a.name}
                            {a.builtin && <span className="ml-2 text-xs px-2 py-0.5 rounded-lg bg-primary/15 text-primary">内置账号</span>}
                            {isSelf && <span className="ml-2 text-xs px-2 py-0.5 rounded-lg bg-secondary text-secondary-foreground">当前登录</span>}
                          </p>
                          <p className="text-xs text-muted-foreground">{a.username}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-5 py-3">
                      {a.builtin ? (
                        <span className="text-foreground">{ADMIN_ROLE_LABEL.super}</span>
                      ) : (
                        <select
                          value={a.role}
                          disabled={locked || roleMutation.isPending}
                          onChange={(e) => roleMutation.mutate({ username: a.username, role: e.target.value as AdminRole })}
                          className="px-2.5 py-1.5 text-sm bg-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring disabled:opacity-50"
                        >
                          {ROLE_OPTIONS.map((r) => (
                            <option key={r} value={r}>
                              {ADMIN_ROLE_LABEL[r]}
                            </option>
                          ))}
                        </select>
                      )}
                    </td>
                    <td className="px-5 py-3">
                      <span className={a.disabled ? "text-destructive font-medium" : "text-muted-foreground"}>
                        {a.disabled ? "已禁用" : "正常"}
                      </span>
                    </td>
                    <td className="px-5 py-3 text-muted-foreground">
                      {a.createdAt ? new Date(a.createdAt).toLocaleString("zh-CN") : "—"}
                    </td>
                    <td className="px-5 py-3 text-right">
                      {a.builtin ? (
                        <span className="text-xs text-muted-foreground">不可修改</span>
                      ) : (
                        <button
                          disabled={locked || disabledMutation.isPending}
                          onClick={() => {
                            if (isSelf) return;
                            if (confirm(a.disabled ? `确定启用「${a.name}」？` : `确定禁用「${a.name}」？禁用后该账号无法登录。`)) {
                              disabledMutation.mutate({ username: a.username, disabled: !a.disabled });
                            }
                          }}
                          className={`px-3 py-1.5 rounded-lg border border-border text-xs font-medium transition-colors disabled:opacity-50 ${
                            a.disabled ? "hover:bg-accent" : "text-destructive hover:bg-destructive/10"
                          }`}
                        >
                          {a.disabled ? "启用" : "禁用"}
                        </button>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}

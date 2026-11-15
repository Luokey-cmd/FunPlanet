import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { toast } from "sonner";
import AccountSwitchList from "../components/AccountSwitchList";
import PasswordInput from "../components/PasswordInput";
import { useAuth } from "../contexts/AuthContext";
import { ApiError } from "../lib/api";

const passwordFieldClass =
  "px-4 py-3 rounded-md border border-slate-200 bg-white/90 text-slate-800 focus:outline-none focus:ring-2 focus:ring-sky-300";

export default function LoginPage() {
  const { login, token, savedAccounts, switchAccount, removeAccount } = useAuth();
  const navigate = useNavigate();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (token) navigate("/", { replace: true });
  }, [token, navigate]);

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await login(username.trim(), password);
      toast.success("登录成功");
      navigate("/", { replace: true });
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : "登录失败");
    } finally {
      setSubmitting(false);
    }
  };

  if (token) return null;

  return (
    <div className="relative min-h-screen overflow-hidden">
      <div
        className="absolute inset-0 bg-cover bg-center bg-no-repeat"
        style={{ backgroundImage: "url(/images/admin-login-bg.png)" }}
        aria-hidden
      />

      {/* 左侧留给插画标题，卡片落在中部留白云层 */}
      <div className="relative z-10 min-h-screen grid grid-cols-1 lg:grid-cols-12 items-center gap-4 px-6 py-10">
        <div className="hidden lg:block lg:col-span-4" aria-hidden />
        <div className="lg:col-span-4 flex justify-center">
          <div className="w-full max-w-[380px] translate-x-0 lg:translate-x-[38%] rounded-xl border border-white/70 bg-white/90 backdrop-blur-md shadow-[0_20px_60px_rgba(56,120,200,0.22)] p-8">
            <div className="text-center mb-8">
              <img
                src="/images/app_icon.png"
                alt="趣玩星球"
                className="inline-block w-14 h-14 rounded-lg object-cover mb-4 shadow-sm"
              />
              <div className="flex items-center gap-2.5 px-2">
                {/* 1 外侧淡→实 · 菱形 · 2 近菱形实→近标题淡 */}
                <span className="flex-1 flex items-center min-w-0" aria-hidden>
                  <span className="h-px flex-1 bg-gradient-to-r from-transparent via-sky-400/40 to-sky-500/90" />
                  <span className="w-1.5 h-1.5 rotate-45 shrink-0 bg-sky-500 mx-1" />
                  <span className="h-px flex-1 bg-gradient-to-r from-sky-500 via-sky-400/55 to-transparent" />
                </span>
                <h1 className="text-2xl font-bold text-slate-800 shrink-0 px-1">趣玩星球</h1>
                {/* 3 近标题淡→近菱形实 · 菱形 · 4 实→外侧淡 */}
                <span className="flex-1 flex items-center min-w-0" aria-hidden>
                  <span className="h-px flex-1 bg-gradient-to-r from-transparent via-sky-400/55 to-sky-500" />
                  <span className="w-1.5 h-1.5 rotate-45 shrink-0 bg-sky-500 mx-1" />
                  <span className="h-px flex-1 bg-gradient-to-r from-sky-500/90 via-sky-400/40 to-transparent" />
                </span>
              </div>
              <p className="text-sm text-slate-500 mt-2">管理后台登录</p>
            </div>
            {savedAccounts.length > 0 ? (
              <div className="mb-5 rounded-lg border border-slate-200 bg-white/70 p-1">
                <p className="px-3 pt-2 pb-1 text-xs text-slate-500">已登录账号，点击即可切换</p>
                <AccountSwitchList
                  accounts={savedAccounts}
                  onSwitch={async (name) => {
                    const target = savedAccounts.find((a) => a.username === name);
                    if (target && !target.token) {
                      setUsername(name);
                      toast.message("请输入密码重新登录");
                      return;
                    }
                    try {
                      await switchAccount(name);
                      toast.success("已切换账号");
                      navigate("/", { replace: true });
                    } catch (err) {
                      setUsername(name);
                      toast.error(err instanceof ApiError ? err.message : err instanceof Error ? err.message : "该账号已失效，请重新登录");
                    }
                  }}
                  onRemove={(name) => {
                    removeAccount(name);
                    toast.success("已移除账号");
                  }}
                />
              </div>
            ) : null}
            <form onSubmit={onSubmit} className="flex flex-col gap-4">
              <label className="flex flex-col gap-1.5 text-sm">
                <span className="text-slate-500">账号</span>
                <input
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  className="px-4 py-3 rounded-md border border-slate-200 bg-white/90 text-slate-800 focus:outline-none focus:ring-2 focus:ring-sky-300"
                  autoComplete="username"
                />
              </label>
              <label className="flex flex-col gap-1.5 text-sm">
                <span className="text-slate-500">密码</span>
                <PasswordInput
                  value={password}
                  onChange={setPassword}
                  autoComplete="current-password"
                  className={passwordFieldClass}
                />
              </label>
              <button
                type="submit"
                disabled={submitting}
                className="mt-2 py-3 rounded-md bg-primary text-primary-foreground font-medium hover:opacity-90 disabled:opacity-60"
              >
                {submitting ? "登录中…" : "登录"}
              </button>
            </form>
            <p className="text-sm text-center text-slate-500 mt-6">
              没有账号？{" "}
              <Link to="/register" className="text-sky-600 font-medium hover:underline">
                立即注册
              </Link>
            </p>
            <p className="text-xs text-slate-400 text-center mt-3">
              内置账号 admin / admin123（可在服务端 .env 配置）
            </p>
          </div>
        </div>
        <div className="hidden lg:block lg:col-span-4" aria-hidden />
      </div>
    </div>
  );
}

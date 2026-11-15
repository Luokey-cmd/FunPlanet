import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { toast } from "sonner";
import PasswordInput from "../components/PasswordInput";
import { useAuth } from "../contexts/AuthContext";
import { ApiError } from "../lib/api";

const fieldClass =
  "px-4 py-2.5 rounded-md border border-slate-200 bg-white/90 text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-sky-300";

export default function RegisterPage() {
  const { register, token } = useAuth();
  const navigate = useNavigate();
  const [username, setUsername] = useState("");
  const [name, setName] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (token) navigate("/", { replace: true });
  }, [token, navigate]);

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (password !== confirmPassword) {
      toast.error("两次输入的密码不一致");
      return;
    }
    setSubmitting(true);
    try {
      await register({
        username: username.trim(),
        password,
        confirmPassword,
        name: name.trim() || undefined,
      });
      toast.success("注册成功");
      navigate("/", { replace: true });
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : "注册失败");
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

      <div className="relative z-10 min-h-screen grid grid-cols-1 lg:grid-cols-12 items-center gap-4 px-6 py-3">
        <div className="hidden lg:block lg:col-span-4" aria-hidden />
        <div className="lg:col-span-4 flex justify-center max-h-[calc(100dvh-1.5rem)]">
          <div className="w-full max-w-[380px] max-h-full translate-x-0 lg:translate-x-[38%] rounded-xl border border-white/70 bg-white/90 backdrop-blur-md shadow-[0_20px_60px_rgba(56,120,200,0.22)] px-7 py-6 flex flex-col">
            <div className="text-center mb-5 shrink-0">
              <img
                src="/images/app_icon.png"
                alt="趣玩星球"
                className="inline-block w-12 h-12 rounded-lg object-cover mb-3 shadow-sm"
              />
              <div className="flex items-center gap-2.5 px-2">
                <span className="flex-1 flex items-center min-w-0" aria-hidden>
                  <span className="h-px flex-1 bg-gradient-to-r from-transparent via-sky-400/40 to-sky-500/90" />
                  <span className="w-1.5 h-1.5 rotate-45 shrink-0 bg-sky-500 mx-1" />
                  <span className="h-px flex-1 bg-gradient-to-r from-sky-500 via-sky-400/55 to-transparent" />
                </span>
                <h1 className="text-2xl font-bold text-slate-800 shrink-0 px-1">趣玩星球</h1>
                <span className="flex-1 flex items-center min-w-0" aria-hidden>
                  <span className="h-px flex-1 bg-gradient-to-r from-transparent via-sky-400/55 to-sky-500" />
                  <span className="w-1.5 h-1.5 rotate-45 shrink-0 bg-sky-500 mx-1" />
                  <span className="h-px flex-1 bg-gradient-to-r from-sky-500/90 via-sky-400/40 to-transparent" />
                </span>
              </div>
              <p className="text-sm text-slate-500 mt-1.5">管理后台注册</p>
            </div>
            <form onSubmit={onSubmit} className="flex flex-col gap-3 min-h-0">
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-slate-500">登录账号</span>
                <input
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="至少 3 位，字母/数字/下划线"
                  className="px-4 py-2.5 rounded-md border border-slate-200 bg-white/90 text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-sky-300"
                  autoComplete="username"
                  required
                />
              </label>
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-slate-500">管理员姓名（选填）</span>
                <input
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="默认同账号"
                  className="px-4 py-2.5 rounded-md border border-slate-200 bg-white/90 text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-sky-300"
                  autoComplete="name"
                />
              </label>
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-slate-500">密码</span>
                <PasswordInput
                  value={password}
                  onChange={setPassword}
                  placeholder="至少 6 位"
                  autoComplete="new-password"
                  required
                  className={fieldClass}
                />
              </label>
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-slate-500">确认密码</span>
                <PasswordInput
                  value={confirmPassword}
                  onChange={setConfirmPassword}
                  placeholder="至少 6 位"
                  autoComplete="new-password"
                  required
                  className={fieldClass}
                />
              </label>
              <button
                type="submit"
                disabled={submitting}
                className="mt-1 py-2.5 rounded-md bg-primary text-primary-foreground font-medium hover:opacity-90 disabled:opacity-60"
              >
                {submitting ? "注册中…" : "注册并登录"}
              </button>
            </form>
            <p className="text-sm text-center text-slate-500 mt-4 shrink-0">
              已有账号？{" "}
              <Link to="/login" className="text-sky-600 font-medium hover:underline">
                去登录
              </Link>
            </p>
          </div>
        </div>
        <div className="hidden lg:block lg:col-span-4" aria-hidden />
      </div>
    </div>
  );
}

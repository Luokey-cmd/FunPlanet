import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { toast } from "sonner";
import { useAuth } from "../contexts/AuthContext";
import { ApiError } from "../lib/api";

import SunMoonToggle from "../components/SunMoonToggle";

export default function LoginPage() {
  const { login, token } = useAuth();
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
    <div className="min-h-screen flex items-center justify-center p-6 bg-background relative">
      <div className="absolute top-6 right-6">
        <SunMoonToggle />
      </div>
      <div className="w-full max-w-md rounded-3xl border border-border bg-card shadow-custom p-8">
        <div className="text-center mb-8">
          <div className="inline-flex w-14 h-14 rounded-2xl bg-primary items-center justify-center text-2xl mb-4">
            🪐
          </div>
          <h1 className="text-2xl font-bold text-foreground">趣玩星球</h1>
          <p className="text-sm text-muted-foreground mt-1">管理后台登录</p>
        </div>
        <form onSubmit={onSubmit} className="flex flex-col gap-4">
          <label className="flex flex-col gap-1.5 text-sm">
            <span className="text-muted-foreground">账号</span>
            <input
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="px-4 py-3 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
              autoComplete="username"
            />
          </label>
          <label className="flex flex-col gap-1.5 text-sm">
            <span className="text-muted-foreground">密码</span>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="px-4 py-3 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
              autoComplete="current-password"
            />
          </label>
          <button
            type="submit"
            disabled={submitting}
            className="mt-2 py-3 rounded-xl bg-primary text-primary-foreground font-medium hover:opacity-90 disabled:opacity-60"
          >
            {submitting ? "登录中…" : "登录"}
          </button>
        </form>
        <p className="text-sm text-center text-muted-foreground mt-6">
          没有账号？{" "}
          <Link to="/register" className="text-primary font-medium hover:underline">
            立即注册
          </Link>
        </p>
        <p className="text-xs text-muted-foreground text-center mt-3">
          内置账号 admin / admin123（可在服务端 .env 配置）
        </p>
      </div>
    </div>
  );
}

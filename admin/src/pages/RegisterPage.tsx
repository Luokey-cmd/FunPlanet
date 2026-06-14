import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { toast } from "sonner";
import SunMoonToggle from "../components/SunMoonToggle";
import { useAuth } from "../contexts/AuthContext";
import { ApiError } from "../lib/api";

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
          <p className="text-sm text-muted-foreground mt-1">管理后台注册</p>
        </div>
        <form onSubmit={onSubmit} className="flex flex-col gap-4">
          <label className="flex flex-col gap-1.5 text-sm">
            <span className="text-muted-foreground">登录账号</span>
            <input
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="至少 3 位，字母/数字/下划线"
              className="px-4 py-3 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
              autoComplete="username"
              required
            />
          </label>
          <label className="flex flex-col gap-1.5 text-sm">
            <span className="text-muted-foreground">管理员姓名（选填）</span>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="默认同账号"
              className="px-4 py-3 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
              autoComplete="name"
            />
          </label>
          <label className="flex flex-col gap-1.5 text-sm">
            <span className="text-muted-foreground">密码</span>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="至少 6 位"
              className="px-4 py-3 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
              autoComplete="new-password"
              required
            />
          </label>
          <label className="flex flex-col gap-1.5 text-sm">
            <span className="text-muted-foreground">确认密码</span>
            <input
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              className="px-4 py-3 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
              autoComplete="new-password"
              required
            />
          </label>
          <button
            type="submit"
            disabled={submitting}
            className="mt-2 py-3 rounded-xl bg-primary text-primary-foreground font-medium hover:opacity-90 disabled:opacity-60"
          >
            {submitting ? "注册中…" : "注册并登录"}
          </button>
        </form>
        <p className="text-sm text-center text-muted-foreground mt-6">
          已有账号？{" "}
          <Link to="/login" className="text-primary font-medium hover:underline">
            去登录
          </Link>
        </p>
      </div>
    </div>
  );
}

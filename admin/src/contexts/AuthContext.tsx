import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";import { adminApi, clearToken, getToken, setToken, type AdminInfo } from "../lib/api";

interface AuthContextValue {
  token: string | null;
  admin: AdminInfo | null;
  loading: boolean;
  login: (username: string, password: string) => Promise<void>;
  register: (body: {
    username: string;
    password: string;
    confirmPassword: string;
    name?: string;
  }) => Promise<void>;
  logout: () => void;
  refreshAdmin: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [token, setTokenState] = useState<string | null>(getToken());
  const [admin, setAdmin] = useState<AdminInfo | null>(null);
  const [loading, setLoading] = useState(true);

  const refreshAdmin = useCallback(async () => {
    const res = await adminApi.me();
    setAdmin(res.admin);
  }, []);

  useEffect(() => {
    if (!token) {
      setLoading(false);
      return;
    }
    refreshAdmin()
      .catch(() => {
        clearToken();
        setTokenState(null);
        setAdmin(null);
      })
      .finally(() => setLoading(false));
  }, [token]);

  const value = useMemo<AuthContextValue>(
    () => ({
      token,
      admin,
      loading,
      login: async (username, password) => {
        const res = await adminApi.login(username, password);
        setToken(res.token);
        setTokenState(res.token);
        setAdmin(res.admin);
      },
      register: async (body) => {
        const res = await adminApi.register(body);
        setToken(res.token);
        setTokenState(res.token);
        setAdmin(res.admin);
      },
      logout: () => {
        clearToken();
        setTokenState(null);
        setAdmin(null);
      },
      refreshAdmin,
    }),
    [token, admin, loading, refreshAdmin],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}

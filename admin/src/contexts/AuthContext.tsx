import { useQueryClient } from "@tanstack/react-query";
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import {
  clearSavedAccountToken,
  findSavedAccount,
  loadSavedAccounts,
  removeSavedAccount,
  upsertSavedAccount,
  type SavedAdminAccount,
} from "../lib/account-store";
import { adminApi, clearToken, getToken, setToken, type AdminInfo } from "../lib/api";

interface AuthContextValue {
  token: string | null;
  admin: AdminInfo | null;
  loading: boolean;
  savedAccounts: SavedAdminAccount[];
  login: (username: string, password: string) => Promise<void>;
  register: (body: {
    username: string;
    password: string;
    confirmPassword: string;
    name?: string;
  }) => Promise<void>;
  logout: () => void;
  switchAccount: (username: string) => Promise<void>;
  beginAddAccount: () => void;
  removeAccount: (username: string) => void;
  refreshAdmin: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const queryClient = useQueryClient();
  const [token, setTokenState] = useState<string | null>(getToken());
  const [admin, setAdmin] = useState<AdminInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [savedAccounts, setSavedAccounts] = useState<SavedAdminAccount[]>(() => loadSavedAccounts());

  const rememberAccount = useCallback((info: AdminInfo, nextToken: string) => {
    setSavedAccounts(
      upsertSavedAccount({
        username: info.username,
        name: info.name,
        avatarPath: info.avatarPath,
        token: nextToken,
        lastUsedAt: Date.now(),
      }),
    );
  }, []);

  const refreshAdmin = useCallback(async () => {
    const res = await adminApi.me();
    setAdmin(res.admin);
    const current = getToken();
    if (current) rememberAccount(res.admin, current);
  }, [rememberAccount]);

  useEffect(() => {
    if (!token) {
      setLoading(false);
      return;
    }
    refreshAdmin()
      .catch(() => {
        // 会话失效：结束当前登录，但保留账号卡片（清空其 token，需重新登录）
        const expired = loadSavedAccounts().find((item) => item.token === token);
        if (expired) setSavedAccounts(clearSavedAccountToken(expired.username));
        clearToken();
        setTokenState(null);
        setAdmin(null);
      })
      .finally(() => setLoading(false));
    // 仅随 token 拉取一次当前管理员
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  const activateSession = useCallback(
    (nextToken: string, info: AdminInfo) => {
      setToken(nextToken);
      setTokenState(nextToken);
      setAdmin(info);
      rememberAccount(info, nextToken);
      queryClient.clear();
    },
    [queryClient, rememberAccount],
  );

  const endSession = useCallback(() => {
    clearToken();
    setTokenState(null);
    setAdmin(null);
    queryClient.clear();
  }, [queryClient]);

  const value = useMemo<AuthContextValue>(
    () => ({
      token,
      admin,
      loading,
      savedAccounts,
      login: async (username, password) => {
        const res = await adminApi.login(username, password);
        activateSession(res.token, res.admin);
      },
      register: async (body) => {
        const res = await adminApi.register(body);
        activateSession(res.token, res.admin);
      },
      // 退出只结束当前会话，已登录过的账号仍保留在列表中
      logout: () => {
        endSession();
      },
      switchAccount: async (username) => {
        if (admin?.username === username) return;
        const target = findSavedAccount(username);
        if (!target) throw new Error("账号不存在");
        if (!target.token) throw new Error("该账号需重新登录");
        const previousToken = getToken();
        const previousAdmin = admin;
        setToken(target.token);
        try {
          const res = await adminApi.me();
          activateSession(target.token, res.admin);
        } catch (error) {
          setSavedAccounts(clearSavedAccountToken(username));
          if (previousToken) {
            setToken(previousToken);
            setTokenState(previousToken);
            setAdmin(previousAdmin);
          } else {
            clearToken();
            setTokenState(null);
            setAdmin(null);
          }
          throw error;
        }
      },
      beginAddAccount: () => {
        endSession();
      },
      removeAccount: (username) => {
        const isCurrent = admin?.username === username;
        setSavedAccounts(removeSavedAccount(username));
        if (isCurrent) endSession();
      },
      refreshAdmin,
    }),
    [token, admin, loading, savedAccounts, refreshAdmin, activateSession, endSession],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}

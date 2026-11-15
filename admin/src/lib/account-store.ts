const ACCOUNTS_KEY = "funplanet_admin_accounts";

export type SavedAdminAccount = {
  username: string;
  name: string;
  avatarPath?: string | null;
  token: string;
  lastUsedAt: number;
};

export function loadSavedAccounts(): SavedAdminAccount[] {
  try {
    const raw = localStorage.getItem(ACCOUNTS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter(
        (item): item is SavedAdminAccount =>
          Boolean(
            item &&
              typeof item === "object" &&
              typeof (item as SavedAdminAccount).username === "string" &&
              typeof (item as SavedAdminAccount).token === "string",
          ),
      )
      .sort((a, b) => (b.lastUsedAt ?? 0) - (a.lastUsedAt ?? 0));
  } catch {
    return [];
  }
}

function persist(accounts: SavedAdminAccount[]) {
  localStorage.setItem(ACCOUNTS_KEY, JSON.stringify(accounts));
}

export function upsertSavedAccount(account: SavedAdminAccount): SavedAdminAccount[] {
  const next = loadSavedAccounts().filter((item) => item.username !== account.username);
  next.unshift(account);
  persist(next);
  return next;
}

export function removeSavedAccount(username: string): SavedAdminAccount[] {
  const next = loadSavedAccounts().filter((item) => item.username !== username);
  persist(next);
  return next;
}

export function findSavedAccount(username: string): SavedAdminAccount | undefined {
  return loadSavedAccounts().find((item) => item.username === username);
}

/** 清除某个账号的 token，但仍保留在列表中（需重新登录才能切换） */
export function clearSavedAccountToken(username: string): SavedAdminAccount[] {
  const next = loadSavedAccounts().map((item) =>
    item.username === username ? { ...item, token: "" } : item,
  );
  persist(next);
  return next;
}

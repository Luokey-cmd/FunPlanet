import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SETTINGS_PATH = path.join(__dirname, '../../data/admin-settings.json');

const DEFAULTS = {
  displayName: '趣玩星球管理员',
  systemName: '趣玩星球管理后台',
  password: null,
  avatarPath: null,
  notifications: {
    orderNotify: true,
    userNotify: true,
    systemNotify: true,
  },
};

function mergeSettings(parsed = {}) {
  return {
    ...DEFAULTS,
    ...parsed,
    notifications: { ...DEFAULTS.notifications, ...(parsed.notifications ?? {}) },
  };
}

export function readAdminSettings() {
  try {
    const raw = fs.readFileSync(SETTINGS_PATH, 'utf8');
    return mergeSettings(JSON.parse(raw));
  } catch {
    return mergeSettings();
  }
}

export function writeAdminSettings(partial) {
  const current = readAdminSettings();
  const next = mergeSettings({
    ...current,
    ...partial,
    notifications: partial.notifications
      ? { ...current.notifications, ...partial.notifications }
      : current.notifications,
  });
  fs.mkdirSync(path.dirname(SETTINGS_PATH), { recursive: true });
  fs.writeFileSync(SETTINGS_PATH, JSON.stringify(next, null, 2), 'utf8');
  return next;
}

export function getAdminUsername() {
  return process.env.ADMIN_USERNAME || 'admin';
}

export function getEffectivePassword() {
  const settings = readAdminSettings();
  return settings.password ?? process.env.ADMIN_PASSWORD ?? 'admin123';
}

export function verifyAdminPassword(password) {
  return password === getEffectivePassword();
}

export function getAdminProfile(username) {
  const settings = readAdminSettings();
  const resolvedUsername = username ?? getAdminUsername();
  return {
    username: resolvedUsername,
    name: settings.displayName,
    systemName: settings.systemName,
    avatarPath: settings.avatarPath ?? null,
    notifications: settings.notifications,
  };
}

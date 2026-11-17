import {
  createAdminAccount,
  findAdminAccount,
  getAccountRole,
  isRegisteredAdmin,
  updateAdminAccountAvatar,
  updateAdminAccountName,
  updateAdminAccountPassword,
  verifyRegisteredAdmin,
} from '../utils/admin-accounts.js';
import {
  getAdminProfile,
  getAdminUsername,
  readAdminSettings,
  verifyAdminPassword,
  writeAdminSettings,
} from '../utils/admin-settings.js';

// 角色解析：内置默认管理员永远是超级管理员；注册账号读账号文件里的 role
export function resolveAdminRole(username) {
  if (username === getAdminUsername()) return 'super';
  return getAccountRole(findAdminAccount(username));
}

export function resolveAdminProfile(username) {
  const account = findAdminAccount(username);
  const settings = readAdminSettings();
  if (account) {
    return {
      username: account.username,
      name: account.name,
      systemName: settings.systemName,
      avatarPath: account.avatarPath ?? null,
      notifications: settings.notifications,
      role: resolveAdminRole(username),
    };
  }
  return { ...getAdminProfile(username), role: resolveAdminRole(username) };
}

export { createAdminAccount, verifyRegisteredAdmin, isRegisteredAdmin };

export async function changeAdminPassword(username, currentPassword, newPassword) {
  if (isRegisteredAdmin(username)) {
    return updateAdminAccountPassword(username, currentPassword, newPassword);
  }
  if (username === getAdminUsername() && verifyAdminPassword(currentPassword)) {
    writeAdminSettings({ password: newPassword });
    return true;
  }
  return false;
}

export function updateAdminDisplayName(username, displayName) {
  if (isRegisteredAdmin(username)) {
    return updateAdminAccountName(username, displayName);
  }
  if (username === getAdminUsername()) {
    writeAdminSettings({ displayName });
    return true;
  }
  return false;
}

export function updateAdminAvatar(username, avatarPath) {
  if (isRegisteredAdmin(username)) {
    return updateAdminAccountAvatar(username, avatarPath);
  }
  if (username === getAdminUsername()) {
    writeAdminSettings({ avatarPath });
    return true;
  }
  return false;
}

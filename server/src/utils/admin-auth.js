import {
  createAdminAccount,
  findAdminAccount,
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
    };
  }
  if (username === getAdminUsername()) {
    return getAdminProfile(username);
  }
  return getAdminProfile(username);
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

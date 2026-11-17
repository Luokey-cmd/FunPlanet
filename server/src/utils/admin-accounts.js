import fs from 'fs';
import path from 'path';
import bcrypt from 'bcryptjs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ACCOUNTS_PATH = path.join(__dirname, '../../data/admin-accounts.json');

function writeAccounts(accounts) {
  fs.mkdirSync(path.dirname(ACCOUNTS_PATH), { recursive: true });
  fs.writeFileSync(ACCOUNTS_PATH, JSON.stringify(accounts, null, 2), 'utf8');
}

export function readAdminAccounts() {
  try {
    const raw = fs.readFileSync(ACCOUNTS_PATH, 'utf8');
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

export function findAdminAccount(username) {
  return readAdminAccounts().find((a) => a.username === username) ?? null;
}

// 后台角色：super 超级管理员 / operator 运营管理员 / support 客服专员
export const ADMIN_ROLES = ['super', 'operator', 'support'];

export function normalizeAdminRole(role) {
  return ADMIN_ROLES.includes(role) ? role : 'operator';
}

// 注册账号的角色：老账号没有 role 字段时按运营管理员处理
export function getAccountRole(account) {
  return account ? normalizeAdminRole(account.role) : 'operator';
}

export async function verifyRegisteredAdmin(username, password) {
  const account = findAdminAccount(username);
  if (!account) return null;
  if (account.disabled) {
    const err = new Error('ACCOUNT_DISABLED');
    err.code = 'ACCOUNT_DISABLED';
    throw err;
  }
  const match = await bcrypt.compare(password, account.passwordHash);
  if (!match) return null;
  return { username: account.username, name: account.name };
}

export async function createAdminAccount({ username, password, name }) {
  const accounts = readAdminAccounts();
  if (accounts.some((a) => a.username === username)) {
    const err = new Error('USERNAME_TAKEN');
    err.code = 'USERNAME_TAKEN';
    throw err;
  }
  const passwordHash = await bcrypt.hash(password, 10);
  const account = {
    username,
    passwordHash,
    name: name || username,
    avatarPath: null,
    role: 'operator',
    disabled: false,
    createdAt: new Date().toISOString(),
  };
  accounts.push(account);
  writeAccounts(accounts);
  return { username: account.username, name: account.name };
}

export function updateAdminAccountName(username, name) {
  const accounts = readAdminAccounts();
  const idx = accounts.findIndex((a) => a.username === username);
  if (idx === -1) return false;
  accounts[idx].name = name;
  writeAccounts(accounts);
  return true;
}

export function updateAdminAccountAvatar(username, avatarPath) {
  const accounts = readAdminAccounts();
  const idx = accounts.findIndex((a) => a.username === username);
  if (idx === -1) return false;
  accounts[idx].avatarPath = avatarPath;
  writeAccounts(accounts);
  return true;
}

export async function updateAdminAccountPassword(username, currentPassword, newPassword) {
  const accounts = readAdminAccounts();
  const idx = accounts.findIndex((a) => a.username === username);
  if (idx === -1) return false;
  const match = await bcrypt.compare(currentPassword, accounts[idx].passwordHash);
  if (!match) return false;
  accounts[idx].passwordHash = await bcrypt.hash(newPassword, 10);
  writeAccounts(accounts);
  return true;
}

export function isRegisteredAdmin(username) {
  return findAdminAccount(username) != null;
}

export function updateAdminAccountRole(username, role) {
  const accounts = readAdminAccounts();
  const idx = accounts.findIndex((a) => a.username === username);
  if (idx === -1) return false;
  accounts[idx].role = normalizeAdminRole(role);
  writeAccounts(accounts);
  return true;
}

export function setAdminAccountDisabled(username, disabled) {
  const accounts = readAdminAccounts();
  const idx = accounts.findIndex((a) => a.username === username);
  if (idx === -1) return false;
  accounts[idx].disabled = Boolean(disabled);
  writeAccounts(accounts);
  return true;
}

// 给管理员管理页用的安全列表：不含密码哈希
export function listAdminAccountsSafe() {
  return readAdminAccounts().map((a) => ({
    username: a.username,
    name: a.name,
    avatarPath: a.avatarPath ?? null,
    role: getAccountRole(a),
    disabled: Boolean(a.disabled),
    createdAt: a.createdAt ?? null,
    builtin: false,
  }));
}

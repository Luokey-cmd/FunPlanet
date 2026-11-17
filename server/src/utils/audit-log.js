import fs from 'fs';
import path from 'path';
import { randomUUID } from 'crypto';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const AUDIT_PATH = path.join(__dirname, '../../data/admin-audit-log.json');
const MAX_ENTRIES = 500;

function writeEntries(entries) {
  fs.mkdirSync(path.dirname(AUDIT_PATH), { recursive: true });
  fs.writeFileSync(AUDIT_PATH, JSON.stringify(entries, null, 2), 'utf8');
}

export function readAuditLog() {
  try {
    const parsed = JSON.parse(fs.readFileSync(AUDIT_PATH, 'utf8'));
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

// 记录一条管理员操作日志；写失败不影响主流程
export function appendAuditLog({ username, name, action, detail }) {
  try {
    const entries = readAuditLog();
    entries.unshift({
      id: randomUUID(),
      time: new Date().toISOString(),
      username: username ?? '',
      name: name ?? username ?? '',
      action,
      detail: detail ?? '',
    });
    writeEntries(entries.slice(0, MAX_ENTRIES));
  } catch {
    // 忽略日志写入错误
  }
}

export function clearAuditLog() {
  writeEntries([]);
}

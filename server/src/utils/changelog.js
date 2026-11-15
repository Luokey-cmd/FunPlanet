import fs from 'fs';
import path from 'path';
import { randomUUID } from 'crypto';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CHANGELOG_PATH = path.join(__dirname, '../../data/changelog.json');

const DEFAULT_ENTRIES = [
  {
    id: 'cl-001',
    version: '1.2.0',
    title: '管理后台体验升级',
    date: '2026-06-07',
    tag: 'feature',
    items: [
      '新增更新日志模块，支持发布、编辑与删除',
      '新增管理员注册与账户体系',
      '支持白天/黑夜主题切换与平滑过渡动画',
      '系统设置完善：账户信息、安全、通知、数据管理',
      '网站 favicon 更换为趣玩星球应用图标',
    ],
  },
  {
    id: 'cl-002',
    version: '1.1.0',
    title: '业务功能增强',
    date: '2026-06-04',
    tag: 'feature',
    items: [
      '商品管理支持缩略图、收藏数展示',
      '订单销量改为真实已付款统计',
      '轮播图、优惠券管理上线',
      '数据看板与营收分析图表',
    ],
  },
  {
    id: 'cl-003',
    version: '1.0.0',
    title: '趣玩星球管理后台首发',
    date: '2026-06-01',
    tag: 'feature',
    items: [
      '管理员登录与 JWT 鉴权',
      '商品、订单、用户基础管理',
      'Labubu 夏日蓝主题界面',
      '与 App 端 API 数据打通',
    ],
  },
];

function writeEntries(entries) {
  fs.mkdirSync(path.dirname(CHANGELOG_PATH), { recursive: true });
  fs.writeFileSync(CHANGELOG_PATH, JSON.stringify(entries, null, 2), 'utf8');
}

export function readChangelog() {
  try {
    const raw = fs.readFileSync(CHANGELOG_PATH, 'utf8');
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed) || parsed.length === 0) {
      writeEntries(DEFAULT_ENTRIES);
      return [...DEFAULT_ENTRIES];
    }
    return parsed.sort((a, b) => String(b.date).localeCompare(String(a.date)));
  } catch {
    writeEntries(DEFAULT_ENTRIES);
    return [...DEFAULT_ENTRIES];
  }
}

export function createChangelogEntry(body) {
  const version = String(body.version ?? '').trim();
  const title = String(body.title ?? '').trim();
  const date = String(body.date ?? '').trim() || new Date().toISOString().slice(0, 10);
  const tag = ['feature', 'fix', 'improve'].includes(body.tag) ? body.tag : 'feature';
  const items = normalizeItems(body.items);

  if (!version) throw new Error('VERSION_REQUIRED');
  if (!title) throw new Error('TITLE_REQUIRED');
  if (!items.length) throw new Error('ITEMS_REQUIRED');

  const entry = { id: randomUUID(), version, title, date, tag, items };
  const entries = readChangelog();
  entries.unshift(entry);
  writeEntries(entries);
  return entry;
}

export function updateChangelogEntry(id, body) {
  const entries = readChangelog();
  const idx = entries.findIndex((e) => e.id === id);
  if (idx === -1) return null;

  const current = entries[idx];
  const next = {
    ...current,
    version: body.version != null ? String(body.version).trim() : current.version,
    title: body.title != null ? String(body.title).trim() : current.title,
    date: body.date != null ? String(body.date).trim() : current.date,
    tag: body.tag != null && ['feature', 'fix', 'improve'].includes(body.tag) ? body.tag : current.tag,
    items: body.items != null ? normalizeItems(body.items) : current.items,
  };

  if (!next.version || !next.title || !next.items.length) {
    throw new Error('INVALID_ENTRY');
  }

  entries[idx] = next;
  writeEntries(entries);
  return next;
}

export function deleteChangelogEntry(id) {
  const entries = readChangelog();
  const next = entries.filter((e) => e.id !== id);
  if (next.length === entries.length) return false;
  writeEntries(next);
  return true;
}

function normalizeItems(items) {
  if (Array.isArray(items)) {
    return items.map((i) => String(i).trim()).filter(Boolean);
  }
  return String(items ?? '')
    .split('\n')
    .map((i) => i.trim())
    .filter(Boolean);
}

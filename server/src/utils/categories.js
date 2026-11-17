import fs from 'fs';
import path from 'path';
import { randomUUID } from 'crypto';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CATEGORIES_PATH = path.join(__dirname, '../../data/categories.json');

// 与此前写在前端的六大分类保持一致，第一次读取时落盘为可管理数据
const DEFAULT_CATEGORIES = [
  { id: 'cat-toy', name: '玩具', sortOrder: 1 },
  { id: 'cat-plush', name: '公仔', sortOrder: 2 },
  { id: 'cat-figure', name: '手办', sortOrder: 3 },
  { id: 'cat-merch', name: '谷子', sortOrder: 4 },
  { id: 'cat-card', name: '小卡', sortOrder: 5 },
  { id: 'cat-stationery', name: '文具', sortOrder: 6 },
];

function writeCategories(categories) {
  fs.mkdirSync(path.dirname(CATEGORIES_PATH), { recursive: true });
  fs.writeFileSync(CATEGORIES_PATH, JSON.stringify(categories, null, 2), 'utf8');
}

function sortCategories(list) {
  return [...list].sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0) || a.name.localeCompare(b.name));
}

export function readCategories() {
  try {
    const raw = fs.readFileSync(CATEGORIES_PATH, 'utf8');
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) throw new Error('INVALID_CATEGORIES_FILE');
    return sortCategories(parsed);
  } catch {
    writeCategories(DEFAULT_CATEGORIES);
    return sortCategories(DEFAULT_CATEGORIES);
  }
}

export function createCategory(body) {
  const name = String(body.name ?? '').trim();
  if (!name) throw new Error('NAME_REQUIRED');
  const categories = readCategories();
  if (categories.some((c) => c.name === name)) throw new Error('NAME_TAKEN');
  const sortOrder =
    body.sortOrder != null && body.sortOrder !== '' ? Number(body.sortOrder) : categories.length + 1;
  const category = { id: randomUUID(), name, sortOrder: Number.isNaN(sortOrder) ? categories.length + 1 : sortOrder };
  categories.push(category);
  writeCategories(categories);
  return category;
}

export function updateCategory(id, body) {
  const categories = readCategories();
  const idx = categories.findIndex((c) => c.id === id);
  if (idx === -1) return null;
  const current = categories[idx];
  const name = body.name != null ? String(body.name).trim() : current.name;
  if (!name) throw new Error('NAME_REQUIRED');
  if (categories.some((c) => c.id !== id && c.name === name)) throw new Error('NAME_TAKEN');
  const sortOrder =
    body.sortOrder != null && body.sortOrder !== '' ? Number(body.sortOrder) : current.sortOrder;
  const next = { ...current, name, sortOrder: Number.isNaN(sortOrder) ? current.sortOrder : sortOrder };
  categories[idx] = next;
  writeCategories(categories);
  return { category: next, renamedFrom: name !== current.name ? current.name : null };
}

export function deleteCategory(id) {
  const categories = readCategories();
  const target = categories.find((c) => c.id === id);
  if (!target) return null;
  writeCategories(categories.filter((c) => c.id !== id));
  return target;
}

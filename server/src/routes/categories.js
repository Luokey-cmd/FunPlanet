import { Router } from 'express';
import { ok } from '../utils/response.js';

const router = Router();

const categories = [
  { id: 'toy', name: '玩具' },
  { id: 'stationery', name: '文具' },
  { id: 'figure', name: '手办' },
  { id: 'doll', name: '公仔' },
  { id: 'merch', name: '谷子' },
  { id: 'card', name: '小卡' },
];

router.get('/', (_req, res) => {
  ok(res, { categories });
});

export default router;

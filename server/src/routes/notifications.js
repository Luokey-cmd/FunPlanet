import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';

const router = Router();

function serializeNotification(row) {
  return {
    id: row.id,
    title: row.title,
    body: row.body,
    type: row.type,
    read: row.read,
    createdAt: row.createdAt.toISOString(),
  };
}

router.get('/', authRequired, async (req, res) => {
  const rows = await prisma.notification.findMany({
    where: { userId: req.user.sub },
    orderBy: { createdAt: 'desc' },
  });
  ok(res, { notifications: rows.map(serializeNotification) });
});

router.put('/read-all', authRequired, async (req, res) => {
  await prisma.notification.updateMany({
    where: { userId: req.user.sub, read: false },
    data: { read: true },
  });
  ok(res, { updated: true });
});

router.put('/:id/read', authRequired, async (req, res) => {
  const id = String(req.params.id ?? '').trim();
  const row = await prisma.notification.findFirst({
    where: { id, userId: req.user.sub },
  });
  if (!row) return fail(res, 404, '通知不存在');

  const updated = await prisma.notification.update({
    where: { id },
    data: { read: true },
  });
  ok(res, { notification: serializeNotification(updated) });
});

export default router;

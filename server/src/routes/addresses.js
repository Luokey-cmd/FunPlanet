import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';

const router = Router();

function serializeAddress(row) {
  return {
    id: row.id,
    name: row.name,
    phone: row.phone,
    detail: row.detail,
    isDefault: row.isDefault,
  };
}

function validateAddressInput(name, phone, detail) {
  if (!name) return '请填写收货人';
  if (!phone) return '请填写手机号';
  if (!detail) return '请填写详细地址';
  return null;
}

router.get('/', authRequired, async (req, res) => {
  const rows = await prisma.address.findMany({
    where: { userId: req.user.sub },
    orderBy: [{ isDefault: 'desc' }, { updatedAt: 'desc' }],
  });
  ok(res, { addresses: rows.map(serializeAddress) });
});

router.post('/', authRequired, async (req, res) => {
  const name = String(req.body?.name ?? '').trim();
  const phone = String(req.body?.phone ?? '').trim();
  const detail = String(req.body?.detail ?? '').trim();
  const isDefault = Boolean(req.body?.isDefault);

  const inputError = validateAddressInput(name, phone, detail);
  if (inputError) return fail(res, 400, inputError);

  const row = await prisma.$transaction(async (tx) => {
    if (isDefault) {
      await tx.address.updateMany({
        where: { userId: req.user.sub },
        data: { isDefault: false },
      });
    }
    const count = await tx.address.count({ where: { userId: req.user.sub } });
    return tx.address.create({
      data: {
        userId: req.user.sub,
        name,
        phone,
        detail,
        isDefault: isDefault || count === 0,
      },
    });
  });

  ok(res, { address: serializeAddress(row) });
});

router.put('/:id/default', authRequired, async (req, res) => {
  const id = String(req.params.id ?? '').trim();
  const existing = await prisma.address.findFirst({
    where: { id, userId: req.user.sub },
  });
  if (!existing) return fail(res, 404, '地址不存在');

  const row = await prisma.$transaction(async (tx) => {
    await tx.address.updateMany({
      where: { userId: req.user.sub },
      data: { isDefault: false },
    });
    return tx.address.update({
      where: { id },
      data: { isDefault: true },
    });
  });

  ok(res, { address: serializeAddress(row) });
});

router.put('/:id', authRequired, async (req, res) => {
  const id = String(req.params.id ?? '').trim();
  const name = String(req.body?.name ?? '').trim();
  const phone = String(req.body?.phone ?? '').trim();
  const detail = String(req.body?.detail ?? '').trim();
  const isDefault = Boolean(req.body?.isDefault);

  const existing = await prisma.address.findFirst({
    where: { id, userId: req.user.sub },
  });
  if (!existing) return fail(res, 404, '地址不存在');

  const inputError = validateAddressInput(name, phone, detail);
  if (inputError) return fail(res, 400, inputError);

  const row = await prisma.$transaction(async (tx) => {
    if (isDefault) {
      await tx.address.updateMany({
        where: { userId: req.user.sub },
        data: { isDefault: false },
      });
    }
    return tx.address.update({
      where: { id },
      data: { name, phone, detail, isDefault: isDefault || existing.isDefault },
    });
  });

  ok(res, { address: serializeAddress(row) });
});

router.delete('/:id', authRequired, async (req, res) => {
  const id = String(req.params.id ?? '').trim();
  const existing = await prisma.address.findFirst({
    where: { id, userId: req.user.sub },
  });
  if (!existing) return fail(res, 404, '地址不存在');

  await prisma.$transaction(async (tx) => {
    await tx.address.delete({ where: { id } });
    if (existing.isDefault) {
      const next = await tx.address.findFirst({
        where: { userId: req.user.sub },
        orderBy: { updatedAt: 'desc' },
      });
      if (next) {
        await tx.address.update({ where: { id: next.id }, data: { isDefault: true } });
      }
    }
  });

  ok(res, { removed: true });
});

export default router;

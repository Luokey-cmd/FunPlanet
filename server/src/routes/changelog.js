import { Router } from 'express';
import { readChangelog } from '../utils/changelog.js';
import { ok } from '../utils/response.js';

const router = Router();

router.get('/', (_req, res) => {
  ok(res, { entries: readChangelog() });
});

export default router;

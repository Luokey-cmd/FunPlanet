import { verifyToken } from '../utils/jwt.js';
import { fail } from '../utils/response.js';

export function authRequired(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    fail(res, 401, '未登录');
    return;
  }
  try {
    req.user = verifyToken(token);
    next();
  } catch {
    fail(res, 401, '登录已过期，请重新登录');
  }
}

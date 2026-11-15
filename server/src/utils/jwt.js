import jwt from 'jsonwebtoken';
import { getJwtSecret } from './startup-check.js';

export function signToken(payload) {
  return jwt.sign(payload, getJwtSecret(), { expiresIn: '7d' });
}

export function verifyToken(token) {
  return jwt.verify(token, getJwtSecret());
}

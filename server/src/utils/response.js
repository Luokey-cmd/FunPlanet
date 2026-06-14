export function ok(res, data) {
  res.json({ code: 0, message: 'ok', data });
}

export function fail(res, status, message, code = status) {
  res.status(status).json({ code, message, data: null });
}

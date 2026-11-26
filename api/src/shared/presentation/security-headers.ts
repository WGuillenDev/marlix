import type { RequestHandler } from 'express';

const SECURITY_HEADERS: Readonly<Record<string, string>> = {
  'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  'Content-Security-Policy': "default-src 'none'; frame-ancestors 'none'",
};

export const securityHeaders: RequestHandler = (_req, res, next) => {
  res.set(SECURITY_HEADERS);
  next();
};

/** /v1 carries personal messages: no cache, browser or intermediary, may keep them. */
export const noStore: RequestHandler = (_req, res, next) => {
  res.set('Cache-Control', 'no-store');
  next();
};

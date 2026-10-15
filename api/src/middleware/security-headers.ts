// HTTP security headers (S2-9). The API only returns JSON, so a few fixed
// headers are enough; why not helmet is in docs/decisions.md.
import type { RequestHandler } from 'express';

const SECURITY_HEADERS: Readonly<Record<string, string>> = {
  // HTTPS only, for a year, on this host and its subdomains.
  'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  // Nothing to load or embed: no page here is meant for a browser.
  'Content-Security-Policy': "default-src 'none'; frame-ancestors 'none'",
};

/** Applies to every response, errors included. */
export const securityHeaders: RequestHandler = (_req, res, next) => {
  res.set(SECURITY_HEADERS);
  next();
};

/** /v1 carries personal messages: no cache, browser or intermediary, may keep them. */
export const noStore: RequestHandler = (_req, res, next) => {
  res.set('Cache-Control', 'no-store');
  next();
};

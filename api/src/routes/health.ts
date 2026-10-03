import { Router } from 'express';

// GET /health (docs/api-contract.md). Public and outside /v1: the uptime
// monitor calls it every 10 minutes. It never touches the database or Groq.
export const healthRouter = Router();

healthRouter.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

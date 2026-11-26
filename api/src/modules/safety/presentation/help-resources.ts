import { Router } from 'express';

import type { CrisisConfig } from '../domain/crisis-config.js';

export function createHelpResourcesRouter({ updatedAt, resources }: CrisisConfig): Router {
  const router = Router();

  router.get('/help-resources', (_req, res) => {
    res.status(200).json({ updatedAt, resources });
  });

  return router;
}

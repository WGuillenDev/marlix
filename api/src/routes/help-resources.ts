// GET /v1/help-resources (S2-3). Contract: docs/api-contract.md#get-v1help-resources.
import { Router } from 'express';

import type { CrisisConfig } from '../config/crisis-config.js';

/** Public: the help screen must work before sign-in and without the token. */
export function createHelpResourcesRouter({ updatedAt, resources }: CrisisConfig): Router {
  const router = Router();

  router.get('/help-resources', (_req, res) => {
    res.status(200).json({ updatedAt, resources });
  });

  return router;
}

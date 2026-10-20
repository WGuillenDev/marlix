// GET /v1/me and POST /v1/onboarding (S5-5). Contract: docs/api-contract.md#get-v1me.
import { Router } from 'express';
import { z } from 'zod';

import { currentUser } from '../middleware/current-user.js';
import { ApiError } from '../middleware/error-handler.js';
import type { ProfileStore } from '../services/profile/profile-store.js';

const onboardingSchema = z
  .object({
    // Onboarding cannot finish without the explicit consent.
    dataConsent: z.literal(true, { error: 'Must be true: the consent is required' }),
    remindersEnabled: z.boolean(),
  })
  .strict();

export function createProfileRouter(profiles: ProfileStore): Router {
  const router = Router();

  router.get('/me', async (_req, res) => {
    const profile = await profiles.get(currentUser(res).id);
    if (!profile) throw new ApiError(404, 'NOT_FOUND', 'The profile does not exist.');
    res.status(200).json(profile);
  });

  router.post('/onboarding', async (req, res) => {
    const parsed = onboardingSchema.safeParse(req.body);
    if (!parsed.success) {
      throw ApiError.validation(
        'The request body is invalid.',
        parsed.error.issues.map((issue) => ({
          field: issue.path.join('.') || 'body',
          message: issue.message,
        })),
      );
    }
    res
      .status(200)
      .json(await profiles.completeOnboarding(currentUser(res).id, parsed.data.remindersEnabled));
  });

  return router;
}

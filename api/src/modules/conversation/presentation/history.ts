import { Router } from 'express';
import { z } from 'zod';

import { currentUser } from '../../../shared/presentation/current-user.js';
import { ApiError } from '../../../shared/presentation/error-handler.js';
import { decodeCursor, type MessageStore } from '../application/message-store.js';

const querySchema = z
  .object({
    limit: z.coerce.number().int().min(1).max(100).default(50),
    before: z.string().min(1).max(200).optional(),
  })
  .strict();

export function createHistoryRouter(messages: MessageStore): Router {
  const router = Router();

  router.get('/history', async (req, res) => {
    const parsed = querySchema.safeParse(req.query);
    const before = parsed.success && parsed.data.before ? decodeCursor(parsed.data.before) : undefined;
    if (!parsed.success || (parsed.data.before && !before)) {
      const issues = parsed.success
        ? [{ field: 'before', message: 'Must be a cursor from a previous response' }]
        : parsed.error.issues.map((issue) => ({
            field: issue.path.join('.') || 'query',
            message: issue.message,
          }));
      throw ApiError.validation('The query is invalid.', issues);
    }

    const page = await messages.page(currentUser(res).id, {
      limit: parsed.data.limit,
      ...(before ? { before } : {}),
    });
    res.status(200).json(page);
  });

  return router;
}

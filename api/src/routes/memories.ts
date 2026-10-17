// GET, PATCH and DELETE /v1/memories (S4-8). Contract: docs/api-contract.md#get-v1memories.
import { Router } from 'express';
import { z } from 'zod';

import { currentUser } from '../middleware/current-user.js';
import { ApiError } from '../middleware/error-handler.js';
import type { MemoryStore } from '../services/memory/memory-store.js';

const editSchema = z.object({ fact: z.string().trim().min(1).max(500) }).strict();
const idSchema = z.uuid();

export function createMemoriesRouter(memories: MemoryStore): Router {
  const router = Router();

  router.get('/memories', async (_req, res) => {
    const all = await memories.list(currentUser(res).id);
    res.status(200).json({ memories: all.reverse() });
  });

  router.patch('/memories/:id', async (req, res) => {
    const parsed = editSchema.safeParse(req.body);
    if (!parsed.success) {
      throw ApiError.validation(
        'The request body is invalid.',
        parsed.error.issues.map((issue) => ({
          field: issue.path.join('.') || 'body',
          message: issue.message,
        })),
      );
    }
    const memory = await memories.edit(
      currentUser(res).id,
      memoryId(req.params.id),
      parsed.data.fact,
    );
    if (!memory) throw notFound();
    res.status(200).json(memory);
  });

  router.delete('/memories/:id', async (req, res) => {
    if (!(await memories.remove(currentUser(res).id, memoryId(req.params.id)))) throw notFound();
    res.status(204).end();
  });

  router.delete('/memories', async (_req, res) => {
    await memories.removeAll(currentUser(res).id);
    res.status(204).end();
  });

  return router;
}

/** A malformed id cannot exist, so it is a 404 and never reaches the database. */
function memoryId(raw: string | string[] | undefined): string {
  const parsed = idSchema.safeParse(raw);
  if (!parsed.success) throw notFound();
  return parsed.data;
}

function notFound(): ApiError {
  return new ApiError(404, 'NOT_FOUND', 'The memory does not exist.');
}

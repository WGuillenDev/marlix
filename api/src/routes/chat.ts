// POST /v1/chat (S1-5). Contract: docs/api-contract.md#post-v1chat.
import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import type { CrisisConfig } from '../config/crisis-config.js';
import { currentUser } from '../middleware/current-user.js';
import { ApiError } from '../middleware/error-handler.js';
import type { ChatService } from '../services/chat-service.js';
import type { UsageLimiter } from '../services/usage/usage-limiter.js';

const MAX_MESSAGE_LENGTH = 2000;

const chatRequestSchema = z
  .object({
    message: z
      .string()
      .trim()
      .min(1)
      // Counted in characters, not UTF-16 units, so an emoji counts as one.
      .refine((text) => [...text].length <= MAX_MESSAGE_LENGTH, {
        message: `Must be at most ${MAX_MESSAGE_LENGTH} characters`,
      }),
    mode: z.enum(['text', 'voice']).default('text'),
    // Accepted and validated; it is checked against the history once
    // messages are stored (S4-4).
    interruptedMessageId: z.uuid().nullable().optional(),
  })
  .strict();

export function createChatRouter(
  chatService: ChatService,
  crisis: CrisisConfig,
  usageLimiter: UsageLimiter,
): Router {
  const router = Router();

  // Errors (invalid body, LLM failures) go to the central error handler.
  router.post('/chat', async (req, res) => {
    const parsed = chatRequestSchema.safeParse(req.body);
    if (!parsed.success) {
      throw ApiError.validation(
        'The request body is invalid.',
        parsed.error.issues.map((issue) => ({
          field: issue.path.join('.') || 'body',
          message: issue.message,
        })),
      );
    }

    const { message, mode } = parsed.data;
    const userMessageCreatedAt = new Date().toISOString();
    const user = currentUser(res);
    const outcome = await chatService.reply({ message, mode, user });
    const isCrisis = outcome.type === 'crisis';

    // IDs are generated per request until messages are stored (S4-4).
    res.status(200).json({
      type: outcome.type,
      userMessage: {
        id: randomUUID(),
        role: 'user',
        content: message,
        createdAt: userMessageCreatedAt,
      },
      reply: {
        id: randomUUID(),
        role: 'assistant',
        content: isCrisis ? crisis.reply : outcome.content,
        createdAt: new Date().toISOString(),
        interrupted: false,
      },
      ...(isCrisis ? { resources: crisis.resources } : {}),
      usage: usageLimiter.snapshot(user),
    });
  });

  return router;
}

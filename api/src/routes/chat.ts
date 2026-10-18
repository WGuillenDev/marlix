// POST /v1/chat (S1-5). Contract: docs/api-contract.md#post-v1chat.
import { Router } from 'express';
import { z } from 'zod';

import type { CrisisConfig } from '../config/crisis-config.js';
import { currentUser } from '../middleware/current-user.js';
import { ApiError } from '../middleware/error-handler.js';
import type { ChatService } from '../services/chat-service.js';

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
    // Must be one of the user's own replies; the chat service checks it.
    interruptedMessageId: z.uuid().nullable().optional(),
  })
  .strict();

export function createChatRouter(chatService: ChatService, crisis: CrisisConfig): Router {
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

    const { message, mode, interruptedMessageId } = parsed.data;
    const user = currentUser(res);
    const { type, userMessage, reply, usage } = await chatService.reply({
      message,
      mode,
      user,
      interruptedMessageId,
    });
    const isCrisis = type === 'crisis';

    res.status(200).json({
      type,
      userMessage: {
        id: userMessage.id,
        role: userMessage.role,
        content: userMessage.content,
        createdAt: userMessage.createdAt,
      },
      reply,
      ...(isCrisis ? { resources: crisis.resources } : {}),
      ...(usage ? { usage } : {}),
    });
  });

  return router;
}

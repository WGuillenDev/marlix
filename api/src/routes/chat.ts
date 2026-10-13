// POST /v1/chat (S1-5). Contract: docs/api-contract.md#post-v1chat.
import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import type { ChatService } from '../services/chat-service.js';
import { LlmError } from '../services/llm/index.js';

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

export function createChatRouter(chatService: ChatService): Router {
  const router = Router();

  router.post('/chat', async (req, res) => {
    const parsed = chatRequestSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({
        error: {
          code: 'VALIDATION_ERROR',
          message: 'The request body is invalid.',
          details: {
            fields: parsed.error.issues.map((issue) => ({
              field: issue.path.join('.') || 'body',
              message: issue.message,
            })),
          },
        },
      });
      return;
    }

    const { message, mode } = parsed.data;
    const userMessageCreatedAt = new Date().toISOString();

    let replyContent: string;
    try {
      replyContent = await chatService.reply({ message, mode });
    } catch (error) {
      if (!(error instanceof LlmError)) throw error;
      // Only the error kind is logged, never the conversation.
      console.error(`chat: LLM failed (${error.kind})`);
      if (error.retryAfterSeconds) res.set('Retry-After', String(error.retryAfterSeconds));
      res.status(503).json({
        error: { code: 'LLM_UNAVAILABLE', message: 'The model is not available right now.' },
      });
      return;
    }

    // IDs are generated per request until messages are stored (S4-4).
    res.status(200).json({
      type: 'reply',
      userMessage: {
        id: randomUUID(),
        role: 'user',
        content: message,
        createdAt: userMessageCreatedAt,
      },
      reply: {
        id: randomUUID(),
        role: 'assistant',
        content: replyContent,
        createdAt: new Date().toISOString(),
        interrupted: false,
      },
    });
  });

  return router;
}

import { Router, type Response } from 'express';
import { z } from 'zod';

import type { CrisisConfig } from '../../safety/domain/crisis-config.js';
import { currentUser } from '../../../shared/presentation/current-user.js';
import { ApiError } from '../../../shared/presentation/error-handler.js';
import type { ChatOutcome, ChatService } from '../application/chat-service.js';
import { LlmError } from '../../../shared/application/ai/errors.js';


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
    interruptedMessageId: z.uuid().nullable().optional(),
  })
  .strict();

export function createChatRouter(chatService: ChatService, crisis: CrisisConfig): Router {
  const router = Router();

  const outcomeBody = ({ type, tone, userMessage, reply, usage }: ChatOutcome) => ({
    type,
    tone,
    userMessage: {
      id: userMessage.id,
      role: userMessage.role,
      content: userMessage.content,
      createdAt: userMessage.createdAt,
    },
    reply,
    ...(type === 'crisis' ? { resources: crisis.resources } : {}),
    ...(usage ? { usage } : {}),
  });

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
    const input = { message, mode, user, interruptedMessageId };

    if (mode !== 'voice' || req.accepts(['json', 'text/event-stream']) !== 'text/event-stream') {
      res.status(200).json(outcomeBody(await chatService.reply(input)));
      return;
    }

    const stream = new EventStream(res);
    // Abort provider work when the client disconnects.
    const cancelled = new AbortController();
    res.on('close', () => {
      if (!res.writableFinished) cancelled.abort();
    });

    try {
      const outcome = await chatService.replyStream(
        input,
        (sentence) => stream.send('sentence', sentence),
        cancelled.signal,
      );
      stream.send(outcome.type === 'crisis' ? 'crisis' : 'done', outcomeBody(outcome));
      stream.end();
    } catch (error) {
      // Before the first event, failures can still use a regular JSON response.
      if (!stream.started) throw error;
      stream.send('error', streamError(error));
      stream.end();
    }
  });

  return router;
}

class EventStream {
  started = false;

  constructor(private readonly res: Response) {}

  send(event: string, data: unknown): void {
    if (this.res.writableEnded || this.res.destroyed) return;
    if (!this.started) {
      this.started = true;
      this.res.status(200).set({
        'Content-Type': 'text/event-stream; charset=utf-8',
        'Cache-Control': 'no-cache, no-transform',
        // Render's proxy would otherwise hold the events until the end.
        'X-Accel-Buffering': 'no',
      });
      this.res.flushHeaders();
    }
    this.res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
  }

  end(): void {
    this.res.end();
  }
}

function streamError(error: unknown) {
  if (error instanceof LlmError) {
    console.warn(`LLM call failed: ${error.kind}`);
    return { error: { code: 'LLM_UNAVAILABLE', message: 'The model is not available right now.' } };
  }
  console.error(`Unexpected error in the stream: ${error instanceof Error ? error.name : typeof error}`);
  return { error: { code: 'INTERNAL_ERROR', message: 'Unexpected error.' } };
}

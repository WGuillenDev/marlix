// POST /v1/chat (S1-5), streamed in voice mode (S6-10). Contract: docs/api-contract.md#post-v1chat.
import { Router, type Response } from 'express';
import { z } from 'zod';

import type { CrisisConfig } from '../config/crisis-config.js';
import { currentUser } from '../middleware/current-user.js';
import { ApiError } from '../middleware/error-handler.js';
import type { ChatOutcome, ChatService } from '../services/chat-service.js';
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
    // Must be one of the user's own replies; the chat service checks it.
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
    const input = { message, mode, user, interruptedMessageId };

    // Only the voice mode streams: the text chat keeps its paragraphs.
    if (mode !== 'voice' || req.accepts(['json', 'text/event-stream']) !== 'text/event-stream') {
      res.status(200).json(outcomeBody(await chatService.reply(input)));
      return;
    }

    const stream = new EventStream(res);
    // The app went away before the answer was complete: stop paying for the model.
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
      // Before the first event nothing was sent, so the error handler still
      // answers with a normal JSON error and its status.
      if (!stream.started) throw error;
      stream.send('error', streamError(error));
      stream.end();
    }
  });

  return router;
}

/** Server-Sent Events. The headers go out with the first event, not before. */
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

// The same body as the central error handler gives, with fixed messages.
function streamError(error: unknown) {
  if (error instanceof LlmError) {
    console.warn(`LLM call failed: ${error.kind}`);
    return { error: { code: 'LLM_UNAVAILABLE', message: 'The model is not available right now.' } };
  }
  console.error(`Unexpected error in the stream: ${error instanceof Error ? error.name : typeof error}`);
  return { error: { code: 'INTERNAL_ERROR', message: 'Unexpected error.' } };
}

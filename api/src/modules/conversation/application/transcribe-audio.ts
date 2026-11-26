import { UsageLimitExceededError, type UsageLimiter, type UsageUser } from '../../usage/application/usage-limiter.js';
import type { Transcriber } from './transcriber.js';

/** Each one costs Groq's shared audio quota, so they are limited apart from the chat. */
export const TRANSCRIBE_RATE_LIMIT = { requests: 20, windowSeconds: 60 };

export function createTranscribeAudio(transcriber: Transcriber, usage: UsageLimiter, now: () => number) {
  const recent = new Map<string, number[]>();

  function takeSlot(userId: string): void {
    const { requests, windowSeconds } = TRANSCRIBE_RATE_LIMIT;
    const current = now();
    const windowStart = current - windowSeconds * 1000;
    const attempts = (recent.get(userId) ?? []).filter((time) => time > windowStart);
    if (attempts.length >= requests) {
      recent.set(userId, attempts);
      throw new UsageLimitExceededError({
        reason: 'rate_limit',
        retryAfterSeconds: Math.ceil((attempts[0]! - windowStart) / 1000),
      });
    }
    recent.set(userId, [...attempts, current]);
  }

  return async (user: UsageUser, audio: Uint8Array): Promise<string> => {
    const { remaining, resetsAt } = await usage.snapshot(user);
    if (remaining === 0) throw new UsageLimitExceededError({ reason: 'daily_limit', resetsAt });
    takeSlot(user.id);
    return transcriber.transcribe(audio);
  };
}

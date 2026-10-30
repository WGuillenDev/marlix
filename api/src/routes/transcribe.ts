// POST /v1/transcribe (S6-9). Contract: docs/api-contract.md#post-v1transcribe.
import express, { Router } from 'express';

import { currentUser } from '../middleware/current-user.js';
import { ApiError } from '../middleware/error-handler.js';
import type { Transcriber } from '../services/transcription/transcriber.js';
import type { UsageLimiter } from '../services/usage/usage-limiter.js';
import { UsageLimitExceededError } from '../services/usage/usage-limiter.js';

/** What the app records: WAV, 16 kHz, mono, 16-bit PCM. */
export const SAMPLE_RATE = 16_000;
const BYTES_PER_SECOND = SAMPLE_RATE * 2;
const WAV_HEADER_BYTES = 44;
/** A turn is at most 30 s in the app; a little more is allowed. */
export const MAX_SECONDS = 32;
const MIN_SECONDS = 0.25;
const MAX_BYTES = WAV_HEADER_BYTES + MAX_SECONDS * BYTES_PER_SECOND;

/** Each one costs Groq's shared audio quota, so they are limited apart from the chat. */
export const TRANSCRIBE_RATE_LIMIT = { requests: 20, windowSeconds: 60 };

/** Whether [audio] is the WAV the app sends, and how many seconds it holds. */
export function wavSeconds(audio: Uint8Array): number | undefined {
  if (audio.length < WAV_HEADER_BYTES) return undefined;
  const view = new DataView(audio.buffer, audio.byteOffset, audio.byteLength);
  const text = (offset: number) => String.fromCharCode(...audio.subarray(offset, offset + 4));
  const isWav = text(0) === 'RIFF' && text(8) === 'WAVE' && text(12) === 'fmt ';
  const pcm = view.getUint16(20, true) === 1;
  const mono = view.getUint16(22, true) === 1;
  const rate = view.getUint32(24, true) === SAMPLE_RATE;
  const bits = view.getUint16(34, true) === 16;
  if (!isWav || !pcm || !mono || !rate || !bits) return undefined;
  return (audio.length - WAV_HEADER_BYTES) / BYTES_PER_SECOND;
}

export function createTranscribeRouter(
  transcriber: Transcriber,
  usage: UsageLimiter,
  now: () => number = Date.now,
): Router {
  const router = Router();
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

  router.post(
    '/transcribe',
    express.raw({ type: ['audio/wav', 'audio/x-wav'], limit: MAX_BYTES }),
    async (req, res) => {
      const audio: unknown = req.body;
      if (!(audio instanceof Uint8Array) || audio.length === 0) {
        throw ApiError.validation('The body must be WAV audio (Content-Type: audio/wav).');
      }
      const seconds = wavSeconds(audio);
      if (seconds === undefined) {
        throw ApiError.validation('The audio must be WAV, 16 kHz, mono, 16-bit PCM.');
      }
      if (seconds < MIN_SECONDS) {
        throw ApiError.validation('The audio is too short.');
      }

      const user = currentUser(res);
      // Nothing to answer once the day ran out: the chat would refuse it.
      const { remaining, resetsAt } = await usage.snapshot(user);
      if (remaining === 0) throw new UsageLimitExceededError({ reason: 'daily_limit', resetsAt });
      takeSlot(user.id);

      // The audio and the text are never saved or logged.
      const text = await transcriber.transcribe(audio);
      res.status(200).json({ text });
    },
  );

  return router;
}

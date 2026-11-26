import express, { Router } from 'express';

import { currentUser } from '../../../shared/presentation/current-user.js';
import { ApiError } from '../../../shared/presentation/error-handler.js';
import type { Transcriber } from '../application/transcriber.js';
import type { UsageLimiter } from '../../usage/application/usage-limiter.js';
import { createTranscribeAudio } from '../application/transcribe-audio.js';
import { MAX_BYTES, MIN_SECONDS, wavSeconds } from '../domain/wav.js';

export function createTranscribeRouter(
  transcriber: Transcriber,
  usage: UsageLimiter,
  now: () => number = Date.now,
): Router {
  const router = Router();
  const transcribeAudio = createTranscribeAudio(transcriber, usage, now);

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

      const text = await transcribeAudio(currentUser(res), audio);
      res.status(200).json({ text });
    },
  );

  return router;
}

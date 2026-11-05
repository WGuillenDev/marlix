// Whisper on Groq (S6-9): free plan, Zero Data Retention on in the console, so
// Groq does not keep the audio. Decision: docs/decisions.md.
import OpenAI, { toFile } from 'openai';

import { cleanTranscript, speechOf, type Transcriber } from '../transcription/transcriber.js';
import { GROQ_DEFAULT_BASE_URL, translateGroqError } from './groq-provider.js';

const DEFAULT_TIMEOUT_MS = 15_000;

/**
 * Words of Costa Rican Spanish that Whisper would otherwise spell as something
 * else. A prompt only biases the spelling; it is never an instruction.
 */
export const TRANSCRIPTION_PROMPT =
  'Conversación en español de Costa Rica. Mae, tuanis, pura vida, diay, qué carga, chiva, upe, brete, jupa, pura vida mae.';

export interface GroqTranscriberOptions {
  apiKey: string;
  model: string;
  baseUrl?: string;
  timeoutMs?: number;
  /** For tests: replaces the HTTP client. */
  fetch?: typeof fetch;
}

export class GroqTranscriber implements Transcriber {
  readonly #client: OpenAI;
  readonly #model: string;

  constructor(options: GroqTranscriberOptions) {
    this.#model = options.model;
    this.#client = new OpenAI({
      apiKey: options.apiKey,
      baseURL: options.baseUrl ?? GROQ_DEFAULT_BASE_URL,
      timeout: options.timeoutMs ?? DEFAULT_TIMEOUT_MS,
      maxRetries: 0,
      logLevel: 'off',
      ...(options.fetch ? { fetch: options.fetch } : {}),
    });
  }

  async transcribe(audio: Uint8Array): Promise<string> {
    try {
      const result = await this.#client.audio.transcriptions.create({
        file: await toFile(audio, 'speech.wav', { type: 'audio/wav' }),
        model: this.#model,
        language: 'es',
        prompt: TRANSCRIPTION_PROMPT,
        response_format: 'verbose_json',
        temperature: 0,
      });
      // Without segments there is nothing to doubt: the text is all there is.
      return result.segments ? speechOf(result.segments) : cleanTranscript(result.text);
    } catch (error) {
      throw translateGroqError(error);
    }
  }
}

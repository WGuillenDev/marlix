import OpenAI, { toFile } from 'openai';

import { cleanTranscript, speechOf, type Transcriber } from '../../../modules/conversation/application/transcriber.js';
import { GROQ_DEFAULT_BASE_URL, translateGroqError } from './groq-provider.js';

const DEFAULT_TIMEOUT_MS = 15_000;

/** The prompt biases Whisper toward Costa Rican spellings. It is not a vocabulary limit. */
export const TRANSCRIPTION_PROMPT =
  'Conversación en español de Costa Rica. Mae, tuanis, pura vida, diay, qué carga, chiva, upe, brete, jupa, pura vida mae.';

export interface GroqTranscriberOptions {
  apiKey: string;
  model: string;
  baseUrl?: string;
  timeoutMs?: number;
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
      return result.segments ? speechOf(result.segments) : cleanTranscript(result.text);
    } catch (error) {
      throw translateGroqError(error);
    }
  }
}

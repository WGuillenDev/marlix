// Hold the last fragment until punctuation or the end confirms the sentence boundary.

const BOUNDARY = /(?<=[.!?…])\s+|\n+/;
// "1." or "2)" alone: the marker of a list item, not a sentence.
const LIST_MARKER_ONLY = /^\d{1,2}[.)]$/;

export class SentenceStream {
  #buffer = '';
  #marker = '';

  push(piece: string): string[] {
    this.#buffer += piece;
    const sentences: string[] = [];
    for (;;) {
      const boundary = BOUNDARY.exec(this.#buffer);
      if (!boundary) break;
      const sentence = this.#take(this.#buffer.slice(0, boundary.index));
      this.#buffer = this.#buffer.slice(boundary.index + boundary[0].length);
      if (sentence) sentences.push(sentence);
    }
    return sentences;
  }

  flush(): string[] {
    const rest = this.#take(this.#buffer, true);
    this.#buffer = '';
    return rest ? [rest] : [];
  }

  #take(text: string, last = false): string {
    const sentence = `${this.#marker}${text.trim()}`.trim();
    this.#marker = '';
    if (!last && LIST_MARKER_ONLY.test(sentence)) {
      this.#marker = `${sentence} `;
      return '';
    }
    return sentence;
  }
}

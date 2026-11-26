import type { PostgrestError } from '@supabase/supabase-js';

/** Database error text may quote a user's message. Keep only the error code. */
export class DatabaseError extends Error {
  constructor() {
    super('The database call failed');
    this.name = 'DatabaseError';
  }
}

export function databaseFailure(scope: string, error?: PostgrestError): DatabaseError {
  console.error(`${scope} failed: ${error?.code || 'no code'}`);
  return new DatabaseError();
}

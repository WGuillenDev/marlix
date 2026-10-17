import type { PostgrestError } from '@supabase/supabase-js';

/**
 * A database call failed. It carries no message on purpose: the database's
 * text can quote the row being written, which holds the user's words.
 */
export class DatabaseError extends Error {
  constructor() {
    super('The database call failed');
    this.name = 'DatabaseError';
  }
}

/** Logs only the error code and returns the error to throw. */
export function databaseFailure(scope: string, error?: PostgrestError): DatabaseError {
  console.error(`${scope} failed: ${error?.code || 'no code'}`);
  return new DatabaseError();
}

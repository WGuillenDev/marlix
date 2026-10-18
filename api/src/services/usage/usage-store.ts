// Where the daily counters and caps live (S4-13): the daily_usage and plan_limits tables.

export interface UsageStore {
  /** Interactions the user has had on a Costa Rica day (YYYY-MM-DD). */
  used(userId: string, day: string): Promise<number>;
  /** Daily cap of a plan, or undefined if there is no such plan. */
  dailyCap(plan: string): Promise<number | undefined>;
  /** Counts one more interaction on the day and returns the day's new total. */
  record(userId: string, day: string): Promise<number>;
}

/**
 * The database failed. It carries no message on purpose: the database's text
 * can quote what was being written.
 */
export class UsageStoreError extends Error {
  constructor() {
    super('The usage store failed');
    this.name = 'UsageStoreError';
  }
}

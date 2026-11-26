
export interface UsageStore {
  used(userId: string, day: string): Promise<number>;
  dailyCap(plan: string): Promise<number | undefined>;
  record(userId: string, day: string): Promise<number>;
}

export class UsageStoreError extends Error {
  constructor() {
    super('The usage store failed');
    this.name = 'UsageStoreError';
  }
}

export interface AccountStore {
  /** Deleting the Auth account also deletes its dependent data. */
  deleteAccount(userId: string): Promise<void>;
}

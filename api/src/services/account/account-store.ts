export interface AccountStore {
  /**
   * Deletes the account. The profile, conversations, messages, memories and
   * usage go with it through `on delete cascade` (docs/schema.sql). Deleting
   * an account that is already gone is not an error.
   */
  deleteAccount(userId: string): Promise<void>;
}

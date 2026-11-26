export interface AuthenticatedUser {
  id: string;
  plan: string;
  /** Latest credential entry in epoch seconds. Refreshing a token does not advance it. */
  signedInAt?: number;
}

import type { AuthenticatedUser } from '../domain/authenticated-user.js';
import { hasRecentSignIn } from '../domain/recent-sign-in.js';
import type { AccountStore } from './account-store.js';

export async function deleteAccount(accounts: AccountStore, user: AuthenticatedUser, now: Date) {
  if (!hasRecentSignIn(user.signedInAt, now)) return false;
  await accounts.deleteAccount(user.id);
  return true;
}

export const RECENT_SIGN_IN_SECONDS = 5 * 60;

export function hasRecentSignIn(signedInAt: number | undefined, now: Date): boolean {
  return signedInAt !== undefined && now.getTime() / 1000 - signedInAt <= RECENT_SIGN_IN_SECONDS;
}

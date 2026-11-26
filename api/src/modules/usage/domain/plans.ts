export interface PlanLimits {
  rateLimit: { requests: number; windowSeconds: number };
}

export type PlansConfig = Record<string, PlanLimits>;

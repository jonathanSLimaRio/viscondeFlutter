import { ApiError } from "@/lib/server/errors";

type LimitBucket = {
  count: number;
  resetAt: number;
};

const buckets = new Map<string, LimitBucket>();

export function enforceRateLimit(
  key: string,
  options: { limit: number; windowMs: number; message?: string }
) {
  const now = Date.now();
  const current = buckets.get(key);

  if (!current || now > current.resetAt) {
    buckets.set(key, {
      count: 1,
      resetAt: now + options.windowMs,
    });
    return;
  }

  if (current.count >= options.limit) {
    throw new ApiError(
      options.message ?? "Muitas tentativas. Tente novamente em instantes.",
      429,
      "RATE_LIMITED"
    );
  }

  current.count += 1;
  buckets.set(key, current);
}

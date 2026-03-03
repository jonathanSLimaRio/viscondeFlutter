import { createHash } from "node:crypto";

import { type UxEventName } from "@prisma/client";

import { prisma } from "@/lib/prisma";
import { type AuthContext } from "@/lib/server/auth-context";
import { env } from "@/lib/server/env";
import { ApiError } from "@/lib/server/errors";

const UX_EVENT_NAME_MAP = {
  session_started: "SESSION_STARTED",
  auth_error_shown: "AUTH_ERROR_SHOWN",
  story_create_started: "STORY_CREATE_STARTED",
  story_create_step_completed: "STORY_CREATE_STEP_COMPLETED",
  story_create_abandoned: "STORY_CREATE_ABANDONED",
  story_published: "STORY_PUBLISHED",
  game_hub_opened: "GAME_HUB_OPENED",
} as const;

type UxClientInfo = {
  platform?: string;
  appVersion?: string;
  appBuild?: string;
  locale?: string;
  timezone?: string;
};

type UxEventInput = {
  eventId: string;
  name: keyof typeof UX_EVENT_NAME_MAP;
  occurredAt: Date;
  source?: string;
  childId?: string;
  params?: Record<string, unknown>;
};

type IngestUxEventsInput = {
  auth: AuthContext | null;
  appSessionId: string;
  client?: UxClientInfo;
  events: UxEventInput[];
};

type UxDateRangeInput = {
  dateFrom?: string;
  dateTo?: string;
  timezone?: string;
};

type PrimitiveParam = string | number | boolean | null;

const PARAM_ALLOWLIST: Record<keyof typeof UX_EVENT_NAME_MAP, readonly string[]> = {
  session_started: ["source"],
  auth_error_shown: [
    "session_expired",
    "message",
    "error_kind",
    "status_code",
    "code",
    "source",
  ],
  story_create_started: ["step", "source", "flow", "duration_ms", "reason"],
  story_create_step_completed: ["step", "source", "flow", "duration_ms", "reason"],
  story_create_abandoned: ["step", "source", "flow", "duration_ms", "reason"],
  story_published: ["story_id", "steps"],
  game_hub_opened: ["selected_child", "source"],
};

function toUtcStartOfDay(dateValue: string) {
  const [yearText, monthText, dayText] = dateValue.split("-");
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  return new Date(Date.UTC(year, month - 1, day, 0, 0, 0, 0));
}

function toUtcEndOfDay(dateValue: string) {
  const [yearText, monthText, dayText] = dateValue.split("-");
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  return new Date(Date.UTC(year, month - 1, day, 23, 59, 59, 999));
}

function normalizeDateRange(input: UxDateRangeInput) {
  const now = new Date();

  const dateTo = input.dateTo ? toUtcEndOfDay(input.dateTo) : now;
  const dateFrom = input.dateFrom
    ? toUtcStartOfDay(input.dateFrom)
    : new Date(dateTo.getTime() - 6 * 24 * 60 * 60 * 1000);

  if (dateFrom.getTime() > dateTo.getTime()) {
    throw new ApiError("Periodo invalido para consulta do funil.", 400, "INVALID_DATE_RANGE");
  }

  return {
    dateFrom,
    dateTo,
    timezone: input.timezone ?? "UTC",
  };
}

function hashChildId(childId: string) {
  return createHash("sha256")
    .update(`${env.uxAnalyticsHashSalt}:${childId}`)
    .digest("hex");
}

function sanitizeParams(
  eventName: keyof typeof UX_EVENT_NAME_MAP,
  raw: Record<string, unknown> | undefined
): Record<string, PrimitiveParam> | null {
  if (!raw) {
    return null;
  }

  const allowlist = PARAM_ALLOWLIST[eventName];
  const result: Record<string, PrimitiveParam> = {};

  for (const [key, value] of Object.entries(raw)) {
    if (!allowlist.includes(key)) {
      continue;
    }

    if (
      typeof value === "string" ||
      typeof value === "number" ||
      typeof value === "boolean" ||
      value === null
    ) {
      result[key] = value;
    }
  }

  return Object.keys(result).length > 0 ? result : null;
}

function resolveChildId(event: UxEventInput) {
  const direct = event.childId?.trim();
  if (direct) {
    return direct;
  }

  const fromParams = event.params?.["child_id"];
  if (typeof fromParams === "string" && fromParams.trim().length > 0) {
    return fromParams.trim();
  }

  return undefined;
}

function normalizeStep(raw: unknown) {
  const step = typeof raw === "number" ? Math.trunc(raw) : Number(raw);
  if (!Number.isInteger(step)) {
    return null;
  }

  return step;
}

export async function ingestUxEvents(input: IngestUxEventsInput) {
  const rows = input.events.map((event) => {
    const eventName = UX_EVENT_NAME_MAP[event.name] as UxEventName;
    const childId = resolveChildId(event);
    const params = sanitizeParams(event.name, event.params);

    return {
      eventId: event.eventId,
      eventName,
      appSessionId: input.appSessionId,
      userId: input.auth?.userId,
      mobileSessionId: input.auth?.sessionId,
      childHash: childId ? hashChildId(childId) : null,
      occurredAt: event.occurredAt,
      source: event.source ?? null,
      params: params ?? undefined,
      platform: input.client?.platform ?? null,
      appVersion: input.client?.appVersion ?? null,
      appBuild: input.client?.appBuild ?? null,
      locale: input.client?.locale ?? null,
      timezone: input.client?.timezone ?? null,
    };
  });

  if (rows.length === 0) {
    return {
      accepted: 0,
      deduplicated: 0,
      rejected: 0,
    };
  }

  const result = await prisma.uxAnalyticsEvent.createMany({
    data: rows,
    skipDuplicates: true,
  });

  return {
    accepted: result.count,
    deduplicated: rows.length - result.count,
    rejected: 0,
  };
}

export async function getUxFunnelOverview(input: UxDateRangeInput) {
  const range = normalizeDateRange(input);

  const [events, newAuthSessions] = await Promise.all([
    prisma.uxAnalyticsEvent.findMany({
      where: {
        occurredAt: {
          gte: range.dateFrom,
          lte: range.dateTo,
        },
      },
      select: {
        appSessionId: true,
        mobileSessionId: true,
        eventName: true,
        params: true,
      },
    }),
    prisma.mobileSession.count({
      where: {
        createdAt: {
          gte: range.dateFrom,
          lte: range.dateTo,
        },
      },
    }),
  ]);

  type FunnelFlags = {
    started: boolean;
    step1: boolean;
    step2: boolean;
    step3: boolean;
    published: boolean;
    gameHubOpened: boolean;
  };

  const funnelBySession = new Map<string, FunnelFlags>();
  const explicitAbandonedByStep: Record<string, number> = {
    step1: 0,
    step2: 0,
    step3: 0,
    unknown: 0,
  };

  const authErrorCountByType = new Map<string, number>();
  const trackedNewAuthSessions = new Set<string>();

  function readFlags(sessionId: string) {
    const existing = funnelBySession.get(sessionId);
    if (existing) {
      return existing;
    }

    const created: FunnelFlags = {
      started: false,
      step1: false,
      step2: false,
      step3: false,
      published: false,
      gameHubOpened: false,
    };
    funnelBySession.set(sessionId, created);
    return created;
  }

  for (const event of events) {
    const flags = readFlags(event.appSessionId);

    if (event.eventName === "SESSION_STARTED" && event.mobileSessionId) {
      trackedNewAuthSessions.add(event.mobileSessionId);
    }

    if (event.eventName === "STORY_CREATE_STARTED") {
      flags.started = true;
      continue;
    }

    if (event.eventName === "STORY_CREATE_STEP_COMPLETED") {
      const rawStep =
        event.params && typeof event.params === "object" ? (event.params as Record<string, unknown>).step : null;
      const step = normalizeStep(rawStep);
      if (step === 1) {
        flags.step1 = true;
      }
      if (step === 2) {
        flags.step2 = true;
      }
      if (step === 3) {
        flags.step3 = true;
      }
      continue;
    }

    if (event.eventName === "STORY_CREATE_ABANDONED") {
      const rawStep =
        event.params && typeof event.params === "object" ? (event.params as Record<string, unknown>).step : null;
      const step = normalizeStep(rawStep);
      if (step === 1) {
        explicitAbandonedByStep.step1 += 1;
      } else if (step === 2) {
        explicitAbandonedByStep.step2 += 1;
      } else if (step === 3) {
        explicitAbandonedByStep.step3 += 1;
      } else {
        explicitAbandonedByStep.unknown += 1;
      }
      continue;
    }

    if (event.eventName === "STORY_PUBLISHED") {
      flags.published = true;
      continue;
    }

    if (event.eventName === "GAME_HUB_OPENED") {
      flags.gameHubOpened = true;
      continue;
    }

    if (event.eventName === "AUTH_ERROR_SHOWN") {
      const params =
        event.params && typeof event.params === "object"
          ? (event.params as Record<string, unknown>)
          : null;
      const sessionExpired = params?.session_expired === true;
      const kind = typeof params?.error_kind === "string" ? params.error_kind.trim() : "";
      const key = sessionExpired ? "session_expired" : kind.length > 0 ? kind : "unknown";

      authErrorCountByType.set(key, (authErrorCountByType.get(key) ?? 0) + 1);
    }
  }

  const totals = {
    started: 0,
    step1: 0,
    step2: 0,
    step3: 0,
    published: 0,
    gameHubOpened: 0,
  };

  for (const flags of funnelBySession.values()) {
    if (flags.started) {
      totals.started += 1;
    }
    if (flags.step1) {
      totals.step1 += 1;
    }
    if (flags.step2) {
      totals.step2 += 1;
    }
    if (flags.step3) {
      totals.step3 += 1;
    }
    if (flags.published) {
      totals.published += 1;
    }
    if (flags.gameHubOpened) {
      totals.gameHubOpened += 1;
    }
  }

  const dropoffByProgression = {
    startedToStep1: Math.max(0, totals.started - totals.step1),
    step1ToStep2: Math.max(0, totals.step1 - totals.step2),
    step2ToStep3: Math.max(0, totals.step2 - totals.step3),
    step3ToPublished: Math.max(0, totals.step3 - totals.published),
    publishedToGameHubOpened: Math.max(0, totals.published - totals.gameHubOpened),
  };

  const authErrors = [...authErrorCountByType.entries()]
    .map(([type, count]) => ({ type, count }))
    .sort((left, right) => right.count - left.count);

  const coveragePct =
    newAuthSessions > 0 ? Number(((trackedNewAuthSessions.size / newAuthSessions) * 100).toFixed(2)) : 0;

  return {
    generatedAt: new Date(),
    range: {
      dateFrom: range.dateFrom,
      dateTo: range.dateTo,
      timezone: range.timezone,
    },
    coverage: {
      newAuthSessions,
      trackedNewAuthSessions: trackedNewAuthSessions.size,
      coveragePct,
    },
    funnel: {
      ...totals,
      dropoffByProgression,
      explicitAbandonedByStep,
    },
    authErrors: {
      total: authErrors.reduce((sum, item) => sum + item.count, 0),
      breakdown: authErrors,
    },
  };
}

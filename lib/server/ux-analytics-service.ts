import { createHash } from "node:crypto";

import { type UxEventName } from "@prisma/client";

import { prisma } from "@/lib/prisma";
import { type AuthContext } from "@/lib/server/auth-context";
import { env } from "@/lib/server/env";
import { ApiError } from "@/lib/server/errors";

const UX_EVENT_NAME_MAP = {
  session_started: "SESSION_STARTED",
  auth_error_shown: "AUTH_ERROR_SHOWN",
  auth_refresh_success: "AUTH_REFRESH_SUCCESS",
  auth_refresh_failed: "AUTH_REFRESH_FAILED",
  story_create_started: "STORY_CREATE_STARTED",
  story_create_step_completed: "STORY_CREATE_STEP_COMPLETED",
  story_create_abandoned: "STORY_CREATE_ABANDONED",
  story_published: "STORY_PUBLISHED",
  game_hub_opened: "GAME_HUB_OPENED",
  vault_state_shown: "VAULT_STATE_SHOWN",
  vault_retry_tapped: "VAULT_RETRY_TAPPED",
  vault_empty_cta_tapped: "VAULT_EMPTY_CTA_TAPPED",
  game_state_shown: "GAME_STATE_SHOWN",
  game_retry_tapped: "GAME_RETRY_TAPPED",
  game_empty_cta_tapped: "GAME_EMPTY_CTA_TAPPED",
  post_publish_modal_opened: "POST_PUBLISH_MODAL_OPENED",
  post_publish_cta_clicked: "POST_PUBLISH_CTA_CLICKED",
  pin_prompt_shown: "PIN_PROMPT_SHOWN",
  pin_prompt_success: "PIN_PROMPT_SUCCESS",
  pin_prompt_abandon: "PIN_PROMPT_ABANDON",
  pin_lock_now_clicked: "PIN_LOCK_NOW_CLICKED",
  story_game_room_opened: "STORY_GAME_ROOM_OPENED",
  story_game_action_selected: "STORY_GAME_ACTION_SELECTED",
  story_game_step_saved: "STORY_GAME_STEP_SAVED",
  story_game_step_failed: "STORY_GAME_STEP_FAILED",
  story_game_fallback_classic: "STORY_GAME_FALLBACK_CLASSIC",
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
  auth_refresh_success: ["source"],
  auth_refresh_failed: ["reason", "message", "source"],
  story_create_started: ["step", "source", "flow", "duration_ms", "reason"],
  story_create_step_completed: ["step", "source", "flow", "duration_ms", "reason"],
  story_create_abandoned: ["step", "source", "flow", "duration_ms", "reason"],
  story_published: ["story_id", "steps", "source", "flow", "auto_completed_steps"],
  game_hub_opened: ["selected_child", "source"],
  vault_state_shown: ["screen", "state", "filtered", "source"],
  vault_retry_tapped: ["screen", "source"],
  vault_empty_cta_tapped: ["screen", "cta", "state", "source"],
  game_state_shown: ["screen", "state", "source"],
  game_retry_tapped: ["screen", "source"],
  game_empty_cta_tapped: ["screen", "cta", "state", "source"],
  post_publish_modal_opened: [
    "source",
    "flow",
    "story_id",
    "coins_delta",
    "stars_delta",
    "achievements_count",
  ],
  post_publish_cta_clicked: ["source", "flow", "target"],
  pin_prompt_shown: ["source"],
  pin_prompt_success: ["source", "expires_at"],
  pin_prompt_abandon: ["source", "reason", "message"],
  pin_lock_now_clicked: ["source"],
  story_game_room_opened: ["source", "flow", "story_id", "steps", "mode"],
  story_game_action_selected: [
    "source",
    "flow",
    "story_id",
    "step",
    "action_key",
    "action_label",
    "mode",
  ],
  story_game_step_saved: ["source", "flow", "story_id", "step", "node", "pending_count", "mode"],
  story_game_step_failed: [
    "source",
    "flow",
    "story_id",
    "step",
    "node",
    "error_kind",
    "status_code",
    "mode",
  ],
  story_game_fallback_classic: ["source", "flow", "story_id", "reason"],
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
  const stepDurationTotals = {
    step1: { totalMs: 0, count: 0 },
    step2: { totalMs: 0, count: 0 },
    step3: { totalMs: 0, count: 0 },
  };
  const postPublish = {
    publishedTotal: 0,
    modalOpenedTotal: 0,
    ctaClicksTotal: 0,
    ctaClicksByTarget: {
      continueSaga: 0,
      goGame: 0,
      backToVault: 0,
    },
  };
  const sessionsWithPostPublishModal = new Set<string>();
  const sessionsWithPostPublishCta = new Set<string>();
  const screenStates = {
    vault: {
      loadingShown: 0,
      emptyShown: 0,
      errorShown: 0,
      contentShown: 0,
      retryTapped: 0,
      emptyCtaTapped: 0,
    },
    game: {
      loadingShown: 0,
      emptyShown: 0,
      errorShown: 0,
      contentShown: 0,
      retryTapped: 0,
      emptyCtaTapped: 0,
    },
  };
  const pinFriction = {
    promptShownTotal: 0,
    promptSuccessTotal: 0,
    promptAbandonTotal: 0,
    lockNowTotal: 0,
    abandonByReason: new Map<string, number>(),
  };

  function normalizeScreen(raw: unknown): "vault" | "game" | null {
    if (raw === "vault" || raw === "game") {
      return raw;
    }
    return null;
  }

  function normalizeStateLabel(raw: unknown): string | null {
    if (typeof raw !== "string") {
      return null;
    }
    const state = raw.trim().toLowerCase();
    return state.length > 0 ? state : null;
  }

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
      const params =
        event.params && typeof event.params === "object"
          ? (event.params as Record<string, unknown>)
          : null;
      const rawStep = params?.step;
      const step = normalizeStep(rawStep);
      const rawDuration = params?.duration_ms;
      const durationMs =
        typeof rawDuration === "number" ? Math.trunc(rawDuration) : Number(rawDuration ?? Number.NaN);
      if (step === 1) {
        flags.step1 = true;
        if (Number.isFinite(durationMs) && durationMs > 0) {
          stepDurationTotals.step1.totalMs += durationMs;
          stepDurationTotals.step1.count += 1;
        }
      }
      if (step === 2) {
        flags.step2 = true;
        if (Number.isFinite(durationMs) && durationMs > 0) {
          stepDurationTotals.step2.totalMs += durationMs;
          stepDurationTotals.step2.count += 1;
        }
      }
      if (step === 3) {
        flags.step3 = true;
        if (Number.isFinite(durationMs) && durationMs > 0) {
          stepDurationTotals.step3.totalMs += durationMs;
          stepDurationTotals.step3.count += 1;
        }
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
      postPublish.publishedTotal += 1;
      continue;
    }

    if (event.eventName === "GAME_HUB_OPENED") {
      flags.gameHubOpened = true;
      continue;
    }

    if (event.eventName === "POST_PUBLISH_MODAL_OPENED") {
      postPublish.modalOpenedTotal += 1;
      sessionsWithPostPublishModal.add(event.appSessionId);
      continue;
    }

    if (event.eventName === "POST_PUBLISH_CTA_CLICKED") {
      postPublish.ctaClicksTotal += 1;
      sessionsWithPostPublishCta.add(event.appSessionId);
      const params =
        event.params && typeof event.params === "object"
          ? (event.params as Record<string, unknown>)
          : null;
      const rawTarget = typeof params?.target === "string" ? params.target.trim().toLowerCase() : "";
      if (rawTarget === "continue_saga") {
        postPublish.ctaClicksByTarget.continueSaga += 1;
      } else if (rawTarget === "go_game") {
        postPublish.ctaClicksByTarget.goGame += 1;
      } else if (rawTarget === "back_to_vault") {
        postPublish.ctaClicksByTarget.backToVault += 1;
      }
      continue;
    }

    if (event.eventName === "PIN_PROMPT_SHOWN") {
      pinFriction.promptShownTotal += 1;
      continue;
    }

    if (event.eventName === "PIN_PROMPT_SUCCESS") {
      pinFriction.promptSuccessTotal += 1;
      continue;
    }

    if (event.eventName === "PIN_PROMPT_ABANDON") {
      pinFriction.promptAbandonTotal += 1;
      const params =
        event.params && typeof event.params === "object"
          ? (event.params as Record<string, unknown>)
          : null;
      const reason =
        typeof params?.reason === "string" && params.reason.trim().length > 0
          ? params.reason.trim()
          : "unknown";
      pinFriction.abandonByReason.set(
        reason,
        (pinFriction.abandonByReason.get(reason) ?? 0) + 1
      );
      continue;
    }

    if (event.eventName === "PIN_LOCK_NOW_CLICKED") {
      pinFriction.lockNowTotal += 1;
      continue;
    }

    if (
      event.eventName === "VAULT_STATE_SHOWN" ||
      event.eventName === "GAME_STATE_SHOWN" ||
      event.eventName === "VAULT_RETRY_TAPPED" ||
      event.eventName === "GAME_RETRY_TAPPED" ||
      event.eventName === "VAULT_EMPTY_CTA_TAPPED" ||
      event.eventName === "GAME_EMPTY_CTA_TAPPED"
    ) {
      const params =
        event.params && typeof event.params === "object"
          ? (event.params as Record<string, unknown>)
          : null;

      const screen = normalizeScreen(params?.screen);
      if (!screen) {
        continue;
      }

      if (event.eventName === "VAULT_RETRY_TAPPED" || event.eventName === "GAME_RETRY_TAPPED") {
        screenStates[screen].retryTapped += 1;
        continue;
      }

      if (event.eventName === "VAULT_EMPTY_CTA_TAPPED" || event.eventName === "GAME_EMPTY_CTA_TAPPED") {
        screenStates[screen].emptyCtaTapped += 1;
        continue;
      }

      const state = normalizeStateLabel(params?.state);
      if (state == null) {
        continue;
      }

      if (state.startsWith("loading")) {
        screenStates[screen].loadingShown += 1;
      } else if (state.startsWith("error")) {
        screenStates[screen].errorShown += 1;
      } else if (state.startsWith("empty")) {
        screenStates[screen].emptyShown += 1;
      } else if (state.startsWith("content")) {
        screenStates[screen].contentShown += 1;
      }
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
  let sessionsWithNextAction = 0;
  for (const sessionId of sessionsWithPostPublishCta) {
    if (sessionsWithPostPublishModal.has(sessionId)) {
      sessionsWithNextAction += 1;
    }
  }
  const toRate = (value: number, base: number) =>
    base > 0 ? Number(((value / base) * 100).toFixed(2)) : 0;
  const toAvgDuration = (totalMs: number, count: number) =>
    count > 0 ? Math.round(totalMs / count) : 0;

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
      completionRates: {
        step1FromStartedPct: toRate(totals.step1, totals.started),
        step2FromStep1Pct: toRate(totals.step2, totals.step1),
        step3FromStep2Pct: toRate(totals.step3, totals.step2),
        publishedFromStep3Pct: toRate(totals.published, totals.step3),
      },
      avgDurationMs: {
        step1: toAvgDuration(stepDurationTotals.step1.totalMs, stepDurationTotals.step1.count),
        step2: toAvgDuration(stepDurationTotals.step2.totalMs, stepDurationTotals.step2.count),
        step3: toAvgDuration(stepDurationTotals.step3.totalMs, stepDurationTotals.step3.count),
      },
    },
    authErrors: {
      total: authErrors.reduce((sum, item) => sum + item.count, 0),
      breakdown: authErrors,
    },
    postPublish: {
      ...postPublish,
      modalOpenRatePct: toRate(postPublish.modalOpenedTotal, postPublish.publishedTotal),
      continueSagaClickRatePct: toRate(
        postPublish.ctaClicksByTarget.continueSaga,
        postPublish.modalOpenedTotal
      ),
      nextActionConversionPct: toRate(
        sessionsWithNextAction,
        sessionsWithPostPublishModal.size
      ),
    },
    screenStates,
    pinFriction: {
      promptShownTotal: pinFriction.promptShownTotal,
      promptSuccessTotal: pinFriction.promptSuccessTotal,
      promptAbandonTotal: pinFriction.promptAbandonTotal,
      lockNowTotal: pinFriction.lockNowTotal,
      successRatePct: toRate(pinFriction.promptSuccessTotal, pinFriction.promptShownTotal),
      abandonRatePct: toRate(pinFriction.promptAbandonTotal, pinFriction.promptShownTotal),
      abandonByReason: [...pinFriction.abandonByReason.entries()]
        .map(([reason, count]) => ({ reason, count }))
        .sort((left, right) => right.count - left.count),
    },
  };
}

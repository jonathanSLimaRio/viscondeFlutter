import type { ModerationPolicy, ModerationScope } from "@prisma/client";

import { prisma } from "@/lib/prisma";
import { ApiError } from "@/lib/server/errors";

const fallbackBlockedTermsByScope: Record<ModerationScope, string[]> = {
  USER_NAME: [
    "sexo",
    "sexual",
    "porn",
    "droga",
    "drogas",
    "matar",
    "morte",
    "assassino",
    "abuso",
    "terror",
  ],
  CHILD_NAME: [
    "sexo",
    "sexual",
    "porn",
    "droga",
    "drogas",
    "matar",
    "morte",
    "assassino",
    "abuso",
    "terror",
  ],
  STORY_TEXT: [
    "sexo",
    "sexual",
    "porn",
    "nudez",
    "droga",
    "drogas",
    "matar",
    "morte",
    "assassino",
    "abuso",
    "tortura",
    "terror",
    "sequestro",
    "suicidio",
  ],
  CHAT_TEXT: [
    "sexo",
    "sexual",
    "porn",
    "nudez",
    "droga",
    "drogas",
    "matar",
    "morte",
    "assassino",
    "abuso",
    "tortura",
    "terror",
    "sequestro",
    "suicidio",
  ],
  TEMPLATE_TEXT: [
    "sexo",
    "sexual",
    "porn",
    "nudez",
    "droga",
    "drogas",
    "matar",
    "morte",
    "assassino",
    "abuso",
    "tortura",
    "terror",
    "sequestro",
    "suicidio",
  ],
};

type EffectiveTerm = {
  termNormalized: string;
  displayTerm: string;
  policy: ModerationPolicy;
  replacement: string | null;
};

function normalizeForMatching(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim()
    .replace(/\s+/g, " ");
}

function buildPreview(value: string, max = 120) {
  const normalized = value.trim().replace(/\s+/g, " ");
  if (normalized.length <= max) {
    return normalized;
  }
  return `${normalized.slice(0, max - 3)}...`;
}

async function safeCreateModerationEvent(input: {
  userId?: string | null;
  scope: ModerationScope;
  field: string;
  originalPreview: string;
  action: "BLOCK" | "SANITIZE";
  matchedTerm: string;
}) {
  try {
    await prisma.moderationEvent.create({
      data: {
        userId: input.userId ?? null,
        scope: input.scope,
        field: input.field,
        originalPreview: input.originalPreview,
        action: input.action,
        matchedTerm: input.matchedTerm,
      },
    });
  } catch {
    // Nao quebrar o fluxo principal por falha de auditoria.
  }
}

async function loadEffectiveTerms(scope: ModerationScope): Promise<EffectiveTerm[]> {
  const terms = await prisma.moderationTerm.findMany({
    where: {
      scope,
      isActive: true,
    },
    select: {
      termNormalized: true,
      displayTerm: true,
      policy: true,
      replacement: true,
    },
    orderBy: {
      createdAt: "asc",
    },
  });

  if (terms.length > 0) {
    return terms.map((term) => ({
      termNormalized: term.termNormalized,
      displayTerm: term.displayTerm,
      policy: term.policy,
      replacement: term.replacement,
    }));
  }

  return (fallbackBlockedTermsByScope[scope] ?? []).map((term) => {
    const normalized = normalizeForMatching(term);
    return {
      termNormalized: normalized,
      displayTerm: term,
      policy: "BLOCK" as const,
      replacement: null,
    };
  });
}

function sanitizeByDisplayTerm(value: string, term: EffectiveTerm) {
  if (!term.replacement || term.replacement.trim().length === 0) {
    return value;
  }

  const replacement = term.replacement.trim();
  const escapedDisplay = term.displayTerm.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  if (!escapedDisplay) {
    return value;
  }

  const displayRegex = new RegExp(escapedDisplay, "giu");
  return value.replace(displayRegex, replacement);
}

export async function moderateTextInput(input: {
  value: string;
  scope: ModerationScope;
  field: string;
  userId?: string | null;
}) {
  const raw = input.value.trim();
  if (!raw) {
    return raw;
  }

  const normalized = normalizeForMatching(raw);
  const effectiveTerms = await loadEffectiveTerms(input.scope);

  let sanitized = raw;
  for (const term of effectiveTerms) {
    if (!term.termNormalized) {
      continue;
    }

    if (!normalized.includes(term.termNormalized)) {
      continue;
    }

    if (term.policy === "BLOCK") {
      await safeCreateModerationEvent({
        userId: input.userId,
        scope: input.scope,
        field: input.field,
        originalPreview: buildPreview(raw),
        action: "BLOCK",
        matchedTerm: term.displayTerm,
      });

      throw new ApiError(
        `Conteudo nao permitido no campo ${input.field}.`,
        400,
        "MODERATION_BLOCKED_TERM"
      );
    }

    const nextValue = sanitizeByDisplayTerm(sanitized, term);
    if (nextValue !== sanitized) {
      sanitized = nextValue;
      await safeCreateModerationEvent({
        userId: input.userId,
        scope: input.scope,
        field: input.field,
        originalPreview: buildPreview(raw),
        action: "SANITIZE",
        matchedTerm: term.displayTerm,
      });
    }
  }

  return sanitized.trim();
}

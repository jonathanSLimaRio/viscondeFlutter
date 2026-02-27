import type { ModerationPolicy, ModerationScope } from "@prisma/client";

import { prisma } from "@/lib/prisma";
import { ApiError } from "@/lib/server/errors";

function normalizeTerm(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim()
    .replace(/\s+/g, " ");
}

function normalizeOptional(value?: string | null) {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

export async function listModerationTerms() {
  const terms = await prisma.moderationTerm.findMany({
    include: {
      createdBy: {
        select: {
          id: true,
          name: true,
          email: true,
        },
      },
      updatedBy: {
        select: {
          id: true,
          name: true,
          email: true,
        },
      },
    },
    orderBy: [{ scope: "asc" }, { createdAt: "asc" }],
  });

  return terms.map((term) => ({
    id: term.id,
    termNormalized: term.termNormalized,
    displayTerm: term.displayTerm,
    policy: term.policy,
    replacement: term.replacement,
    scope: term.scope,
    isActive: term.isActive,
    createdAt: term.createdAt,
    updatedAt: term.updatedAt,
    createdBy: term.createdBy,
    updatedBy: term.updatedBy,
  }));
}

export async function createModerationTerm(
  userId: string,
  input: {
    displayTerm: string;
    policy: ModerationPolicy;
    replacement?: string | null;
    scope: ModerationScope;
    isActive?: boolean;
  }
) {
  const displayTerm = input.displayTerm.trim();
  if (!displayTerm) {
    throw new ApiError("displayTerm obrigatorio.", 400, "MODERATION_TERM_INVALID");
  }

  const termNormalized = normalizeTerm(displayTerm);
  if (!termNormalized) {
    throw new ApiError("displayTerm invalido.", 400, "MODERATION_TERM_INVALID");
  }

  if (input.policy === "SANITIZE" && !normalizeOptional(input.replacement)) {
    throw new ApiError(
      "replacement obrigatorio para policy SANITIZE.",
      400,
      "MODERATION_TERM_REPLACEMENT_REQUIRED"
    );
  }

  const existing = await prisma.moderationTerm.findUnique({
    where: {
      termNormalized,
    },
    select: {
      id: true,
    },
  });

  if (existing) {
    throw new ApiError(
      "Termo de moderacao ja cadastrado.",
      409,
      "MODERATION_TERM_CONFLICT"
    );
  }

  const created = await prisma.moderationTerm.create({
    data: {
      termNormalized,
      displayTerm,
      policy: input.policy,
      replacement: normalizeOptional(input.replacement),
      scope: input.scope,
      isActive: input.isActive ?? true,
      createdByUserId: userId,
      updatedByUserId: userId,
    },
  });

  return {
    id: created.id,
    termNormalized: created.termNormalized,
    displayTerm: created.displayTerm,
    policy: created.policy,
    replacement: created.replacement,
    scope: created.scope,
    isActive: created.isActive,
    createdAt: created.createdAt,
    updatedAt: created.updatedAt,
  };
}

export async function updateModerationTerm(
  userId: string,
  termId: string,
  input: {
    displayTerm?: string;
    policy?: ModerationPolicy;
    replacement?: string | null;
    scope?: ModerationScope;
    isActive?: boolean;
  }
) {
  const existing = await prisma.moderationTerm.findUnique({
    where: {
      id: termId,
    },
  });

  if (!existing) {
    throw new ApiError("Termo de moderacao nao encontrado.", 404, "MODERATION_TERM_NOT_FOUND");
  }

  const displayTerm = input.displayTerm?.trim();
  const termNormalized = displayTerm ? normalizeTerm(displayTerm) : undefined;

  if (termNormalized) {
    const conflict = await prisma.moderationTerm.findFirst({
      where: {
        termNormalized,
        id: {
          not: termId,
        },
      },
      select: {
        id: true,
      },
    });

    if (conflict) {
      throw new ApiError(
        "Termo de moderacao ja cadastrado.",
        409,
        "MODERATION_TERM_CONFLICT"
      );
    }
  }

  const nextPolicy = input.policy ?? existing.policy;
  const nextReplacement =
    input.replacement !== undefined ? normalizeOptional(input.replacement) : existing.replacement;

  if (nextPolicy === "SANITIZE" && !nextReplacement) {
    throw new ApiError(
      "replacement obrigatorio para policy SANITIZE.",
      400,
      "MODERATION_TERM_REPLACEMENT_REQUIRED"
    );
  }

  const updated = await prisma.moderationTerm.update({
    where: {
      id: termId,
    },
    data: {
      displayTerm,
      termNormalized,
      policy: input.policy,
      replacement: input.replacement !== undefined ? nextReplacement : undefined,
      scope: input.scope,
      isActive: input.isActive,
      updatedByUserId: userId,
    },
  });

  return {
    id: updated.id,
    termNormalized: updated.termNormalized,
    displayTerm: updated.displayTerm,
    policy: updated.policy,
    replacement: updated.replacement,
    scope: updated.scope,
    isActive: updated.isActive,
    createdAt: updated.createdAt,
    updatedAt: updated.updatedAt,
  };
}

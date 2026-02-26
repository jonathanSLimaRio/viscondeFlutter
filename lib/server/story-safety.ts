import { ApiError } from "@/lib/server/errors";

const blockedPatterns = [
  /assassin/iu,
  /arma/iu,
  /sangue/iu,
  /matar/iu,
  /morte/iu,
  /tortur/iu,
  /terror/iu,
  /suicid/iu,
  /sexo/iu,
  /sexual/iu,
  /nudez/iu,
  /porn/iu,
  /drog/iu,
  /sequestr/iu,
  /abuso/iu,
  /viol[eê]n/iu,
];

const softPatterns = [/briga/iu, /medo/iu, /monstro/iu, /escurid[aã]o/iu, /grito/iu];

function normalize(value: string) {
  return value.trim().replace(/\s+/g, " ");
}

export function assertSafeTextInput(value: string, fieldName = "contexto") {
  const normalized = normalize(value);

  if (!normalized) {
    return;
  }

  for (const pattern of blockedPatterns) {
    if (pattern.test(normalized)) {
      throw new ApiError(
        `Conteudo nao permitido para publico infantil em ${fieldName}.`,
        400,
        "UNSAFE_CONTENT"
      );
    }
  }
}

export function sanitizeIdeaText(value: string) {
  let normalized = normalize(value);

  for (const pattern of blockedPatterns) {
    normalized = normalized.replace(pattern, "desafio");
  }

  for (const pattern of softPatterns) {
    normalized = normalized.replace(pattern, "misterio");
  }

  normalized = normalized.replace(/[<>`]/g, "");

  return normalized;
}

export function filterSafeIdeas(ideas: string[]) {
  let safetyAdjusted = false;
  const safeIdeas: string[] = [];

  for (const rawIdea of ideas) {
    const idea = normalize(rawIdea);
    if (!idea) {
      continue;
    }

    const blocked = blockedPatterns.some((pattern) => pattern.test(idea));
    if (blocked) {
      const rewritten = sanitizeIdeaText(idea);
      if (rewritten) {
        safetyAdjusted = true;
        safeIdeas.push(rewritten);
      }
      continue;
    }

    const rewritten = sanitizeIdeaText(idea);
    if (rewritten !== idea) {
      safetyAdjusted = true;
    }

    safeIdeas.push(rewritten);
  }

  return {
    ideas: Array.from(new Set(safeIdeas)).slice(0, 4),
    safetyAdjusted,
  };
}

export function assertSafeContext(values: Array<{ field: string; value?: string | null }>) {
  for (const item of values) {
    if (!item.value) {
      continue;
    }

    assertSafeTextInput(item.value, item.field);
  }
}

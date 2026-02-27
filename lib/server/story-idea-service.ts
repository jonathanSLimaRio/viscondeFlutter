import { findFallbackIdeasFromPrompts } from "@/lib/server/content-admin-service";
import { env } from "@/lib/server/env";

import { assertSafeContext, filterSafeIdeas } from "@/lib/server/story-safety";
import { resolveAgeBand } from "@/lib/server/virtue-service";

type StoryIdeaSource = "AI" | "TEMPLATE";

export type StoryIdeaResult = {
  ideas: string[];
  source: StoryIdeaSource;
  safetyAdjusted: boolean;
  fallbackReason: string | null;
};

export type StoryIdeaContext = {
  theme: string;
  scenario: string;
  objective: string;
  ageSnapshotYears: number;
  characters: string[];
  currentMode: "PARENT_NARRATOR" | "CHILD_CHOOSER";
  contextHint?: string;
  lastNarrative?: string;
};

const templateIdeasByTheme: Record<string, string[]> = {
  amizade: [
    "Um personagem novo precisa de ajuda para fazer amigos na vila.",
    "A turma encontra um enigma que so pode ser resolvido cooperando.",
    "Uma festa surpresa precisa de um plano em equipe para dar certo.",
  ],
  coragem: [
    "A crianca ajuda um amigo a tentar algo novo com pequenos passos.",
    "Uma ponte de nuvens exige calma, respiracao e apoio mutuo.",
    "O grupo precisa falar com gentileza para convencer um guardiao timido.",
  ],
  empatia: [
    "Um personagem ficou triste e o grupo tenta entender como acolher.",
    "A equipe descobre pistas sobre o que cada amigo esta sentindo.",
    "Dois personagens pensam diferente e precisam se escutar.",
  ],
};

function normalizeTheme(theme: string) {
  return theme
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .trim()
    .toLowerCase();
}

function fallbackIdeas(context: StoryIdeaContext) {
  const themeKey = normalizeTheme(context.theme);
  const themeTemplates = templateIdeasByTheme[themeKey];

  if (themeTemplates && themeTemplates.length > 0) {
    return themeTemplates;
  }

  return [
    `No cenario ${context.scenario}, um pequeno desafio aparece e pede colaboracao.`,
    `Os personagens ${context.characters.slice(0, 2).join(" e ")} encontram uma pista surpresa.`,
    `Para cumprir o objetivo \"${context.objective}\", o grupo precisa fazer uma escolha gentil.`,
  ];
}

function extractTextFromResponsesPayload(payload: unknown) {
  if (!payload || typeof payload !== "object") {
    return "";
  }

  const record = payload as {
    output_text?: unknown;
    output?: Array<{ content?: Array<{ type?: string; text?: string }> }>;
  };

  if (typeof record.output_text === "string") {
    return record.output_text;
  }

  const chunks: string[] = [];
  for (const item of record.output ?? []) {
    for (const content of item.content ?? []) {
      if (typeof content.text === "string") {
        chunks.push(content.text);
      }
    }
  }

  return chunks.join("\n");
}

function parseIdeasFromText(raw: string) {
  const trimmed = raw.trim();
  if (!trimmed) {
    return [] as string[];
  }

  try {
    const parsed = JSON.parse(trimmed) as { ideas?: unknown };
    if (Array.isArray(parsed.ideas)) {
      return parsed.ideas.map((item) => String(item).trim()).filter(Boolean);
    }
  } catch {
    // ignore and fallback to line parsing
  }

  return trimmed
    .split(/\n+/)
    .map((item) => item.replace(/^[-*\d.)\s]+/, "").trim())
    .filter(Boolean);
}

async function generateIdeasFromOpenAI(context: StoryIdeaContext) {
  const instructions = [
    "Voce cria ideias para historias infantis de 4 a 10 anos.",
    "Responda em portugues brasileiro.",
    "Evite qualquer violencia, terror, linguagem adulta, sexualizacao ou conteudo assustador.",
    "Mantenha tom acolhedor e ludico.",
    "Retorne apenas JSON valido no formato: {\"ideas\":[\"...\",\"...\",\"...\"]}.",
    "Gere entre 3 e 4 ideias curtas, objetivas e acionaveis para o pai narrador.",
  ].join(" ");

  const prompt = {
    theme: context.theme,
    scenario: context.scenario,
    objective: context.objective,
    ageSnapshotYears: context.ageSnapshotYears,
    characters: context.characters,
    mode: context.currentMode,
    contextHint: context.contextHint ?? null,
    lastNarrative: context.lastNarrative ?? null,
  };

  const response = await fetch(`${env.openaiBaseUrl}/responses`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${env.openaiApiKey}`,
    },
    body: JSON.stringify({
      model: env.openaiIdeasModel,
      temperature: 0.6,
      max_output_tokens: 280,
      input: [
        {
          role: "system",
          content: instructions,
        },
        {
          role: "user",
          content: JSON.stringify(prompt),
        },
      ],
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`OpenAI request failed (${response.status}): ${body.slice(0, 300)}`);
  }

  const payload = (await response.json()) as unknown;
  const text = extractTextFromResponsesPayload(payload);
  const ideas = parseIdeasFromText(text);

  return ideas.slice(0, 4);
}

export async function generateStoryIdeas(context: StoryIdeaContext): Promise<StoryIdeaResult> {
  assertSafeContext([
    { field: "tema", value: context.theme },
    { field: "cenario", value: context.scenario },
    { field: "objetivo", value: context.objective },
    { field: "dica", value: context.contextHint },
    { field: "narrativa", value: context.lastNarrative },
  ]);

  let source: StoryIdeaSource = "TEMPLATE";
  let fallbackReason: string | null = null;
  let rawIdeas: string[] = [];
  const ageBand = resolveAgeBand(context.ageSnapshotYears);

  if (env.openaiApiKey) {
    try {
      rawIdeas = await generateIdeasFromOpenAI(context);
      source = "AI";
    } catch (error) {
      source = "TEMPLATE";
      fallbackReason =
        error instanceof Error
          ? error.message.slice(0, 240)
          : "Falha ao gerar ideias com IA.";
    }
  } else {
    fallbackReason = "OPENAI_API_KEY nao configurada.";
  }

  if (rawIdeas.length < 2) {
    const promptIdeas = await findFallbackIdeasFromPrompts({
      theme: context.theme,
      ageBand,
      mode: context.currentMode,
    });

    rawIdeas = promptIdeas.length >= 2 ? promptIdeas : fallbackIdeas(context);
    source = "TEMPLATE";
    fallbackReason = fallbackReason ?? "Resposta IA insuficiente.";
  }

  const filtered = filterSafeIdeas(rawIdeas);
  if (filtered.ideas.length < 2) {
    const fallback = filterSafeIdeas(fallbackIdeas(context));
    return {
      ideas: fallback.ideas.slice(0, 4),
      source: "TEMPLATE",
      safetyAdjusted: true,
      fallbackReason: "Conteudo inseguro bloqueado.",
    };
  }

  return {
    ideas: filtered.ideas.slice(0, 4),
    source,
    safetyAdjusted: filtered.safetyAdjusted,
    fallbackReason,
  };
}

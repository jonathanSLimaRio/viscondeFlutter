import type { AgeBand, PromptKind, StoryMode } from "@prisma/client";

import { prisma } from "@/lib/prisma";
import { ApiError } from "@/lib/server/errors";
import { moderateTextInput } from "@/lib/server/moderation-service";

function slugify(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function normalizeOptional(value?: string | null) {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }

  return trimmed;
}

async function ensureThemeExists(themeId: string | null | undefined) {
  if (!themeId) {
    return;
  }

  const exists = await prisma.storyTheme.findUnique({
    where: {
      id: themeId,
    },
    select: {
      id: true,
    },
  });

  if (!exists) {
    throw new ApiError("Tema nao encontrado.", 404, "THEME_NOT_FOUND");
  }
}

async function ensureVirtueExists(virtueId: string | null | undefined) {
  if (!virtueId) {
    return;
  }

  const exists = await prisma.virtue.findUnique({
    where: {
      id: virtueId,
    },
    select: {
      id: true,
    },
  });

  if (!exists) {
    throw new ApiError("Virtude nao encontrada.", 404, "VIRTUE_NOT_FOUND");
  }
}

function toThemeDTO(theme: {
  id: string;
  slug: string;
  name: string;
  shortDescription: string;
  iconKey: string;
  sortOrder: number;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: theme.id,
    slug: theme.slug,
    name: theme.name,
    shortDescription: theme.shortDescription,
    iconKey: theme.iconKey,
    sortOrder: theme.sortOrder,
    isActive: theme.isActive,
    createdAt: theme.createdAt,
    updatedAt: theme.updatedAt,
  };
}

function toVirtueDTO(virtue: {
  id: string;
  slug: string;
  name: string;
  shortDescription: string;
  iconKey: string;
  sortOrder: number;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: virtue.id,
    slug: virtue.slug,
    name: virtue.name,
    shortDescription: virtue.shortDescription,
    iconKey: virtue.iconKey,
    sortOrder: virtue.sortOrder,
    isActive: virtue.isActive,
    createdAt: virtue.createdAt,
    updatedAt: virtue.updatedAt,
  };
}

export async function listAdminThemes() {
  const themes = await prisma.storyTheme.findMany({
    orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
  });

  return themes.map(toThemeDTO);
}

export async function createAdminTheme(
  userId: string,
  input: {
    slug?: string;
    name: string;
    shortDescription: string;
    iconKey: string;
    sortOrder?: number;
    isActive?: boolean;
  }
) {
  const normalizedName = await moderateTextInput({
    value: input.name,
    scope: "TEMPLATE_TEXT",
    field: "name",
    userId,
  });
  const normalizedShortDescription = await moderateTextInput({
    value: input.shortDescription,
    scope: "TEMPLATE_TEXT",
    field: "shortDescription",
    userId,
  });
  const normalizedIconKey = await moderateTextInput({
    value: input.iconKey,
    scope: "TEMPLATE_TEXT",
    field: "iconKey",
    userId,
  });

  const slug = slugify(input.slug ?? normalizedName);
  if (!slug) {
    throw new ApiError("Slug invalido para tema.", 400, "THEME_SLUG_INVALID");
  }

  const existing = await prisma.storyTheme.findUnique({
    where: {
      slug,
    },
    select: {
      id: true,
    },
  });

  if (existing) {
    throw new ApiError("Slug de tema ja cadastrado.", 409, "THEME_SLUG_CONFLICT");
  }

  const created = await prisma.storyTheme.create({
    data: {
      slug,
      name: normalizedName,
      shortDescription: normalizedShortDescription,
      iconKey: normalizedIconKey,
      sortOrder: input.sortOrder ?? 0,
      isActive: input.isActive ?? true,
    },
  });

  return toThemeDTO(created);
}

export async function updateAdminTheme(
  userId: string,
  themeId: string,
  input: {
    slug?: string;
    name?: string;
    shortDescription?: string;
    iconKey?: string;
    sortOrder?: number;
    isActive?: boolean;
  }
) {
  const existing = await prisma.storyTheme.findUnique({
    where: {
      id: themeId,
    },
    select: {
      id: true,
    },
  });

  if (!existing) {
    throw new ApiError("Tema nao encontrado.", 404, "THEME_NOT_FOUND");
  }

  const normalizedName = input.name
    ? await moderateTextInput({
        value: input.name,
        scope: "TEMPLATE_TEXT",
        field: "name",
        userId,
      })
    : undefined;
  const normalizedShortDescription = input.shortDescription
    ? await moderateTextInput({
        value: input.shortDescription,
        scope: "TEMPLATE_TEXT",
        field: "shortDescription",
        userId,
      })
    : undefined;
  const normalizedIconKey = input.iconKey
    ? await moderateTextInput({
        value: input.iconKey,
        scope: "TEMPLATE_TEXT",
        field: "iconKey",
        userId,
      })
    : undefined;

  let nextSlug: string | undefined;
  if (input.slug !== undefined || normalizedName !== undefined) {
    nextSlug = slugify(input.slug ?? normalizedName ?? "");
    if (!nextSlug) {
      throw new ApiError("Slug invalido para tema.", 400, "THEME_SLUG_INVALID");
    }

    const conflicting = await prisma.storyTheme.findFirst({
      where: {
        slug: nextSlug,
        id: {
          not: themeId,
        },
      },
      select: {
        id: true,
      },
    });

    if (conflicting) {
      throw new ApiError("Slug de tema ja cadastrado.", 409, "THEME_SLUG_CONFLICT");
    }
  }

  const updated = await prisma.storyTheme.update({
    where: {
      id: themeId,
    },
    data: {
      slug: nextSlug,
      name: normalizedName,
      shortDescription: normalizedShortDescription,
      iconKey: normalizedIconKey,
      sortOrder: input.sortOrder,
      isActive: input.isActive,
    },
  });

  return toThemeDTO(updated);
}

export async function listAdminVirtues() {
  const virtues = await prisma.virtue.findMany({
    orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
  });

  return virtues.map(toVirtueDTO);
}

export async function createAdminVirtue(
  userId: string,
  input: {
    slug?: string;
    name: string;
    shortDescription: string;
    iconKey: string;
    sortOrder?: number;
    isActive?: boolean;
  }
) {
  const normalizedName = await moderateTextInput({
    value: input.name,
    scope: "TEMPLATE_TEXT",
    field: "name",
    userId,
  });
  const normalizedShortDescription = await moderateTextInput({
    value: input.shortDescription,
    scope: "TEMPLATE_TEXT",
    field: "shortDescription",
    userId,
  });
  const normalizedIconKey = await moderateTextInput({
    value: input.iconKey,
    scope: "TEMPLATE_TEXT",
    field: "iconKey",
    userId,
  });
  const slug = slugify(input.slug ?? normalizedName);

  if (!slug) {
    throw new ApiError("Slug invalido para virtude.", 400, "VIRTUE_SLUG_INVALID");
  }

  const existing = await prisma.virtue.findUnique({
    where: {
      slug,
    },
    select: {
      id: true,
    },
  });

  if (existing) {
    throw new ApiError("Slug de virtude ja cadastrado.", 409, "VIRTUE_SLUG_CONFLICT");
  }

  const created = await prisma.virtue.create({
    data: {
      slug,
      name: normalizedName,
      shortDescription: normalizedShortDescription,
      iconKey: normalizedIconKey,
      sortOrder: input.sortOrder ?? 0,
      isActive: input.isActive ?? true,
    },
  });

  return toVirtueDTO(created);
}

export async function updateAdminVirtue(
  userId: string,
  virtueId: string,
  input: {
    slug?: string;
    name?: string;
    shortDescription?: string;
    iconKey?: string;
    sortOrder?: number;
    isActive?: boolean;
  }
) {
  const existing = await prisma.virtue.findUnique({
    where: {
      id: virtueId,
    },
    select: {
      id: true,
    },
  });

  if (!existing) {
    throw new ApiError("Virtude nao encontrada.", 404, "VIRTUE_NOT_FOUND");
  }

  const normalizedName = input.name
    ? await moderateTextInput({
        value: input.name,
        scope: "TEMPLATE_TEXT",
        field: "name",
        userId,
      })
    : undefined;
  const normalizedShortDescription = input.shortDescription
    ? await moderateTextInput({
        value: input.shortDescription,
        scope: "TEMPLATE_TEXT",
        field: "shortDescription",
        userId,
      })
    : undefined;
  const normalizedIconKey = input.iconKey
    ? await moderateTextInput({
        value: input.iconKey,
        scope: "TEMPLATE_TEXT",
        field: "iconKey",
        userId,
      })
    : undefined;

  let nextSlug: string | undefined;
  if (input.slug !== undefined || normalizedName !== undefined) {
    nextSlug = slugify(input.slug ?? normalizedName ?? "");
    if (!nextSlug) {
      throw new ApiError("Slug invalido para virtude.", 400, "VIRTUE_SLUG_INVALID");
    }

    const conflicting = await prisma.virtue.findFirst({
      where: {
        slug: nextSlug,
        id: {
          not: virtueId,
        },
      },
      select: {
        id: true,
      },
    });

    if (conflicting) {
      throw new ApiError("Slug de virtude ja cadastrado.", 409, "VIRTUE_SLUG_CONFLICT");
    }
  }

  const updated = await prisma.virtue.update({
    where: {
      id: virtueId,
    },
    data: {
      slug: nextSlug,
      name: normalizedName,
      shortDescription: normalizedShortDescription,
      iconKey: normalizedIconKey,
      sortOrder: input.sortOrder,
      isActive: input.isActive,
    },
  });

  return toVirtueDTO(updated);
}

export async function listAdminVirtueTemplates(filters: {
  virtueId?: string;
  ageBand?: AgeBand;
}) {
  const templates = await prisma.virtueTemplate.findMany({
    where: {
      virtueId: filters.virtueId,
      ageBand: filters.ageBand,
    },
    include: {
      virtue: {
        select: {
          id: true,
          slug: true,
          name: true,
        },
      },
    },
    orderBy: [{ virtue: { sortOrder: "asc" } }, { ageBand: "asc" }, { sortOrder: "asc" }],
  });

  return templates.map((item) => ({
    id: item.id,
    virtueId: item.virtueId,
    ageBand: item.ageBand,
    dilemmaText: item.dilemmaText,
    endQuestionText: item.endQuestionText,
    sortOrder: item.sortOrder,
    isActive: item.isActive,
    virtue: item.virtue,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
  }));
}

export async function createAdminVirtueTemplate(
  userId: string,
  input: {
    virtueId: string;
    ageBand: AgeBand;
    dilemmaText: string;
    endQuestionText: string;
    sortOrder?: number;
    isActive?: boolean;
  }
) {
  await ensureVirtueExists(input.virtueId);

  const dilemmaText = await moderateTextInput({
    value: input.dilemmaText,
    scope: "TEMPLATE_TEXT",
    field: "dilemmaText",
    userId,
  });
  const endQuestionText = await moderateTextInput({
    value: input.endQuestionText,
    scope: "TEMPLATE_TEXT",
    field: "endQuestionText",
    userId,
  });

  const created = await prisma.virtueTemplate.create({
    data: {
      virtueId: input.virtueId,
      ageBand: input.ageBand,
      dilemmaText,
      endQuestionText,
      sortOrder: input.sortOrder ?? 0,
      isActive: input.isActive ?? true,
    },
    include: {
      virtue: {
        select: {
          id: true,
          slug: true,
          name: true,
        },
      },
    },
  });

  return {
    id: created.id,
    virtueId: created.virtueId,
    ageBand: created.ageBand,
    dilemmaText: created.dilemmaText,
    endQuestionText: created.endQuestionText,
    sortOrder: created.sortOrder,
    isActive: created.isActive,
    virtue: created.virtue,
    createdAt: created.createdAt,
    updatedAt: created.updatedAt,
  };
}

export async function updateAdminVirtueTemplate(
  userId: string,
  templateId: string,
  input: {
    dilemmaText?: string;
    endQuestionText?: string;
    sortOrder?: number;
    isActive?: boolean;
  }
) {
  const existing = await prisma.virtueTemplate.findUnique({
    where: {
      id: templateId,
    },
    select: {
      id: true,
    },
  });

  if (!existing) {
    throw new ApiError("Template de virtude nao encontrado.", 404, "VIRTUE_TEMPLATE_NOT_FOUND");
  }

  const dilemmaText = input.dilemmaText
    ? await moderateTextInput({
        value: input.dilemmaText,
        scope: "TEMPLATE_TEXT",
        field: "dilemmaText",
        userId,
      })
    : undefined;
  const endQuestionText = input.endQuestionText
    ? await moderateTextInput({
        value: input.endQuestionText,
        scope: "TEMPLATE_TEXT",
        field: "endQuestionText",
        userId,
      })
    : undefined;

  const updated = await prisma.virtueTemplate.update({
    where: {
      id: templateId,
    },
    data: {
      dilemmaText,
      endQuestionText,
      sortOrder: input.sortOrder,
      isActive: input.isActive,
    },
    include: {
      virtue: {
        select: {
          id: true,
          slug: true,
          name: true,
        },
      },
    },
  });

  return {
    id: updated.id,
    virtueId: updated.virtueId,
    ageBand: updated.ageBand,
    dilemmaText: updated.dilemmaText,
    endQuestionText: updated.endQuestionText,
    sortOrder: updated.sortOrder,
    isActive: updated.isActive,
    virtue: updated.virtue,
    createdAt: updated.createdAt,
    updatedAt: updated.updatedAt,
  };
}

export async function listAdminPrompts(filters: {
  kind?: PromptKind;
  themeId?: string;
  virtueId?: string;
  ageBand?: AgeBand;
  mode?: StoryMode;
}) {
  const prompts = await prisma.contentPrompt.findMany({
    where: {
      kind: filters.kind,
      themeId: filters.themeId,
      virtueId: filters.virtueId,
      ageBand: filters.ageBand,
      mode: filters.mode,
    },
    include: {
      theme: {
        select: {
          id: true,
          slug: true,
          name: true,
        },
      },
      virtue: {
        select: {
          id: true,
          slug: true,
          name: true,
        },
      },
    },
    orderBy: [{ kind: "asc" }, { sortOrder: "asc" }, { title: "asc" }],
  });

  return prompts.map((prompt) => ({
    id: prompt.id,
    key: prompt.key,
    kind: prompt.kind,
    title: prompt.title,
    text: prompt.text,
    ageBand: prompt.ageBand,
    mode: prompt.mode,
    sortOrder: prompt.sortOrder,
    isActive: prompt.isActive,
    theme: prompt.theme,
    virtue: prompt.virtue,
    createdAt: prompt.createdAt,
    updatedAt: prompt.updatedAt,
  }));
}

export async function createAdminPrompt(
  userId: string,
  input: {
    key: string;
    kind: PromptKind;
    title: string;
    text: string;
    themeId?: string | null;
    virtueId?: string | null;
    ageBand?: AgeBand | null;
    mode?: StoryMode | null;
    sortOrder?: number;
    isActive?: boolean;
  }
) {
  await ensureThemeExists(input.themeId);
  await ensureVirtueExists(input.virtueId);

  const normalizedTitle = await moderateTextInput({
    value: input.title,
    scope: "TEMPLATE_TEXT",
    field: "title",
    userId,
  });
  const normalizedText = await moderateTextInput({
    value: input.text,
    scope: "TEMPLATE_TEXT",
    field: "text",
    userId,
  });
  const key = slugify(input.key);
  if (!key) {
    throw new ApiError("Chave de prompt invalida.", 400, "PROMPT_KEY_INVALID");
  }

  const existing = await prisma.contentPrompt.findUnique({
    where: {
      key,
    },
    select: {
      id: true,
    },
  });

  if (existing) {
    throw new ApiError("Chave de prompt ja cadastrada.", 409, "PROMPT_KEY_CONFLICT");
  }

  const created = await prisma.contentPrompt.create({
    data: {
      key,
      kind: input.kind,
      title: normalizedTitle,
      text: normalizedText,
      themeId: normalizeOptional(input.themeId),
      virtueId: normalizeOptional(input.virtueId),
      ageBand: input.ageBand ?? null,
      mode: input.mode ?? null,
      sortOrder: input.sortOrder ?? 0,
      isActive: input.isActive ?? true,
    },
    include: {
      theme: {
        select: {
          id: true,
          slug: true,
          name: true,
        },
      },
      virtue: {
        select: {
          id: true,
          slug: true,
          name: true,
        },
      },
    },
  });

  return {
    id: created.id,
    key: created.key,
    kind: created.kind,
    title: created.title,
    text: created.text,
    ageBand: created.ageBand,
    mode: created.mode,
    sortOrder: created.sortOrder,
    isActive: created.isActive,
    theme: created.theme,
    virtue: created.virtue,
    createdAt: created.createdAt,
    updatedAt: created.updatedAt,
  };
}

export async function updateAdminPrompt(
  userId: string,
  promptId: string,
  input: {
    key?: string;
    kind?: PromptKind;
    title?: string;
    text?: string;
    themeId?: string | null;
    virtueId?: string | null;
    ageBand?: AgeBand | null;
    mode?: StoryMode | null;
    sortOrder?: number;
    isActive?: boolean;
  }
) {
  const existing = await prisma.contentPrompt.findUnique({
    where: {
      id: promptId,
    },
    select: {
      id: true,
    },
  });

  if (!existing) {
    throw new ApiError("Prompt nao encontrado.", 404, "PROMPT_NOT_FOUND");
  }

  await ensureThemeExists(input.themeId);
  await ensureVirtueExists(input.virtueId);

  let key: string | undefined;
  if (input.key !== undefined) {
    key = slugify(input.key);
    if (!key) {
      throw new ApiError("Chave de prompt invalida.", 400, "PROMPT_KEY_INVALID");
    }

    const conflict = await prisma.contentPrompt.findFirst({
      where: {
        key,
        id: {
          not: promptId,
        },
      },
      select: {
        id: true,
      },
    });

    if (conflict) {
      throw new ApiError("Chave de prompt ja cadastrada.", 409, "PROMPT_KEY_CONFLICT");
    }
  }

  const title = input.title
    ? await moderateTextInput({
        value: input.title,
        scope: "TEMPLATE_TEXT",
        field: "title",
        userId,
      })
    : undefined;
  const text = input.text
    ? await moderateTextInput({
        value: input.text,
        scope: "TEMPLATE_TEXT",
        field: "text",
        userId,
      })
    : undefined;

  const updated = await prisma.contentPrompt.update({
    where: {
      id: promptId,
    },
    data: {
      key,
      kind: input.kind,
      title,
      text,
      themeId: input.themeId !== undefined ? normalizeOptional(input.themeId) : undefined,
      virtueId: input.virtueId !== undefined ? normalizeOptional(input.virtueId) : undefined,
      ageBand: input.ageBand !== undefined ? input.ageBand : undefined,
      mode: input.mode !== undefined ? input.mode : undefined,
      sortOrder: input.sortOrder,
      isActive: input.isActive,
    },
    include: {
      theme: {
        select: {
          id: true,
          slug: true,
          name: true,
        },
      },
      virtue: {
        select: {
          id: true,
          slug: true,
          name: true,
        },
      },
    },
  });

  return {
    id: updated.id,
    key: updated.key,
    kind: updated.kind,
    title: updated.title,
    text: updated.text,
    ageBand: updated.ageBand,
    mode: updated.mode,
    sortOrder: updated.sortOrder,
    isActive: updated.isActive,
    theme: updated.theme,
    virtue: updated.virtue,
    createdAt: updated.createdAt,
    updatedAt: updated.updatedAt,
  };
}

export async function listContentThemes() {
  const themes = await prisma.storyTheme.findMany({
    where: {
      isActive: true,
    },
    orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
  });

  return themes.map(toThemeDTO);
}

export async function listPublicStoryTemplates() {
  const templates = await prisma.storyTemplate.findMany({
    where: {
      isPublished: true,
      isActive: true,
    },
    include: {
      theme: {
        select: {
          id: true,
          slug: true,
          name: true,
        },
      },
      virtue: {
        select: {
          id: true,
          slug: true,
          name: true,
        },
      },
      _count: {
        select: {
          characters: true,
          nodes: true,
        },
      },
    },
    orderBy: [{ updatedAt: "desc" }, { title: "asc" }],
  });

  return templates.map((template) => ({
    id: template.id,
    slug: template.slug,
    title: template.title,
    description: template.description,
    ageBand: template.ageBand,
    version: template.version,
    theme: template.theme,
    virtue: template.virtue,
    defaultScenario: template.defaultScenario,
    defaultObjective: template.defaultObjective,
    charactersCount: template._count.characters,
    nodesCount: template._count.nodes,
    updatedAt: template.updatedAt,
  }));
}

export async function getPublicStoryTemplatePrefill(templateId: string) {
  const template = await prisma.storyTemplate.findFirst({
    where: {
      id: templateId,
      isPublished: true,
      isActive: true,
    },
    include: {
      theme: {
        select: {
          id: true,
          slug: true,
          name: true,
        },
      },
      virtue: {
        select: {
          id: true,
          slug: true,
          name: true,
        },
      },
      characters: {
        orderBy: {
          sortOrder: "asc",
        },
      },
    },
  });

  if (!template) {
    throw new ApiError("Template publicado nao encontrado.", 404, "STORY_TEMPLATE_NOT_FOUND");
  }

  return {
    id: template.id,
    slug: template.slug,
    title: template.title,
    description: template.description,
    ageBand: template.ageBand,
    version: template.version,
    virtueId: template.virtueId,
    theme: template.theme?.name ?? "",
    scenario: template.defaultScenario,
    objective: template.defaultObjective,
    characters: template.characters.map((character) => ({
      name: character.name,
      role: character.role,
    })),
    virtue: template.virtue,
    themeMeta: template.theme,
  };
}

export async function resolveTemplateForStoryCreation(sourceTemplateId?: string) {
  if (!sourceTemplateId) {
    return null;
  }

  const template = await prisma.storyTemplate.findFirst({
    where: {
      id: sourceTemplateId,
      isPublished: true,
      isActive: true,
    },
    select: {
      id: true,
      virtueId: true,
      title: true,
    },
  });

  if (!template) {
    throw new ApiError("Template informado nao esta disponivel.", 404, "STORY_TEMPLATE_NOT_FOUND");
  }

  return template;
}

export async function findFallbackIdeasFromPrompts(input: {
  theme?: string;
  virtueId?: string | null;
  ageBand?: AgeBand | null;
  mode?: StoryMode;
}) {
  const prompts = await prisma.contentPrompt.findMany({
    where: {
      kind: "IDEA_FALLBACK",
      isActive: true,
      OR: [
        {
          theme: input.theme
            ? {
                name: {
                  contains: input.theme,
                  mode: "insensitive",
                },
              }
            : undefined,
        },
        input.virtueId
          ? {
              virtueId: input.virtueId,
            }
          : undefined,
        input.ageBand
          ? {
              ageBand: input.ageBand,
            }
          : undefined,
        input.mode
          ? {
              mode: input.mode,
            }
          : undefined,
        {},
      ].filter((entry) => Boolean(entry)),
    },
    orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }],
    take: 8,
    select: {
      text: true,
    },
  });

  return prompts.map((prompt) => prompt.text.trim()).filter(Boolean);
}

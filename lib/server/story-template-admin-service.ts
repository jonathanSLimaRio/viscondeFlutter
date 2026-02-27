import type { AgeBand, Prisma, StoryTemplateNodeKind } from "@prisma/client";

import { prisma } from "@/lib/prisma";
import { ApiError } from "@/lib/server/errors";
import { moderateTextInput } from "@/lib/server/moderation-service";

type DbClient = Prisma.TransactionClient | typeof prisma;

type ValidationIssue = {
  code: string;
  message: string;
  nodeId?: string;
};

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
  return trimmed.length > 0 ? trimmed : null;
}

async function ensureThemeExists(themeId: string | null | undefined) {
  if (!themeId) {
    return;
  }

  const exists = await prisma.storyTheme.findUnique({
    where: { id: themeId },
    select: { id: true },
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
    where: { id: virtueId },
    select: { id: true },
  });
  if (!exists) {
    throw new ApiError("Virtude nao encontrada.", 404, "VIRTUE_NOT_FOUND");
  }
}

async function prepareTemplateForEdit(
  tx: Prisma.TransactionClient,
  templateId: string,
  userId: string
) {
  const current = await tx.storyTemplate.findUnique({
    where: {
      id: templateId,
    },
    select: {
      id: true,
      isPublished: true,
    },
  });

  if (!current) {
    throw new ApiError("Template de historia nao encontrado.", 404, "STORY_TEMPLATE_NOT_FOUND");
  }

  if (!current.isPublished) {
    await tx.storyTemplate.update({
      where: { id: templateId },
      data: {
        updatedByUserId: userId,
      },
    });
    return;
  }

  await tx.storyTemplate.update({
    where: { id: templateId },
    data: {
      isPublished: false,
      publishedAt: null,
      version: {
        increment: 1,
      },
      updatedByUserId: userId,
    },
  });
}

function toTemplateListItem(template: {
  id: string;
  slug: string;
  title: string;
  description: string;
  isActive: boolean;
  isPublished: boolean;
  version: number;
  ageBand: AgeBand | null;
  updatedAt: Date;
  publishedAt: Date | null;
  theme: { id: string; name: string; slug: string } | null;
  virtue: { id: string; name: string; slug: string } | null;
  _count: { nodes: number; characters: number };
}) {
  return {
    id: template.id,
    slug: template.slug,
    title: template.title,
    description: template.description,
    isActive: template.isActive,
    isPublished: template.isPublished,
    version: template.version,
    ageBand: template.ageBand,
    updatedAt: template.updatedAt,
    publishedAt: template.publishedAt,
    theme: template.theme,
    virtue: template.virtue,
    nodesCount: template._count.nodes,
    charactersCount: template._count.characters,
  };
}

function toTemplateDetail(template: {
  id: string;
  slug: string;
  title: string;
  description: string;
  isActive: boolean;
  isPublished: boolean;
  version: number;
  ageBand: AgeBand | null;
  defaultScenario: string;
  defaultObjective: string;
  publishedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  theme: { id: string; slug: string; name: string } | null;
  virtue: { id: string; slug: string; name: string } | null;
  characters: Array<{
    id: string;
    name: string;
    role: string | null;
    sortOrder: number;
    createdAt: Date;
    updatedAt: Date;
  }>;
  nodes: Array<{
    id: string;
    nodeKey: string;
    kind: StoryTemplateNodeKind;
    title: string;
    narratorText: string | null;
    promptHint: string | null;
    sortOrder: number;
    createdAt: Date;
    updatedAt: Date;
    options: Array<{
      id: string;
      optionKey: string;
      label: string;
      nextNodeId: string;
      sortOrder: number;
      createdAt: Date;
      updatedAt: Date;
    }>;
  }>;
}) {
  return {
    id: template.id,
    slug: template.slug,
    title: template.title,
    description: template.description,
    isActive: template.isActive,
    isPublished: template.isPublished,
    version: template.version,
    ageBand: template.ageBand,
    defaultScenario: template.defaultScenario,
    defaultObjective: template.defaultObjective,
    publishedAt: template.publishedAt,
    createdAt: template.createdAt,
    updatedAt: template.updatedAt,
    theme: template.theme,
    virtue: template.virtue,
    characters: template.characters,
    nodes: template.nodes.map((node) => ({
      id: node.id,
      nodeKey: node.nodeKey,
      kind: node.kind,
      title: node.title,
      narratorText: node.narratorText,
      promptHint: node.promptHint,
      sortOrder: node.sortOrder,
      createdAt: node.createdAt,
      updatedAt: node.updatedAt,
      options: node.options.map((option) => ({
        id: option.id,
        optionKey: option.optionKey,
        label: option.label,
        nextNodeId: option.nextNodeId,
        sortOrder: option.sortOrder,
        createdAt: option.createdAt,
        updatedAt: option.updatedAt,
      })),
    })),
  };
}

async function getTemplateDetailById(db: DbClient, templateId: string) {
  const template = await db.storyTemplate.findUnique({
    where: {
      id: templateId,
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
        orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }],
      },
      nodes: {
        orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }],
        include: {
          options: {
            orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }],
          },
        },
      },
    },
  });

  if (!template) {
    throw new ApiError("Template de historia nao encontrado.", 404, "STORY_TEMPLATE_NOT_FOUND");
  }

  return template;
}

async function ensureTemplateSlugAvailable(slug: string, templateId?: string) {
  const conflict = await prisma.storyTemplate.findFirst({
    where: {
      slug,
      id: templateId
        ? {
            not: templateId,
          }
        : undefined,
    },
    select: {
      id: true,
    },
  });

  if (conflict) {
    throw new ApiError("Slug de template ja cadastrado.", 409, "STORY_TEMPLATE_SLUG_CONFLICT");
  }
}

export async function listAdminStoryTemplates() {
  const templates = await prisma.storyTemplate.findMany({
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
          nodes: true,
          characters: true,
        },
      },
    },
    orderBy: [{ updatedAt: "desc" }, { title: "asc" }],
  });

  return templates.map(toTemplateListItem);
}

export async function createAdminStoryTemplate(
  userId: string,
  input: {
    slug?: string;
    title: string;
    description: string;
    themeId?: string | null;
    virtueId?: string | null;
    ageBand?: AgeBand | null;
    defaultScenario: string;
    defaultObjective: string;
    isActive?: boolean;
  }
) {
  await ensureThemeExists(input.themeId);
  await ensureVirtueExists(input.virtueId);

  const title = await moderateTextInput({
    value: input.title,
    scope: "TEMPLATE_TEXT",
    field: "title",
    userId,
  });
  const description = await moderateTextInput({
    value: input.description,
    scope: "TEMPLATE_TEXT",
    field: "description",
    userId,
  });
  const defaultScenario = await moderateTextInput({
    value: input.defaultScenario,
    scope: "TEMPLATE_TEXT",
    field: "defaultScenario",
    userId,
  });
  const defaultObjective = await moderateTextInput({
    value: input.defaultObjective,
    scope: "TEMPLATE_TEXT",
    field: "defaultObjective",
    userId,
  });

  const slug = slugify(input.slug ?? title);
  if (!slug) {
    throw new ApiError("Slug invalido para template.", 400, "STORY_TEMPLATE_SLUG_INVALID");
  }

  await ensureTemplateSlugAvailable(slug);

  const created = await prisma.storyTemplate.create({
    data: {
      slug,
      title,
      description,
      themeId: normalizeOptional(input.themeId),
      virtueId: normalizeOptional(input.virtueId),
      ageBand: input.ageBand ?? null,
      defaultScenario,
      defaultObjective,
      isActive: input.isActive ?? true,
      isPublished: false,
      version: 1,
      createdByUserId: userId,
      updatedByUserId: userId,
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
          nodes: true,
          characters: true,
        },
      },
    },
  });

  return toTemplateListItem(created);
}

export async function getAdminStoryTemplate(templateId: string) {
  const template = await getTemplateDetailById(prisma, templateId);
  return toTemplateDetail(template);
}

export async function updateAdminStoryTemplate(
  userId: string,
  templateId: string,
  input: {
    slug?: string;
    title?: string;
    description?: string;
    themeId?: string | null;
    virtueId?: string | null;
    ageBand?: AgeBand | null;
    defaultScenario?: string;
    defaultObjective?: string;
    isActive?: boolean;
  }
) {
  await ensureThemeExists(input.themeId);
  await ensureVirtueExists(input.virtueId);

  const title = input.title
    ? await moderateTextInput({
        value: input.title,
        scope: "TEMPLATE_TEXT",
        field: "title",
        userId,
      })
    : undefined;
  const description = input.description
    ? await moderateTextInput({
        value: input.description,
        scope: "TEMPLATE_TEXT",
        field: "description",
        userId,
      })
    : undefined;
  const defaultScenario = input.defaultScenario
    ? await moderateTextInput({
        value: input.defaultScenario,
        scope: "TEMPLATE_TEXT",
        field: "defaultScenario",
        userId,
      })
    : undefined;
  const defaultObjective = input.defaultObjective
    ? await moderateTextInput({
        value: input.defaultObjective,
        scope: "TEMPLATE_TEXT",
        field: "defaultObjective",
        userId,
      })
    : undefined;

  let slug: string | undefined;
  if (input.slug !== undefined || title !== undefined) {
    slug = slugify(input.slug ?? title ?? "");
    if (!slug) {
      throw new ApiError("Slug invalido para template.", 400, "STORY_TEMPLATE_SLUG_INVALID");
    }
    await ensureTemplateSlugAvailable(slug, templateId);
  }

  await prisma.$transaction(async (tx) => {
    await prepareTemplateForEdit(tx, templateId, userId);
    await tx.storyTemplate.update({
      where: {
        id: templateId,
      },
      data: {
        slug,
        title,
        description,
        themeId: input.themeId !== undefined ? normalizeOptional(input.themeId) : undefined,
        virtueId: input.virtueId !== undefined ? normalizeOptional(input.virtueId) : undefined,
        ageBand: input.ageBand !== undefined ? input.ageBand : undefined,
        defaultScenario,
        defaultObjective,
        isActive: input.isActive,
        updatedByUserId: userId,
      },
    });
  });

  return getAdminStoryTemplate(templateId);
}

export async function addAdminStoryTemplateCharacter(
  userId: string,
  templateId: string,
  input: {
    name: string;
    role?: string | null;
    sortOrder?: number;
  }
) {
  const name = await moderateTextInput({
    value: input.name,
    scope: "TEMPLATE_TEXT",
    field: "name",
    userId,
  });
  const role = input.role
    ? await moderateTextInput({
        value: input.role,
        scope: "TEMPLATE_TEXT",
        field: "role",
        userId,
      })
    : null;

  await prisma.$transaction(async (tx) => {
    await prepareTemplateForEdit(tx, templateId, userId);

    let sortOrder = input.sortOrder;
    if (sortOrder === undefined) {
      const latest = await tx.storyTemplateCharacter.findFirst({
        where: {
          templateId,
        },
        orderBy: {
          sortOrder: "desc",
        },
        select: {
          sortOrder: true,
        },
      });
      sortOrder = (latest?.sortOrder ?? -1) + 1;
    }

    await tx.storyTemplateCharacter.create({
      data: {
        templateId,
        name,
        role,
        sortOrder,
      },
    });
  });

  return getAdminStoryTemplate(templateId);
}

export async function addAdminStoryTemplateNode(
  userId: string,
  templateId: string,
  input: {
    nodeKey: string;
    kind: StoryTemplateNodeKind;
    title: string;
    narratorText?: string | null;
    promptHint?: string | null;
    sortOrder?: number;
  }
) {
  const nodeKey = slugify(input.nodeKey);
  if (!nodeKey) {
    throw new ApiError("nodeKey invalido.", 400, "STORY_TEMPLATE_NODE_KEY_INVALID");
  }

  const title = await moderateTextInput({
    value: input.title,
    scope: "TEMPLATE_TEXT",
    field: "title",
    userId,
  });
  const narratorText = input.narratorText
    ? await moderateTextInput({
        value: input.narratorText,
        scope: "TEMPLATE_TEXT",
        field: "narratorText",
        userId,
      })
    : null;
  const promptHint = input.promptHint
    ? await moderateTextInput({
        value: input.promptHint,
        scope: "TEMPLATE_TEXT",
        field: "promptHint",
        userId,
      })
    : null;

  await prisma.$transaction(async (tx) => {
    await prepareTemplateForEdit(tx, templateId, userId);

    const conflict = await tx.storyTemplateNode.findFirst({
      where: {
        templateId,
        nodeKey,
      },
      select: {
        id: true,
      },
    });

    if (conflict) {
      throw new ApiError("nodeKey ja existe neste template.", 409, "STORY_TEMPLATE_NODE_KEY_CONFLICT");
    }

    let sortOrder = input.sortOrder;
    if (sortOrder === undefined) {
      const latest = await tx.storyTemplateNode.findFirst({
        where: {
          templateId,
        },
        orderBy: {
          sortOrder: "desc",
        },
        select: {
          sortOrder: true,
        },
      });
      sortOrder = (latest?.sortOrder ?? -1) + 1;
    }

    await tx.storyTemplateNode.create({
      data: {
        templateId,
        nodeKey,
        kind: input.kind,
        title,
        narratorText,
        promptHint,
        sortOrder,
      },
    });
  });

  return getAdminStoryTemplate(templateId);
}

export async function updateAdminStoryTemplateNode(
  userId: string,
  templateId: string,
  nodeId: string,
  input: {
    nodeKey?: string;
    kind?: StoryTemplateNodeKind;
    title?: string;
    narratorText?: string | null;
    promptHint?: string | null;
    sortOrder?: number;
  }
) {
  const node = await prisma.storyTemplateNode.findUnique({
    where: {
      id: nodeId,
    },
    select: {
      id: true,
      templateId: true,
    },
  });

  if (!node || node.templateId !== templateId) {
    throw new ApiError("No de template nao encontrado.", 404, "STORY_TEMPLATE_NODE_NOT_FOUND");
  }

  const nodeKey = input.nodeKey !== undefined ? slugify(input.nodeKey) : undefined;
  if (input.nodeKey !== undefined && !nodeKey) {
    throw new ApiError("nodeKey invalido.", 400, "STORY_TEMPLATE_NODE_KEY_INVALID");
  }

  const title = input.title
    ? await moderateTextInput({
        value: input.title,
        scope: "TEMPLATE_TEXT",
        field: "title",
        userId,
      })
    : undefined;
  const narratorText = input.narratorText
    ? await moderateTextInput({
        value: input.narratorText,
        scope: "TEMPLATE_TEXT",
        field: "narratorText",
        userId,
      })
    : input.narratorText === null
      ? null
      : undefined;
  const promptHint = input.promptHint
    ? await moderateTextInput({
        value: input.promptHint,
        scope: "TEMPLATE_TEXT",
        field: "promptHint",
        userId,
      })
    : input.promptHint === null
      ? null
      : undefined;

  await prisma.$transaction(async (tx) => {
    await prepareTemplateForEdit(tx, templateId, userId);

    if (nodeKey) {
      const conflict = await tx.storyTemplateNode.findFirst({
        where: {
          templateId,
          nodeKey,
          id: {
            not: nodeId,
          },
        },
        select: {
          id: true,
        },
      });

      if (conflict) {
        throw new ApiError("nodeKey ja existe neste template.", 409, "STORY_TEMPLATE_NODE_KEY_CONFLICT");
      }
    }

    await tx.storyTemplateNode.update({
      where: {
        id: nodeId,
      },
      data: {
        nodeKey,
        kind: input.kind,
        title,
        narratorText,
        promptHint,
        sortOrder: input.sortOrder,
      },
    });
  });

  return getAdminStoryTemplate(templateId);
}

export async function addAdminStoryTemplateOption(
  userId: string,
  templateId: string,
  input: {
    nodeId: string;
    optionKey: string;
    label: string;
    nextNodeId: string;
    sortOrder?: number;
  }
) {
  const optionKey = slugify(input.optionKey);
  if (!optionKey) {
    throw new ApiError("optionKey invalido.", 400, "STORY_TEMPLATE_OPTION_KEY_INVALID");
  }

  const label = await moderateTextInput({
    value: input.label,
    scope: "TEMPLATE_TEXT",
    field: "label",
    userId,
  });

  await prisma.$transaction(async (tx) => {
    await prepareTemplateForEdit(tx, templateId, userId);

    const node = await tx.storyTemplateNode.findUnique({
      where: {
        id: input.nodeId,
      },
      select: {
        id: true,
        templateId: true,
        kind: true,
      },
    });

    if (!node || node.templateId !== templateId) {
      throw new ApiError("No de origem nao encontrado.", 404, "STORY_TEMPLATE_NODE_NOT_FOUND");
    }

    if (node.kind !== "CHOICE") {
      throw new ApiError("Apenas nos CHOICE aceitam opcoes.", 409, "STORY_TEMPLATE_OPTION_NODE_KIND_INVALID");
    }

    const nextNode = await tx.storyTemplateNode.findUnique({
      where: {
        id: input.nextNodeId,
      },
      select: {
        id: true,
        templateId: true,
      },
    });

    if (!nextNode || nextNode.templateId !== templateId) {
      throw new ApiError("No de destino nao encontrado no template.", 404, "STORY_TEMPLATE_NEXT_NODE_NOT_FOUND");
    }

    const conflict = await tx.storyTemplateOption.findFirst({
      where: {
        nodeId: input.nodeId,
        optionKey,
      },
      select: {
        id: true,
      },
    });

    if (conflict) {
      throw new ApiError(
        "optionKey ja existe para o no informado.",
        409,
        "STORY_TEMPLATE_OPTION_KEY_CONFLICT"
      );
    }

    let sortOrder = input.sortOrder;
    if (sortOrder === undefined) {
      const latest = await tx.storyTemplateOption.findFirst({
        where: {
          nodeId: input.nodeId,
        },
        orderBy: {
          sortOrder: "desc",
        },
        select: {
          sortOrder: true,
        },
      });
      sortOrder = (latest?.sortOrder ?? -1) + 1;
    }

    await tx.storyTemplateOption.create({
      data: {
        nodeId: input.nodeId,
        optionKey,
        label,
        nextNodeId: input.nextNodeId,
        sortOrder,
      },
    });
  });

  return getAdminStoryTemplate(templateId);
}

export async function updateAdminStoryTemplateOption(
  userId: string,
  templateId: string,
  optionId: string,
  input: {
    optionKey?: string;
    label?: string;
    nextNodeId?: string;
    sortOrder?: number;
  }
) {
  const option = await prisma.storyTemplateOption.findUnique({
    where: {
      id: optionId,
    },
    include: {
      node: {
        select: {
          templateId: true,
        },
      },
    },
  });

  if (!option || option.node.templateId !== templateId) {
    throw new ApiError("Opcao de template nao encontrada.", 404, "STORY_TEMPLATE_OPTION_NOT_FOUND");
  }

  const optionKey = input.optionKey !== undefined ? slugify(input.optionKey) : undefined;
  if (input.optionKey !== undefined && !optionKey) {
    throw new ApiError("optionKey invalido.", 400, "STORY_TEMPLATE_OPTION_KEY_INVALID");
  }

  const label = input.label
    ? await moderateTextInput({
        value: input.label,
        scope: "TEMPLATE_TEXT",
        field: "label",
        userId,
      })
    : undefined;

  await prisma.$transaction(async (tx) => {
    await prepareTemplateForEdit(tx, templateId, userId);

    if (optionKey) {
      const conflict = await tx.storyTemplateOption.findFirst({
        where: {
          nodeId: option.nodeId,
          optionKey,
          id: {
            not: optionId,
          },
        },
        select: {
          id: true,
        },
      });

      if (conflict) {
        throw new ApiError(
          "optionKey ja existe para o no informado.",
          409,
          "STORY_TEMPLATE_OPTION_KEY_CONFLICT"
        );
      }
    }

    if (input.nextNodeId) {
      const nextNode = await tx.storyTemplateNode.findUnique({
        where: {
          id: input.nextNodeId,
        },
        select: {
          id: true,
          templateId: true,
        },
      });

      if (!nextNode || nextNode.templateId !== templateId) {
        throw new ApiError(
          "No de destino nao encontrado no template.",
          404,
          "STORY_TEMPLATE_NEXT_NODE_NOT_FOUND"
        );
      }
    }

    await tx.storyTemplateOption.update({
      where: {
        id: optionId,
      },
      data: {
        optionKey,
        label,
        nextNodeId: input.nextNodeId,
        sortOrder: input.sortOrder,
      },
    });
  });

  return getAdminStoryTemplate(templateId);
}

export async function validateAdminStoryTemplate(templateId: string) {
  const template = await getTemplateDetailById(prisma, templateId);
  const issues: ValidationIssue[] = [];

  const nodes = template.nodes;
  const nodeById = new Map(nodes.map((node) => [node.id, node]));
  const startNodes = nodes.filter((node) => node.kind === "START");
  const endNodes = nodes.filter((node) => node.kind === "END");

  if (startNodes.length !== 1) {
    issues.push({
      code: "TEMPLATE_START_NODE_INVALID",
      message: "Template deve conter exatamente 1 no START.",
    });
  }

  if (endNodes.length < 1) {
    issues.push({
      code: "TEMPLATE_END_NODE_MISSING",
      message: "Template deve conter ao menos 1 no END.",
    });
  }

  for (const node of nodes) {
    if (node.kind === "CHOICE" && (node.options.length < 2 || node.options.length > 4)) {
      issues.push({
        code: "TEMPLATE_CHOICE_OPTIONS_RANGE_INVALID",
        message: "Nos CHOICE devem ter entre 2 e 4 opcoes.",
        nodeId: node.id,
      });
    }

    for (const option of node.options) {
      const nextNode = nodeById.get(option.nextNodeId);
      if (!nextNode) {
        issues.push({
          code: "TEMPLATE_NEXT_NODE_INVALID",
          message: "Opcao aponta para no inexistente no template.",
          nodeId: node.id,
        });
      }
    }
  }

  if (startNodes.length === 1) {
    const visited = new Set<string>();
    const queue: string[] = [startNodes[0].id];

    while (queue.length > 0) {
      const nodeId = queue.shift();
      if (!nodeId || visited.has(nodeId)) {
        continue;
      }

      visited.add(nodeId);
      const node = nodeById.get(nodeId);
      if (!node) {
        continue;
      }

      for (const option of node.options) {
        if (!visited.has(option.nextNodeId)) {
          queue.push(option.nextNodeId);
        }
      }
    }

    const orphanNodes = nodes.filter((node) => !visited.has(node.id));
    if (orphanNodes.length > 0) {
      for (const orphan of orphanNodes) {
        issues.push({
          code: "TEMPLATE_ORPHAN_NODE",
          message: `No ${orphan.nodeKey} nao e alcancavel a partir do START.`,
          nodeId: orphan.id,
        });
      }
    }
  }

  return {
    valid: issues.length === 0,
    issues,
    stats: {
      nodesCount: nodes.length,
      optionsCount: nodes.reduce((acc, node) => acc + node.options.length, 0),
      startNodes: startNodes.length,
      endNodes: endNodes.length,
    },
  };
}

export async function publishAdminStoryTemplate(userId: string, templateId: string) {
  const validation = await validateAdminStoryTemplate(templateId);
  if (!validation.valid) {
    throw new ApiError(
      "Template invalido para publicacao. Corrija os problemas de validacao.",
      409,
      "STORY_TEMPLATE_INVALID"
    );
  }

  const template = await prisma.storyTemplate.findUnique({
    where: {
      id: templateId,
    },
    select: {
      id: true,
      isActive: true,
    },
  });

  if (!template) {
    throw new ApiError("Template de historia nao encontrado.", 404, "STORY_TEMPLATE_NOT_FOUND");
  }

  if (!template.isActive) {
    throw new ApiError("Template inativo nao pode ser publicado.", 409, "STORY_TEMPLATE_INACTIVE");
  }

  await prisma.storyTemplate.update({
    where: {
      id: templateId,
    },
    data: {
      isPublished: true,
      publishedAt: new Date(),
      updatedByUserId: userId,
    },
  });

  return {
    ...(await getAdminStoryTemplate(templateId)),
    validation,
  };
}

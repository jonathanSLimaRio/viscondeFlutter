import type { AgeBand } from "@prisma/client";

import { prisma } from "@/lib/prisma";
import { ApiError } from "@/lib/server/errors";

export async function selectVirtueTemplateOrThrow(input: {
  virtueId: string;
  ageBand: AgeBand;
}) {
  const template = await prisma.virtueTemplate.findFirst({
    where: {
      virtueId: input.virtueId,
      ageBand: input.ageBand,
      isActive: true,
    },
    orderBy: {
      sortOrder: "asc",
    },
    select: {
      id: true,
      dilemmaText: true,
      endQuestionText: true,
    },
  });

  if (!template) {
    throw new ApiError(
      "Nao existe dilema/pergunta cadastrados para a virtude e faixa etaria selecionadas.",
      409,
      "VIRTUE_TEMPLATE_MISSING"
    );
  }

  return template;
}

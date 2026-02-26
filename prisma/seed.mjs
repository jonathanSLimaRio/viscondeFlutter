import "dotenv/config";

import { hash } from "@node-rs/argon2";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "@prisma/client";
import pg from "pg";

const { Pool } = pg;

const databaseUrl =
  process.env.PRISMA_DATABASE_URL ??
  process.env.DATABASE_URL ??
  process.env.POSTGRES_URL;

if (!databaseUrl) {
  throw new Error(
    "Database URL ausente. Defina PRISMA_DATABASE_URL, DATABASE_URL ou POSTGRES_URL."
  );
}

const HASH_OPTIONS = {
  algorithm: 2,
  memoryCost: 19_456,
  timeCost: 2,
  parallelism: 1,
};

const pool = new Pool({
  connectionString: databaseUrl,
});

const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

const adminEmail = "admin@visconde.app";
const adminPassword = "admin123";

const virtuesCatalog = [
  {
    slug: "empatia",
    name: "Empatia",
    shortDescription: "Entender sentimentos e acolher com gentileza.",
    iconKey: "empathy",
    sortOrder: 1,
  },
  {
    slug: "coragem",
    name: "Coragem",
    shortDescription: "Enfrentar desafios com calma e confianca.",
    iconKey: "courage",
    sortOrder: 2,
  },
  {
    slug: "honestidade",
    name: "Honestidade",
    shortDescription: "Dizer a verdade com respeito e responsabilidade.",
    iconKey: "honesty",
    sortOrder: 3,
  },
  {
    slug: "paciencia",
    name: "Paciencia",
    shortDescription: "Esperar o momento certo sem perder a calma.",
    iconKey: "patience",
    sortOrder: 4,
  },
  {
    slug: "gratidao",
    name: "Gratidao",
    shortDescription: "Reconhecer o cuidado recebido e agradecer.",
    iconKey: "gratitude",
    sortOrder: 5,
  },
  {
    slug: "respeito",
    name: "Respeito",
    shortDescription: "Tratar cada pessoa com cuidado e dignidade.",
    iconKey: "respect",
    sortOrder: 6,
  },
  {
    slug: "cooperacao",
    name: "Cooperacao",
    shortDescription: "Trabalhar em equipe para resolver desafios.",
    iconKey: "cooperation",
    sortOrder: 7,
  },
  {
    slug: "responsabilidade",
    name: "Responsabilidade",
    shortDescription: "Cuidar das escolhas e cumprir combinados.",
    iconKey: "responsibility",
    sortOrder: 8,
  },
];

const virtueTemplates = {
  empatia: {
    AGE_4_5: {
      dilemmaText:
        "Um amigo ficou triste porque perdeu o brinquedo favorito. O que podemos fazer para ajudar?",
      endQuestionText:
        "Como voce pode mostrar carinho quando percebe alguem triste?",
    },
    AGE_6_8: {
      dilemmaText:
        "Dois personagens querem brincar de coisas diferentes. Como escutar os dois e encontrar um acordo?",
      endQuestionText:
        "Qual atitude ajuda voce a entender melhor o que o outro sente?",
    },
    AGE_9_10: {
      dilemmaText:
        "Um colega foi mal entendido pelo grupo. Como investigar com respeito antes de julgar?",
      endQuestionText:
        "Quando voce escolhe ouvir antes de responder, o que muda na conversa?",
    },
  },
  coragem: {
    AGE_4_5: {
      dilemmaText:
        "A ponte balanca um pouquinho e da frio na barriga. Como atravessar com seguranca e apoio?",
      endQuestionText:
        "Qual pequeno passo te ajuda quando algo parece dificil?",
    },
    AGE_6_8: {
      dilemmaText:
        "A equipe precisa falar com um guardiao timido para conseguir uma pista. Quem comeca e como?",
      endQuestionText:
        "O que te faz sentir mais confiante para tentar algo novo?",
    },
    AGE_9_10: {
      dilemmaText:
        "Ninguem quer assumir a primeira tentativa em um desafio importante. Como liderar sem impor?",
      endQuestionText:
        "Que tipo de coragem voce quer praticar mais nas proximas aventuras?",
    },
  },
  honestidade: {
    AGE_4_5: {
      dilemmaText:
        "Um vaso foi derrubado durante a brincadeira. Como contar a verdade com carinho?",
      endQuestionText:
        "Por que falar a verdade ajuda a consertar as coisas?",
    },
    AGE_6_8: {
      dilemmaText:
        "Um personagem encontrou algo que nao era dele. Como devolver de forma correta?",
      endQuestionText:
        "Como a honestidade fortalece a confianca entre amigos?",
    },
    AGE_9_10: {
      dilemmaText:
        "Para ganhar tempo, o grupo pensa em esconder um erro. Qual escolha protege o time no longo prazo?",
      endQuestionText:
        "Qual foi uma situacao em que ser honesto exigiu coragem?",
    },
  },
  paciencia: {
    AGE_4_5: {
      dilemmaText:
        "A fila para usar o brinquedo magico esta grande. Como esperar sem brigar?",
      endQuestionText:
        "O que voce pode fazer para esperar com tranquilidade?",
    },
    AGE_6_8: {
      dilemmaText:
        "A pista importante so aparece quando todos param e observam com calma. Quem consegue desacelerar o grupo?",
      endQuestionText:
        "Quando voce respira fundo antes de agir, o que melhora?",
    },
    AGE_9_10: {
      dilemmaText:
        "A equipe quer resolver tudo correndo e comeca a errar. Como defender um plano mais cuidadoso?",
      endQuestionText:
        "Como voce percebe a diferenca entre pressa e progresso?",
    },
  },
  gratidao: {
    AGE_4_5: {
      dilemmaText:
        "Um vizinho ajudou o grupo com lanche e agua. Como agradecer de um jeito especial?",
      endQuestionText:
        "De quem voce quer lembrar hoje para agradecer?",
    },
    AGE_6_8: {
      dilemmaText:
        "A aventura deu certo porque varias pessoas colaboraram. Como reconhecer cada ajuda?",
      endQuestionText:
        "Como mostrar gratidao sem precisar de presentes?",
    },
    AGE_9_10: {
      dilemmaText:
        "No final da jornada, o time percebe que quase nao celebrou quem ajudou nos bastidores. O que fazer?",
      endQuestionText:
        "Como a gratidao muda o clima de uma equipe?",
    },
  },
  respeito: {
    AGE_4_5: {
      dilemmaText:
        "Dois personagens querem falar ao mesmo tempo. Como esperar a vez e ouvir com atencao?",
      endQuestionText:
        "Como voce demonstra respeito quando alguem esta falando?",
    },
    AGE_6_8: {
      dilemmaText:
        "O grupo conhece costumes diferentes em outra vila. Como agir com curiosidade e educacao?",
      endQuestionText:
        "O que significa respeitar mesmo quando pensamos diferente?",
    },
    AGE_9_10: {
      dilemmaText:
        "Uma decisao afeta pessoas com opinioes opostas. Como buscar acordo sem desvalorizar ninguem?",
      endQuestionText:
        "Como o respeito ajuda em conversas dificeis?",
    },
  },
  cooperacao: {
    AGE_4_5: {
      dilemmaText:
        "A porta secreta so abre quando todos seguram as pecas juntos. Como combinar o time?",
      endQuestionText:
        "Qual parte voce gosta de fazer quando trabalha em equipe?",
    },
    AGE_6_8: {
      dilemmaText:
        "Cada personagem tem uma habilidade diferente. Como dividir tarefas para todos contribuirem?",
      endQuestionText:
        "Quando cooperar deixou uma tarefa mais facil para voce?",
    },
    AGE_9_10: {
      dilemmaText:
        "O grupo discute quem merece mais destaque. Como reorganizar o time para focar no objetivo comum?",
      endQuestionText:
        "O que faz uma equipe funcionar de verdade?",
    },
  },
  responsabilidade: {
    AGE_4_5: {
      dilemmaText:
        "O mapa da aventura foi deixado no chao e quase se perdeu. Como cuidar melhor dos itens do grupo?",
      endQuestionText:
        "Qual combinadinho voce pode cumprir melhor hoje?",
    },
    AGE_6_8: {
      dilemmaText:
        "Cada pessoa prometeu uma tarefa, mas duas ficaram sem fazer. Como assumir e reorganizar o plano?",
      endQuestionText:
        "Como voce se sente quando cumpre o que combinou?",
    },
    AGE_9_10: {
      dilemmaText:
        "A equipe depende de prazos para chegar ao destino. Como assumir compromissos reais e acompanhar entregas?",
      endQuestionText:
        "Qual responsabilidade nova voce quer treinar nesta semana?",
    },
  },
};

async function main() {
  const passwordHash = await hash(adminPassword, HASH_OPTIONS);

  const user = await prisma.user.upsert({
    where: { email: adminEmail },
    update: {
      name: "admin",
      timezone: "UTC",
      passwordHash,
    },
    create: {
      email: adminEmail,
      name: "admin",
      timezone: "UTC",
      passwordHash,
    },
    select: {
      id: true,
      email: true,
      name: true,
    },
  });

  console.log("Admin seed concluido.");
  console.log(`id=${user.id} email=${user.email} nome=${user.name}`);

  const virtuesBySlug = new Map();

  for (const virtue of virtuesCatalog) {
    const saved = await prisma.virtue.upsert({
      where: { slug: virtue.slug },
      update: {
        name: virtue.name,
        shortDescription: virtue.shortDescription,
        iconKey: virtue.iconKey,
        sortOrder: virtue.sortOrder,
        isActive: true,
      },
      create: {
        slug: virtue.slug,
        name: virtue.name,
        shortDescription: virtue.shortDescription,
        iconKey: virtue.iconKey,
        sortOrder: virtue.sortOrder,
        isActive: true,
      },
      select: {
        id: true,
        slug: true,
      },
    });

    virtuesBySlug.set(saved.slug, saved.id);
  }

  for (const virtue of virtuesCatalog) {
    const virtueId = virtuesBySlug.get(virtue.slug);
    const templatesForVirtue = virtueTemplates[virtue.slug];

    if (!virtueId || !templatesForVirtue) {
      continue;
    }

    for (const [ageBand, payload] of Object.entries(templatesForVirtue)) {
      await prisma.virtueTemplate.upsert({
        where: {
          virtueId_ageBand_sortOrder: {
            virtueId,
            ageBand,
            sortOrder: 1,
          },
        },
        update: {
          dilemmaText: payload.dilemmaText,
          endQuestionText: payload.endQuestionText,
          isActive: true,
        },
        create: {
          virtueId,
          ageBand,
          dilemmaText: payload.dilemmaText,
          endQuestionText: payload.endQuestionText,
          sortOrder: 1,
          isActive: true,
        },
      });
    }
  }

  console.log(`Virtudes seedadas: ${virtuesCatalog.length}`);
}

main()
  .catch((error) => {
    console.error("Falha ao executar seed de admin:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });

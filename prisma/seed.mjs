import "dotenv/config";

import { createHash } from "node:crypto";
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

const achievementCatalog = [
  {
    key: "primeira_historia",
    title: "Primeira Historia",
    description: "Publicou o primeiro capitulo.",
    iconKey: "first_story",
    rewardCoins: 50,
    rewardStars: 2,
    sortOrder: 1,
  },
  {
    key: "streak_7_dias",
    title: "7 Dias Contando",
    description: "Manteve o ritmo por 7 dias.",
    iconKey: "streak_7",
    rewardCoins: 80,
    rewardStars: 3,
    sortOrder: 2,
  },
];

const gamificationCatalogItems = [
  {
    key: "scenario_floresta_luz",
    type: "SCENARIO",
    name: "Floresta de Luz",
    description: "Cenario cosmético com atmosfera encantada.",
    iconKey: "scenario_forest_light",
    priceCoins: 120,
    priceStars: 0,
    sortOrder: 1,
  },
  {
    key: "scenario_castelo_nuvens",
    type: "SCENARIO",
    name: "Castelo das Nuvens",
    description: "Cenario cosmético em altura.",
    iconKey: "scenario_cloud_castle",
    priceCoins: 180,
    priceStars: 1,
    sortOrder: 2,
  },
  {
    key: "character_gato_explorador",
    type: "CHARACTER",
    name: "Gato Explorador",
    description: "Companheiro curioso para novas jornadas.",
    iconKey: "character_cat_explorer",
    priceCoins: 90,
    priceStars: 0,
    sortOrder: 3,
  },
  {
    key: "character_robot_gentil",
    type: "CHARACTER",
    name: "Robo Gentil",
    description: "Personagem de apoio com energia positiva.",
    iconKey: "character_kind_robot",
    priceCoins: 140,
    priceStars: 1,
    sortOrder: 4,
  },
  {
    key: "skin_capa_coragem",
    type: "SKIN",
    name: "Capa da Coragem",
    description: "Skin cosmética inspirada em bravura.",
    iconKey: "skin_courage_cape",
    priceCoins: 110,
    priceStars: 0,
    sortOrder: 5,
  },
  {
    key: "skin_chapeu_mestre",
    type: "SKIN",
    name: "Chapeu do Mestre",
    description: "Skin cosmética para narradores.",
    iconKey: "skin_story_hat",
    priceCoins: 160,
    priceStars: 1,
    sortOrder: 6,
  },
  {
    key: "avatar_estrela_dourada",
    type: "AVATAR",
    name: "Estrela Dourada",
    description: "Avatar brilhante para perfil infantil.",
    iconKey: "avatar_gold_star",
    priceCoins: 80,
    priceStars: 0,
    sortOrder: 7,
  },
  {
    key: "avatar_livro_magico",
    type: "AVATAR",
    name: "Livro Magico",
    description: "Avatar de conto para colecionadores.",
    iconKey: "avatar_magic_book",
    priceCoins: 130,
    priceStars: 1,
    sortOrder: 8,
  },
];

const storyThemesCatalog = [
  {
    slug: "amizade",
    name: "Amizade",
    shortDescription: "Aventuras sobre cooperacao e laços afetivos.",
    iconKey: "theme_friendship",
    sortOrder: 1,
  },
  {
    slug: "misterio",
    name: "Misterio",
    shortDescription: "Pistas, enigmas e descobertas com seguranca infantil.",
    iconKey: "theme_mystery",
    sortOrder: 2,
  },
  {
    slug: "fantasia",
    name: "Fantasia",
    shortDescription: "Cenarios magicos e criativos para contar historias.",
    iconKey: "theme_fantasy",
    sortOrder: 3,
  },
  {
    slug: "familia",
    name: "Familia",
    shortDescription: "Narrativas de cuidado, escuta e gratidao.",
    iconKey: "theme_family",
    sortOrder: 4,
  },
];

const contentPromptsCatalog = [
  {
    key: "fallback_empatia_4_5",
    kind: "IDEA_FALLBACK",
    title: "Empatia inicial 4-5",
    text: "Um amigo ficou triste e precisa de ajuda para voltar a sorrir.",
    virtueSlug: "empatia",
    ageBand: "AGE_4_5",
    mode: "PARENT_NARRATOR",
    sortOrder: 1,
  },
  {
    key: "fallback_coragem_6_8",
    kind: "IDEA_FALLBACK",
    title: "Coragem criativa 6-8",
    text: "A equipe encontra uma ponte desafiadora e decide agir com calma.",
    virtueSlug: "coragem",
    ageBand: "AGE_6_8",
    mode: "PARENT_NARRATOR",
    sortOrder: 2,
  },
  {
    key: "fallback_gratidao_9_10",
    kind: "IDEA_FALLBACK",
    title: "Gratidao em equipe 9-10",
    text: "No fim da missao, o grupo relembra quem ajudou nos bastidores.",
    virtueSlug: "gratidao",
    ageBand: "AGE_9_10",
    mode: "CHILD_CHOOSER",
    sortOrder: 3,
  },
];

const moderationSeedTerms = [
  "sexo",
  "sexual",
  "porn",
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
];

const demoPin = "123456";

const demoUsersCatalog = [
  {
    key: "admin",
    email: adminEmail,
    password: adminPassword,
    name: "admin",
    role: "ADMIN",
  },
  {
    key: "demo",
    email: "demo@visconde.app",
    password: "demo123",
    name: "demo",
    role: "USER",
  },
];

const demoChildrenCatalog = [
  {
    key: "lucas",
    name: "Lucas",
    birthDate: new Date("2018-03-15T00:00:00.000Z"),
    favoriteThemes: ["Misterio", "Fantasia", "Aventura"],
  },
  {
    key: "sofia",
    name: "Sofia",
    birthDate: new Date("2020-08-20T00:00:00.000Z"),
    favoriteThemes: ["Amizade", "Familia", "Fantasia"],
  },
];

const demoCollectionsBlueprint = [
  {
    key: "misterio_floresta",
    title: "Misterio na Floresta",
    theme: "Misterio",
    virtueSlug: "coragem",
    childKey: "lucas",
    isFavorite: true,
    stories: [
      {
        key: "misterio_ep1",
        episodeNumber: 1,
        status: "PUBLISHED",
        title: "Misterio na Floresta",
        theme: "Misterio",
        scenario: "Floresta luminosa com trilhas secretas",
        objective: "Encontrar o cristal da vila antes do anoitecer",
        virtueSlug: "coragem",
        ageBand: "AGE_6_8",
        ageSnapshotYears: 8,
        sourceTemplate: true,
        continuedFromStoryKey: null,
        currentMode: "CHILD_CHOOSER",
        currentStepIndex: 4,
        startedAt: new Date("2025-11-10T18:00:00.000Z"),
        publishedAt: new Date("2025-11-10T18:20:00.000Z"),
        completedAt: new Date("2025-11-10T18:20:00.000Z"),
        referenceAt: new Date("2025-11-10T18:20:00.000Z"),
        characters: [
          { key: "luna", name: "Luna", role: "exploradora" },
          { key: "teo", name: "Teo", role: "guarda da trilha" },
        ],
        steps: [
          {
            stepIndex: 1,
            kind: "NARRATION",
            modeUsed: "PARENT_NARRATOR",
            narratorText:
              "Lucas e Luna chegam a uma floresta cheia de sinais brilhantes.",
          },
          {
            stepIndex: 2,
            kind: "CHILD_CHOICE",
            modeUsed: "CHILD_CHOOSER",
            selectedOptionId: "seguir_luz",
            selectedOptionLabel: "Seguir a trilha de luz",
            childOptions: [
              { id: "investigar_pegadas", label: "Investigar as pegadas" },
              { id: "seguir_luz", label: "Seguir a trilha de luz" },
              { id: "chamar_coruja", label: "Chamar a coruja guardia" },
            ],
          },
          {
            stepIndex: 3,
            kind: "NARRATION",
            modeUsed: "PARENT_NARRATOR",
            narratorText:
              "A trilha leva ate uma ponte antiga com vento forte, mas cheia de estrelas.",
          },
          {
            stepIndex: 4,
            kind: "CHILD_CHOICE",
            modeUsed: "CHILD_CHOOSER",
            selectedOptionId: "atravessar_ponte",
            selectedOptionLabel: "Atravessar a ponte com calma",
            childOptions: [
              {
                id: "atravessar_ponte",
                label: "Atravessar a ponte com calma",
              },
              { id: "fazer_jangada", label: "Construir uma jangada" },
              { id: "voltar_base", label: "Voltar para pedir apoio" },
            ],
          },
        ],
      },
    ],
  },
  {
    key: "viagem_espaco",
    title: "Viagem ao Espaco",
    theme: "Fantasia",
    virtueSlug: "gratidao",
    childKey: "lucas",
    isFavorite: false,
    stories: [
      {
        key: "viagem_espaco_ep1",
        episodeNumber: 1,
        status: "PUBLISHED",
        title: "Viagem ao Espaco - Episodio 1",
        theme: "Fantasia",
        scenario: "Base lunar da turma",
        objective: "Agradecer quem ajudou na decolagem",
        virtueSlug: "gratidao",
        ageBand: "AGE_6_8",
        ageSnapshotYears: 8,
        sourceTemplate: false,
        continuedFromStoryKey: null,
        currentMode: "CHILD_CHOOSER",
        currentStepIndex: 3,
        startedAt: new Date("2025-12-02T19:00:00.000Z"),
        publishedAt: new Date("2025-12-02T19:20:00.000Z"),
        completedAt: new Date("2025-12-02T19:20:00.000Z"),
        referenceAt: new Date("2025-12-02T19:20:00.000Z"),
        characters: [
          { key: "maya", name: "Maya", role: "pilota aprendiz" },
          { key: "astro", name: "Astro", role: "robo ajudante" },
        ],
        steps: [
          {
            stepIndex: 1,
            kind: "NARRATION",
            modeUsed: "PARENT_NARRATOR",
            narratorText:
              "A equipe chega a base lunar depois de uma decolagem segura.",
          },
          {
            stepIndex: 2,
            kind: "CHILD_CHOICE",
            modeUsed: "CHILD_CHOOSER",
            selectedOptionId: "agradecer_time",
            selectedOptionLabel: "Agradecer o time da torre",
            childOptions: [
              {
                id: "agradecer_time",
                label: "Agradecer o time da torre",
              },
              {
                id: "mandar_recado",
                label: "Mandar um recado para a comunidade",
              },
              { id: "celebrar_silencio", label: "Fazer uma celebracao calma" },
            ],
          },
          {
            stepIndex: 3,
            kind: "NARRATION",
            modeUsed: "PARENT_NARRATOR",
            narratorText:
              "Com gratidao, a base inteira responde com luzes coloridas no ceu.",
          },
        ],
      },
      {
        key: "viagem_espaco_ep2",
        episodeNumber: 2,
        status: "PUBLISHED",
        title: "Viagem ao Espaco - Episodio 2",
        theme: "Fantasia",
        scenario: "Jardim estelar com sementes raras",
        objective: "Salvar um jardim estelar ajudando outra tripulacao",
        virtueSlug: "empatia",
        ageBand: "AGE_6_8",
        ageSnapshotYears: 8,
        sourceTemplate: false,
        continuedFromStoryKey: "viagem_espaco_ep1",
        currentMode: "CHILD_CHOOSER",
        currentStepIndex: 3,
        startedAt: new Date("2025-12-09T19:00:00.000Z"),
        publishedAt: new Date("2025-12-09T19:24:00.000Z"),
        completedAt: new Date("2025-12-09T19:24:00.000Z"),
        referenceAt: new Date("2025-12-09T19:24:00.000Z"),
        characters: [
          { key: "maya", name: "Maya", role: "pilota aprendiz" },
          { key: "nina", name: "Nina", role: "amiga viajante" },
        ],
        steps: [
          {
            stepIndex: 1,
            kind: "NARRATION",
            modeUsed: "PARENT_NARRATOR",
            narratorText:
              "Uma tripulacao vizinha pede ajuda para recuperar sementes perdidas.",
          },
          {
            stepIndex: 2,
            kind: "CHILD_CHOICE",
            modeUsed: "CHILD_CHOOSER",
            selectedOptionId: "escutar_equipe",
            selectedOptionLabel: "Escutar primeiro o que cada um sentiu",
            childOptions: [
              {
                id: "escutar_equipe",
                label: "Escutar primeiro o que cada um sentiu",
              },
              { id: "agir_rapido", label: "Agir rapido sem conversar" },
              { id: "chamar_reforco", label: "Chamar reforco com calma" },
            ],
          },
          {
            stepIndex: 3,
            kind: "NARRATION",
            modeUsed: "PARENT_NARRATOR",
            narratorText:
              "A equipe encontra o melhor caminho e salva o jardim com cooperacao.",
          },
        ],
      },
      {
        key: "viagem_espaco_ep3",
        episodeNumber: 3,
        status: "DRAFT",
        title: "Viagem ao Espaco - Episodio 3",
        theme: "Fantasia",
        scenario: "Corredor de nebulas com sinais misteriosos",
        objective: "Escolher o melhor caminho para ajudar outra nave",
        virtueSlug: "cooperacao",
        ageBand: "AGE_6_8",
        ageSnapshotYears: 8,
        sourceTemplate: false,
        continuedFromStoryKey: "viagem_espaco_ep2",
        currentMode: "PARENT_NARRATOR",
        currentStepIndex: 1,
        startedAt: new Date("2026-02-21T19:00:00.000Z"),
        publishedAt: null,
        completedAt: null,
        referenceAt: new Date("2026-02-21T19:08:00.000Z"),
        characters: [
          { key: "maya", name: "Maya", role: "pilota aprendiz" },
          { key: "nina", name: "Nina", role: "amiga viajante" },
        ],
        steps: [
          {
            stepIndex: 1,
            kind: "NARRATION",
            modeUsed: "PARENT_NARRATOR",
            narratorText:
              "Maya e Nina observam duas rotas seguras na nebulosa e combinam agir em equipe.",
          },
        ],
      },
    ],
  },
  {
    key: "castelo_encantado",
    title: "Castelo Encantado",
    theme: "Fantasia",
    virtueSlug: "empatia",
    childKey: "sofia",
    isFavorite: false,
    stories: [
      {
        key: "castelo_ep0",
        episodeNumber: 1,
        status: "ARCHIVED",
        title: "Castelo Encantado - Prologo",
        theme: "Fantasia",
        scenario: "Castelo antigo com salao de mapas",
        objective: "Aprender os combinados da aventura",
        virtueSlug: "respeito",
        ageBand: "AGE_4_5",
        ageSnapshotYears: 6,
        sourceTemplate: false,
        continuedFromStoryKey: null,
        currentMode: "PARENT_NARRATOR",
        currentStepIndex: 2,
        startedAt: new Date("2026-01-30T17:00:00.000Z"),
        publishedAt: new Date("2026-01-30T17:14:00.000Z"),
        completedAt: new Date("2026-01-30T17:14:00.000Z"),
        referenceAt: new Date("2026-02-01T10:00:00.000Z"),
        characters: [
          { key: "sofia", name: "Sofia", role: "heroina" },
          { key: "milo", name: "Milo", role: "guia do castelo" },
        ],
        steps: [
          {
            stepIndex: 1,
            kind: "NARRATION",
            modeUsed: "PARENT_NARRATOR",
            narratorText:
              "Sofia chega ao castelo e conhece os combinados para explorar cada sala.",
          },
          {
            stepIndex: 2,
            kind: "CHILD_CHOICE",
            modeUsed: "CHILD_CHOOSER",
            selectedOptionId: "ouvir_regras",
            selectedOptionLabel: "Ouvir com atencao as regras",
            childOptions: [
              { id: "ouvir_regras", label: "Ouvir com atencao as regras" },
              { id: "testar_porta", label: "Testar uma porta secreta" },
              { id: "perguntar_milo", label: "Pedir ajuda para o Milo" },
            ],
          },
        ],
      },
      {
        key: "castelo_ep1",
        episodeNumber: 2,
        status: "DRAFT",
        title: "Castelo Encantado",
        theme: "Fantasia",
        scenario: "Castelo com saloes coloridos",
        objective: "Ajudar um novo amigo a se sentir em casa",
        virtueSlug: "empatia",
        ageBand: "AGE_4_5",
        ageSnapshotYears: 6,
        sourceTemplate: false,
        continuedFromStoryKey: "castelo_ep0",
        currentMode: "PARENT_NARRATOR",
        currentStepIndex: 2,
        startedAt: new Date("2026-02-14T17:00:00.000Z"),
        publishedAt: null,
        completedAt: null,
        referenceAt: new Date("2026-02-14T17:18:00.000Z"),
        characters: [
          { key: "sofia", name: "Sofia", role: "heroina" },
          { key: "nico", name: "Nico", role: "amigo novo" },
        ],
        steps: [
          {
            stepIndex: 1,
            kind: "NARRATION",
            modeUsed: "PARENT_NARRATOR",
            narratorText:
              "Sofia encontra Nico no castelo, ainda timido com o novo lugar.",
          },
          {
            stepIndex: 2,
            kind: "CHILD_CHOICE",
            modeUsed: "CHILD_CHOOSER",
            selectedOptionId: "mostrar_castelo",
            selectedOptionLabel: "Mostrar o castelo com calma",
            childOptions: [
              { id: "mostrar_castelo", label: "Mostrar o castelo com calma" },
              { id: "brincar_juntos", label: "Convidar para brincar juntos" },
              { id: "buscar_ajuda", label: "Buscar ajuda de um guardiao" },
            ],
          },
        ],
      },
      {
        key: "castelo_ep2",
        episodeNumber: 3,
        status: "DRAFT",
        title: "Castelo Encantado - Episodio 2",
        theme: "Fantasia",
        scenario: "Patio do castelo com trilhas coloridas",
        objective: "Criar um plano para integrar Nico ao time",
        virtueSlug: "cooperacao",
        ageBand: "AGE_4_5",
        ageSnapshotYears: 6,
        sourceTemplate: false,
        continuedFromStoryKey: "castelo_ep1",
        currentMode: "CHILD_CHOOSER",
        currentStepIndex: 2,
        startedAt: new Date("2026-02-28T17:00:00.000Z"),
        publishedAt: null,
        completedAt: null,
        referenceAt: new Date("2026-02-28T17:19:00.000Z"),
        characters: [
          { key: "sofia", name: "Sofia", role: "heroina" },
          { key: "nico", name: "Nico", role: "amigo novo" },
          { key: "milo", name: "Milo", role: "guia do castelo" },
        ],
        steps: [
          {
            stepIndex: 1,
            kind: "NARRATION",
            modeUsed: "PARENT_NARRATOR",
            narratorText:
              "Sofia monta um plano em equipe para que Nico conheca cada canto do castelo.",
          },
          {
            stepIndex: 2,
            kind: "CHILD_CHOICE",
            modeUsed: "CHILD_CHOOSER",
            selectedOptionId: "dividir_tarefas",
            selectedOptionLabel: "Dividir tarefas para todos ajudarem",
            childOptions: [
              {
                id: "dividir_tarefas",
                label: "Dividir tarefas para todos ajudarem",
              },
              { id: "seguir_sozinha", label: "Sofia segue sozinha primeiro" },
              { id: "chamar_guardiao", label: "Chamar o guardiao da torre" },
            ],
          },
        ],
      },
    ],
  },
];

const qaArtStylesCatalog = [
  {
    id: seedId("art_style", "aquarela"),
    name: "Aquarela Suave",
    promptTemplate: "Watercolor illustration, soft brush strokes, warm kids story mood",
  },
  {
    id: seedId("art_style", "cartoon"),
    name: "Cartoon Aventura",
    promptTemplate: "Cartoon adventure style, clean outlines, vibrant colors, playful tone",
  },
  {
    id: seedId("art_style", "fantasia"),
    name: "Fantasia Epica",
    promptTemplate: "Epic fantasy illustration, magical glow, cinematic composition",
  },
];

const qaInventoryItemsCatalog = [
  {
    key: "escudo_papelao",
    name: "Escudo de Papelao",
    description: "Protege contra desafios imaginarios.",
    rarity: "COMMON",
    category: "ITEM",
    icon: "item_shield_cardboard",
    tags: ["coragem", "protecao"],
  },
  {
    key: "mapa_tesouro",
    name: "Mapa do Tesouro",
    description: "Mostra caminhos secretos para novas aventuras.",
    rarity: "EPIC",
    category: "ITEM",
    icon: "item_treasure_map",
    tags: ["exploracao", "curiosidade"],
  },
  {
    key: "coruja_sabia",
    name: "Coruja Sabia",
    description: "Companheira de jornada para escolhas importantes.",
    rarity: "RARE",
    category: "COMPANION",
    icon: "companion_wise_owl",
    tags: ["sabedoria", "amizade"],
  },
  {
    key: "fada_cores",
    name: "Fada das Cores",
    description: "Leva brilho criativo para cada capitulo.",
    rarity: "EPIC",
    category: "COMPANION",
    icon: "companion_fairy_colors",
    tags: ["criatividade", "fantasia"],
  },
];

const qaInventoryUnlockBlueprint = [
  {
    childKey: "lucas",
    unlocks: [
      { itemKey: "escudo_papelao", qty: 1 },
      { itemKey: "mapa_tesouro", qty: 1 },
      { itemKey: "coruja_sabia", qty: 1 },
    ],
  },
  {
    childKey: "sofia",
    unlocks: [
      { itemKey: "escudo_papelao", qty: 1 },
      { itemKey: "fada_cores", qty: 1 },
    ],
  },
];

const qaGamificationUnlockBlueprint = [
  {
    childKey: "lucas",
    unlockItemKeys: ["scenario_floresta_luz", "avatar_estrela_dourada"],
    equippedItemKey: "avatar_estrela_dourada",
  },
  {
    childKey: "sofia",
    unlockItemKeys: ["character_gato_explorador"],
    equippedItemKey: "character_gato_explorador",
  },
];

const qaStoryMemoriesBlueprint = [
  {
    childKey: "lucas",
    storyKey: "misterio_ep1",
    summary:
      "Lucas atravessou a ponte com coragem e encontrou o cristal da vila com a equipe.",
    usedItems: ["escudo_papelao", "mapa_tesouro"],
    virtueLearned: "coragem",
  },
  {
    childKey: "sofia",
    storyKey: "castelo_ep1",
    summary:
      "Sofia acolheu Nico no castelo e escolheu mostrar cada sala com paciencia.",
    usedItems: ["fada_cores"],
    virtueLearned: "empatia",
  },
];

const qaBookProjectConfig = {
  month: "2026-02",
  childKey: "lucas",
  status: "READY",
  title: "Aventuras de Fevereiro",
  pdfUrl: "https://cdn.visconde.app/books/seed-demo-fevereiro.pdf",
  includedStoryKeys: ["misterio_ep1", "viagem_espaco_ep1", "viagem_espaco_ep2"],
};

const qaRemoteRoomConfig = {
  storyKey: "castelo_ep1",
  joinCode: "SEED42",
  callMode: "AUDIO",
  interactions: [
    {
      key: "chat_host_intro",
      type: "CHAT",
      authorRole: "HOST_PARENT",
      messageText: "Sala pronta para testar o modo remoto.",
      emoji: null,
    },
    {
      key: "reaction_guest_star",
      type: "REACTION",
      authorRole: "GUEST_CHILD",
      messageText: null,
      emoji: "star",
    },
  ],
};

const qaWalletBaselineByAccount = {
  admin: { coins: 180, stars: 4 },
  demo: { coins: 140, stars: 3 },
};

const MAX_STORY_STEPS = 12;
const GAME_MAP_VERSION = 1;
const INT32_MAX = 2_147_483_647;

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function hashSeed(value) {
  let hashValue = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hashValue ^= value.charCodeAt(index);
    hashValue = Math.imul(hashValue, 16777619);
  }
  return (Math.abs(hashValue >>> 0) % INT32_MAX) || 1;
}

function computeStoryGameSeed(input) {
  return hashSeed(`${input.storyId}|${input.theme}|${input.scenario}|${input.objective}`);
}

function buildLinearTrailMap(seed) {
  let randomState = seed || 1;
  const nextRandom = () => {
    randomState = (Math.imul(randomState, 1664525) + 1013904223) >>> 0;
    return randomState / 0xffffffff;
  };

  const biomes = ["FOREST", "CASTLE", "UNDERWATER", "SPACE", "TREASURE"];
  const biome = biomes[seed % biomes.length] ?? "FOREST";
  const nodes = [];

  for (let index = 1; index <= MAX_STORY_STEPS; index += 1) {
    const progress = (index - 1) / (MAX_STORY_STEPS - 1);
    const x = clamp(0.08 + progress * 0.84, 0.06, 0.94);
    const wave = Math.sin(progress * Math.PI * 2.6 + nextRandom() * 0.8) * 0.18;
    const jitter = (nextRandom() - 0.5) * 0.06;
    const y = clamp(0.5 + wave + jitter, 0.2, 0.8);

    nodes.push({
      index,
      x: Number(x.toFixed(4)),
      y: Number(y.toFixed(4)),
      kind: index === 1 ? "START" : index === MAX_STORY_STEPS ? "FINISH" : "PATH",
    });
  }

  return {
    biome,
    totalNodes: MAX_STORY_STEPS,
    nodes,
  };
}

function seedId(...parts) {
  return `seed_${parts.join("_")}`;
}

function normalizeTerm(value) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim()
    .replace(/\s+/g, " ");
}

function getVirtueTemplatePayload(virtueSlug, ageBand) {
  const byVirtue = virtueTemplates[virtueSlug];
  if (!byVirtue) {
    throw new Error(`Template de virtude nao encontrado para slug=${virtueSlug}`);
  }

  const payload = byVirtue[ageBand];
  if (!payload) {
    throw new Error(
      `Template de virtude nao encontrado para slug=${virtueSlug} ageBand=${ageBand}`
    );
  }

  return payload;
}

function getStoryReferenceDate(story) {
  if (story.status === "PUBLISHED" && story.publishedAt) {
    return story.publishedAt;
  }

  return story.referenceAt ?? story.startedAt ?? new Date();
}

function resolveStepGameplayMeta(step) {
  const gameNodeIndex = step.gameNodeIndex ?? step.stepIndex;
  const gameActionKey =
    step.gameActionKey ??
    (step.kind === "CHILD_CHOICE"
      ? step.selectedOptionId ?? `choice_step_${step.stepIndex}`
      : `narration_step_${step.stepIndex}`);
  const gameActionLabel =
    step.gameActionLabel ??
    (step.kind === "CHILD_CHOICE"
      ? step.selectedOptionLabel ?? "Escolha da crianca"
      : step.narratorText ?? `Narracao da etapa ${step.stepIndex}`);

  return {
    gameNodeIndex,
    gameActionKey,
    gameActionLabel,
  };
}

function hashJoinCode(value) {
  return createHash("sha256").update(value).digest("hex");
}

function toIsoDateKey(parts) {
  return `${String(parts.year).padStart(4, "0")}-${String(parts.month).padStart(
    2,
    "0"
  )}-${String(parts.day).padStart(2, "0")}`;
}

function localDateParts(date, timezone) {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    weekday: "short",
  });
  const parts = formatter.formatToParts(date);
  const year = Number(parts.find((part) => part.type === "year")?.value ?? "0");
  const month = Number(parts.find((part) => part.type === "month")?.value ?? "0");
  const day = Number(parts.find((part) => part.type === "day")?.value ?? "0");
  const weekday = parts.find((part) => part.type === "weekday")?.value ?? "Mon";
  const weekdayIndex = {
    Sun: 0,
    Mon: 1,
    Tue: 2,
    Wed: 3,
    Thu: 4,
    Fri: 5,
    Sat: 6,
  }[weekday];
  return {
    year,
    month,
    day,
    weekday: weekdayIndex ?? 1,
  };
}

function mondayWeekKey(date, timezone) {
  const parts = localDateParts(date, timezone);
  const base = Date.UTC(parts.year, parts.month - 1, parts.day);
  const mondayOffset = (parts.weekday + 6) % 7;
  const monday = new Date(base - mondayOffset * 24 * 60 * 60 * 1000);
  return toIsoDateKey({
    year: monday.getUTCFullYear(),
    month: monday.getUTCMonth() + 1,
    day: monday.getUTCDate(),
  });
}

async function ensureDemoUsersAndProfiles() {
  const pinHash = await hash(demoPin, HASH_OPTIONS);
  const usersByKey = new Map();

  for (const account of demoUsersCatalog) {
    const passwordHash = await hash(account.password, HASH_OPTIONS);

    const user = await prisma.user.upsert({
      where: { email: account.email },
      update: {
        name: account.name,
        timezone: "UTC",
        passwordHash,
        pinHash,
        pinUpdatedAt: new Date(),
        role: account.role,
      },
      create: {
        email: account.email,
        name: account.name,
        timezone: "UTC",
        passwordHash,
        pinHash,
        pinUpdatedAt: new Date(),
        role: account.role,
      },
      select: {
        id: true,
        email: true,
        name: true,
      },
    });

    const childrenByKey = new Map();
    for (const child of demoChildrenCatalog) {
      const childId = seedId(account.key, "child", child.key);
      const savedChild = await prisma.childProfile.upsert({
        where: { id: childId },
        update: {
          userId: user.id,
          name: child.name,
          birthDate: child.birthDate,
          favoriteThemes: child.favoriteThemes,
          isArchived: false,
        },
        create: {
          id: childId,
          userId: user.id,
          name: child.name,
          birthDate: child.birthDate,
          favoriteThemes: child.favoriteThemes,
          isArchived: false,
        },
        select: {
          id: true,
          name: true,
          birthDate: true,
        },
      });
      childrenByKey.set(child.key, savedChild);
    }

    usersByKey.set(account.key, {
      key: account.key,
      role: account.role,
      user,
      childrenByKey,
    });
  }

  return usersByKey;
}

async function ensureCoreCatalogData(adminUserId) {
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

  const themesBySlug = new Map();
  for (const theme of storyThemesCatalog) {
    const saved = await prisma.storyTheme.upsert({
      where: { slug: theme.slug },
      update: {
        name: theme.name,
        shortDescription: theme.shortDescription,
        iconKey: theme.iconKey,
        sortOrder: theme.sortOrder,
        isActive: true,
      },
      create: {
        slug: theme.slug,
        name: theme.name,
        shortDescription: theme.shortDescription,
        iconKey: theme.iconKey,
        sortOrder: theme.sortOrder,
        isActive: true,
      },
      select: {
        id: true,
        slug: true,
      },
    });
    themesBySlug.set(saved.slug, saved.id);
  }

  for (const prompt of contentPromptsCatalog) {
    const virtueId = virtuesBySlug.get(prompt.virtueSlug) ?? null;
    await prisma.contentPrompt.upsert({
      where: { key: prompt.key },
      update: {
        kind: prompt.kind,
        title: prompt.title,
        text: prompt.text,
        virtueId,
        ageBand: prompt.ageBand,
        mode: prompt.mode,
        sortOrder: prompt.sortOrder,
        isActive: true,
      },
      create: {
        key: prompt.key,
        kind: prompt.kind,
        title: prompt.title,
        text: prompt.text,
        virtueId,
        ageBand: prompt.ageBand,
        mode: prompt.mode,
        sortOrder: prompt.sortOrder,
        isActive: true,
      },
    });
  }

  const sampleTemplate = await prisma.storyTemplate.upsert({
    where: { slug: "aventura-floresta-encantada" },
    update: {
      title: "Aventura na Floresta Encantada",
      description: "Template de exemplo com escolhas para criacao guiada.",
      themeId: themesBySlug.get("fantasia") ?? null,
      virtueId: virtuesBySlug.get("coragem") ?? null,
      ageBand: "AGE_6_8",
      defaultScenario: "Floresta encantada com trilhas brilhantes",
      defaultObjective: "Ajudar um amigo a encontrar o mapa perdido",
      isActive: true,
      updatedByUserId: adminUserId,
    },
    create: {
      slug: "aventura-floresta-encantada",
      title: "Aventura na Floresta Encantada",
      description: "Template de exemplo com escolhas para criacao guiada.",
      themeId: themesBySlug.get("fantasia") ?? null,
      virtueId: virtuesBySlug.get("coragem") ?? null,
      ageBand: "AGE_6_8",
      defaultScenario: "Floresta encantada com trilhas brilhantes",
      defaultObjective: "Ajudar um amigo a encontrar o mapa perdido",
      isActive: true,
      isPublished: true,
      publishedAt: new Date(),
      version: 1,
      createdByUserId: adminUserId,
      updatedByUserId: adminUserId,
    },
    select: {
      id: true,
    },
  });

  const existingTemplateCharacters = await prisma.storyTemplateCharacter.count({
    where: {
      templateId: sampleTemplate.id,
    },
  });

  if (existingTemplateCharacters === 0) {
    await prisma.storyTemplateCharacter.createMany({
      data: [
        {
          templateId: sampleTemplate.id,
          name: "Luna",
          role: "exploradora",
          sortOrder: 0,
        },
        {
          templateId: sampleTemplate.id,
          name: "Theo",
          role: "amigo curioso",
          sortOrder: 1,
        },
      ],
    });
  }

  const existingTemplateNodes = await prisma.storyTemplateNode.count({
    where: {
      templateId: sampleTemplate.id,
    },
  });

  if (existingTemplateNodes === 0) {
    const startNode = await prisma.storyTemplateNode.create({
      data: {
        templateId: sampleTemplate.id,
        nodeKey: "start",
        kind: "START",
        title: "Inicio da aventura",
        narratorText: "A dupla encontra uma trilha de luz no meio da floresta.",
        sortOrder: 0,
      },
    });

    const choiceNode = await prisma.storyTemplateNode.create({
      data: {
        templateId: sampleTemplate.id,
        nodeKey: "escolha_trilha",
        kind: "CHOICE",
        title: "Escolha da trilha",
        narratorText: "Agora e hora de decidir qual caminho seguir.",
        sortOrder: 1,
      },
    });

    const endNodeA = await prisma.storyTemplateNode.create({
      data: {
        templateId: sampleTemplate.id,
        nodeKey: "final_pontes",
        kind: "END",
        title: "Final da ponte brilhante",
        narratorText: "Com coragem, todos atravessam e encontram o mapa.",
        sortOrder: 2,
      },
    });

    const endNodeB = await prisma.storyTemplateNode.create({
      data: {
        templateId: sampleTemplate.id,
        nodeKey: "final_cachoeira",
        kind: "END",
        title: "Final da cachoeira",
        narratorText: "Perto da cachoeira, o amigo recupera o mapa perdido.",
        sortOrder: 3,
      },
    });

    await prisma.storyTemplateOption.createMany({
      data: [
        {
          nodeId: startNode.id,
          optionKey: "seguir_escolha",
          label: "Continuar para a escolha principal",
          nextNodeId: choiceNode.id,
          sortOrder: 0,
        },
        {
          nodeId: choiceNode.id,
          optionKey: "ponte",
          label: "Ir pela ponte brilhante",
          nextNodeId: endNodeA.id,
          sortOrder: 0,
        },
        {
          nodeId: choiceNode.id,
          optionKey: "cachoeira",
          label: "Ir pela trilha da cachoeira",
          nextNodeId: endNodeB.id,
          sortOrder: 1,
        },
      ],
    });
  }

  for (const term of moderationSeedTerms) {
    const normalized = normalizeTerm(term);
    await prisma.moderationTerm.upsert({
      where: {
        termNormalized: normalized,
      },
      update: {
        displayTerm: term,
        policy: "BLOCK",
        replacement: null,
        scope: "TEMPLATE_TEXT",
        isActive: true,
        updatedByUserId: adminUserId,
      },
      create: {
        termNormalized: normalized,
        displayTerm: term,
        policy: "BLOCK",
        replacement: null,
        scope: "TEMPLATE_TEXT",
        isActive: true,
        createdByUserId: adminUserId,
        updatedByUserId: adminUserId,
      },
    });
  }

  const achievementsToUpsert = [
    ...achievementCatalog,
    ...virtuesCatalog.map((virtue, index) => ({
      key: `virtude_${virtue.slug}`,
      title: `Virtude: ${virtue.name}`,
      description: `Trabalhou a virtude ${virtue.name} em uma aventura.`,
      iconKey: `virtue_${virtue.slug}`,
      rewardCoins: 25,
      rewardStars: 1,
      sortOrder: 10 + index,
    })),
  ];

  for (const achievement of achievementsToUpsert) {
    await prisma.achievement.upsert({
      where: { key: achievement.key },
      update: {
        title: achievement.title,
        description: achievement.description,
        iconKey: achievement.iconKey,
        rewardCoins: achievement.rewardCoins,
        rewardStars: achievement.rewardStars,
        sortOrder: achievement.sortOrder,
        isActive: true,
      },
      create: {
        key: achievement.key,
        title: achievement.title,
        description: achievement.description,
        iconKey: achievement.iconKey,
        rewardCoins: achievement.rewardCoins,
        rewardStars: achievement.rewardStars,
        sortOrder: achievement.sortOrder,
        isActive: true,
      },
    });
  }

  const gamificationCatalogByKey = new Map();
  for (const item of gamificationCatalogItems) {
    const saved = await prisma.gamificationCatalogItem.upsert({
      where: { key: item.key },
      update: {
        type: item.type,
        name: item.name,
        description: item.description,
        iconKey: item.iconKey,
        priceCoins: item.priceCoins,
        priceStars: item.priceStars,
        sortOrder: item.sortOrder,
        isActive: true,
      },
      create: {
        key: item.key,
        type: item.type,
        name: item.name,
        description: item.description,
        iconKey: item.iconKey,
        priceCoins: item.priceCoins,
        priceStars: item.priceStars,
        sortOrder: item.sortOrder,
        isActive: true,
      },
      select: {
        id: true,
        key: true,
      },
    });
    gamificationCatalogByKey.set(saved.key, saved.id);
  }

  return {
    virtuesBySlug,
    themesBySlug,
    sampleTemplateId: sampleTemplate.id,
    achievementsCount: achievementsToUpsert.length,
    gamificationCatalogByKey,
  };
}

async function applyDemoForUser(accountState, coreRefs) {
  const collectionIdsByKey = new Map();
  let storiesCount = 0;

  for (const collection of demoCollectionsBlueprint) {
    const child = accountState.childrenByKey.get(collection.childKey);
    if (!child) {
      throw new Error(
        `Crianca demo nao encontrada para account=${accountState.key} child=${collection.childKey}`
      );
    }

    const collectionVirtueId = coreRefs.virtuesBySlug.get(collection.virtueSlug) ?? null;
    const collectionId = seedId(accountState.key, "collection", collection.key);
    const lastReferenceAt = new Date(
      Math.max(...collection.stories.map((story) => getStoryReferenceDate(story).getTime()))
    );

    await prisma.storyCollection.upsert({
      where: { id: collectionId },
      update: {
        userId: accountState.user.id,
        childProfileId: child.id,
        title: collection.title,
        theme: collection.theme,
        virtueId: collectionVirtueId,
        isFavorite: collection.isFavorite,
        templateFromStoryId: null,
        lastReferenceAt,
      },
      create: {
        id: collectionId,
        userId: accountState.user.id,
        childProfileId: child.id,
        title: collection.title,
        theme: collection.theme,
        virtueId: collectionVirtueId,
        isFavorite: collection.isFavorite,
        templateFromStoryId: null,
        lastReferenceAt,
      },
      select: { id: true },
    });

    collectionIdsByKey.set(collection.key, collectionId);
  }

  for (const collection of demoCollectionsBlueprint) {
    const child = accountState.childrenByKey.get(collection.childKey);
    const collectionId = collectionIdsByKey.get(collection.key);
    if (!child || !collectionId) {
      continue;
    }

    for (const story of collection.stories) {
      const storyId = seedId(accountState.key, "story", story.key);
      const continuedFromStoryId = story.continuedFromStoryKey
        ? seedId(accountState.key, "story", story.continuedFromStoryKey)
        : null;
      const virtueId = coreRefs.virtuesBySlug.get(story.virtueSlug) ?? null;
      const templatePayload = getVirtueTemplatePayload(story.virtueSlug, story.ageBand);
      const storyPrefix = seedId(accountState.key, "story", story.key);
      const titleFinal =
        story.status === "PUBLISHED" || story.status === "ARCHIVED" ? story.title : null;
      const gameSeed = computeStoryGameSeed({
        storyId,
        theme: story.theme,
        scenario: story.scenario,
        objective: story.objective,
      });
      const gameMap = buildLinearTrailMap(gameSeed);

      await prisma.story.upsert({
        where: { id: storyId },
        update: {
          userId: accountState.user.id,
          childProfileId: child.id,
          collectionId,
          sourceTemplateId: story.sourceTemplate ? coreRefs.sampleTemplateId : null,
          episodeNumber: story.episodeNumber,
          continuedFromStoryId,
          sessionKind: "PRESENTIAL",
          virtueId,
          titleDraft: story.title,
          titleFinal,
          theme: story.theme,
          scenario: story.scenario,
          objective: story.objective,
          ageBand: story.ageBand,
          virtueSource: "MANUAL",
          dilemmaText: templatePayload.dilemmaText,
          endQuestionText: templatePayload.endQuestionText,
          status: story.status,
          currentMode: story.currentMode,
          currentStepIndex: story.currentStepIndex,
          gameMode: "TRAIL_LINEAR",
          gameSeed,
          gameMapVersion: GAME_MAP_VERSION,
          gameMapJson: gameMap,
          ageSnapshotYears: story.ageSnapshotYears,
          startedAt: story.startedAt,
          publishedAt: story.publishedAt,
          completedAt: story.completedAt,
        },
        create: {
          id: storyId,
          userId: accountState.user.id,
          childProfileId: child.id,
          collectionId,
          sourceTemplateId: story.sourceTemplate ? coreRefs.sampleTemplateId : null,
          episodeNumber: story.episodeNumber,
          continuedFromStoryId,
          sessionKind: "PRESENTIAL",
          virtueId,
          titleDraft: story.title,
          titleFinal,
          theme: story.theme,
          scenario: story.scenario,
          objective: story.objective,
          ageBand: story.ageBand,
          virtueSource: "MANUAL",
          dilemmaText: templatePayload.dilemmaText,
          endQuestionText: templatePayload.endQuestionText,
          status: story.status,
          currentMode: story.currentMode,
          currentStepIndex: story.currentStepIndex,
          gameMode: "TRAIL_LINEAR",
          gameSeed,
          gameMapVersion: GAME_MAP_VERSION,
          gameMapJson: gameMap,
          ageSnapshotYears: story.ageSnapshotYears,
          startedAt: story.startedAt,
          publishedAt: story.publishedAt,
          completedAt: story.completedAt,
        },
      });

      const characterIds = [];
      for (const [index, character] of story.characters.entries()) {
        const characterId = seedId(
          accountState.key,
          "story",
          story.key,
          "char",
          character.key
        );
        characterIds.push(characterId);
        await prisma.storyCharacter.upsert({
          where: { id: characterId },
          update: {
            storyId,
            name: character.name,
            role: character.role ?? null,
          },
          create: {
            id: characterId,
            storyId,
            name: character.name,
            role: character.role ?? null,
          },
        });
      }

      await prisma.storyCharacter.deleteMany({
        where: {
          storyId,
          id: {
            startsWith: `${storyPrefix}_char_`,
            notIn: characterIds,
          },
        },
      });

      const stepIndexes = [];
      for (const step of story.steps) {
        const localEventId = `seed_evt_${accountState.key}_${story.key}_${step.stepIndex}`;
        const gameplayMeta = resolveStepGameplayMeta(step);
        stepIndexes.push(step.stepIndex);
        await prisma.storyStep.upsert({
          where: {
            storyId_stepIndex: {
              storyId,
              stepIndex: step.stepIndex,
            },
          },
          update: {
            kind: step.kind,
            modeUsed: step.modeUsed,
            localEventId,
            narratorPrompt: null,
            childOptionsJson: step.childOptions ?? null,
            selectedOptionId: step.selectedOptionId ?? null,
            selectedOptionLabel: step.selectedOptionLabel ?? null,
            narratorText: step.narratorText ?? null,
            gameNodeIndex: gameplayMeta.gameNodeIndex,
            gameActionKey: gameplayMeta.gameActionKey,
            gameActionLabel: gameplayMeta.gameActionLabel,
            autoSavedAt: story.referenceAt,
          },
          create: {
            id: seedId(
              accountState.key,
              "story",
              story.key,
              "step",
              String(step.stepIndex)
            ),
            storyId,
            stepIndex: step.stepIndex,
            kind: step.kind,
            modeUsed: step.modeUsed,
            localEventId,
            narratorPrompt: null,
            childOptionsJson: step.childOptions ?? null,
            selectedOptionId: step.selectedOptionId ?? null,
            selectedOptionLabel: step.selectedOptionLabel ?? null,
            narratorText: step.narratorText ?? null,
            gameNodeIndex: gameplayMeta.gameNodeIndex,
            gameActionKey: gameplayMeta.gameActionKey,
            gameActionLabel: gameplayMeta.gameActionLabel,
            autoSavedAt: story.referenceAt,
            createdAt: story.startedAt,
          },
        });
      }

      await prisma.storyStep.deleteMany({
        where: {
          storyId,
          localEventId: {
            startsWith: `seed_evt_${accountState.key}_${story.key}_`,
          },
          stepIndex: {
            notIn: stepIndexes,
          },
        },
      });

      storiesCount += 1;
    }
  }

  return {
    collectionsCount: demoCollectionsBlueprint.length,
    storiesCount,
    childrenCount: demoChildrenCatalog.length,
  };
}

async function ensureDemoStoryVaultData(coreRefs, usersByKey) {
  const summary = {
    usersCount: 0,
    childrenCount: 0,
    collectionsCount: 0,
    storiesCount: 0,
  };

  for (const account of demoUsersCatalog) {
    const accountState = usersByKey.get(account.key);
    if (!accountState) {
      continue;
    }

    const applied = await applyDemoForUser(accountState, coreRefs);
    summary.usersCount += 1;
    summary.childrenCount += applied.childrenCount;
    summary.collectionsCount += applied.collectionsCount;
    summary.storiesCount += applied.storiesCount;
  }

  return summary;
}

async function ensureQaArtStylesData() {
  for (const style of qaArtStylesCatalog) {
    await prisma.artStyle.upsert({
      where: { id: style.id },
      update: {
        name: style.name,
        promptTemplate: style.promptTemplate,
      },
      create: {
        id: style.id,
        name: style.name,
        promptTemplate: style.promptTemplate,
      },
    });
  }

  return {
    count: qaArtStylesCatalog.length,
  };
}

async function ensureQaParallelInventoryData(usersByKey) {
  const inventoryItemIdsByKey = new Map();

  for (const item of qaInventoryItemsCatalog) {
    const saved = await prisma.inventoryItem.upsert({
      where: { key: item.key },
      update: {
        name: item.name,
        description: item.description,
        rarity: item.rarity,
        category: item.category,
        icon: item.icon,
        tags: item.tags,
      },
      create: {
        key: item.key,
        name: item.name,
        description: item.description,
        rarity: item.rarity,
        category: item.category,
        icon: item.icon,
        tags: item.tags,
      },
      select: {
        id: true,
        key: true,
      },
    });
    inventoryItemIdsByKey.set(saved.key, saved.id);
  }

  let childInventoryCount = 0;
  for (const account of demoUsersCatalog) {
    const accountState = usersByKey.get(account.key);
    if (!accountState) {
      continue;
    }

    for (const config of qaInventoryUnlockBlueprint) {
      const child = accountState.childrenByKey.get(config.childKey);
      if (!child) {
        continue;
      }

      for (const unlock of config.unlocks) {
        const itemId = inventoryItemIdsByKey.get(unlock.itemKey);
        if (!itemId) {
          continue;
        }

        await prisma.childInventory.upsert({
          where: {
            childProfileId_itemId: {
              childProfileId: child.id,
              itemId,
            },
          },
          update: {
            qty: unlock.qty,
            acquiredAt: new Date("2026-02-20T12:00:00.000Z"),
          },
          create: {
            id: seedId(account.key, "inventory", config.childKey, unlock.itemKey),
            childProfileId: child.id,
            itemId,
            qty: unlock.qty,
            acquiredAt: new Date("2026-02-20T12:00:00.000Z"),
            lastUsedAt: null,
          },
        });

        childInventoryCount += 1;
      }
    }
  }

  return {
    itemsCount: qaInventoryItemsCatalog.length,
    childInventoryCount,
  };
}

async function ensureQaStoryMemoriesData(usersByKey) {
  let memoriesCount = 0;

  for (const account of demoUsersCatalog) {
    const accountState = usersByKey.get(account.key);
    if (!accountState) {
      continue;
    }

    for (const memory of qaStoryMemoriesBlueprint) {
      const child = accountState.childrenByKey.get(memory.childKey);
      if (!child) {
        continue;
      }

      const storyId = seedId(account.key, "story", memory.storyKey);
      await prisma.storyMemory.upsert({
        where: {
          storyId_childProfileId: {
            storyId,
            childProfileId: child.id,
          },
        },
        update: {
          summary: memory.summary,
          usedItems: memory.usedItems,
          virtueLearned: memory.virtueLearned,
        },
        create: {
          id: seedId(account.key, "memory", memory.storyKey, memory.childKey),
          storyId,
          childProfileId: child.id,
          summary: memory.summary,
          usedItems: memory.usedItems,
          virtueLearned: memory.virtueLearned,
        },
      });
      memoriesCount += 1;
    }
  }

  return {
    memoriesCount,
  };
}

async function ensureQaBookProjectsData(usersByKey) {
  let projectsCount = 0;

  for (const account of demoUsersCatalog) {
    const accountState = usersByKey.get(account.key);
    if (!accountState) {
      continue;
    }

    const child = accountState.childrenByKey.get(qaBookProjectConfig.childKey);
    if (!child) {
      continue;
    }

    const includedStories = qaBookProjectConfig.includedStoryKeys.map((storyKey) =>
      seedId(account.key, "story", storyKey)
    );

    await prisma.bookProject.upsert({
      where: {
        childProfileId_month: {
          childProfileId: child.id,
          month: qaBookProjectConfig.month,
        },
      },
      update: {
        userId: accountState.user.id,
        title: qaBookProjectConfig.title,
        status: qaBookProjectConfig.status,
        pdfUrl: qaBookProjectConfig.pdfUrl,
        includedStories,
      },
      create: {
        id: seedId(account.key, "book_project", qaBookProjectConfig.month),
        userId: accountState.user.id,
        childProfileId: child.id,
        month: qaBookProjectConfig.month,
        title: qaBookProjectConfig.title,
        status: qaBookProjectConfig.status,
        pdfUrl: qaBookProjectConfig.pdfUrl,
        includedStories,
      },
    });

    projectsCount += 1;
  }

  return {
    projectsCount,
  };
}

async function ensureQaRemoteRoomData(usersByKey) {
  let roomsCount = 0;
  let participantsCount = 0;
  let interactionsCount = 0;

  for (const account of demoUsersCatalog) {
    const accountState = usersByKey.get(account.key);
    if (!accountState) {
      continue;
    }

    const storyId = seedId(accountState.key, "story", qaRemoteRoomConfig.storyKey);
    const room = await prisma.remoteStoryRoom.upsert({
      where: { storyId },
      update: {
        ownerUserId: accountState.user.id,
        status: "OPEN",
        joinCodeHash: hashJoinCode(qaRemoteRoomConfig.joinCode),
        joinCodeExpiresAt: new Date("2099-12-31T23:59:59.000Z"),
        joinCodeConsumedAt: null,
        callMode: qaRemoteRoomConfig.callMode,
        maxParticipants: 2,
        closedAt: null,
      },
      create: {
        id: seedId(accountState.key, "remote_room", qaRemoteRoomConfig.storyKey),
        storyId,
        ownerUserId: accountState.user.id,
        status: "OPEN",
        joinCodeHash: hashJoinCode(qaRemoteRoomConfig.joinCode),
        joinCodeExpiresAt: new Date("2099-12-31T23:59:59.000Z"),
        joinCodeConsumedAt: null,
        callMode: qaRemoteRoomConfig.callMode,
        maxParticipants: 2,
        closedAt: null,
      },
      select: {
        id: true,
      },
    });

    await prisma.story.updateMany({
      where: {
        id: storyId,
        status: "DRAFT",
      },
      data: {
        sessionKind: "REMOTE",
      },
    });

    const hostParticipant = await prisma.remoteStoryParticipant.upsert({
      where: {
        remoteRoomId_role: {
          remoteRoomId: room.id,
          role: "HOST_PARENT",
        },
      },
      update: {
        displayName: accountState.user.name ?? "Responsavel",
        status: "CONNECTED",
        lastSeenAt: new Date("2026-03-01T12:00:00.000Z"),
        leftAt: null,
        deviceInfo: "seed-host",
      },
      create: {
        id: seedId(accountState.key, "remote_participant", "host"),
        remoteRoomId: room.id,
        role: "HOST_PARENT",
        displayName: accountState.user.name ?? "Responsavel",
        status: "CONNECTED",
        lastSeenAt: new Date("2026-03-01T12:00:00.000Z"),
        joinedAt: new Date("2026-03-01T11:58:00.000Z"),
        leftAt: null,
        deviceInfo: "seed-host",
      },
      select: {
        id: true,
        displayName: true,
      },
    });

    const guestChild = accountState.childrenByKey.get("sofia");
    const guestParticipant = await prisma.remoteStoryParticipant.upsert({
      where: {
        remoteRoomId_role: {
          remoteRoomId: room.id,
          role: "GUEST_CHILD",
        },
      },
      update: {
        displayName: guestChild?.name ?? "Convidado",
        status: "CONNECTED",
        lastSeenAt: new Date("2026-03-01T12:01:00.000Z"),
        leftAt: null,
        deviceInfo: "seed-guest-tablet",
      },
      create: {
        id: seedId(accountState.key, "remote_participant", "guest"),
        remoteRoomId: room.id,
        role: "GUEST_CHILD",
        displayName: guestChild?.name ?? "Convidado",
        status: "CONNECTED",
        lastSeenAt: new Date("2026-03-01T12:01:00.000Z"),
        joinedAt: new Date("2026-03-01T11:59:00.000Z"),
        leftAt: null,
        deviceInfo: "seed-guest-tablet",
      },
      select: {
        id: true,
        displayName: true,
      },
    });

    const interactionIds = [];
    for (const [index, interaction] of qaRemoteRoomConfig.interactions.entries()) {
      const interactionId = seedId(accountState.key, "remote_interaction", interaction.key);
      interactionIds.push(interactionId);

      const isHost = interaction.authorRole === "HOST_PARENT";
      await prisma.storyInteraction.upsert({
        where: { id: interactionId },
        update: {
          storyId,
          remoteRoomId: room.id,
          type: interaction.type,
          authorRole: interaction.authorRole,
          authorUserId: isHost ? accountState.user.id : null,
          authorParticipantId: isHost ? hostParticipant.id : guestParticipant.id,
          authorDisplayName: isHost
            ? hostParticipant.displayName
            : guestParticipant.displayName,
          messageText: interaction.messageText,
          emoji: interaction.emoji,
        },
        create: {
          id: interactionId,
          storyId,
          remoteRoomId: room.id,
          type: interaction.type,
          authorRole: interaction.authorRole,
          authorUserId: isHost ? accountState.user.id : null,
          authorParticipantId: isHost ? hostParticipant.id : guestParticipant.id,
          authorDisplayName: isHost
            ? hostParticipant.displayName
            : guestParticipant.displayName,
          messageText: interaction.messageText,
          emoji: interaction.emoji,
          createdAt: new Date(`2026-03-01T12:0${index}:00.000Z`),
        },
      });
    }

    await prisma.storyInteraction.deleteMany({
      where: {
        remoteRoomId: room.id,
        id: {
          startsWith: `seed_${accountState.key}_remote_interaction_`,
          notIn: interactionIds,
        },
      },
    });

    roomsCount += 1;
    participantsCount += 2;
    interactionsCount += interactionIds.length;
  }

  return {
    roomsCount,
    participantsCount,
    interactionsCount,
  };
}

async function ensureQaGamificationBaselineData(coreRefs, usersByKey) {
  let walletsCount = 0;
  let streaksCount = 0;
  let missionsCount = 0;
  let unlocksCount = 0;

  const weekKey = mondayWeekKey(new Date(), "UTC");
  const weekStartDate = new Date(`${weekKey}T00:00:00.000Z`);
  const virtueForMissionId = coreRefs.virtuesBySlug.get("coragem") ?? null;

  for (const account of demoUsersCatalog) {
    const accountState = usersByKey.get(account.key);
    if (!accountState) {
      continue;
    }

    const baseline = qaWalletBaselineByAccount[account.key] ?? { coins: 100, stars: 2 };
    const existingWallet = await prisma.wallet.findUnique({
      where: { userId: accountState.user.id },
    });

    if (!existingWallet) {
      await prisma.wallet.create({
        data: {
          id: seedId(account.key, "wallet"),
          userId: accountState.user.id,
          coins: baseline.coins,
          stars: baseline.stars,
        },
      });
    } else {
      const nextCoins = Math.max(existingWallet.coins, baseline.coins);
      const nextStars = Math.max(existingWallet.stars, baseline.stars);
      if (nextCoins !== existingWallet.coins || nextStars !== existingWallet.stars) {
        await prisma.wallet.update({
          where: { id: existingWallet.id },
          data: {
            coins: nextCoins,
            stars: nextStars,
          },
        });
      }
    }
    walletsCount += 1;

    for (const childConfig of demoChildrenCatalog) {
      const child = accountState.childrenByKey.get(childConfig.key);
      if (!child) {
        continue;
      }

      const streakSeed =
        childConfig.key === "lucas"
          ? { currentDays: 4, bestDays: 7, shieldCount: 1 }
          : { currentDays: 2, bestDays: 3, shieldCount: 1 };

      const existingStreak = await prisma.childStreak.findUnique({
        where: { childProfileId: child.id },
      });

      if (!existingStreak) {
        await prisma.childStreak.create({
          data: {
            id: seedId(account.key, "streak", childConfig.key),
            userId: accountState.user.id,
            childProfileId: child.id,
            currentDays: streakSeed.currentDays,
            bestDays: streakSeed.bestDays,
            shieldCount: streakSeed.shieldCount,
            lastCountedDate: weekStartDate,
            lastShieldGrantWeekKey: weekKey,
          },
        });
      } else {
        const nextLastCountedDate =
          existingStreak.lastCountedDate &&
          existingStreak.lastCountedDate.getTime() > weekStartDate.getTime()
            ? existingStreak.lastCountedDate
            : weekStartDate;

        await prisma.childStreak.update({
          where: { id: existingStreak.id },
          data: {
            userId: accountState.user.id,
            currentDays: Math.max(existingStreak.currentDays, streakSeed.currentDays),
            bestDays: Math.max(existingStreak.bestDays, streakSeed.bestDays),
            shieldCount: Math.max(existingStreak.shieldCount, streakSeed.shieldCount),
            lastCountedDate: nextLastCountedDate,
            lastShieldGrantWeekKey: existingStreak.lastShieldGrantWeekKey ?? weekKey,
          },
        });
      }
      streaksCount += 1;

      const missionsSeed = [
        {
          key: "publish_count",
          kind: "PUBLISH_COUNT",
          title: "Conte 2 capitulos",
          description: "Publique 2 capitulos nesta semana.",
          targetValue: 2,
          progressValue: 1,
          virtueId: null,
          rewardCoins: 35,
          rewardStars: 1,
        },
        {
          key: "publish_with_virtue",
          kind: "PUBLISH_WITH_VIRTUE",
          title: "1 historia sobre coragem",
          description: "Publique 1 capitulo com a virtude Coragem.",
          targetValue: 1,
          progressValue: 1,
          virtueId: virtueForMissionId,
          rewardCoins: 40,
          rewardStars: 1,
        },
        {
          key: "continue_episode",
          kind: "CONTINUE_EPISODE",
          title: "Continue 1 episodio",
          description: "Publique 1 episodio de continuacao nesta semana.",
          targetValue: 1,
          progressValue: childConfig.key === "lucas" ? 1 : 0,
          virtueId: null,
          rewardCoins: 35,
          rewardStars: 1,
        },
      ];

      for (const mission of missionsSeed) {
        const status = mission.progressValue >= mission.targetValue ? "COMPLETED" : "ACTIVE";
        const completedAt = status === "COMPLETED" ? new Date("2026-03-01T12:30:00.000Z") : null;

        const existingMission = await prisma.childWeeklyMission.findFirst({
          where: {
            userId: accountState.user.id,
            childProfileId: child.id,
            weekKey,
            kind: mission.kind,
            virtueId: mission.virtueId,
          },
          select: {
            id: true,
          },
        });

        if (existingMission) {
          await prisma.childWeeklyMission.update({
            where: { id: existingMission.id },
            data: {
              title: mission.title,
              description: mission.description,
              targetValue: mission.targetValue,
              progressValue: mission.progressValue,
              status,
              rewardCoins: mission.rewardCoins,
              rewardStars: mission.rewardStars,
              completedAt,
            },
          });
        } else {
          await prisma.childWeeklyMission.create({
            data: {
              id: seedId(account.key, "mission", childConfig.key, weekKey, mission.key),
              userId: accountState.user.id,
              childProfileId: child.id,
              weekKey,
              kind: mission.kind,
              title: mission.title,
              description: mission.description,
              targetValue: mission.targetValue,
              progressValue: mission.progressValue,
              status,
              virtueId: mission.virtueId,
              rewardCoins: mission.rewardCoins,
              rewardStars: mission.rewardStars,
              completedAt,
            },
          });
        }

        missionsCount += 1;
      }
    }

    for (const unlockConfig of qaGamificationUnlockBlueprint) {
      const child = accountState.childrenByKey.get(unlockConfig.childKey);
      if (!child) {
        continue;
      }

      for (const itemKey of unlockConfig.unlockItemKeys) {
        const itemId = coreRefs.gamificationCatalogByKey.get(itemKey);
        if (!itemId) {
          continue;
        }

        await prisma.childInventoryItem.upsert({
          where: {
            childProfileId_itemId: {
              childProfileId: child.id,
              itemId,
            },
          },
          update: {
            equipped: itemKey === unlockConfig.equippedItemKey,
          },
          create: {
            id: seedId(account.key, "gamification_unlock", unlockConfig.childKey, itemKey),
            childProfileId: child.id,
            itemId,
            unlockedAt: new Date("2026-02-21T12:00:00.000Z"),
            equipped: itemKey === unlockConfig.equippedItemKey,
          },
        });
        unlocksCount += 1;
      }
    }
  }

  return {
    walletsCount,
    streaksCount,
    missionsCount,
    unlocksCount,
  };
}

async function logStoryRoomTargets(usersByKey) {
  console.log("Historias alvo para abrir sala:");

  for (const account of demoUsersCatalog) {
    const accountState = usersByKey.get(account.key);
    if (!accountState) {
      continue;
    }

    const stories = await prisma.story.findMany({
      where: {
        userId: accountState.user.id,
        id: {
          startsWith: `seed_${account.key}_story_`,
        },
      },
      select: {
        id: true,
        status: true,
        sessionKind: true,
        currentStepIndex: true,
        titleDraft: true,
        titleFinal: true,
      },
    });

    const statusPriority = {
      DRAFT: 0,
      PUBLISHED: 1,
      ARCHIVED: 2,
    };

    const ordered = [...stories].sort((left, right) => {
      const statusDiff = (statusPriority[left.status] ?? 99) - (statusPriority[right.status] ?? 99);
      if (statusDiff !== 0) {
        return statusDiff;
      }
      return right.currentStepIndex - left.currentStepIndex;
    });

    for (const story of ordered) {
      console.log(
        `- account=${account.key} storyId=${story.id} status=${story.status} session=${story.sessionKind} steps=${story.currentStepIndex} route=/stories/${story.id}/room title="${story.titleFinal ?? story.titleDraft}"`
      );
    }
  }
}

async function main() {
  const usersByKey = await ensureDemoUsersAndProfiles();
  const adminState = usersByKey.get("admin");

  if (!adminState) {
    throw new Error("Conta admin nao foi criada durante o seed.");
  }

  console.log("Contas demo seedadas:");
  for (const account of demoUsersCatalog) {
    const state = usersByKey.get(account.key);
    if (!state) {
      continue;
    }
    console.log(
      `- key=${account.key} id=${state.user.id} email=${state.user.email} nome=${state.user.name}`
    );
  }

  const coreRefs = await ensureCoreCatalogData(adminState.user.id);
  const vaultSummary = await ensureDemoStoryVaultData(coreRefs, usersByKey);
  const artStylesSummary = await ensureQaArtStylesData();
  const parallelInventorySummary = await ensureQaParallelInventoryData(usersByKey);
  const memoriesSummary = await ensureQaStoryMemoriesData(usersByKey);
  const bookProjectsSummary = await ensureQaBookProjectsData(usersByKey);
  const remoteRoomSummary = await ensureQaRemoteRoomData(usersByKey);
  const gamificationBaselineSummary = await ensureQaGamificationBaselineData(
    coreRefs,
    usersByKey
  );

  console.log(`Virtudes seedadas: ${virtuesCatalog.length}`);
  console.log(`Temas seedados: ${storyThemesCatalog.length}`);
  console.log(`Prompts seedados: ${contentPromptsCatalog.length}`);
  console.log(`Termos de moderacao seedados: ${moderationSeedTerms.length}`);
  console.log(`Conquistas seedadas: ${coreRefs.achievementsCount}`);
  console.log(`Itens de catalogo seedados: ${gamificationCatalogItems.length}`);
  console.log(`Art styles seedados: ${artStylesSummary.count}`);
  console.log(`Contas demo seedadas: ${vaultSummary.usersCount}`);
  console.log(`Criancas demo seedadas: ${vaultSummary.childrenCount}`);
  console.log(`Colecoes demo seedadas: ${vaultSummary.collectionsCount}`);
  console.log(`Historias demo seedadas: ${vaultSummary.storiesCount}`);
  console.log(`Inventario paralelo seedado: ${parallelInventorySummary.itemsCount} itens base`);
  console.log(
    `Inventario por crianca seedado: ${parallelInventorySummary.childInventoryCount} vinculos`
  );
  console.log(`Memorias seedadas: ${memoriesSummary.memoriesCount}`);
  console.log(`Book projects READY seedados: ${bookProjectsSummary.projectsCount}`);
  console.log(`Salas remotas QA seedadas: ${remoteRoomSummary.roomsCount}`);
  console.log(`Participantes remotos QA seedados: ${remoteRoomSummary.participantsCount}`);
  console.log(`Interacoes remotas QA seedadas: ${remoteRoomSummary.interactionsCount}`);
  console.log(`Wallet baseline QA aplicado: ${gamificationBaselineSummary.walletsCount}`);
  console.log(`Streak baseline QA aplicado: ${gamificationBaselineSummary.streaksCount}`);
  console.log(`Missoes baseline QA aplicadas: ${gamificationBaselineSummary.missionsCount}`);
  console.log(
    `Unlocks de gamificacao QA aplicados: ${gamificationBaselineSummary.unlocksCount}`
  );
  console.log(`PIN demo configurado para contas seedadas: ${demoPin}`);
  await logStoryRoomTargets(usersByKey);
}

main()
  .catch((error) => {
    console.error("Falha ao executar seed de conteudo demo:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });

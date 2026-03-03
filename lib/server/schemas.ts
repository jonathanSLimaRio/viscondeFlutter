import { z } from "zod";

const passwordSchema = z
  .string()
  .min(8, "A senha deve ter pelo menos 8 caracteres.")
  .max(128, "A senha deve ter no maximo 128 caracteres.");

const pinSchema = z.string().regex(/^\d{6}$/, "PIN deve conter 6 digitos.");
const storyModeSchema = z.enum(["PARENT_NARRATOR", "CHILD_CHOOSER"]);
const storyStatusSchema = z.enum(["DRAFT", "PUBLISHED", "ARCHIVED"]);
const storyStepKindSchema = z.enum(["NARRATION", "CHILD_CHOICE", "SYSTEM"]);
const callModeSchema = z.enum(["NONE", "AUDIO", "VIDEO"]);
const catalogItemTypeSchema = z.enum(["SCENARIO", "CHARACTER", "SKIN", "AVATAR"]);
const ageBandSchema = z.enum(["AGE_4_5", "AGE_6_8", "AGE_9_10"]);
const promptKindSchema = z.enum(["IDEA_SYSTEM", "IDEA_FALLBACK", "NARRATOR_HINT"]);
const storyTemplateNodeKindSchema = z.enum(["START", "NARRATION", "CHOICE", "END"]);
const moderationPolicySchema = z.enum(["BLOCK", "SANITIZE"]);
const moderationScopeSchema = z.enum([
  "USER_NAME",
  "CHILD_NAME",
  "STORY_TEXT",
  "CHAT_TEXT",
  "TEMPLATE_TEXT",
]);
const uxEventNameSchema = z.enum([
  "session_started",
  "auth_error_shown",
  "story_create_started",
  "story_create_step_completed",
  "story_create_abandoned",
  "story_published",
  "game_hub_opened",
  "vault_state_shown",
  "vault_retry_tapped",
  "vault_empty_cta_tapped",
  "game_state_shown",
  "game_retry_tapped",
  "game_empty_cta_tapped",
  "post_publish_modal_opened",
  "post_publish_cta_clicked",
  "pin_prompt_shown",
  "pin_prompt_success",
  "pin_prompt_abandon",
  "pin_lock_now_clicked",
]);

const optionalString = z
  .string()
  .trim()
  .min(1)
  .max(120)
  .optional()
  .nullable();

const uxClientInfoSchema = z
  .object({
    platform: z.string().trim().min(1).max(40).optional(),
    appVersion: z.string().trim().min(1).max(80).optional(),
    appBuild: z.string().trim().min(1).max(40).optional(),
    locale: z.string().trim().min(1).max(40).optional(),
    timezone: z.string().trim().min(1).max(80).optional(),
  })
  .strict()
  .optional();

export const uxEventSchema = z.object({
  eventId: z.string().trim().min(1).max(140),
  name: uxEventNameSchema,
  occurredAt: z.coerce.date(),
  source: z.string().trim().min(1).max(120).optional(),
  childId: z.string().trim().min(1).max(120).optional(),
  params: z.record(z.string(), z.unknown()).optional(),
});

export const uxEventsBatchSchema = z.object({
  appSessionId: z.string().trim().min(1).max(140),
  client: uxClientInfoSchema,
  events: z.array(uxEventSchema).min(1).max(50),
});

export const uxFunnelQuerySchema = z.object({
  dateFrom: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  dateTo: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  timezone: z.string().trim().min(1).max(80).optional(),
});

export const signUpSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: passwordSchema,
  name: optionalString,
  timezone: z.string().trim().min(1).max(100).optional(),
});

export const loginSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(1),
});

export const socialLoginSchema = z.object({
  idToken: z.string().min(1),
  timezone: z.string().trim().min(1).max(100).optional(),
});

export const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

export const logoutSchema = z.object({
  refreshToken: z.string().min(1).optional(),
});

export const forgotPasswordSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
});

export const resetPasswordSchema = z.object({
  token: z.string().min(12),
  newPassword: passwordSchema,
});

export const updateMeSchema = z.object({
  name: optionalString,
  timezone: z.string().trim().min(1).max(100).optional(),
});

export const createChildSchema = z.object({
  name: z.string().trim().min(1).max(120),
  birthDate: z.coerce.date(),
  favoriteThemes: z.array(z.string().trim().min(1).max(80)).default([]),
});

export const updateChildSchema = z.object({
  name: z.string().trim().min(1).max(120).optional(),
  birthDate: z.coerce.date().optional(),
  favoriteThemes: z.array(z.string().trim().min(1).max(80)).optional(),
  isArchived: z.boolean().optional(),
});

export const setPinSchema = z.object({
  pin: pinSchema,
});

export const verifyPinSchema = z.object({
  pin: pinSchema,
});

export const resetPinSchema = z.object({
  newPin: pinSchema,
  currentPassword: z.string().min(1).optional(),
  googleIdToken: z.string().min(1).optional(),
  appleIdentityToken: z.string().min(1).optional(),
});

const storyCharacterInputSchema = z.object({
  name: z.string().trim().min(1).max(80),
  role: z.string().trim().min(1).max(80).optional(),
});

export const createStorySessionSchema = z.object({
  childProfileId: z.string().trim().min(1).max(120),
  titleDraft: z.string().trim().min(1).max(140),
  theme: z.string().trim().min(1).max(120),
  scenario: z.string().trim().min(1).max(160),
  characters: z.array(storyCharacterInputSchema).min(1).max(8),
  objective: z.string().trim().min(1).max(200),
  startMode: storyModeSchema.default("PARENT_NARRATOR"),
  virtueId: z.string().trim().min(1).max(120).optional(),
  sourceTemplateId: z.string().trim().min(1).max(120).optional(),
  artStyleId: z.string().trim().min(1).max(120).optional(),
});

export const updateStorySessionSetupSchema = z
  .object({
    titleDraft: z.string().trim().min(1).max(140).optional(),
    theme: z.string().trim().min(1).max(120).optional(),
    scenario: z.string().trim().min(1).max(160).optional(),
    objective: z.string().trim().min(1).max(200).optional(),
    characters: z.array(storyCharacterInputSchema).min(1).max(8).optional(),
    virtueId: z.string().trim().min(1).max(120).optional().nullable(),
    sourceTemplateId: z.string().trim().min(1).max(120).optional().nullable(),
    artStyleId: z.string().trim().min(1).max(120).optional().nullable(),
    mode: storyModeSchema.optional(),
  })
  .superRefine((value, context) => {
    if (
      value.titleDraft === undefined &&
      value.theme === undefined &&
      value.scenario === undefined &&
      value.objective === undefined &&
      value.characters === undefined &&
      value.virtueId === undefined &&
      value.sourceTemplateId === undefined &&
      value.artStyleId === undefined &&
      value.mode === undefined
    ) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Informe ao menos um campo para atualizar a sessao.",
      });
    }
  });

export const updateStoryModeSchema = z.object({
  mode: storyModeSchema,
});

export const storyIdeasSchema = z.object({
  contextHint: z.string().trim().min(1).max(500).optional(),
});

export const createStoryStepSchema = z
  .object({
    kind: storyStepKindSchema,
    stepIndex: z.number().int().min(1).max(12),
    narratorText: z.string().trim().min(1).max(4000).optional(),
    narratorPrompt: z.string().trim().min(1).max(4000).optional(),
    selectedOptionId: z.string().trim().min(1).max(80).optional(),
    selectedOptionLabel: z.string().trim().min(1).max(200).optional(),
    localEventId: z.string().trim().min(1).max(120),
  })
  .superRefine((value, context) => {
    if (value.kind === "NARRATION") {
      if (!value.narratorText && !value.narratorPrompt) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          message: "Etapa de narracao exige narratorText ou narratorPrompt.",
          path: ["narratorText"],
        });
      }
      return;
    }

    if (value.kind === "CHILD_CHOICE" && !value.selectedOptionLabel) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Etapa de escolha exige selectedOptionLabel.",
        path: ["selectedOptionLabel"],
      });
    }
  });

export const finalizeStorySessionSchema = z.object({
  titleFinal: z.string().trim().min(1).max(140).optional(),
});

export const wizardPublishStorySessionSchema = z.object({
  titleFinal: z.string().trim().min(1).max(140).optional(),
});

export const listStoriesQuerySchema = z.object({
  childProfileId: z.string().trim().min(1).max(120).optional(),
  status: storyStatusSchema.optional(),
});

const dateYyyyMmDdSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const optionalBooleanQuerySchema = z.preprocess((value) => {
  if (typeof value !== "string") {
    return value;
  }

  const normalized = value.trim().toLowerCase();
  if (normalized === "true") {
    return true;
  }
  if (normalized === "false") {
    return false;
  }

  return value;
}, z.boolean().optional());

export const listStoryVaultCollectionsQuerySchema = z.object({
  childProfileId: z.string().trim().min(1).max(120).optional(),
  dateFrom: dateYyyyMmDdSchema.optional(),
  dateTo: dateYyyyMmDdSchema.optional(),
  theme: z.string().trim().min(1).max(120).optional(),
  virtueId: z.string().trim().min(1).max(120).optional(),
  favoriteOnly: optionalBooleanQuerySchema,
});

export const setStoryCollectionFavoriteSchema = z.object({
  isFavorite: z.boolean(),
});

export const continueStorySchema = z.object({
  titleDraft: z.string().trim().min(1).max(140).optional(),
});

export const duplicateStoryTemplateSchema = z.object({
  childProfileId: z.string().trim().min(1).max(120).optional(),
});

export const listGamificationCatalogQuerySchema = z.object({
  childProfileId: z.string().trim().min(1).max(120),
  type: catalogItemTypeSchema.optional(),
});

export const unlockCatalogItemSchema = z.object({
  itemId: z.string().trim().min(1).max(120),
});

export const equipCatalogItemSchema = z.object({
  itemId: z.string().trim().min(1).max(120),
  equipped: z.boolean(),
});

export const virtueSuggestQuerySchema = z.object({
  childProfileId: z.string().trim().min(1).max(120),
});

export const openRemoteRoomSchema = z.object({
  callMode: callModeSchema.default("AUDIO").optional(),
});

export const joinRemoteRoomSchema = z.object({
  code: z.string().trim().min(4).max(20),
  displayName: z.string().trim().min(1).max(40),
});

export const createRemoteStepSchema = z.object({
  kind: z.literal("CHILD_CHOICE").default("CHILD_CHOICE"),
  stepIndex: z.number().int().min(1).max(12),
  selectedOptionId: z.string().trim().min(1).max(80).optional(),
  selectedOptionLabel: z.string().trim().min(1).max(200),
  localEventId: z.string().trim().min(1).max(120),
});

export const createRemoteChatSchema = z.object({
  messageText: z.string().trim().min(1).max(160),
});

const allowedReactionEmojis = ["👍", "👏", "❤️", "😂", "😮", "🎉", "💡", "🌟"];

export const createRemoteReactionSchema = z.object({
  emoji: z
    .string()
    .trim()
    .refine((value) => allowedReactionEmojis.includes(value), "Emoji nao permitido."),
});

export const listAdminVirtueTemplatesQuerySchema = z.object({
  virtueId: z.string().trim().min(1).max(120).optional(),
  ageBand: ageBandSchema.optional(),
});

export const listAdminPromptsQuerySchema = z.object({
  kind: promptKindSchema.optional(),
  themeId: z.string().trim().min(1).max(120).optional(),
  virtueId: z.string().trim().min(1).max(120).optional(),
  ageBand: ageBandSchema.optional(),
  mode: storyModeSchema.optional(),
});

export const createAdminThemeSchema = z.object({
  slug: z.string().trim().min(1).max(120).optional(),
  name: z.string().trim().min(1).max(120),
  shortDescription: z.string().trim().min(1).max(220),
  iconKey: z.string().trim().min(1).max(120),
  sortOrder: z.number().int().min(0).max(9999).optional(),
  isActive: z.boolean().optional(),
});

export const updateAdminThemeSchema = z.object({
  slug: z.string().trim().min(1).max(120).optional(),
  name: z.string().trim().min(1).max(120).optional(),
  shortDescription: z.string().trim().min(1).max(220).optional(),
  iconKey: z.string().trim().min(1).max(120).optional(),
  sortOrder: z.number().int().min(0).max(9999).optional(),
  isActive: z.boolean().optional(),
});

export const createAdminVirtueSchema = z.object({
  slug: z.string().trim().min(1).max(120).optional(),
  name: z.string().trim().min(1).max(120),
  shortDescription: z.string().trim().min(1).max(220),
  iconKey: z.string().trim().min(1).max(120),
  sortOrder: z.number().int().min(0).max(9999).optional(),
  isActive: z.boolean().optional(),
});

export const updateAdminVirtueSchema = z.object({
  slug: z.string().trim().min(1).max(120).optional(),
  name: z.string().trim().min(1).max(120).optional(),
  shortDescription: z.string().trim().min(1).max(220).optional(),
  iconKey: z.string().trim().min(1).max(120).optional(),
  sortOrder: z.number().int().min(0).max(9999).optional(),
  isActive: z.boolean().optional(),
});

export const createAdminVirtueTemplateSchema = z.object({
  virtueId: z.string().trim().min(1).max(120),
  ageBand: ageBandSchema,
  dilemmaText: z.string().trim().min(1).max(4000),
  endQuestionText: z.string().trim().min(1).max(2000),
  sortOrder: z.number().int().min(0).max(9999).optional(),
  isActive: z.boolean().optional(),
});

export const updateAdminVirtueTemplateSchema = z.object({
  dilemmaText: z.string().trim().min(1).max(4000).optional(),
  endQuestionText: z.string().trim().min(1).max(2000).optional(),
  sortOrder: z.number().int().min(0).max(9999).optional(),
  isActive: z.boolean().optional(),
});

export const createAdminPromptSchema = z.object({
  key: z.string().trim().min(1).max(120),
  kind: promptKindSchema,
  title: z.string().trim().min(1).max(180),
  text: z.string().trim().min(1).max(4000),
  themeId: z.string().trim().min(1).max(120).optional().nullable(),
  virtueId: z.string().trim().min(1).max(120).optional().nullable(),
  ageBand: ageBandSchema.optional().nullable(),
  mode: storyModeSchema.optional().nullable(),
  sortOrder: z.number().int().min(0).max(9999).optional(),
  isActive: z.boolean().optional(),
});

export const updateAdminPromptSchema = z.object({
  key: z.string().trim().min(1).max(120).optional(),
  kind: promptKindSchema.optional(),
  title: z.string().trim().min(1).max(180).optional(),
  text: z.string().trim().min(1).max(4000).optional(),
  themeId: z.string().trim().min(1).max(120).optional().nullable(),
  virtueId: z.string().trim().min(1).max(120).optional().nullable(),
  ageBand: ageBandSchema.optional().nullable(),
  mode: storyModeSchema.optional().nullable(),
  sortOrder: z.number().int().min(0).max(9999).optional(),
  isActive: z.boolean().optional(),
});

export const createAdminStoryTemplateSchema = z.object({
  slug: z.string().trim().min(1).max(120).optional(),
  title: z.string().trim().min(1).max(180),
  description: z.string().trim().min(1).max(1000),
  themeId: z.string().trim().min(1).max(120).optional().nullable(),
  virtueId: z.string().trim().min(1).max(120).optional().nullable(),
  ageBand: ageBandSchema.optional().nullable(),
  defaultScenario: z.string().trim().min(1).max(300),
  defaultObjective: z.string().trim().min(1).max(300),
  isActive: z.boolean().optional(),
});

export const updateAdminStoryTemplateSchema = z.object({
  slug: z.string().trim().min(1).max(120).optional(),
  title: z.string().trim().min(1).max(180).optional(),
  description: z.string().trim().min(1).max(1000).optional(),
  themeId: z.string().trim().min(1).max(120).optional().nullable(),
  virtueId: z.string().trim().min(1).max(120).optional().nullable(),
  ageBand: ageBandSchema.optional().nullable(),
  defaultScenario: z.string().trim().min(1).max(300).optional(),
  defaultObjective: z.string().trim().min(1).max(300).optional(),
  isActive: z.boolean().optional(),
});

export const createAdminStoryTemplateCharacterSchema = z.object({
  name: z.string().trim().min(1).max(120),
  role: z.string().trim().min(1).max(120).optional().nullable(),
  sortOrder: z.number().int().min(0).max(9999).optional(),
});

export const createAdminStoryTemplateNodeSchema = z.object({
  nodeKey: z.string().trim().min(1).max(120),
  kind: storyTemplateNodeKindSchema,
  title: z.string().trim().min(1).max(180),
  narratorText: z.string().trim().min(1).max(4000).optional().nullable(),
  promptHint: z.string().trim().min(1).max(1000).optional().nullable(),
  sortOrder: z.number().int().min(0).max(9999).optional(),
});

export const updateAdminStoryTemplateNodeSchema = z.object({
  nodeKey: z.string().trim().min(1).max(120).optional(),
  kind: storyTemplateNodeKindSchema.optional(),
  title: z.string().trim().min(1).max(180).optional(),
  narratorText: z.string().trim().min(1).max(4000).optional().nullable(),
  promptHint: z.string().trim().min(1).max(1000).optional().nullable(),
  sortOrder: z.number().int().min(0).max(9999).optional(),
});

export const createAdminStoryTemplateOptionSchema = z.object({
  nodeId: z.string().trim().min(1).max(120),
  optionKey: z.string().trim().min(1).max(120),
  label: z.string().trim().min(1).max(220),
  nextNodeId: z.string().trim().min(1).max(120),
  sortOrder: z.number().int().min(0).max(9999).optional(),
});

export const updateAdminStoryTemplateOptionSchema = z.object({
  optionKey: z.string().trim().min(1).max(120).optional(),
  label: z.string().trim().min(1).max(220).optional(),
  nextNodeId: z.string().trim().min(1).max(120).optional(),
  sortOrder: z.number().int().min(0).max(9999).optional(),
});

export const createModerationTermSchema = z.object({
  displayTerm: z.string().trim().min(1).max(120),
  policy: moderationPolicySchema,
  replacement: z.string().trim().min(1).max(120).optional().nullable(),
  scope: moderationScopeSchema,
  isActive: z.boolean().optional(),
});

export const updateModerationTermSchema = z.object({
  displayTerm: z.string().trim().min(1).max(120).optional(),
  policy: moderationPolicySchema.optional(),
  replacement: z.string().trim().min(1).max(120).optional().nullable(),
  scope: moderationScopeSchema.optional(),
  isActive: z.boolean().optional(),
});

export function parseBody<T>(schema: z.ZodSchema<T>, body: unknown) {
  return schema.parse(body);
}

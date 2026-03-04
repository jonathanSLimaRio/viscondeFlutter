import { z } from "zod";

const passwordSchema = z
  .string()
  .min(8, "A senha deve ter pelo menos 8 caracteres.")
  .max(128, "A senha deve ter no maximo 128 caracteres.");

const pinSchema = z.string().regex(/^\d{6}$/, "PIN deve conter 6 digitos.");
const storyModeSchema = z.enum(["PARENT_NARRATOR", "CHILD_CHOOSER"]);
const storyStatusSchema = z.enum(["DRAFT", "PUBLISHED", "ARCHIVED"]);
const storyStepKindSchema = z.enum(["NARRATION", "CHILD_CHOICE", "SYSTEM"]);
const catalogItemTypeSchema = z.enum(["SCENARIO", "CHARACTER", "SKIN", "AVATAR"]);
const uxEventNameSchema = z.enum([
  "session_started",
  "auth_error_shown",
  "auth_refresh_success",
  "auth_refresh_failed",
  "story_create_started",
  "story_create_step_completed",
  "story_create_abandoned",
  "story_published",
  "game_hub_opened",
  "game_home_opened",
  "adventure_resume_clicked",
  "avatar_editor_opened",
  "avatar_saved",
  "content_fallback_used",
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
  "vault_story_opened",
  "vault_story_open_failed",
  "vault_collection_actions_opened",
  "story_game_room_opened",
  "story_game_action_selected",
  "story_game_step_saved",
  "story_game_step_failed",
  "story_game_fallback_classic",
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
  avatarPresetKey: z.string().trim().min(1).max(40).optional(),
  avatarVariant: z.number().int().min(1).max(3).optional(),
  avatarAccent: z.string().trim().min(1).max(40).optional(),
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
  avatarPresetKey: z.string().trim().min(1).max(40).optional(),
  avatarVariant: z.number().int().min(1).max(3).optional(),
  avatarAccent: z.string().trim().min(1).max(40).optional(),
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
  role: z
    .preprocess(
      (value) => (value === null ? undefined : value),
      z.string().trim().min(1).max(80).optional()
    ),
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
    gameNodeIndex: z.number().int().min(1).max(12).optional(),
    gameAction: z
      .object({
        key: z.string().trim().min(1).max(80),
        label: z.string().trim().min(1).max(200),
      })
      .optional(),
    localEventId: z.string().trim().min(1).max(120),
  })
  .superRefine((value, context) => {
    if (value.kind === "NARRATION") {
      if (!value.narratorText && !value.narratorPrompt && !value.gameAction) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          message: "Etapa de narracao exige narratorText, narratorPrompt ou gameAction.",
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

export function parseBody<T>(schema: z.ZodSchema<T>, body: unknown) {
  return schema.parse(body);
}

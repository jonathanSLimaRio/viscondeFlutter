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

const optionalString = z
  .string()
  .trim()
  .min(1)
  .max(120)
  .optional()
  .nullable();

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

export const createStorySessionSchema = z.object({
  childProfileId: z.string().trim().min(1).max(120),
  titleDraft: z.string().trim().min(1).max(140),
  theme: z.string().trim().min(1).max(120),
  scenario: z.string().trim().min(1).max(160),
  characters: z
    .array(
      z.object({
        name: z.string().trim().min(1).max(80),
        role: z.string().trim().min(1).max(80).optional(),
      })
    )
    .min(1)
    .max(8),
  objective: z.string().trim().min(1).max(200),
  startMode: storyModeSchema.default("PARENT_NARRATOR"),
  virtueId: z.string().trim().min(1).max(120).optional(),
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

export const listStoriesQuerySchema = z.object({
  childProfileId: z.string().trim().min(1).max(120).optional(),
  status: storyStatusSchema.optional(),
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

export function parseBody<T>(schema: z.ZodSchema<T>, body: unknown) {
  return schema.parse(body);
}

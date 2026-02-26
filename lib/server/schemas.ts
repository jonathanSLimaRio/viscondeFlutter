import { z } from "zod";

const passwordSchema = z
  .string()
  .min(8, "A senha deve ter pelo menos 8 caracteres.")
  .max(128, "A senha deve ter no maximo 128 caracteres.");

const pinSchema = z.string().regex(/^\d{6}$/, "PIN deve conter 6 digitos.");

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

export function parseBody<T>(schema: z.ZodSchema<T>, body: unknown) {
  return schema.parse(body);
}

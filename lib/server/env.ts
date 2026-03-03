import { z } from "zod";

const envSchema = z
  .object({
    NODE_ENV: z.string().optional(),
    JWT_SECRET: z.string().min(32).optional(),
    NEXTAUTH_SECRET: z.string().min(32).optional(),
    ACCESS_TOKEN_TTL_MINUTES: z.coerce.number().int().positive().optional(),
    REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().optional(),
    PASSWORD_RESET_TTL_MINUTES: z.coerce.number().int().positive().optional(),
    APP_BASE_URL: z.string().url().optional(),

    GOOGLE_CLIENT_ID: z.string().min(1).optional(),
    GOOGLE_CLIENT_SECRET: z.string().min(1).optional(),
    APPLE_CLIENT_ID: z.string().min(1).optional(),
    APPLE_CLIENT_SECRET: z.string().min(1).optional(),

    WORDPRESS_URL: z.string().url().optional(),
    WORDPRESS_GRAPHQL_URL: z.string().url().optional(),
    WP_USER: z.string().min(1).optional(),
    WP_APP_PASS: z.string().min(1).optional(),

    RESEND_API_KEY: z.string().min(1).optional(),
    RESEND_FROM_EMAIL: z.string().email().optional(),

    OPENAI_API_KEY: z.string().min(1).optional(),
    OPENAI_IDEAS_MODEL: z.string().min(1).optional(),
    OPENAI_BASE_URL: z.string().url().optional(),
    UX_ANALYTICS_HASH_SALT: z.string().min(1).optional(),

    REALTIME_GATEWAY_PUBLIC_WS_URL: z.string().url().optional(),
    REALTIME_GATEWAY_INTERNAL_HTTP_URL: z.string().url().optional(),
    REALTIME_GATEWAY_INTERNAL_SECRET: z.string().min(1).optional(),
    REMOTE_PARTICIPANT_TOKEN_TTL_MINUTES: z.coerce.number().int().positive().optional(),
    REMOTE_JOIN_CODE_TTL_MINUTES: z.coerce.number().int().positive().optional(),
    WEBRTC_STUN_URLS: z.string().optional(),
    WEBRTC_TURN_URL: z.string().url().optional(),
    WEBRTC_TURN_USERNAME: z.string().min(1).optional(),
    WEBRTC_TURN_PASSWORD: z.string().min(1).optional(),
  })
  .passthrough();

const parsed = envSchema.safeParse(process.env);

const raw = parsed.success ? parsed.data : process.env;

const fallbackJwtSecret =
  raw.JWT_SECRET ??
  raw.NEXTAUTH_SECRET ??
  "dev-insecure-jwt-secret-change-me-in-production";

const isProduction = raw.NODE_ENV === "production";

function toPositiveInt(value: unknown, fallback: number) {
  const n = Number(value);
  if (Number.isInteger(n) && n > 0) {
    return n;
  }

  return fallback;
}

export const env = {
  isProduction,
  jwtSecret: fallbackJwtSecret,
  accessTokenTtlMinutes: toPositiveInt(raw.ACCESS_TOKEN_TTL_MINUTES, 15),
  refreshTokenTtlDays: toPositiveInt(raw.REFRESH_TOKEN_TTL_DAYS, 30),
  passwordResetTtlMinutes: toPositiveInt(raw.PASSWORD_RESET_TTL_MINUTES, 30),
  appBaseUrl: raw.APP_BASE_URL,

  googleClientId: raw.GOOGLE_CLIENT_ID,
  googleClientSecret: raw.GOOGLE_CLIENT_SECRET,
  appleClientId: raw.APPLE_CLIENT_ID,
  appleClientSecret: raw.APPLE_CLIENT_SECRET,

  wordpressUrl: raw.WORDPRESS_URL,
  wordpressGraphqlUrl: raw.WORDPRESS_GRAPHQL_URL,
  wpUser: raw.WP_USER,
  wpAppPass: raw.WP_APP_PASS,

  resendApiKey: raw.RESEND_API_KEY,
  resendFromEmail: raw.RESEND_FROM_EMAIL,

  openaiApiKey: raw.OPENAI_API_KEY,
  openaiIdeasModel: raw.OPENAI_IDEAS_MODEL ?? "gpt-4.1-mini",
  openaiBaseUrl: raw.OPENAI_BASE_URL ?? "https://api.openai.com/v1",
  uxAnalyticsHashSalt: raw.UX_ANALYTICS_HASH_SALT ?? fallbackJwtSecret,

  realtimeGatewayPublicWsUrl: raw.REALTIME_GATEWAY_PUBLIC_WS_URL,
  realtimeGatewayInternalHttpUrl: raw.REALTIME_GATEWAY_INTERNAL_HTTP_URL,
  realtimeGatewayInternalSecret: raw.REALTIME_GATEWAY_INTERNAL_SECRET,
  remoteParticipantTokenTtlMinutes: toPositiveInt(raw.REMOTE_PARTICIPANT_TOKEN_TTL_MINUTES, 240),
  remoteJoinCodeTtlMinutes: toPositiveInt(raw.REMOTE_JOIN_CODE_TTL_MINUTES, 15),
  webrtcStunUrls: (raw.WEBRTC_STUN_URLS ?? "stun:stun.l.google.com:19302")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean),
  webrtcTurnUrl: raw.WEBRTC_TURN_URL,
  webrtcTurnUsername: raw.WEBRTC_TURN_USERNAME,
  webrtcTurnPassword: raw.WEBRTC_TURN_PASSWORD,
};

export function assertRuntimeSecrets() {
  if (
    env.isProduction &&
    env.jwtSecret === "dev-insecure-jwt-secret-change-me-in-production"
  ) {
    throw new Error("JWT_SECRET ou NEXTAUTH_SECRET precisa ser definido em producao.");
  }
}

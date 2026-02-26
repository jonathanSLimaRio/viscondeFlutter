import { env } from "@/lib/server/env";

export async function sendPasswordResetEmail(input: {
  email: string;
  token: string;
}) {
  const resetUrl =
    env.appBaseUrl && input.token
      ? `${env.appBaseUrl.replace(/\/$/, "")}/reset-password?token=${encodeURIComponent(
          input.token
        )}`
      : null;

  if (env.resendApiKey && env.resendFromEmail) {
    await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: env.resendFromEmail,
        to: input.email,
        subject: "Redefinicao de senha",
        html: `<p>Use o link para redefinir sua senha:</p><p>${resetUrl ?? input.token}</p>`,
      }),
    });

    return;
  }

  // Fallback para MVP: loga token no servidor quando nenhum provider estiver configurado.
  console.info("[password-reset]", {
    email: input.email,
    token: input.token,
    resetUrl,
  });
}

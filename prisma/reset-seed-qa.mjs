import "dotenv/config";

import { spawnSync } from "node:child_process";

const CONFIRM_TOKEN = "RESET_VISCONDE";

function getDatabaseUrl() {
  return (
    process.env.PRISMA_DATABASE_URL ??
    process.env.DATABASE_URL ??
    process.env.POSTGRES_URL ??
    ""
  );
}

function maskDatabaseUrl(urlValue) {
  try {
    const parsed = new URL(urlValue);
    const protocol = parsed.protocol || "postgres://";
    const host = parsed.hostname || "unknown-host";
    const port = parsed.port ? `:${parsed.port}` : "";
    return `${protocol}//***:***@${host}${port}${parsed.pathname}`;
  } catch {
    return "***";
  }
}

function runStep(label, command, args) {
  console.log(`\n[db:reset:seed:qa] ${label}`);
  const result = spawnSync(command, args, {
    stdio: "inherit",
    cwd: process.cwd(),
    env: process.env,
  });

  if (result.error) {
    throw result.error;
  }

  if (typeof result.status === "number" && result.status !== 0) {
    throw new Error(`Falha em "${label}" (exit=${result.status}).`);
  }
}

async function main() {
  const databaseUrl = getDatabaseUrl();
  if (!databaseUrl) {
    throw new Error(
      "Database URL ausente. Defina PRISMA_DATABASE_URL, DATABASE_URL ou POSTGRES_URL."
    );
  }

  if (process.env.DB_RESET_CONFIRM !== CONFIRM_TOKEN) {
    throw new Error(
      `Reset bloqueado. Defina DB_RESET_CONFIRM=${CONFIRM_TOKEN} para continuar.`
    );
  }

  console.log(`[db:reset:seed:qa] Banco alvo: ${maskDatabaseUrl(databaseUrl)}`);
  console.log("[db:reset:seed:qa] Iniciando reset destrutivo + seed QA...");

  const prismaCmd = process.platform === "win32" ? "npx.cmd" : "npx";
  const nodeCmd = process.execPath;

  runStep("Prisma migrate reset", prismaCmd, [
    "prisma",
    "migrate",
    "reset",
    "--force",
  ]);
  runStep("Prisma generate", prismaCmd, ["prisma", "generate"]);
  runStep("Seed principal", nodeCmd, ["prisma/seed.mjs"]);
  runStep("Backfill gamification QA", nodeCmd, ["prisma/gamification-backfill.mjs"]);
  runStep("Verificacao de seed", nodeCmd, ["prisma/seed-verify.mjs"]);

  console.log("\n[db:reset:seed:qa] Concluido com sucesso.");
}

main().catch((error) => {
  console.error("[db:reset:seed:qa] Falha:", error);
  process.exitCode = 1;
});

import { env } from "@/lib/server/env";
import { ApiError } from "@/lib/server/errors";

function assertWordPressConfigured() {
  if (!env.wordpressUrl || !env.wpUser || !env.wpAppPass) {
    throw new ApiError(
      "Integracao WordPress nao configurada no backend.",
      500,
      "WORDPRESS_NOT_CONFIGURED"
    );
  }
}

function sanitizeFilename(name: string) {
  return name.replace(/[^a-zA-Z0-9._-]/g, "-");
}

export async function uploadFileToWordPress(input: {
  file: File;
  filenamePrefix: string;
}) {
  assertWordPressConfigured();

  const fileExt = input.file.name.split(".").pop() ?? "bin";
  const filename = sanitizeFilename(`${input.filenamePrefix}-${Date.now()}.${fileExt}`);
  const buffer = Buffer.from(await input.file.arrayBuffer());

  const response = await fetch(`${env.wordpressUrl}/wp-json/wp/v2/media`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${Buffer.from(`${env.wpUser}:${env.wpAppPass}`).toString("base64")}`,
      "Content-Type": input.file.type || "application/octet-stream",
      "Content-Disposition": `attachment; filename=\"${filename}\"`,
    },
    body: buffer,
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new ApiError(
      `Falha no upload para WordPress: ${errorText}`,
      502,
      "WORDPRESS_UPLOAD_FAILED"
    );
  }

  const data = (await response.json()) as {
    id?: number;
    source_url?: string;
    guid?: { rendered?: string };
  };

  return {
    mediaId: data.id ?? null,
    sourceUrl: data.source_url ?? data.guid?.rendered ?? null,
  };
}

import { NextResponse } from "next/server";
import { ZodError } from "zod";

import { ApiError, getErrorMessage } from "@/lib/server/errors";

export function ok<T>(data: T, status = 200) {
  return NextResponse.json(data, { status });
}

export function fail(message: string, status = 400, code = "BAD_REQUEST") {
  return NextResponse.json({ error: message, code }, { status });
}

export function handleRouteError(error: unknown) {
  if (error instanceof ZodError) {
    return NextResponse.json(
      {
        error: "Dados inválidos para esta operação.",
        code: "VALIDATION_ERROR",
        issues: error.issues.map((issue) => ({
          code: issue.code,
          path: issue.path.map(String).join("."),
          message: issue.message,
        })),
      },
      { status: 400 }
    );
  }

  if (error instanceof ApiError) {
    return fail(error.message, error.status, error.code);
  }

  return fail(getErrorMessage(error), 500, "INTERNAL_SERVER_ERROR");
}

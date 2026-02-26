import { NextResponse } from "next/server";

import { ApiError, getErrorMessage } from "@/lib/server/errors";

export function ok<T>(data: T, status = 200) {
  return NextResponse.json(data, { status });
}

export function fail(message: string, status = 400, code = "BAD_REQUEST") {
  return NextResponse.json({ error: message, code }, { status });
}

export function handleRouteError(error: unknown) {
  if (error instanceof ApiError) {
    return fail(error.message, error.status, error.code);
  }

  return fail(getErrorMessage(error), 500, "INTERNAL_SERVER_ERROR");
}

import { NextResponse } from "next/server";

export async function GET() {
  return NextResponse.json({
    status: "ok",
    service: "visconde-backend",
    timestamp: new Date().toISOString(),
  });
}

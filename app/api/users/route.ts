import { Prisma } from "@prisma/client";
import { NextResponse } from "next/server";

import { prisma } from "@/lib/prisma";

export const runtime = "nodejs";

export async function GET() {
  try {
    const users = await prisma.user.findMany({
      orderBy: { createdAt: "desc" },
    });

    return NextResponse.json(users);
  } catch {
    return NextResponse.json(
      { error: "Nao foi possivel listar usuarios." },
      { status: 500 }
    );
  }
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const email = typeof body?.email === "string" ? body.email.trim() : "";
    const name = typeof body?.name === "string" ? body.name.trim() : null;

    if (!email) {
      return NextResponse.json(
        { error: "Campo email e obrigatorio." },
        { status: 400 }
      );
    }

    const user = await prisma.user.create({
      data: {
        email,
        name: name || null,
      },
    });

    return NextResponse.json(user, { status: 201 });
  } catch (error) {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === "P2002"
    ) {
      return NextResponse.json(
        { error: "Email ja cadastrado." },
        { status: 409 }
      );
    }

    return NextResponse.json(
      { error: "Nao foi possivel criar usuario." },
      { status: 500 }
    );
  }
}

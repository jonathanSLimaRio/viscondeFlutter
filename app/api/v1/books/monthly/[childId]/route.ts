import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/app/api/auth/[...nextauth]/route";
import { createMonthlyBookProject } from "@/lib/server/book-service";
import { ApiError, handleApiError } from "@/lib/server/error";
import { z } from "zod";

const createBookSchema = z.object({
  monthStr: z.string().regex(/^\d{4}-\d{2}$/, "Invalid month format. Expected YYYY-MM"),
});

export async function POST(
  request: Request,
  { params }: { params: { childId: string } }
) {
  try {
    const session = await getServerSession(authOptions);

    if (!session?.user?.id) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const { childId } = params;
    const body = await request.json();
    const { monthStr } = createBookSchema.parse(body);

    const project = await createMonthlyBookProject(session.user.id, childId, monthStr);
    return NextResponse.json(project);

  } catch (error) {
    return handleApiError(error);
  }
}

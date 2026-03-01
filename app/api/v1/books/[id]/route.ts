import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/app/api/auth/[...nextauth]/route";
import { getBookProject } from "@/lib/server/book-service";
import { handleApiError } from "@/lib/server/error";

export async function GET(
  request: Request,
  { params }: { params: { id: string } }
) {
  try {
    const session = await getServerSession(authOptions);

    if (!session?.user?.id) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const { id } = params;

    const project = await getBookProject(session.user.id, id);
    return NextResponse.json(project);

  } catch (error) {
    return handleApiError(error);
  }
}

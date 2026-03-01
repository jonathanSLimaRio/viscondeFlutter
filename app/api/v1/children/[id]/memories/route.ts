import { NextResponse } from 'next/server';
import { getLatestStoryMemory } from '@/lib/server/inventory-service';
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';

export async function GET(
  req: Request,
  { params }: { params: { id: string } }
) {
  try {
    const session = await getServerSession(authOptions);
    const userId = (session?.user as any)?.id;
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const memory = await getLatestStoryMemory(params.id);
    return NextResponse.json(memory);
  } catch (error) {
    console.error('Error fetching memory:', error);
    return NextResponse.json(
      { error: 'Internal server error while fetching memory' },
      { status: 500 }
    );
  }
}

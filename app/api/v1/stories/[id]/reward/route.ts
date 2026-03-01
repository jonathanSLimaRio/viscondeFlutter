import { NextResponse } from 'next/server';
import { rewardRandomItem } from '@/lib/server/inventory-service';
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';

export async function POST(
  req: Request,
  { params }: { params: { id: string } }
) {
  try {
    const session = await getServerSession(authOptions);
    const userId = (session?.user as any)?.id;
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const reward = await rewardRandomItem(params.id);
    return NextResponse.json({ reward });
  } catch (error) {
    console.error('Error rewarding item:', error);
    return NextResponse.json(
      { error: 'Internal server error while processing reward' },
      { status: 500 }
    );
  }
}

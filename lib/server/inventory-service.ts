import { prisma } from '@/lib/prisma';
import { ApiError } from '@/lib/server/errors';
import { ItemCategory, RarityLevel } from '@prisma/client';

type InventorySeedItem = {
  key: string;
  name: string;
  description: string;
  rarity: RarityLevel;
  category: ItemCategory;
  icon: string;
  tags: string[];
};

export const INVENTORY_SEED_DATA: InventorySeedItem[] = [
  { key: 'escudo_papelao', name: 'Escudo de Papelão', description: 'Protege contra vilões imaginários.', rarity: RarityLevel.COMMON, category: ItemCategory.ITEM, icon: '🛡️', tags: ['coragem', 'protecao'] },
  { key: 'espada_madeira', name: 'Espada de Madeira', description: 'Uma espada leve e ágil.', rarity: RarityLevel.COMMON, category: ItemCategory.ITEM, icon: '🗡️', tags: ['coragem', 'aventura'] },
  { key: 'pocao_alegria', name: 'Poção da Alegria', description: 'Garante boas risadas.', rarity: RarityLevel.RARE, category: ItemCategory.ITEM, icon: '🧪', tags: ['alegria', 'magia'] },
  { key: 'mapa_tesouro', name: 'Mapa do Tesouro', description: 'Mostra o caminho para coisas legais.', rarity: RarityLevel.EPIC, category: ItemCategory.ITEM, icon: '🗺️', tags: ['curiosidade', 'exploracao'] },
  { key: 'bussola_dourada', name: 'Bússola Dourada', description: 'Sempre aponta para o caminho certo.', rarity: RarityLevel.LEGENDARY, category: ItemCategory.ITEM, icon: '🧭', tags: ['sabedoria', 'direcao'] },

  { key: 'coruja_sabia', name: 'Corujinha Sábia', description: 'Dá bons conselhos.', rarity: RarityLevel.RARE, category: ItemCategory.COMPANION, icon: '🦉', tags: ['sabedoria', 'companhia'] },
  { key: 'sapo_saltitante', name: 'Sapo Saltitante', description: 'Pula muito alto!', rarity: RarityLevel.COMMON, category: ItemCategory.COMPANION, icon: '🐸', tags: ['alegria', 'natureza'] },
  { key: 'fada_cores', name: 'Fadinha das Cores', description: 'Deixa tudo mais bonito.', rarity: RarityLevel.EPIC, category: ItemCategory.COMPANION, icon: '🧚', tags: ['criatividade', 'magia'] },
  { key: 'cachorro_leal', name: 'Cachorrinho Leal', description: 'O melhor amigo para a aventura.', rarity: RarityLevel.COMMON, category: ItemCategory.COMPANION, icon: '🐶', tags: ['lealdade', 'amizade'] },
];

export async function ensureInventorySeeded() {
  try {
    const count = await prisma.inventoryItem.count();
    if (count === 0) {
      await prisma.inventoryItem.createMany({
        data: INVENTORY_SEED_DATA.map(item => ({
          key: item.key,
          name: item.name,
          description: item.description,
          rarity: item.rarity,
          category: item.category,
          icon: item.icon,
          tags: item.tags,
        })),
        skipDuplicates: true,
      });
      console.log('Inventory items seeded successfully.');
    }
  } catch (error) {
    console.warn('Could not seed inventory (maybe DB needs push/generate)', error);
  }
}

async function requireOwnedChild(userId: string, childProfileId: string) {
  const child = await prisma.childProfile.findFirst({
    where: {
      id: childProfileId,
      userId,
      isArchived: false,
    },
    select: { id: true },
  });

  if (!child) {
    throw new ApiError('Perfil infantil nao encontrado.', 404, 'CHILD_NOT_FOUND');
  }
}

async function requireOwnedStory(userId: string, storyId: string) {
  const story = await prisma.story.findFirst({
    where: {
      id: storyId,
      userId,
    },
    select: { id: true, childProfileId: true },
  });

  if (!story) {
    throw new ApiError('Historia nao encontrada.', 404, 'STORY_NOT_FOUND');
  }

  return story;
}

export async function getChildInventory(userId: string, childProfileId: string) {
  // Try to seed first so that we have items available
  await ensureInventorySeeded();
  await requireOwnedChild(userId, childProfileId);

  const inventory = await prisma.childInventory.findMany({
    where: { childProfileId },
    include: { item: true },
    orderBy: { acquiredAt: 'desc' },
  });

  return inventory;
}

export async function getLatestStoryMemory(userId: string, childProfileId: string) {
  await requireOwnedChild(userId, childProfileId);

  const memory = await prisma.storyMemory.findFirst({
    where: { childProfileId },
    orderBy: { createdAt: 'desc' },
  });

  return memory;
}

export async function rewardRandomItem(userId: string, storyId: string) {
  await ensureInventorySeeded();

  // Find owned story to get the child profile.
  const story = await requireOwnedStory(userId, storyId);

  // Get all items not yet owned by the child
  const ownedInventories = await prisma.childInventory.findMany({
    where: { childProfileId: story.childProfileId },
    select: { itemId: true }
  });
  const ownedItemIds = ownedInventories.map(inv => inv.itemId);

  const availableItems = await prisma.inventoryItem.findMany({
    where: {
      id: { notIn: ownedItemIds }
    }
  });

  // If child has everything, no new reward, just return null or random duplicate
  if (availableItems.length === 0) {
    return null;
  }

  // Pick random item
  const randomIndex = Math.floor(Math.random() * availableItems.length);
  const selectedItem = availableItems[randomIndex];

  // Grant to child
  const childInventory = await prisma.childInventory.create({
    data: {
      childProfileId: story.childProfileId,
      itemId: selectedItem.id,
      qty: 1,
    },
    include: { item: true }
  });

  return childInventory;
}

export async function saveStoryMemory(
  storyId: string,
  childProfileId: string,
  summary: string,
  usedItems: string[],
  virtueLearned?: string
) {
  const memory = await prisma.storyMemory.upsert({
    where: {
      storyId_childProfileId: {
        storyId,
        childProfileId,
      }
    },
    update: {
      summary,
      usedItems,
      virtueLearned,
    },
    create: {
      storyId,
      childProfileId,
      summary,
      usedItems,
      virtueLearned,
    }
  });

  return memory;
}

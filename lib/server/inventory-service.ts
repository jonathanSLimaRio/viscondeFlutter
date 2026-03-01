// @ts-nocheck
import { z } from 'zod';
import { prisma } from '@/lib/prisma';
// @ts-ignore - Ignore type errors if Prisma Client hasn't been generated yet for the new models
import { RarityLevel, ItemCategory } from '@prisma/client';

export const INVENTORY_SEED_DATA = [
  { key: 'escudo_papelao', name: 'Escudo de Papelão', description: 'Protege contra vilões imaginários.', rarity: 'COMMON', category: 'ITEM', icon: '🛡️', tags: ['coragem', 'protecao'] },
  { key: 'espada_madeira', name: 'Espada de Madeira', description: 'Uma espada leve e ágil.', rarity: 'COMMON', category: 'ITEM', icon: '🗡️', tags: ['coragem', 'aventura'] },
  { key: 'pocao_alegria', name: 'Poção da Alegria', description: 'Garante boas risadas.', rarity: 'RARE', category: 'ITEM', icon: '🧪', tags: ['alegria', 'magia'] },
  { key: 'mapa_tesouro', name: 'Mapa do Tesouro', description: 'Mostra o caminho para coisas legais.', rarity: 'EPIC', category: 'ITEM', icon: '🗺️', tags: ['curiosidade', 'exploracao'] },
  { key: 'bussola_dourada', name: 'Bússola Dourada', description: 'Sempre aponta para o caminho certo.', rarity: 'LEGENDARY', category: 'ITEM', icon: '🧭', tags: ['sabedoria', 'direcao'] },

  { key: 'coruja_sabia', name: 'Corujinha Sábia', description: 'Dá bons conselhos.', rarity: 'RARE', category: 'COMPANION', icon: '🦉', tags: ['sabedoria', 'companhia'] },
  { key: 'sapo_saltitante', name: 'Sapo Saltitante', description: 'Pula muito alto!', rarity: 'COMMON', category: 'COMPANION', icon: '🐸', tags: ['alegria', 'natureza'] },
  { key: 'fada_cores', name: 'Fadinha das Cores', description: 'Deixa tudo mais bonito.', rarity: 'EPIC', category: 'COMPANION', icon: '🧚', tags: ['criatividade', 'magia'] },
  { key: 'cachorro_leal', name: 'Cachorrinho Leal', description: 'O melhor amigo para a aventura.', rarity: 'COMMON', category: 'COMPANION', icon: '🐶', tags: ['lealdade', 'amizade'] },
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
          rarity: item.rarity as any,
          category: item.category as any,
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

export async function getChildInventory(childProfileId: string) {
  // Try to seed first so that we have items available
  await ensureInventorySeeded();

  const inventory = await prisma.childInventory.findMany({
    where: { childProfileId },
    include: { item: true },
    orderBy: { acquiredAt: 'desc' },
  });

  return inventory;
}

export async function getLatestStoryMemory(childProfileId: string) {
  const memory = await prisma.storyMemory.findFirst({
    where: { childProfileId },
    orderBy: { createdAt: 'desc' },
  });

  return memory;
}

export async function rewardRandomItem(storyId: string) {
  await ensureInventorySeeded();

  // Find the story to get the child
  const story = await prisma.story.findUnique({
    where: { id: storyId },
    select: { id: true, childProfileId: true }
  });

  if (!story) throw new Error('Story not found');

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

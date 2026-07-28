import * as THREE from 'three';
import type { PenguinKit } from './penguin';
import { penguinFigure } from './penguin';
import type { HumanKit } from './human';
import { humanFigure } from './human';
import {
  buildCat, buildEmberDove, buildFernElk, buildHeron, buildMagpie, buildMossCat, buildSquirrel,
} from './critters';
import { freeze } from './figures';

/**
 * Who everybody is.
 *
 * The world file gives us 23 `NPCSpot`s and their `NpcId`s and nothing else —
 * every one of them was rendering as the same green capsule with a hat. The
 * reference sheets show two peoples living alongside each other plus the
 * creatures, so that is the split: penguins hold the firehouse and the water,
 * people hold the parks and the town, and the woods belong to the animals.
 */

/** Clan colours, off the icon key on the sheet. */
export const CLAN = {
  Wavecrest: '#3f7d8c',
  Frostbeak: '#b0cedb',
  Stonefloe: '#8a8478',
  Windwaddle: '#7d9a52',
  Sunflipper: '#d9a34a',
  Moonhollow: '#4c4d7d',
};

const LEATHER = '#6b5136';
const EMBER_CLOTH = '#c25b4e';   // brick red: firehouse colours without glowing

/** Pip. No hat — the bare silhouette is the character, and it has to read from
 *  behind at all times. The scarf is the only thing that marks him firehouse. */
export const PIP_KIT: PenguinKit = {
  scarf: EMBER_CLOTH,
  belt: LEATHER,
  satchel: '#7a5c3a',
};

export type CastEntry =
  | { kind: 'penguin'; name: string; verb?: string; kit: PenguinKit }
  | { kind: 'human'; name: string; verb?: string; kit: HumanKit }
  | { kind: 'critter'; name: string; verb?: string; build: () => THREE.Group;
      /** Stands in shallow water rather than on the bed beneath it. */
      wader?: boolean; scale?: number };

export const CAST: Record<string, CastEntry> = {
  // ---------------- penguins: the firehouse and the water ----------------
  Firefighter1: {
    kind: 'penguin', name: 'Captain Rosa',
    kit: { scarf: EMBER_CLOTH, hat: 'firehelm', hatColor: '#b5453c', belt: LEATHER, tool: 'hose', scale: 1.05 },
  },
  Firefighter2: {
    kind: 'penguin', name: 'Firefighter Jude',
    kit: { scarf: '#d9a34a', hat: 'firehelm', hatColor: '#8d949c', belt: LEATHER, tool: 'hammer' },
  },
  Firefighter3: {
    kind: 'penguin', name: 'Firefighter Kit',
    kit: { scarf: EMBER_CLOTH, hat: 'cap', hatColor: '#b5453c', satchel: '#7a5c3a', belt: LEATHER, scale: 0.92 },
  },
  SailorMoss: {
    kind: 'penguin', name: 'Old Moss',
    kit: { scarf: CLAN.Wavecrest, hat: 'straw', hatColor: '#c2a86a', tool: 'rod', belt: LEATHER, satchel: '#6b5136' },
  },
  OldSpan: {
    kind: 'penguin', name: 'Old Span',
    kit: {
      body: '#3a4048', crest: '#dfe3e8', cloak: '#3d5a6c', cloakTrim: '#c8a24a',
      hat: 'hood', hatColor: '#3d5a6c', tool: 'staff', scale: 1.12,
    },
  },
  Watchkeeper: {
    kind: 'penguin', name: 'The Watchkeeper',
    kit: {
      cloak: CLAN.Moonhollow, cloakTrim: '#8f8fc4', hat: 'hood', hatColor: CLAN.Moonhollow,
      tool: 'lantern', scale: 1.08,
    },
  },
  Sudsy: {
    kind: 'penguin', name: 'Sudsy',
    kit: { apron: '#cfe0dd', hat: 'cap', hatColor: CLAN.Windwaddle, belt: LEATHER, scarf: '#8fb8c4' },
  },

  // ---------------- people: the parks, the town, the woods' edge ----------------
  RangerMaple: {
    kind: 'human', name: 'Ranger Maple',
    kit: {
      tunic: '#5c7350', vest: '#47603f', cloak: '#3f5236', hood: true, belt: LEATHER,
      pack: '#6b5136', boots: '#3f3428', hair: '#8a5a34', hairStyle: 'bun', tool: 'bow',
    },
  },
  WardenBram: {
    kind: 'human', name: 'Warden Bram',
    kit: {
      tunic: '#4a5568', vest: '#3f5a7a', trim: '#c8a24a', cloak: '#2f4257', belt: LEATHER,
      boots: '#3a3229', hair: '#c9a86a', hairStyle: 'short', tool: 'shield', scale: 1.06,
    },
  },
  Picnicker: {
    kind: 'human', name: 'Theo',
    kit: {
      tunic: '#c8956a', vest: '#a8874e', trousers: '#5c5142', hat: 'wide', hatColor: '#a8874e',
      belt: LEATHER, hair: '#4a3626', tool: 'basket',
    },
  },
  Nora: {
    kind: 'human', name: 'Nora',
    kit: {
      skirt: '#efe7d2', tunic: '#e2d8bf', trim: '#3f5a7a', hair: '#cfc8bb', hairStyle: 'long',
      glasses: true, boots: '#6b5136', tool: 'book',
    },
  },
  Sam: {
    kind: 'human', name: 'Sam',
    kit: {
      tunic: '#8c4a3f', vest: '#6b4a52', trousers: '#4a4438', hair: '#3a2c22', hairStyle: 'curly',
      belt: LEATHER, boots: '#3f3428', tool: 'lute',
    },
  },
  GardenerFern: {
    kind: 'human', name: 'Gardener Fern',
    kit: {
      tunic: '#8a9a6a', apron: '#7d9a52', trousers: '#5c5142', hat: 'flowercrown',
      hair: '#6b4a34', hairStyle: 'bun', boots: '#5a4a38', tool: 'basket',
    },
  },
  BakerLena: {
    kind: 'human', name: 'Baker Lena',
    kit: {
      tunic: '#c8756a', apron: '#efe7d2', trousers: '#6b5a4a', hair: '#3a2c22', hairStyle: 'bun',
      belt: '#8a6a4a', boots: '#5a4a38', tool: 'basket',
    },
  },
  JunoKid: {
    kind: 'human', name: 'Juno',
    kit: {
      tunic: '#4a7d8c', trousers: '#4c4438', hair: '#3a2c22', hairStyle: 'short',
      boots: '#3f3428', scale: 0.72,
    },
  },
  BeeKid: {
    kind: 'human', name: 'Bee',
    kit: {
      tunic: '#d9a34a', trousers: '#5c5142', hair: '#6b4a34', hairStyle: 'curly',
      boots: '#3f3428', scale: 0.68,
    },
  },

  // ---------------- creatures ----------------
  AshCat: { kind: 'critter', name: 'Ash the Cat', verb: 'Rescue', build: buildCat },
  Mossmitt: { kind: 'critter', name: 'Mossmitt', build: buildMossCat },
  Marla: { kind: 'critter', name: 'Frantic Squirrel', build: buildSquirrel },
  Cindercoo: { kind: 'critter', name: 'Cindercoo', build: buildEmberDove },
  Glint: { kind: 'critter', name: 'Glint', build: buildMagpie },
  MistHeron: { kind: 'critter', name: 'The Mist Heron', build: buildHeron, wader: true },
  FernElk: { kind: 'critter', name: 'Sirelen', build: buildFernElk },
};

/** Build the figure for an NpcId, or a plain penguin for anyone unlisted. */
export function castFigure(id: string): { object: THREE.Group; entry: CastEntry } {
  const entry: CastEntry = CAST[id] ?? {
    kind: 'penguin', name: id, kit: { scarf: CLAN.Stonefloe },
  };
  let object: THREE.Group;
  if (entry.kind === 'penguin') object = penguinFigure(entry.kit, entry.name);
  else if (entry.kind === 'human') object = humanFigure(entry.kit, entry.name);
  else {
    object = freeze(entry.build(), entry.name);
    if (entry.scale) object.scale.setScalar(entry.scale);
  }
  return { object, entry };
}

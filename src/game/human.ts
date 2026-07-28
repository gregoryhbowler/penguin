import * as THREE from 'three';
import { G, dome, freeze, piece, ring, shell } from './figures';

/**
 * People.
 *
 * The human sheet is all about layers — a tunic under a jerkin under a cloak,
 * with a belt and a pack over the top — and about silhouette reading at a
 * glance: the Guardian is a shield, the Ranger is a hood, the Scholar is a long
 * pale robe, the Bard is a lute. So this builds in layers too, and every layer
 * is optional.
 *
 * They stand about 5.2 studs to Pip's 3.3, which is the right amount taller: he
 * has to look up at them without them towering.
 */

export type HumanHat = 'none' | 'wide' | 'cap' | 'headband' | 'flowercrown';
export type HumanTool =
  | 'none' | 'sword' | 'shield' | 'bow' | 'staff' | 'lute' | 'book' | 'spear'
  | 'flask' | 'basket' | 'axe';

export interface HumanKit {
  skin?: string;
  hair?: string;
  hairStyle?: 'short' | 'long' | 'bun' | 'curly' | 'bald';
  tunic?: string;
  /** Jerkin / vest / tabard worn over the tunic. */
  vest?: string;
  trim?: string;
  trousers?: string;
  boots?: string;
  cloak?: string;
  hood?: boolean;
  /** A fur mantle across the shoulders — the Nomad read. */
  fur?: string;
  belt?: string;
  pack?: string;
  apron?: string;
  /** A long robe or skirt in place of trousers. */
  skirt?: string;
  glasses?: boolean;
  hat?: HumanHat;
  hatColor?: string;
  tool?: HumanTool;
  toolColor?: string;
  scale?: number;
}

const SKIN = '#e0b291';
const HAIR = '#5a4230';

export function buildHuman(kit: HumanKit = {}): THREE.Group {
  const root = new THREE.Group();
  const skin = kit.skin ?? SKIN;
  const tunic = kit.tunic ?? '#6d7a5a';
  const trousers = kit.trousers ?? '#4c4438';
  const boots = kit.boots ?? '#3f3428';

  // ---- legs ----
  if (!kit.skirt) {
    for (const s of [-1, 1]) {
      piece(root, G.capsule, trousers, {
        pos: [s * 0.26, 1.46, 0], scale: [0.38, 0.95, 0.38], rough: 0.9,
      });
    }
  }
  for (const s of [-1, 1]) {
    piece(root, G.box, boots, {
      pos: [s * 0.26, 0.26, -0.06], scale: [0.42, 0.52, 0.66], rough: 0.75,
    });
  }
  if (kit.skirt) {
    piece(root, shell(0.6, 1.12, 2.4, 0), kit.skirt, {
      pos: [0, 1.72, 0], rough: 0.92, side: THREE.DoubleSide,
    });
  }

  // ---- torso ----
  piece(root, G.box, tunic, { pos: [0, 2.58, 0], scale: [0.88, 0.6, 0.58], rough: 0.9 });
  piece(root, G.box, tunic, { pos: [0, 3.45, 0], scale: [0.96, 1.5, 0.62], rough: 0.9 });
  if (kit.vest) {
    piece(root, G.box, kit.vest, { pos: [0, 3.62, 0], scale: [1.0, 1.2, 0.68], rough: 0.88 });
  }
  if (kit.trim) {
    piece(root, G.box, kit.trim, { pos: [0, 3.5, -0.33], scale: [0.22, 1.5, 0.06], rough: 0.85 });
  }
  if (kit.apron) {
    piece(root, G.box, kit.apron, { pos: [0, 2.66, -0.34], scale: [0.76, 1.85, 0.08], rough: 0.95 });
  }
  for (const s of [-1, 1]) {
    piece(root, G.ball, kit.vest ?? tunic, { pos: [s * 0.5, 4.06, 0], scale: 0.54, rough: 0.9 });
  }

  // ---- arms ----
  for (const s of [-1, 1]) {
    piece(root, G.capsule, tunic, {
      pos: [s * 0.62, 3.44, 0.02], rot: [0, 0, s * 0.07], scale: [0.28, 0.56, 0.28], rough: 0.9,
    });
    piece(root, G.ball, skin, { pos: [s * 0.68, 2.82, 0.04], scale: 0.32, rough: 0.75 });
  }

  // ---- head ----
  piece(root, G.cyl, skin, { pos: [0, 4.3, 0], scale: [0.26, 0.3, 0.26], rough: 0.75 });
  piece(root, G.sphere, skin, { pos: [0, 4.7, 0], scale: [0.84, 0.92, 0.84], rough: 0.75 });
  for (const s of [-1, 1]) {
    piece(root, G.ball, '#26282e', { pos: [s * 0.15, 4.74, -0.36], scale: 0.1, rough: 0.35, shadow: false });
  }
  piece(root, G.ball, skin, { pos: [0, 4.66, -0.4], scale: [0.12, 0.14, 0.12], rough: 0.75, shadow: false });

  const hair = kit.hair ?? HAIR;
  switch (kit.hairStyle ?? 'short') {
    case 'short':
      piece(root, dome(0.44, 0.5), hair, { pos: [0, 4.79, 0.02], rough: 0.9 });
      piece(root, G.box, hair, { pos: [0, 4.74, 0.3], scale: [0.66, 0.5, 0.24], rough: 0.9 });
      break;
    case 'long':
      piece(root, dome(0.44, 0.5), hair, { pos: [0, 4.79, 0.02], rough: 0.9 });
      piece(root, G.box, hair, { pos: [0, 4.3, 0.24], scale: [0.72, 1.1, 0.32], rough: 0.9 });
      break;
    case 'bun':
      piece(root, dome(0.44, 0.5), hair, { pos: [0, 4.79, 0.02], rough: 0.9 });
      piece(root, G.ball, hair, { pos: [0, 4.94, 0.34], scale: 0.44, rough: 0.9 });
      break;
    case 'curly':
      for (let i = 0; i < 8; i++) {
        const a = (i / 8) * Math.PI * 2;
        piece(root, G.ball, hair, {
          pos: [Math.sin(a) * 0.3, 4.94 + Math.cos(a * 3) * 0.06, Math.cos(a) * 0.3 + 0.06],
          scale: 0.4, rough: 0.92,
        });
      }
      break;
  }
  if (kit.glasses) {
    for (const s of [-1, 1]) {
      piece(root, ring(0.17, 0.028, 12), '#8a7a5e', {
        pos: [s * 0.16, 4.74, -0.37], rot: [Math.PI / 2, 0, 0],
        rough: 0.4, metal: 0.6, shadow: false,
      });
    }
  }

  // ---- outer layers ----
  if (kit.fur) {
    for (let i = 0; i < 10; i++) {
      const a = (i / 10) * Math.PI * 2;
      piece(root, G.ball, kit.fur, {
        pos: [Math.sin(a) * 0.56, 4.02 + Math.cos(a * 2) * 0.05, Math.cos(a) * 0.42],
        scale: 0.46, rough: 0.98,
      });
    }
  }
  if (kit.cloak) {
    piece(root, shell(0.66, 1.24, 2.7, 1.5), kit.cloak, {
      pos: [0, 2.82, 0.08], rough: 0.93, side: THREE.DoubleSide,
    });
    piece(root, ring(0.66, 0.13), kit.trim ?? kit.cloak, {
      pos: [0, 4.08, 0.08], rot: [Math.PI / 2, 0, 0], scale: [1, 1, 0.86], rough: 0.9,
    });
    if (kit.hood) {
      piece(root, new THREE.SphereGeometry(0.62, 16, 12, Math.PI * 0.3, Math.PI * 1.4, 0, Math.PI * 0.66), kit.cloak, {
        pos: [0, 4.68, 0.14], rough: 0.93, side: THREE.DoubleSide,
      });
    }
  }
  if (kit.belt) {
    piece(root, ring(0.5, 0.09), kit.belt, {
      pos: [0, 2.72, 0], rot: [Math.PI / 2, 0, 0], scale: [1, 1, 0.72], rough: 0.7,
    });
    piece(root, G.box, '#c8a24a', { pos: [0, 2.72, -0.32], scale: [0.24, 0.24, 0.1], rough: 0.4, metal: 0.65 });
  }
  if (kit.pack) {
    piece(root, G.box, kit.pack, { pos: [0, 3.6, 0.52], scale: [0.66, 0.8, 0.42], rough: 0.9 });
    piece(root, G.box, kit.pack, { pos: [0, 4.02, 0.52], scale: [0.7, 0.16, 0.46], rough: 0.9 });
  }

  buildHumanHat(root, kit);
  buildHumanTool(root, kit);

  if (kit.scale) root.scale.setScalar(kit.scale);
  return root;
}

function buildHumanHat(root: THREE.Group, kit: HumanKit) {
  const c = kit.hatColor ?? '#6b5136';
  switch (kit.hat) {
    case 'wide':
      piece(root, G.cone, c, { pos: [0, 5.02, 0], scale: [2.2, 0.34, 2.2], rough: 0.94 });
      piece(root, G.cyl, c, { pos: [0, 5.12, 0], scale: [0.86, 0.42, 0.86], rough: 0.94 });
      break;
    case 'cap':
      piece(root, dome(0.48, 0.55), c, { pos: [0, 4.7, 0], rough: 0.9 });
      piece(root, G.box, c, { pos: [0, 4.78, -0.44], rot: [0.14, 0, 0], scale: [0.62, 0.08, 0.4], rough: 0.9 });
      break;
    case 'headband':
      piece(root, ring(0.44, 0.07), c, { pos: [0, 4.86, 0], rot: [Math.PI / 2, 0, 0], rough: 0.9 });
      break;
    case 'flowercrown': {
      const petals = ['#e8879c', '#f4ead6', '#e8c15c'];
      for (let i = 0; i < 8; i++) {
        const a = (i / 8) * Math.PI * 2;
        piece(root, G.ball, petals[i % 3], {
          pos: [Math.sin(a) * 0.4, 4.94, Math.cos(a) * 0.4], scale: 0.18, rough: 0.9,
        });
      }
      break;
    }
  }
}

function buildHumanTool(root: THREE.Group, kit: HumanKit) {
  const c = kit.toolColor ?? '#7a5c3a';
  switch (kit.tool) {
    case 'sword':
      piece(root, G.box, '#b8c0c6', { pos: [0.82, 3.5, 0.06], rot: [0, 0, 0.08], scale: [0.12, 2.1, 0.28], rough: 0.28, metal: 0.85 });
      piece(root, G.box, '#c8a24a', { pos: [0.8, 2.5, 0.06], scale: [0.6, 0.14, 0.2], rough: 0.4, metal: 0.7 });
      piece(root, G.cyl, '#4a3a2a', { pos: [0.79, 2.25, 0.06], scale: [0.12, 0.5, 0.12], rough: 0.85 });
      break;
    case 'shield':
      piece(root, G.box, c, { pos: [-0.86, 3.4, -0.12], rot: [0, 0.25, -0.06], scale: [0.14, 1.7, 1.15], rough: 0.5, metal: 0.35 });
      piece(root, G.ball, '#c8a24a', { pos: [-0.96, 3.45, -0.16], scale: 0.42, rough: 0.35, metal: 0.7 });
      break;
    case 'bow':
      piece(root, new THREE.TorusGeometry(0.95, 0.07, 6, 18, Math.PI * 1.1), c, {
        pos: [-0.82, 3.5, 0.1], rot: [0, Math.PI / 2, -0.5], rough: 0.85,
      });
      break;
    case 'spear':
      piece(root, G.cyl, c, { pos: [0.82, 3.2, 0.08], rot: [0, 0, -0.06], scale: [0.11, 5.4, 0.11], rough: 0.88 });
      piece(root, G.cone, '#b8c0c6', { pos: [0.66, 5.95, 0.08], scale: [0.28, 0.7, 0.28], rough: 0.3, metal: 0.8 });
      break;
    case 'staff':
      piece(root, G.cyl, c, { pos: [0.82, 3.1, 0.08], rot: [0, 0, -0.05], scale: [0.13, 5.0, 0.13], rough: 0.88 });
      piece(root, G.ball, '#cfe6ee', { pos: [0.75, 5.7, 0.08], scale: 0.44, rough: 0.25, glow: 0.5 });
      break;
    case 'lute':
      piece(root, G.sphere, c, { pos: [0.3, 3.1, -0.5], rot: [0.2, 0, -0.4], scale: [1.1, 1.25, 0.62], rough: 0.6 });
      piece(root, G.box, '#4a3a2a', { pos: [-0.35, 3.85, -0.6], rot: [0.2, 0, -0.4], scale: [0.18, 1.7, 0.12], rough: 0.7 });
      piece(root, G.ball, '#2a2018', { pos: [0.32, 3.14, -0.78], scale: [0.3, 0.3, 0.1], rough: 0.9, shadow: false });
      break;
    case 'book':
      piece(root, G.box, c, { pos: [0, 3.0, -0.5], rot: [-0.35, 0, 0], scale: [0.8, 0.16, 0.6], rough: 0.85 });
      piece(root, G.box, '#efe7d2', { pos: [0, 3.04, -0.52], rot: [-0.35, 0, 0], scale: [0.74, 0.1, 0.55], rough: 0.95 });
      break;
    case 'flask':
      piece(root, G.sphere, '#cfe6ee', { pos: [0.72, 2.95, -0.24], scale: [0.42, 0.46, 0.42], rough: 0.15, opacity: 0.7 });
      piece(root, G.ball, '#8ec87a', { pos: [0.72, 2.9, -0.24], scale: 0.3, glow: 0.9, rough: 0.2 });
      break;
    case 'axe':
      piece(root, G.cyl, c, { pos: [0.82, 3.0, 0.08], rot: [0, 0, -0.06], scale: [0.13, 3.2, 0.13], rough: 0.88 });
      piece(root, G.box, '#8d949c', { pos: [0.68, 4.3, 0.08], rot: [0, 0, 0.2], scale: [0.16, 0.7, 0.55], rough: 0.35, metal: 0.8 });
      break;
    case 'basket':
      piece(root, new THREE.CylinderGeometry(0.46, 0.36, 0.62, 12, 1, true), '#a8874e', {
        pos: [0.74, 2.72, -0.2], rough: 0.95, side: THREE.DoubleSide,
      });
      piece(root, G.ball, '#c9d68f', { pos: [0.74, 2.94, -0.2], scale: [0.74, 0.32, 0.74], rough: 0.9 });
      break;
  }
}

/** A dressed person, collapsed to a couple of draw calls. */
export function humanFigure(kit: HumanKit, name = 'Human'): THREE.Group {
  const out = freeze(buildHuman(kit), name);
  if (kit.scale) out.scale.setScalar(kit.scale); // freeze() bakes the root scale away
  return out;
}

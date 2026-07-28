import * as THREE from 'three';
import { G, dome, freeze, piece } from './figures';

/**
 * The animals.
 *
 * Half the cast isn't a person at all — a cat tangled in a tent, a frantic
 * squirrel, an ember-lit dove on a rooftop, a heron standing in the river, and
 * Sirelen, the elk of the Whispering Woods. The beast sheet is the guide here:
 * calm faces, natural silhouettes, and a cool glow on anything touched by
 * spirit. Nothing in the world glows warm except fire, so a spirit creature
 * that IS fire (Cindercoo) is allowed to break that rule and nothing else is.
 */

const _ = (g: THREE.Group) => g;

/** Ash — the cat from the collapsed tent. */
export function buildCat(coat = '#7e7c84', eye = '#8ec87a'): THREE.Group {
  const g = new THREE.Group();
  piece(g, G.sphere, coat, { pos: [0, 0.85, 0], scale: [1.53, 1.26, 2.16], rough: 0.85 });
  piece(g, G.sphere, coat, { pos: [0, 1.6, -0.85], scale: [1.1, 1.1, 1.1], rough: 0.85 });
  // Tail, curled up and over — the line that makes a lump of spheres a cat.
  for (let i = 0; i < 6; i++) {
    const t = i / 5;
    piece(g, G.ball, coat, {
      pos: [0, 0.95 + Math.sin(t * 2.2) * 0.72, 1.1 + t * 0.72],
      scale: 0.4 - t * 0.12, rough: 0.85,
    });
  }
  for (const s of [-1, 1]) {
    piece(g, G.cone, coat, { pos: [s * 0.25, 2.05, -0.85], scale: [0.34, 0.4, 0.34], rough: 0.85 });
    piece(g, G.ball, eye, { pos: [s * 0.2, 1.68, -1.3], scale: 0.18, rough: 0.3, shadow: false });
    // legs
    piece(g, G.cyl, coat, { pos: [s * 0.42, 0.28, -0.5], scale: [0.26, 0.56, 0.26], rough: 0.85 });
    piece(g, G.cyl, coat, { pos: [s * 0.42, 0.28, 0.62], scale: [0.26, 0.56, 0.26], rough: 0.85 });
  }
  piece(g, G.ball, '#d98a94', { pos: [0, 1.5, -1.4], scale: 0.14, rough: 0.6, shadow: false });
  return g;
}

/** Mossmitt — a cat the woods have been quietly reclaiming. */
export function buildMossCat(): THREE.Group {
  const g = buildCat('#6d7566', '#c9e08a');
  for (let i = 0; i < 9; i++) {
    const a = (i / 9) * Math.PI * 2;
    piece(g, G.ball, i % 3 ? '#5f7d43' : '#7d9a52', {
      pos: [Math.sin(a) * 0.55, 1.35 + Math.cos(a * 2) * 0.3, Math.cos(a) * 0.9],
      scale: 0.38, rough: 0.96,
    });
  }
  // Two little caps, because a mossy cat should be growing something.
  for (const s of [-1, 1]) {
    piece(g, G.cyl, '#e8dcc4', { pos: [s * 0.34, 1.62, 0.35], scale: [0.1, 0.28, 0.1], rough: 0.9 });
    piece(g, dome(0.24, 0.5), '#c8756a', { pos: [s * 0.34, 1.74, 0.35], rough: 0.85 });
  }
  return g;
}

/** Marla — the frantic squirrel. */
export function buildSquirrel(): THREE.Group {
  const g = new THREE.Group();
  const fur = '#a86a3c';
  piece(g, G.sphere, fur, { pos: [0, 0.62, 0], scale: [0.86, 1.0, 0.78], rough: 0.9 });
  piece(g, G.sphere, '#e8d5b8', { pos: [0, 0.56, -0.28], scale: [0.55, 0.66, 0.4], rough: 0.9 });
  piece(g, G.sphere, fur, { pos: [0, 1.16, -0.16], scale: [0.62, 0.6, 0.6], rough: 0.9 });
  piece(g, G.cone, '#c8845a', { pos: [0, 1.08, -0.5], rot: [-Math.PI / 2, 0, 0], scale: [0.16, 0.24, 0.16], rough: 0.7 });
  for (const s of [-1, 1]) {
    piece(g, G.ball, fur, { pos: [s * 0.22, 1.44, -0.14], scale: 0.24, rough: 0.9 });
    piece(g, G.ball, '#1c1a18', { pos: [s * 0.18, 1.2, -0.44], scale: 0.11, rough: 0.3, shadow: false });
    piece(g, G.cyl, fur, { pos: [s * 0.24, 0.14, -0.08], scale: [0.16, 0.3, 0.16], rough: 0.9 });
  }
  // The tail is the whole animal.
  for (let i = 0; i < 7; i++) {
    const t = i / 6;
    piece(g, G.ball, i % 2 ? fur : '#c08050', {
      pos: [0, 0.5 + t * 1.5, 0.42 + Math.sin(t * 2.4) * 0.5],
      scale: 0.5 + Math.sin(t * 3) * 0.14, rough: 0.95,
    });
  }
  return g;
}

/** A small bird, used for the ember dove and the frost magpie. */
function buildBird(body: string, wing: string, beak: string, glow?: string): THREE.Group {
  const g = new THREE.Group();
  piece(g, G.sphere, body, { pos: [0, 0.7, 0], scale: [0.72, 0.8, 0.98], rough: 0.85 });
  piece(g, G.sphere, body, { pos: [0, 1.24, -0.3], scale: [0.5, 0.5, 0.5], rough: 0.85 });
  piece(g, G.cone, beak, { pos: [0, 1.2, -0.58], rot: [-Math.PI / 2, 0, 0], scale: [0.12, 0.28, 0.12], rough: 0.6 });
  for (const s of [-1, 1]) {
    piece(g, G.sphere, wing, {
      pos: [s * 0.34, 0.74, 0.04], rot: [0, 0, s * 0.2], scale: [0.16, 0.56, 0.84], rough: 0.88,
    });
    piece(g, G.ball, '#16181c', { pos: [s * 0.17, 1.3, -0.44], scale: 0.1, rough: 0.3, shadow: false });
    piece(g, G.cyl, beak, { pos: [s * 0.16, 0.16, -0.06], scale: [0.08, 0.32, 0.08], rough: 0.7 });
  }
  piece(g, G.cone, wing, { pos: [0, 0.72, 0.68], rot: [1.35, 0, 0], scale: [0.44, 0.7, 0.2], rough: 0.88 });
  if (glow) {
    piece(g, G.ball, glow, { pos: [0, 0.66, -0.42], scale: 0.34, glow: 1.6, rough: 0.2, shadow: false });
  }
  return g;
}

/** Cindercoo — an ember spirit wearing the shape of a rooftop dove. */
export function buildEmberDove(): THREE.Group {
  const g = buildBird('#6b5a5e', '#4e4247', '#d9a05a', '#ff9645');
  for (let i = 0; i < 5; i++) {
    const a = (i / 5) * Math.PI * 2;
    piece(g, G.ball, '#ffb765', {
      pos: [Math.sin(a) * 0.5, 1.5 + Math.cos(a * 2) * 0.16, Math.cos(a) * 0.4],
      scale: 0.13, glow: 2.0, rough: 0.2, shadow: false,
    });
  }
  return g;
}

/** Glint — a frostfell magpie with something bright in its beak. */
export function buildMagpie(): THREE.Group {
  const g = buildBird('#e8eef2', '#2f3944', '#3f4954');
  piece(g, G.ball, '#9ad9e8', { pos: [0, 1.2, -0.76], scale: 0.22, glow: 1.4, rough: 0.15, shadow: false });
  return g;
}

/** The Mist Heron — tall, still, standing in the shallows. */
export function buildHeron(): THREE.Group {
  const g = new THREE.Group();
  const pale = '#b9c9cf';
  for (const s of [-1, 1]) {
    piece(g, G.cyl, '#8a949a', { pos: [s * 0.22, 1.15, 0], scale: [0.13, 2.3, 0.13], rough: 0.8 });
    piece(g, G.box, '#8a949a', { pos: [s * 0.22, 0.05, -0.16], scale: [0.24, 0.1, 0.5], rough: 0.8 });
  }
  piece(g, G.sphere, pale, { pos: [0, 2.6, 0.05], scale: [0.9, 1.0, 1.7], rough: 0.86 });
  for (const s of [-1, 1]) {
    piece(g, G.sphere, '#94a6ae', {
      pos: [s * 0.42, 2.6, 0.1], rot: [0, 0, s * 0.12], scale: [0.16, 0.72, 1.5], rough: 0.88,
    });
  }
  // Long S-curve neck.
  for (let i = 0; i < 6; i++) {
    const t = i / 5;
    piece(g, G.ball, pale, {
      pos: [0, 3.0 + t * 1.5, -0.5 + Math.sin(t * 3.0) * 0.42 - t * 0.15],
      scale: 0.38 - t * 0.08, rough: 0.86,
    });
  }
  piece(g, G.sphere, pale, { pos: [0, 4.6, -0.72], scale: [0.42, 0.42, 0.6], rough: 0.86 });
  piece(g, G.cone, '#e0c268', { pos: [0, 4.56, -1.28], rot: [-Math.PI / 2, 0, 0], scale: [0.13, 0.9, 0.13], rough: 0.6 });
  for (const s of [-1, 1]) {
    piece(g, G.ball, '#1c1e22', { pos: [s * 0.16, 4.66, -0.92], scale: 0.1, rough: 0.3, shadow: false });
  }
  piece(g, G.box, '#3d4a52', { pos: [0, 4.72, -0.38], rot: [0.5, 0, 0], scale: [0.06, 0.5, 0.1], rough: 0.9 });
  return g;
}

/**
 * Sirelen, the Fern Elk — the woods' own guardian. Deliberately the largest
 * character you can walk up to, and the only one whose antlers are a garden.
 */
export function buildFernElk(): THREE.Group {
  const g = new THREE.Group();
  const hide = '#6e6558';
  const pale = '#9a9284';
  const horn = '#9a9080';

  // Legs. Thin ones turned the whole animal into a lightbulb on stilts — an
  // elk this size needs a limb you could believe carries it.
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    const z = sz < 0 ? -2.1 : 2.3;
    piece(g, G.cyl, hide, { pos: [sx * 0.95, 2.5, z], scale: [0.62, 2.6, 0.62], rough: 0.9 });
    piece(g, G.ball, hide, { pos: [sx * 0.95, 1.6, z + sz * 0.05], scale: 0.62, rough: 0.9 });
    piece(g, G.cyl, hide, { pos: [sx * 0.95, 0.85, z + sz * 0.1], scale: [0.46, 1.6, 0.46], rough: 0.9 });
    piece(g, G.box, '#3a352e', { pos: [sx * 0.95, 0.16, z + sz * 0.1 - 0.08], scale: [0.48, 0.34, 0.66], rough: 0.7 });
  }

  // Barrel, chest and rump as three overlapping masses rather than one sphere.
  piece(g, G.sphere, hide, { pos: [0, 4.9, 0], scale: [2.6, 2.7, 6.0], rough: 0.9 });
  piece(g, G.sphere, hide, { pos: [0, 5.05, 1.9], scale: [2.5, 2.5, 3.0], rough: 0.9 });
  piece(g, G.sphere, hide, { pos: [0, 4.75, -2.1], scale: [2.5, 2.7, 2.8], rough: 0.9 });
  piece(g, G.sphere, pale, { pos: [0, 3.95, -0.1], scale: [2.0, 1.3, 4.8], rough: 0.9 });
  piece(g, G.cone, hide, { pos: [0, 5.0, 3.1], rot: [-2.5, 0, 0], scale: [0.4, 1.2, 0.4], rough: 0.9 });

  // Neck: short, thick and angled forward. A long vertical one reads llama.
  for (let i = 0; i < 5; i++) {
    const t = i / 4;
    piece(g, G.ball, hide, {
      pos: [0, 5.8 + t * 1.25, -2.5 - t * 1.6],
      scale: 1.85 - t * 0.5, rough: 0.9,
    });
  }

  // Head, muzzle and eyes. Big enough to carry the antlers.
  const hy = 7.3;
  const hz = -4.5;
  piece(g, G.sphere, hide, { pos: [0, hy, hz], scale: [1.3, 1.35, 2.4], rough: 0.9 });
  piece(g, G.sphere, hide, { pos: [0, hy - 0.34, hz - 1.05], scale: [0.98, 0.92, 1.3], rough: 0.9 });
  piece(g, G.sphere, pale, { pos: [0, hy - 0.5, hz - 1.35], scale: [0.78, 0.62, 0.72], rough: 0.9 });
  piece(g, G.ball, '#2a2620', { pos: [0, hy - 0.52, hz - 1.62], scale: 0.34, rough: 0.5, shadow: false });
  for (const s of [-1, 1]) {
    piece(g, G.ball, '#e8f0d8', { pos: [s * 0.52, hy + 0.24, hz - 0.62], scale: 0.26, glow: 0.5, rough: 0.3, shadow: false });
    piece(g, G.cone, hide, { pos: [s * 0.72, hy + 0.68, hz + 0.55], rot: [-0.3, 0, s * 0.7], scale: [0.36, 0.85, 0.36], rough: 0.9 });

    // Antlers. Rooted ON the head and swept up and back, with a garden in
    // them — the whole point of the character.
    let x = s * 0.5, y = hy + 0.85, z = hz + 0.25;
    for (let i = 0; i < 4; i++) {
      const nx = x + s * 0.46;
      const ny = y + 0.86;
      const nz = z + 0.52;
      piece(g, G.cyl, horn, {
        pos: [(x + nx) / 2, (y + ny) / 2, (z + nz) / 2],
        rot: [Math.atan2(nz - z, ny - y), 0, -Math.atan2(nx - x, ny - y)],
        scale: [0.26, 1.2, 0.26], rough: 0.88,
      });
      // A tine off each fork, reaching up and forward rather than sideways.
      piece(g, G.cyl, horn, {
        pos: [nx + s * 0.14, ny + 0.44, nz - 0.34],
        rot: [-0.55, 0, s * 0.25], scale: [0.15, 0.85, 0.15], rough: 0.88,
      });
      piece(g, G.ball, i % 2 ? '#5f7d43' : '#7d9a52', { pos: [nx, ny + 0.24, nz], scale: 0.9, rough: 0.95 });
      if (i % 2) {
        piece(g, G.ball, '#e8dcc4', { pos: [nx + s * 0.3, ny + 0.52, nz - 0.3], scale: 0.28, rough: 0.9, shadow: false });
      }
      x = nx; y = ny; z = nz;
    }
  }
  return g;
}

/**
 * Kodama. The world file tags eight `ShySpot`s, seven of them `Style: kodama`,
 * and nothing had ever read them. They are the cheapest wonder in the game:
 * a pale head, three dark holes, and the good manners to look at you.
 */
export function buildKodama(): THREE.Group {
  const g = new THREE.Group();
  const pale = '#e9ecdf';
  piece(g, G.sphere, pale, { pos: [0, 1.05, 0], scale: [0.86, 0.92, 0.86], rough: 0.92 });
  piece(g, G.capsule, pale, { pos: [0, 0.42, 0], scale: [0.26, 0.3, 0.26], rough: 0.92 });
  for (const s of [-1, 1]) {
    piece(g, G.ball, pale, { pos: [s * 0.3, 0.5, 0], rot: [0, 0, s * 0.5], scale: [0.14, 0.34, 0.14], rough: 0.92 });
    piece(g, G.ball, '#2b2f36', { pos: [s * 0.19, 1.12, -0.36], scale: 0.15, rough: 0.4, shadow: false });
  }
  piece(g, G.ball, '#2b2f36', { pos: [0, 0.92, -0.38], scale: [0.14, 0.18, 0.14], rough: 0.4, shadow: false });
  return g;
}

export const critterFigure = (build: () => THREE.Group, name: string) => freeze(_(build()), name);

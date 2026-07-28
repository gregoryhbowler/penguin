import * as THREE from 'three';
import { G, dome, freeze, piece, ring, shell } from './figures';

/**
 * Penguins.
 *
 * Built from primitives like the Roblox rig — the chunky silhouette IS the
 * character — but everything above the body is a *kit*. The clan sheet reads as
 * one species doing many jobs: the Fisher is a straw hat and a rod, the Elder is
 * a robe and a staff, the Blacksmith is goggles and an apron. So the body is
 * fixed and the costume is data, which is what lets a whole clan exist without a
 * whole clan's worth of code.
 */

export type Hat =
  | 'none' | 'straw' | 'flowers' | 'firehelm' | 'cap' | 'hood' | 'goggles' | 'woolly';
export type Tool =
  | 'none' | 'rod' | 'staff' | 'hammer' | 'lantern' | 'basket' | 'hose';

export interface PenguinKit {
  /** Back, head and flippers. */
  body?: string;
  belly?: string;
  beak?: string;
  /** A rockhopper-ish tuft. */
  crest?: string;
  scarf?: string;
  hat?: Hat;
  hatColor?: string;
  /** A robe or cape over the shoulders. */
  cloak?: string;
  cloakTrim?: string;
  apron?: string;
  belt?: string;
  satchel?: string;
  tool?: Tool;
  toolColor?: string;
  /** Elders and spirits run a little bigger or smaller. */
  scale?: number;
}

const BLACK = '#2b2f36';
const WHITE = '#f2ece1';
const BEAK = '#e8a33d';
const LEATHER = '#6b5136';

export interface PenguinRig {
  root: THREE.Group;
  body: THREE.Mesh;
  head: THREE.Group;
  flipperL: THREE.Mesh;
  flipperR: THREE.Mesh;
  footL: THREE.Mesh;
  footR: THREE.Mesh;
}

export function buildPenguin(kit: PenguinKit = {}): PenguinRig {
  const root = new THREE.Group();
  const skin = kit.body ?? BLACK;
  const belly = kit.belly ?? WHITE;
  const beakCol = kit.beak ?? BEAK;

  // ---- body: egg-shaped, slightly squashed ----
  const body = piece(root, G.sphere, skin, {
    pos: [0, 1.25, 0], scale: [1.84, 2.36, 1.72], rough: 0.72,
  });
  piece(root, G.sphere, belly, {
    pos: [0, 1.2, -0.35], scale: [1.4, 1.9, 1.2], rough: 0.8,
  });

  // ---- head ----
  const head = new THREE.Group();
  head.position.y = 2.5;
  root.add(head);
  piece(head, G.sphere, skin, { scale: [1.44, 1.37, 1.37], rough: 0.72 });
  piece(head, G.sphere, belly, { pos: [0, -0.04, -0.42], scale: [0.96, 1.02, 0.6], rough: 0.8 });
  piece(head, G.cone, beakCol, {
    pos: [0, -0.06, -0.78], rot: [-Math.PI / 2, 0, 0], scale: [0.34, 0.44, 0.34], rough: 0.55,
  });
  for (const s of [-1, 1]) {
    piece(head, G.ball, '#15171c', { pos: [s * 0.25, 0.12, -0.6], scale: 0.2, rough: 0.35 });
    piece(head, G.ball, '#ffffff', { pos: [s * 0.28, 0.17, -0.66], scale: 0.064, rough: 0.3, shadow: false });
  }
  if (kit.crest) {
    for (let i = 0; i < 5; i++) {
      const a = (i / 4 - 0.5) * 1.5;
      piece(head, G.cone, kit.crest, {
        pos: [Math.sin(a) * 0.42, 0.6, Math.cos(a) * 0.2 - 0.18],
        rot: [-0.5, a, 0], scale: [0.16, 0.5, 0.16], rough: 0.85,
      });
    }
  }

  // ---- flippers ----
  const flipperL = piece(root, G.sphere, skin, {
    pos: [-0.88, 1.35, 0], scale: [0.2, 0.95, 0.5], rough: 0.72,
  });
  const flipperR = piece(root, G.sphere, skin, {
    pos: [0.88, 1.35, 0], scale: [0.2, 0.95, 0.5], rough: 0.72,
  });

  // ---- feet ----
  const footL = piece(root, G.sphere, beakCol, {
    pos: [-0.34, 0.16, -0.16], scale: [0.44, 0.24, 0.76], rough: 0.6,
  });
  const footR = piece(root, G.sphere, beakCol, {
    pos: [0.34, 0.16, -0.16], scale: [0.44, 0.24, 0.76], rough: 0.6,
  });

  // ---- costume ----
  if (kit.cloak) {
    piece(root, shell(0.95, 1.5, 1.95, 1.7), kit.cloak, {
      pos: [0, 1.32, 0.06], rough: 0.9, side: THREE.DoubleSide,
    });
    // A collar closes the top of the cone, which otherwise reads as a bucket.
    piece(root, ring(0.7, 0.15), kit.cloakTrim ?? kit.cloak, {
      pos: [0, 2.18, 0.06], rot: [Math.PI / 2, 0, 0], scale: [1, 1, 1.35], rough: 0.9,
    });
    if (kit.cloakTrim) {
      piece(root, shell(1.46, 1.5, 0.26, 1.7), kit.cloakTrim, {
        pos: [0, 0.44, 0.06], rough: 0.85, side: THREE.DoubleSide,
      });
    }
  }
  if (kit.apron) {
    piece(root, G.box, kit.apron, {
      pos: [0, 1.12, -0.82], scale: [1.24, 1.5, 0.12], rough: 0.95,
    });
    piece(root, G.box, kit.apron, {
      pos: [0, 1.95, -0.72], scale: [0.72, 0.5, 0.1], rough: 0.95,
    });
  }
  if (kit.belt) {
    // On the hips, BELOW the flippers. At 1.02 the ring ran straight through
    // both of them at the exact height they hang, and Pip looked pinned.
    piece(root, ring(0.85, 0.1), kit.belt, {
      pos: [0, 0.74, 0], rot: [Math.PI / 2, 0, 0], scale: [1, 1, 0.94], rough: 0.7,
    });
    piece(root, G.box, '#c8a24a', {
      pos: [0, 0.74, -0.8], scale: [0.3, 0.3, 0.14], rough: 0.45, metal: 0.6,
    });
  }
  if (kit.satchel) {
    // Hung on the hip behind the flipper, not through it. No shoulder strap:
    // a straight band across a body this round can't be made to lie on it, and
    // the two that were here read as sticks pushed into his back.
    piece(root, G.box, kit.satchel, {
      pos: [0.88, 0.72, 0.38], rot: [0, -0.25, 0], scale: [0.5, 0.52, 0.42], rough: 0.85,
    });
    piece(root, G.box, kit.satchel, {
      pos: [0.88, 0.98, 0.38], rot: [0, -0.25, 0], scale: [0.54, 0.14, 0.46], rough: 0.85,
    });
  }
  if (kit.scarf) {
    piece(root, ring(0.68, 0.15), kit.scarf, {
      pos: [0, 2.08, 0], rot: [Math.PI / 2, 0, 0], scale: [1, 1, 1.1], rough: 0.95,
    });
    // The trailing end is most of what sells a scarf in motion.
    piece(root, G.box, kit.scarf, {
      pos: [0.32, 1.55, 0.66], rot: [0.25, 0.1, -0.18], scale: [0.38, 1.15, 0.16], rough: 0.95,
    });
  }

  buildHat(head, kit);
  buildTool(root, kit);

  if (kit.scale) root.scale.setScalar(kit.scale);
  return { root, body, head, flipperL, flipperR, footL, footR };
}

function buildHat(head: THREE.Group, kit: PenguinKit) {
  const c = kit.hatColor ?? LEATHER;
  switch (kit.hat) {
    case 'straw':
      piece(head, G.cone, c, { pos: [0, 0.56, 0], rot: [0.06, 0, 0], scale: [2.3, 0.42, 2.3], rough: 0.95 });
      piece(head, G.cyl, c, { pos: [0, 0.68, -0.02], rot: [0.06, 0, 0], scale: [1.16, 0.42, 1.16], rough: 0.95 });
      piece(head, ring(0.64, 0.07), '#8a7a4e', { pos: [0, 0.58, -0.02], rot: [Math.PI / 2 + 0.06, 0, 0], rough: 0.95 });
      break;
    case 'flowers': {
      const petals = ['#e8879c', '#f4ead6', '#e8c15c', '#d97b8e', '#f0e2c0'];
      for (let i = 0; i < 9; i++) {
        const a = (i / 9) * Math.PI * 2;
        piece(head, G.ball, petals[i % petals.length], {
          pos: [Math.sin(a) * 0.66, 0.44 + Math.cos(a * 2) * 0.05, Math.cos(a) * 0.66],
          scale: 0.26, rough: 0.9,
        });
      }
      for (let i = 0; i < 5; i++) {
        const a = (i / 5) * Math.PI * 2 + 0.4;
        piece(head, G.box, '#5f7d43', {
          pos: [Math.sin(a) * 0.6, 0.36, Math.cos(a) * 0.6],
          rot: [0.4, a, 0], scale: [0.34, 0.06, 0.2], rough: 0.95,
        });
      }
      break;
    }
    case 'firehelm':
      piece(head, dome(0.86, 0.52), c, { pos: [0, 0.16, 0], rough: 0.5, metal: 0.15 });
      // Wide rear brim, narrow front shield — the classic fire helmet read.
      piece(head, G.cone, c, { pos: [0, 0.2, 0.26], rot: [0.16, 0, 0], scale: [2.05, 0.2, 2.5], rough: 0.5, metal: 0.15 });
      piece(head, G.box, '#c8a24a', { pos: [0, 0.5, -0.66], rot: [0.3, 0, 0], scale: [0.52, 0.44, 0.1], rough: 0.35, metal: 0.7 });
      piece(head, G.box, c, { pos: [0, 0.72, -0.1], scale: [0.14, 0.2, 1.3], rough: 0.5, metal: 0.15 });
      break;
    case 'cap':
      piece(head, dome(0.8, 0.5), c, { pos: [0, 0.18, 0], rough: 0.85 });
      piece(head, G.box, c, { pos: [0, 0.24, -0.72], rot: [0.12, 0, 0], scale: [1.0, 0.1, 0.62], rough: 0.85 });
      break;
    case 'hood':
      piece(head, new THREE.SphereGeometry(0.95, 16, 12, Math.PI * 0.3, Math.PI * 1.4, 0, Math.PI * 0.66), c, {
        pos: [0, 0.02, 0.1], rough: 0.93, side: THREE.DoubleSide,
      });
      piece(head, ring(0.86, 0.16), c, { pos: [0, -0.46, 0.05], rot: [Math.PI / 2, 0, 0], scale: [1, 1, 1.15], rough: 0.93 });
      break;
    case 'goggles':
      piece(head, dome(0.8, 0.5), c, { pos: [0, 0.14, 0], rough: 0.8 });
      piece(head, ring(0.79, 0.08), '#4a4038', { pos: [0, 0.42, 0], rot: [Math.PI / 2 + 0.35, 0, 0], rough: 0.7 });
      for (const s of [-1, 1]) {
        piece(head, G.cyl, '#9ad2d8', {
          pos: [s * 0.3, 0.58, -0.5], rot: [1.2, 0, 0], scale: [0.5, 0.16, 0.5], rough: 0.15, metal: 0.3,
        });
      }
      break;
    case 'woolly':
      piece(head, dome(0.82, 0.56), c, { pos: [0, 0.1, 0], rough: 0.97 });
      piece(head, ring(0.79, 0.13), c, { pos: [0, 0.14, 0], rot: [Math.PI / 2, 0, 0], rough: 0.97 });
      piece(head, G.ball, '#f2ece1', { pos: [0, 0.92, 0], scale: 0.44, rough: 0.97 });
      break;
  }
}

function buildTool(root: THREE.Group, kit: PenguinKit) {
  const c = kit.toolColor ?? '#7a5c3a';
  const x = 1.08;
  switch (kit.tool) {
    case 'rod':
      piece(root, G.cyl, c, { pos: [x, 2.0, 0.1], rot: [0.42, 0, -0.2], scale: [0.11, 4.4, 0.11], rough: 0.85 });
      piece(root, G.ball, '#cfe6ee', { pos: [x + 0.85, 3.55, -1.6], scale: 0.16, rough: 0.3, shadow: false });
      break;
    case 'staff':
      piece(root, G.cyl, c, { pos: [x, 1.7, 0.05], rot: [0, 0, -0.1], scale: [0.13, 3.9, 0.13], rough: 0.88 });
      piece(root, G.ball, '#cfe6ee', { pos: [x + 0.2, 3.7, 0.05], scale: 0.42, rough: 0.25, glow: 0.5 });
      break;
    case 'hammer':
      piece(root, G.cyl, c, { pos: [x, 1.75, 0.05], rot: [0, 0, -0.12], scale: [0.14, 2.6, 0.14], rough: 0.85 });
      piece(root, G.box, '#5a5f66', { pos: [x + 0.16, 3.05, 0.05], scale: [0.42, 0.42, 0.9], rough: 0.4, metal: 0.85 });
      break;
    case 'lantern':
      piece(root, G.cyl, '#4a4038', { pos: [x, 2.1, 0.05], rot: [0, 0, -0.5], scale: [0.08, 1.4, 0.08], rough: 0.6 });
      piece(root, G.box, '#4a4038', { pos: [x + 0.42, 1.4, 0.05], scale: [0.42, 0.5, 0.42], rough: 0.5, metal: 0.4 });
      piece(root, G.ball, '#ffd79a', { pos: [x + 0.42, 1.4, 0.05], scale: 0.34, glow: 2.2, rough: 0.2 });
      break;
    case 'basket':
      piece(root, new THREE.CylinderGeometry(0.44, 0.34, 0.6, 12, 1, true), '#a8874e', {
        pos: [x + 0.1, 0.86, -0.1], rough: 0.95, side: THREE.DoubleSide,
      });
      piece(root, G.ball, '#c9d68f', { pos: [x + 0.1, 1.06, -0.1], scale: [0.7, 0.3, 0.7], rough: 0.9 });
      break;
    case 'hose':
      piece(root, ring(0.6, 0.12), '#b5453c', { pos: [x + 0.1, 1.5, 0.3], rot: [0.4, 0.3, 0], rough: 0.85 });
      piece(root, G.cyl, '#c8a24a', { pos: [x + 0.5, 1.85, -0.4], rot: [1.2, 0, -0.3], scale: [0.16, 0.9, 0.16], rough: 0.35, metal: 0.7 });
      break;
  }
}

/** A dressed penguin that stands where it is put — the whole clan except Pip. */
export function penguinFigure(kit: PenguinKit, name = 'Penguin'): THREE.Group {
  const out = freeze(buildPenguin(kit).root, name);
  // freeze() bakes every piece into the root's own frame, which strips the
  // root's scale along with it — so the kit's scale has to go back on after.
  if (kit.scale) out.scale.setScalar(kit.scale);
  return out;
}

/**
 * Pip. The one penguin that stays un-frozen, because his limbs move
 * independently: waddle, flipper flap, belly slide, swim.
 */
export class Pip {
  root = new THREE.Group();
  private rig: PenguinRig;
  private t = 0;

  constructor(kit: PenguinKit = {}) {
    this.rig = buildPenguin(kit);
    this.root.add(this.rig.root);
  }

  /**
   * @param speed01 horizontal speed normalised to walk speed
   * @param facing  yaw in radians
   */
  update(
    dt: number, speed01: number, facing: number,
    sliding: boolean, airborne: boolean, swimming = false,
  ) {
    this.t += dt * (1 + speed01 * 5.5);
    const swing = Math.sin(this.t * 2.2);
    const { root: r, body, head, flipperL, flipperR, footL, footR } = this.rig;

    // Turn smoothly toward the direction of travel.
    let delta = facing - r.rotation.y;
    while (delta > Math.PI) delta -= Math.PI * 2;
    while (delta < -Math.PI) delta += Math.PI * 2;
    r.rotation.y += delta * Math.min(1, dt * 12);

    if (sliding || swimming) {
      // Prone: rotating -90 degrees about X lays him flat with his head end
      // forward and his belly down. It also points his BEAK at the floor,
      // because his face and his belly are the same side of the model — so the
      // head has to come back up by nearly the same angle or he reads as
      // face-planted. The old pose only lifted it by 0.7 rad and then pushed
      // him half a stud INTO the ground on top of that.
      const pitch = swimming ? -1.30 : -1.35;
      r.rotation.x = THREE.MathUtils.damp(r.rotation.x, pitch, 10, dt);
      r.position.y = THREE.MathUtils.damp(r.position.y, 0.66, 10, dt);
      head.rotation.x = THREE.MathUtils.damp(head.rotation.x, swimming ? 1.05 : 1.15, 10, dt);

      if (swimming) {
        // Flippers row, alternating, and the feet trail and kick. Without this
        // he is a rigid body being translated, which is exactly what "he sorta
        // just slides" describes.
        const stroke = Math.sin(this.t * 4.5);
        flipperL.rotation.x = -0.5 + stroke * 0.9;
        flipperR.rotation.x = -0.5 - stroke * 0.9;
        flipperL.rotation.z = THREE.MathUtils.damp(flipperL.rotation.z, -0.95, 10, dt);
        flipperR.rotation.z = -flipperL.rotation.z;
        footL.position.z = -0.16 + Math.sin(this.t * 5.2) * 0.3;
        footR.position.z = -0.16 - Math.sin(this.t * 5.2) * 0.3;
        footL.position.y = 0.16;
        footR.position.y = 0.16;
        body.position.y = 1.25;
      } else {
        flipperL.rotation.x = THREE.MathUtils.damp(flipperL.rotation.x, 0.9, 10, dt);
        flipperR.rotation.x = flipperL.rotation.x;
        flipperL.rotation.z = -0.5;
        flipperR.rotation.z = 0.5;
      }
      return;
    }

    r.rotation.x = THREE.MathUtils.damp(r.rotation.x, 0, 10, dt);
    r.position.y = THREE.MathUtils.damp(r.position.y, 0, 10, dt);
    head.rotation.x = THREE.MathUtils.damp(head.rotation.x, 0, 8, dt);

    // The waddle: body rocks side to side, feet paddle, head bobs a beat behind.
    const rock = swing * 0.17 * speed01;
    r.rotation.z = rock;
    body.position.y = 1.25 + Math.abs(swing) * 0.07 * speed01;
    head.position.y = 2.5 + Math.abs(Math.sin(this.t * 2.2 - 0.5)) * 0.05 * speed01;
    head.rotation.z = -rock * 0.5;

    footL.position.z = -0.16 + swing * 0.42 * speed01;
    footR.position.z = -0.16 - swing * 0.42 * speed01;
    footL.position.y = 0.16 + Math.max(0, swing) * 0.18 * speed01;
    footR.position.y = 0.16 + Math.max(0, -swing) * 0.18 * speed01;

    if (airborne) {
      // Flap! Penguins can't fly, but Pip is an optimist.
      flipperL.rotation.z = THREE.MathUtils.damp(flipperL.rotation.z, -0.5 + Math.sin(this.t * 9) * 0.5, 14, dt);
      flipperR.rotation.z = -flipperL.rotation.z;
      flipperL.rotation.x = 0;
      flipperR.rotation.x = 0;
    } else {
      flipperL.rotation.x = -swing * 0.5 * speed01;
      flipperR.rotation.x = swing * 0.5 * speed01;
      flipperL.rotation.z = THREE.MathUtils.damp(flipperL.rotation.z, 0.12, 10, dt);
      flipperR.rotation.z = -flipperL.rotation.z;
    }
  }
}

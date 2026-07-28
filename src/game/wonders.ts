import * as THREE from 'three';
import type { PartData } from '../engine/world';
import { G, freeze, piece } from './figures';
import { buildKodama } from './critters';
import type { UI } from './ui';

/**
 * The things that are bigger than you.
 *
 * Three ancient beasts off the reference sheet, the kodama that the world file
 * has been quietly asking for since the export (`ShySpot` / `Style: kodama`),
 * and the five spirit circles whose `Whisper` lines were written a year ago and
 * never once shown to a player.
 *
 * Palette rule holds throughout: spirits glow, and they glow COOL. The only
 * warm light in Ember Grove is fire.
 */

// ---------------------------------------------------------------- Neridia

/** Guardian of the Deep — a whale the size of the drawbridge span. */
export function buildWhale(): THREE.Group {
  const g = new THREE.Group();
  const skin = '#42607a';
  const belly = '#9fb6bd';

  piece(g, G.sphere, skin, { pos: [0, 0, 0], scale: [7.0, 6.2, 24.0], rough: 0.55 });
  piece(g, G.sphere, skin, { pos: [0, 0.4, -9.5], scale: [6.2, 5.4, 9.0], rough: 0.55 });
  piece(g, G.sphere, belly, { pos: [0, -2.0, -1.0], scale: [5.4, 3.0, 19.0], rough: 0.6 });
  // Throat pleats.
  for (let i = 0; i < 5; i++) {
    piece(g, G.box, belly, {
      pos: [0, -2.4 + i * 0.1, -11.5 + i * 1.6], scale: [4.2 - i * 0.3, 0.16, 1.0], rough: 0.7,
    });
  }
  // Tail stock and flukes.
  piece(g, G.sphere, skin, { pos: [0, 0.3, 12.0], scale: [2.6, 2.4, 6.0], rough: 0.55 });
  for (const s of [-1, 1]) {
    piece(g, G.sphere, skin, {
      pos: [s * 3.6, 0.5, 15.4], rot: [0, s * 0.35, 0], scale: [7.0, 0.7, 3.4], rough: 0.55,
    });
    // Pectoral fins.
    piece(g, G.sphere, skin, {
      pos: [s * 3.6, -1.2, -4.0], rot: [0.2, s * 0.5, s * 0.5], scale: [1.0, 0.6, 7.0], rough: 0.55,
    });
    piece(g, G.ball, '#1b2b35', { pos: [s * 2.5, 0.9, -12.6], scale: 0.7, rough: 0.4, shadow: false });
  }
  piece(g, G.sphere, skin, { pos: [0, 3.0, 1.5], scale: [1.2, 1.8, 3.0], rough: 0.55 });

  // Reef living on its back, and the old markings under it.
  for (let i = 0; i < 14; i++) {
    const t = i / 13;
    const x = Math.sin(i * 2.1) * 2.2;
    const z = -8 + t * 18;
    piece(g, G.ball, i % 3 === 0 ? '#c8756a' : '#6f9a8a', {
      pos: [x, 2.4 + Math.cos(i) * 0.4, z], scale: 0.5 + (i % 3) * 0.22, rough: 0.85,
    });
  }
  for (let i = 0; i < 10; i++) {
    const t = i / 9;
    piece(g, G.ball, '#8fe4e0', {
      pos: [Math.sin(t * 7.0) * 2.9, 1.4 + Math.cos(t * 5.0) * 1.0, -9 + t * 20],
      scale: 0.3, glow: 1.3, rough: 0.2, shadow: false,
    });
  }
  return g;
}

// ---------------------------------------------------------------- Sylphir

/** Spirit of the Wind — pale, half-there, always circling. */
export function buildSylphir(): THREE.Group {
  const g = new THREE.Group();
  const pale = '#dff0ee';
  const teal = '#8fd6d2';

  piece(g, G.sphere, pale, { pos: [0, 0, 0], scale: [1.9, 1.9, 4.4], rough: 0.3, opacity: 0.85 });
  piece(g, G.sphere, pale, { pos: [0, 1.1, -2.4], scale: [1.3, 1.3, 1.5], rough: 0.3, opacity: 0.85 });
  piece(g, G.cone, '#e8c15c', { pos: [0, 1.0, -3.5], rot: [-Math.PI / 2, 0, 0], scale: [0.3, 1.0, 0.3], rough: 0.5 });
  for (const s of [-1, 1]) {
    piece(g, G.ball, '#2f4f57', { pos: [s * 0.42, 1.3, -3.0], scale: 0.26, rough: 0.3, shadow: false });
    // Long layered wings, each feather a flattened blade.
    for (let i = 0; i < 5; i++) {
      const t = i / 4;
      piece(g, G.sphere, i % 2 ? teal : pale, {
        pos: [s * (1.4 + t * 3.6), 0.5 + t * 1.2, -0.4 + t * 1.9],
        rot: [0, s * (0.3 + t * 0.4), s * (0.4 + t * 0.5)],
        scale: [4.6 - t * 1.2, 0.28, 1.5 - t * 0.4], rough: 0.35, opacity: 0.8,
      });
    }
    // Trailing tail streamers.
    for (let i = 0; i < 3; i++) {
      piece(g, G.sphere, teal, {
        pos: [s * (0.3 + i * 0.35), -0.1 - i * 0.2, 3.4 + i * 2.2],
        rot: [0, 0, s * 0.2], scale: [0.5, 0.2, 5.0 - i * 0.7], rough: 0.35, opacity: 0.6,
      });
    }
  }
  for (let i = 0; i < 6; i++) {
    piece(g, G.ball, '#cfeeee', {
      pos: [Math.sin(i * 2.2) * 2.4, 0.6 + Math.cos(i * 1.7) * 1.4, 1.0 + i * 0.9],
      scale: 0.26, glow: 1.1, rough: 0.2, shadow: false,
    });
  }
  return g;
}

// ---------------------------------------------------------------- Gorog

/** Stone Colossus — asleep long enough that the forest moved in. */
export function buildColossus(): THREE.Group {
  const g = new THREE.Group();
  const rock = '#6e7168';
  const dark = '#585c55';
  const moss = '#5f7d43';

  const boulder = (x: number, y: number, z: number, sx: number, sy: number, sz: number, c = rock) =>
    piece(g, G.sphere, c, {
      pos: [x, y, z], rot: [Math.sin(x) * 0.4, Math.cos(z) * 0.6, Math.sin(y) * 0.3],
      scale: [sx, sy, sz], rough: 0.95,
    });

  /** Moss grows as a cap over the crown of a boulder, never as a disc beside
   *  it — flat slabs floating off the silhouette read as lily pads. */
  const cap = (x: number, y: number, z: number, r: number) =>
    piece(g, G.sphere, moss, {
      pos: [x, y, z], scale: [r * 2.0, r * 0.85, r * 2.0], rough: 0.96,
    });

  // Seated, forearms across the knees, head bowed. Reads as resting, not dead.
  boulder(0, 5.5, 1.0, 13, 11, 11, dark);          // haunches
  boulder(0, 11.2, -1.0, 12, 10.5, 9);             // chest
  boulder(0, 15.0, -0.8, 5.0, 3.6, 4.6, dark);     // neck
  boulder(0, 18.0, -1.4, 7.0, 5.6, 6.4);           // head, up clear of the chest
  boulder(0, 16.6, -4.2, 4.4, 2.6, 2.6, dark);     // heavy brow
  cap(0, 20.2, -0.4, 3.2);
  for (const s of [-1, 1]) {
    boulder(s * 7.0, 3.4, -5.0, 7.0, 6.5, 9.0);    // knees
    boulder(s * 6.2, 1.2, -8.0, 5.0, 3.0, 6.0, dark);
    boulder(s * 8.6, 11.0, -1.0, 5.4, 9.0, 5.4);   // upper arms
    boulder(s * 8.0, 5.6, -5.4, 4.4, 7.4, 4.4);    // forearms
    boulder(s * 6.8, 3.2, -8.6, 3.8, 2.8, 4.6, dark); // hands on the knees
    cap(s * 7.0, 6.5, -5.2, 3.2);
    cap(s * 8.8, 15.2, -1.0, 2.6);
    // Eyes: deep-set, cool, and the only part of him that is awake. Kept below
    // the bloom threshold so they read as lit stone, not headlamps.
    piece(g, G.ball, '#7fd8c4', {
      pos: [s * 2.2, 17.9, -4.0], scale: 1.05, glow: 0.55, rough: 0.2, shadow: false,
    });
  }
  cap(0, 15.4, 3.0, 5.0);

  // A stand of trees that took root on his shoulders and never left.
  for (let i = 0; i < 5; i++) {
    const a = i * 1.9;
    const x = Math.sin(a) * 6.0;
    const z = Math.cos(a) * 3.6 + 2.0;
    piece(g, G.cyl, '#4a3a2c', { pos: [x, 17.5, z], scale: [0.9, 5.0, 0.9], rough: 0.9 });
    piece(g, G.sphere, i % 2 ? '#4e7038' : '#628a46', {
      pos: [x, 21.0, z], scale: [6.5, 4.5, 6.5], rough: 0.95,
    });
  }
  // Two long seams down the chest, like light through cracked stone. Scattered
  // short dashes read as damage, not as a creature holding itself together.
  for (const s of [-1, 1]) {
    for (let i = 0; i < 4; i++) {
      piece(g, G.box, '#7fd8c4', {
        pos: [s * (1.4 + i * 0.5), 8.0 + i * 1.9, -7.6 + i * 0.25],
        rot: [0, 0, s * (0.18 + i * 0.06)], scale: [0.4, 2.0, 0.4],
        glow: 0.45, rough: 0.3, shadow: false,
      });
    }
  }
  return g;
}

// ---------------------------------------------------------------- manager

interface Kodama {
  object: THREE.Group;
  home: THREE.Vector3;
  phase: number;
  /** Kodama are shy. They only turn to look once you are close. */
  seen: number;
}

interface Circle {
  pos: THREE.Vector3;
  whisper: string;
  told: boolean;
}

export class Wonders {
  group = new THREE.Group();
  private whale!: THREE.Group;
  private whaleSpout: THREE.Group;
  private sylphir!: THREE.Group;
  private kodama: Kodama[] = [];
  private circles: Circle[] = [];
  private t = 0;

  constructor(byTag: Map<string, PartData[]>, private ui: UI, place: (x: number, z: number, near: number) => number) {
    this.group.name = 'Wonders';

    // ---- Neridia, patrolling the river channel ----
    this.whale = freeze(buildWhale(), 'Neridia');
    this.group.add(this.whale);
    this.whaleSpout = new THREE.Group();
    for (let i = 0; i < 12; i++) {
      piece(this.whaleSpout, G.ball, '#e8f4f4', {
        pos: [Math.sin(i * 2.1) * 0.9, i * 0.9, Math.cos(i * 2.1) * 0.9],
        scale: 0.9 + i * 0.12, opacity: 0.55, rough: 0.4, shadow: false,
      });
    }
    this.group.add(this.whaleSpout);

    // ---- Sylphir, circling above the Whispering Woods ----
    this.sylphir = freeze(buildSylphir(), 'Sylphir');
    this.group.add(this.sylphir);

    // ---- Gorog, on the road between the campsite and the woods ----
    const colossus = freeze(buildColossus(), 'Gorog');
    colossus.position.set(-600, place(-600, -300, 3) - 1.5, -300);
    colossus.rotation.y = 0.6;
    this.group.add(colossus);

    // ---- kodama at every ShySpot the world file already marks ----
    for (const p of byTag.get('ShySpot') ?? []) {
      if (String(p.attrs?.Style ?? '') !== 'kodama') continue;
      const object = freeze(buildKodama(), 'Kodama');
      const y = place(p.pos[0], p.pos[2], p.pos[1]);
      object.position.set(p.pos[0], y, p.pos[2]);
      this.group.add(object);
      this.kodama.push({
        object, home: object.position.clone(), phase: this.kodama.length * 2.3, seen: 0,
      });
    }

    // ---- the spirit circles, and the lines nobody has ever read ----
    for (const p of byTag.get('SpiritCircle') ?? []) {
      const whisper = String(p.attrs?.Whisper ?? '');
      if (!whisper) continue;
      this.circles.push({ pos: new THREE.Vector3(...p.pos), whisper, told: false });
    }
  }

  update(dt: number, player: THREE.Vector3) {
    this.t += dt;

    // Neridia runs the length of the channel and back, surfacing to breathe.
    // A 46-second lap means she is an event you catch, not scenery you ignore.
    const LAP = 46;
    const u = (this.t % LAP) / LAP;
    const z = -140 + Math.sin(u * Math.PI * 2 - Math.PI / 2) * 0.5 * 520 + 260;
    const heading = Math.cos(u * Math.PI * 2 - Math.PI / 2) >= 0 ? 0 : Math.PI;
    // Depth: mostly down, breaking the surface twice a lap.
    const breach = Math.pow(Math.max(0, Math.sin(u * Math.PI * 4)), 6);
    const y = -6.5 + breach * 6.0;
    this.whale.position.set(492 + Math.sin(this.t * 0.15) * 7, y, z);
    this.whale.rotation.y = heading + Math.sin(this.t * 0.4) * 0.06;
    this.whale.rotation.x = Math.sin(this.t * 0.6) * 0.05 - breach * 0.18;

    const spouting = breach > 0.55;
    this.whaleSpout.visible = spouting;
    if (spouting) {
      this.whaleSpout.position.set(this.whale.position.x, 2.2, z + (heading ? -2 : 2));
      const s = 0.4 + (breach - 0.55) * 1.6;
      this.whaleSpout.scale.set(s, s * 1.4, s);
    }

    // Sylphir keeps a wide slow circle over the woods.
    const a = this.t * 0.085;
    this.sylphir.position.set(
      -425 + Math.cos(a) * 130,
      52 + Math.sin(this.t * 0.3) * 5,
      -255 + Math.sin(a) * 110,
    );
    this.sylphir.rotation.y = -a + Math.PI / 2;
    this.sylphir.rotation.z = Math.sin(a) * 0.12 - 0.2;

    // Kodama: bob, and turn their heads toward you once you are near enough.
    for (const k of this.kodama) {
      const d = k.home.distanceTo(player);
      const want = d < 34 ? 1 : 0;
      k.seen += (want - k.seen) * Math.min(1, dt * 1.6);
      const tt = this.t + k.phase;
      k.object.position.y = k.home.y + Math.sin(tt * 1.7) * 0.08;
      const face = Math.atan2(player.x - k.home.x, player.z - k.home.z) + Math.PI;
      // The famous head-rattle: a small twitch, only while they are watching.
      k.object.rotation.y = face * k.seen + Math.sin(tt * 9) * 0.09 * k.seen;
      k.object.scale.setScalar(0.9 + k.seen * 0.12);
    }

    // Step into a spirit circle and it tells you what it is. Once.
    for (const c of this.circles) {
      if (c.told) continue;
      if (c.pos.distanceTo(player) < 11) {
        c.told = true;
        this.ui.toast(c.whisper, 'story');
      }
    }
  }
}

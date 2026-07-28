import * as THREE from 'three';

/** One part as extracted from the .rbxlx by tools/extract_world.py. */
export interface PartData {
  name: string;
  class: string;
  path: string;
  pos: [number, number, number];
  /** Roblox rotation matrix, row-major R00..R22. */
  rot: number[];
  size: [number, number, number];
  color?: [number, number, number];
  material?: string;
  shape?: string;
  transparency?: number;
  canCollide?: boolean;
  reflectance?: number;
  tags?: string[];
  attrs?: Record<string, string | number | boolean | number[]>;
}

export interface WorldData {
  partCount: number;
  bounds: { min: number[]; max: number[] };
  tagCounts: Record<string, number>;
  parts: PartData[];
}

/** A static oriented box the character controller can collide against. */
export interface Collider {
  center: THREE.Vector3;
  half: THREE.Vector3;
  /** World->local rotation (inverse of the part's orientation). */
  inv: THREE.Matrix3;
  rot: THREE.Matrix3;
  axisAligned: boolean;
  /** Wedges are ramps: their top face slopes from -Z (low) to +Z (high). */
  wedge: boolean;
  /**
   * Too narrow to stand on: a rail, a parapet, a post, a fence.
   *
   * This exists because the world's guard rails are 1.0 to 1.4 studs tall and
   * the effective step-up is 1.75, so Pip could stroll over every safety rail
   * on the lookout tower, every rail on the sky stairs and every rooftop
   * parapet in the neighbourhood, and walk straight off. Height alone can't
   * separate a rail from a stair — the fire escape's risers are 1.55 — but
   * footprint can: you can climb onto a step, and you cannot balance on a
   * 0.2-stud rail.
   */
  thin: boolean;
  /**
   * Half-height of the part's WORLD-space bounding box. For a rotated part this
   * is not half.y — the bandstand deck is a cylinder lying on its side, and
   * reading its local half-height as the world top made it a 10-stud wall.
   */
  worldHalfY: number;
  name: string;
}

export function partMatrix(p: PartData): THREE.Matrix4 {
  const r = p.rot;
  const m = new THREE.Matrix4();
  // Roblox rows R0*, R1*, R2* map directly onto a column-major basis here
  // because we keep Roblox's right-handed Y-up convention.
  m.set(
    r[0], r[1], r[2], p.pos[0],
    r[3], r[4], r[5], p.pos[1],
    r[6], r[7], r[8], p.pos[2],
    0, 0, 0, 1,
  );
  return m;
}

function isIdentityRot(r: number[]): boolean {
  return (
    Math.abs(r[0] - 1) < 1e-4 && Math.abs(r[4] - 1) < 1e-4 && Math.abs(r[8] - 1) < 1e-4 &&
    Math.abs(r[1]) < 1e-4 && Math.abs(r[2]) < 1e-4 && Math.abs(r[3]) < 1e-4 &&
    Math.abs(r[5]) < 1e-4 && Math.abs(r[6]) < 1e-4 && Math.abs(r[7]) < 1e-4
  );
}

/** Below this footprint a part is a rail or a post, never somewhere to stand. */
const THIN_FOOTPRINT = 1.1;

/** How far Pip may rise onto something he cannot stand on — enough for a kerb,
 *  nowhere near enough for a guard rail. */
export const THIN_STEP = 0.7;

export function makeCollider(p: PartData): Collider {
  const r = p.rot;
  const rot = new THREE.Matrix3().set(
    r[0], r[1], r[2],
    r[3], r[4], r[5],
    r[6], r[7], r[8],
  );
  const inv = rot.clone().transpose(); // rotation matrices: inverse == transpose
  return {
    center: new THREE.Vector3(p.pos[0], p.pos[1], p.pos[2]),
    half: new THREE.Vector3(p.size[0] / 2, p.size[1] / 2, p.size[2] / 2),
    rot,
    inv,
    axisAligned: isIdentityRot(r),
    wedge: p.class === 'WedgePart',
    // Narrower than a penguin in one horizontal axis => a barrier, not a step.
    thin: p.class !== 'WedgePart' && Math.min(p.size[0], p.size[2]) < THIN_FOOTPRINT,
    // row 1 of the rotation matrix projects a local extent onto world Y
    worldHalfY:
      Math.abs(r[3]) * (p.size[0] / 2) +
      Math.abs(r[4]) * (p.size[1] / 2) +
      Math.abs(r[5]) * (p.size[2] / 2),
    name: p.name,
  };
}

const _local = new THREE.Vector3();
const _surf = new THREE.Vector3();
const _o = new THREE.Vector3();
const _d = new THREE.Vector3();
const AXES = ['x', 'y', 'z'] as const;

/**
 * Where a straight-down ray first meets an oriented box, in world Y — the real
 * top surface, not the top of its bounding box.
 *
 * This matters far more than it sounds. The Great Bridge's approach ramps are
 * ordinary `Part`s tilted 26 degrees about Z, 37 studs long: reading their top
 * as `center.y + worldHalfY` puts it at 18.6 studs everywhere inside the
 * footprint, so the resolver saw an eighteen-stud wall standing across the only
 * crossing in the world. The same is true of the drawbridge flaps, the boat
 * slipways and the sky bridge. Sampling the actual sloped face makes all of
 * them walkable, and costs one slab test.
 */
function obbTopAt(c: Collider, x: number, z: number): number | null {
  const high = c.worldHalfY + 10;
  _o.set(x - c.center.x, high, z - c.center.z).applyMatrix3(c.inv);
  _d.set(0, -1, 0).applyMatrix3(c.inv);

  let tmin = 0;
  let tmax = Infinity;
  for (const a of AXES) {
    const o = _o[a];
    const d = _d[a];
    const h = c.half[a] + 0.05;
    if (Math.abs(d) < 1e-9) {
      if (o < -h || o > h) return null;   // parallel to this slab and outside it
      continue;
    }
    let t1 = (-h - o) / d;
    let t2 = (h - o) / d;
    if (t1 > t2) { const s = t1; t1 = t2; t2 = s; }
    if (t1 > tmin) tmin = t1;
    if (t2 < tmax) tmax = t2;
    if (tmin > tmax) return null;
  }

  _surf.copy(_o).addScaledVector(_d, tmin).applyMatrix3(c.rot);
  return c.center.y + _surf.y;
}

/**
 * How far a sample may be walked back toward a collider before giving up, and
 * in what steps.
 *
 * A body radius isn't enough. The resolver's broad test projects a world-flat
 * offset through the collider's inverse rotation, which for a part tilted about
 * X or Z reports a footprint wider than the box really is — the Great Bridge's
 * approach claims to span x 384..426 when the box only reaches 387.7..422.3.
 * That gap is where the fallback used to fire and turn the ramp into a wall, so
 * the search has to cover the gap as well as the radius.
 */
const EDGE_REACH = 6;
const EDGE_STEP = 1.2;

/**
 * Height of a collider's walkable top surface at a world XZ, or null if that
 * point is outside its footprint. Boxes are sampled on their true (possibly
 * tilted) top face; wedges slope linearly from their -Z edge up to their +Z
 * edge. Between them that covers every ramp in the world, which is the
 * difference between "the bridge is climbable" and "the bridge is a wall".
 */
export function colliderTopAt(
  c: Collider,
  x: number,
  z: number,
  /**
   * When true, a point that misses the footprint is retried from just inside
   * it instead of returning null. The collision resolver needs this: the
   * player's centre is still a body-radius short of a ramp when the resolver
   * first sees it, and falling back to the box top there re-blocked every ramp
   * one step before its base.
   */
  clampToEdge = false,
): number | null {
  if (!c.wedge) {
    const top = obbTopAt(c, x, z);
    if (top !== null || !clampToEdge) return top;

    // First choice: clamp the sample straight into the collider's own
    // footprint. This is exact for anything rotated only about Y, and it is
    // the ONLY thing that finds a thin part — a 0.25-stud rail is narrower
    // than the march below steps, so marching walks clean over it, reports
    // "not here", and the resolver skips it. That is every guard rail and
    // parapet in the world silently losing its collision.
    _local.set(x - c.center.x, 0, z - c.center.z).applyMatrix3(c.inv);
    _surf.set(
      THREE.MathUtils.clamp(_local.x, -c.half.x, c.half.x),
      0,
      THREE.MathUtils.clamp(_local.z, -c.half.z, c.half.z),
    ).applyMatrix3(c.rot);
    const clamped = obbTopAt(c, c.center.x + _surf.x, c.center.z + _surf.z);
    if (clamped !== null) return clamped;

    // Fallback for parts tilted about X or Z, where zeroing the local height
    // above puts the clamped point off the box: walk in toward the centre.
    const dx = c.center.x - x;
    const dz = c.center.z - z;
    const d = Math.hypot(dx, dz);
    if (d < 1e-6) return null;
    for (let s = EDGE_STEP; s <= Math.min(d, EDGE_REACH); s += EDGE_STEP) {
      const hit = obbTopAt(c, x + (dx / d) * s, z + (dz / d) * s);
      if (hit !== null) return hit;
    }
    return null;
  }

  _local.set(x - c.center.x, 0, z - c.center.z).applyMatrix3(c.inv);
  if (!clampToEdge) {
    if (Math.abs(_local.x) > c.half.x + 0.05) return null;
    if (Math.abs(_local.z) > c.half.z + 0.05) return null;
  }
  const lz = THREE.MathUtils.clamp(_local.z, -c.half.z, c.half.z);
  const lx = THREE.MathUtils.clamp(_local.x, -c.half.x, c.half.x);
  const t = (lz + c.half.z) / (2 * c.half.z);
  const localY = -c.half.y + t * 2 * c.half.y;
  _surf.set(lx, localY, lz).applyMatrix3(c.rot);
  return c.center.y + _surf.y;
}

/**
 * Uniform spatial hash over the XZ plane. The world is ~1500x950 studs with
 * ~3700 parts, so a flat grid keeps broad-phase queries to a handful of cells.
 */
export class ColliderGrid {
  private cells = new Map<string, Collider[]>();
  constructor(private cell = 24) {}

  private key(ix: number, iz: number) {
    return ix + ',' + iz;
  }

  add(c: Collider) {
    // Conservative AABB of the oriented box.
    const e = new THREE.Vector3(
      Math.abs(c.rot.elements[0]) * c.half.x + Math.abs(c.rot.elements[3]) * c.half.y + Math.abs(c.rot.elements[6]) * c.half.z,
      0,
      Math.abs(c.rot.elements[2]) * c.half.x + Math.abs(c.rot.elements[5]) * c.half.y + Math.abs(c.rot.elements[8]) * c.half.z,
    );
    const x0 = Math.floor((c.center.x - e.x) / this.cell);
    const x1 = Math.floor((c.center.x + e.x) / this.cell);
    const z0 = Math.floor((c.center.z - e.z) / this.cell);
    const z1 = Math.floor((c.center.z + e.z) / this.cell);
    for (let ix = x0; ix <= x1; ix++) {
      for (let iz = z0; iz <= z1; iz++) {
        const k = this.key(ix, iz);
        let list = this.cells.get(k);
        if (!list) this.cells.set(k, (list = []));
        list.push(c);
      }
    }
  }

  /** Every collider whose cell overlaps the given XZ radius around a point. */
  query(p: THREE.Vector3, radius: number, out: Collider[]): Collider[] {
    out.length = 0;
    const x0 = Math.floor((p.x - radius) / this.cell);
    const x1 = Math.floor((p.x + radius) / this.cell);
    const z0 = Math.floor((p.z - radius) / this.cell);
    const z1 = Math.floor((p.z + radius) / this.cell);
    for (let ix = x0; ix <= x1; ix++) {
      for (let iz = z0; iz <= z1; iz++) {
        const list = this.cells.get(this.key(ix, iz));
        if (!list) continue;
        for (const c of list) if (!out.includes(c)) out.push(c);
      }
    }
    return out;
  }
}

export async function loadWorld(url: string): Promise<WorldData> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`world load failed: ${res.status}`);
  return res.json();
}

/** Parts tagged for gameplay, indexed by tag. */
export function indexByTag(parts: PartData[]): Map<string, PartData[]> {
  const map = new Map<string, PartData[]>();
  for (const p of parts) {
    if (!p.tags) continue;
    for (const t of p.tags) {
      let list = map.get(t);
      if (!list) map.set(t, (list = []));
      list.push(p);
    }
  }
  return map;
}

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
    name: p.name,
  };
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

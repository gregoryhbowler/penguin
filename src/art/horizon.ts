import * as THREE from 'three';
import { PALETTE } from './scene';

/**
 * What you can see but never reach.
 *
 * Ember Grove sat on a flat green plane that ran to a hard line against the
 * sky, and the world sheets are the opposite of that — every panel has
 * something big and far away in it: mountain walls, a spire, a distant city on
 * a plateau. That silhouette is what tells a player the world continues, and it
 * costs almost nothing because none of it is ever visited.
 *
 * Everything here is unlit and fogged. Distance in this engine is FogExp2, so a
 * shape at a thousand studs is already three-quarters sky colour: the ring
 * reads as pale blue cut-outs stacked in haze, which is exactly the effect the
 * reference paintings get with a wash.
 */

/** Deterministic hash so the skyline is identical on every load. */
function rnd(i: number, salt = 0): number {
  const s = Math.sin(i * 127.1 + salt * 311.7) * 43758.5453;
  return s - Math.floor(s);
}

function ridgeGeometry(width: number, height: number, depth: number): THREE.BufferGeometry {
  // A four-sided pyramid, squashed and skewed so no two peaks match.
  const g = new THREE.ConeGeometry(width / 2, height, 4, 1);
  g.rotateY(Math.PI / 4);
  g.scale(1, 1, depth / width);
  g.translate(0, height / 2, 0);
  return g;
}

export interface Horizon {
  group: THREE.Group;
  /** Keeps the ring centred on the player so it never runs out. */
  update(player: THREE.Vector3): void;
}

export function createHorizon(): Horizon {
  const group = new THREE.Group();
  group.name = 'Horizon';

  // Three bands at different distances. The near band is darker and more
  // saturated, the far band nearly sky — that alone reads as depth.
  const bands = [
    { r: 1320, count: 26, h: [180, 330], w: [320, 560], color: '#b4d0de', order: 0 },
    { r: 1050, count: 30, h: [110, 220], w: [240, 420], color: '#9dc0d2', order: 1 },
    { r: 900, count: 26, h: [80, 140], w: [180, 320], color: '#9ebfd2', order: 2 },
  ];

  const geos: { geo: THREE.BufferGeometry; color: string; order: number }[] = [];
  let n = 0;
  for (const band of bands) {
    const parts: THREE.BufferGeometry[] = [];
    for (let i = 0; i < band.count; i++) {
      const a = (i / band.count) * Math.PI * 2 + rnd(n, 1) * 0.12;
      const r = band.r * (0.88 + rnd(n, 2) * 0.24);
      const h = band.h[0] + rnd(n, 3) * (band.h[1] - band.h[0]);
      const w = band.w[0] + rnd(n, 4) * (band.w[1] - band.w[0]);
      const g = ridgeGeometry(w, h, w * (0.5 + rnd(n, 5) * 0.4));
      g.rotateY(rnd(n, 6) * Math.PI);
      g.translate(Math.sin(a) * r, -14 - rnd(n, 9) * 30, Math.cos(a) * r);
      parts.push(g);
      // A shoulder off each peak, so the ridge line isn't a row of identical
      // triangles. This is the whole difference between "mountains" and "saw".
      const sh = ridgeGeometry(w * 0.66, h * (0.45 + rnd(n, 7) * 0.3), w * 0.4);
      sh.rotateY(rnd(n, 8) * Math.PI);
      sh.translate(
        Math.sin(a) * r + Math.cos(a) * w * (rnd(n, 10) - 0.5) * 1.3,
        -14 - rnd(n, 9) * 30,
        Math.cos(a) * r - Math.sin(a) * w * (rnd(n, 10) - 0.5) * 1.3,
      );
      parts.push(sh);
      n++;
    }
    for (const p of parts) geos.push({ geo: p, color: band.color, order: band.order });
  }

  // A handful of far towers, because the sheet's skyline is never only rock.
  const spires: [number, number, number, number][] = [
    // bearing, radius, height, width
    [0.5, 900, 260, 26],
    [2.1, 1150, 330, 32],
    [3.6, 980, 210, 22],
    [4.9, 1220, 300, 30],
    [5.7, 860, 180, 20],
  ];
  for (const [a, r, h, w] of spires) {
    const x = Math.sin(a) * r;
    const z = Math.cos(a) * r;
    const shaft = new THREE.CylinderGeometry(w * 0.42, w * 0.6, h, 7);
    shaft.translate(x, h / 2 - 14, z);
    geos.push({ geo: shaft, color: '#a6c6d6', order: 3 });
    const cap = new THREE.ConeGeometry(w * 0.7, h * 0.22, 7);
    cap.translate(x, h + h * 0.11 - 14, z);
    geos.push({ geo: cap, color: '#b8d4e0', order: 3 });
  }

  // Merge per colour so the whole skyline is a handful of draw calls.
  const byColor = new Map<string, { list: THREE.BufferGeometry[]; order: number }>();
  for (const { geo, color, order } of geos) {
    let b = byColor.get(color);
    if (!b) byColor.set(color, (b = { list: [], order }));
    b.list.push(geo);
  }

  for (const [color, b] of byColor) {
    // Unlit: these are silhouettes, and shading them would make them read as
    // nearby objects rather than as distance.
    //
    // depthWrite is OFF deliberately. With it on, the ambient-occlusion pass
    // sees a 300-stud depth cliff at every peak and paints a black halo down
    // the far side of it. Keeping the ring out of the depth buffer removes the
    // halo entirely; correct ordering comes from renderOrder instead, far band
    // first, which is why the bands are declared back-to-front above.
    const mat = new THREE.MeshBasicMaterial({
      color: new THREE.Color(color), fog: true, depthWrite: false,
    });
    const mesh = new THREE.Mesh(mergeAll(b.list), mat);
    mesh.frustumCulled = false;
    mesh.renderOrder = -910 + b.order;  // after the sky dome, before anything real
    group.add(mesh);
  }

  const centre = new THREE.Vector3();
  return {
    group,
    update(player) {
      // Follow in XZ only. The ring is far enough that parallax across the map
      // would otherwise swing it visibly past the play area's edge.
      centre.set(player.x, 0, player.z);
      group.position.lerp(centre, 0.04);
    },
  };
}

/** Minimal concat merge — every geometry here is position-only and non-indexed. */
function mergeAll(list: THREE.BufferGeometry[]): THREE.BufferGeometry {
  let total = 0;
  const plain = list.map((g) => {
    const ng = g.index ? g.toNonIndexed() : g;
    total += ng.attributes.position.count;
    return ng;
  });
  const pos = new Float32Array(total * 3);
  const nrm = new Float32Array(total * 3);
  let o = 0;
  for (const g of plain) {
    const p = g.attributes.position.array as Float32Array;
    const nAttr = g.attributes.normal?.array as Float32Array | undefined;
    pos.set(p, o * 3);
    if (nAttr) nrm.set(nAttr, o * 3);
    o += g.attributes.position.count;
  }
  const out = new THREE.BufferGeometry();
  out.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  out.setAttribute('normal', new THREE.BufferAttribute(nrm, 3));
  out.computeBoundingSphere();
  return out;
}

/** Kept for callers that want the haze colour the ring dissolves into. */
export const HAZE = PALETTE.fog;

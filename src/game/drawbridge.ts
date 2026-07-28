import * as THREE from 'three';
import type { Collider, PartData } from '../engine/world';
import { makeCollider } from '../engine/world';

/**
 * The Great Bridge's drawbridge.
 *
 * The two flaps were exported mid-air at 72 degrees — the bridge is up, and the
 * only crossing in the world is a thirty-stud gap over the river. The `.rbxlx`
 * tags a `WinchBase` on each bank with `BridgeLever`, so the intent was always
 * that you work the winch to lower it; nothing had ever read that tag.
 *
 * The flaps are the one piece of the world that moves, so they come out of the
 * static instanced build and out of the collider grid, and hand their colliders
 * to the controller fresh each frame instead.
 */

const FLAP_NAMES = new Set(['FlapWest', 'FlapEast', 'FlapWestStripe', 'FlapEastStripe']);

interface Leaf {
  pivot: THREE.Group;
  /** Signed angle, in radians, from lowered to the exported raised pose. */
  raised: number;
  parts: { part: PartData; localPos: THREE.Vector3; localRot: THREE.Matrix3 }[];
}

function matFor(p: PartData): THREE.Matrix3 {
  const r = p.rot;
  return new THREE.Matrix3().set(r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8]);
}

export class Drawbridge {
  group = new THREE.Group();
  /** 0 = fully up, 1 = down and crossable. */
  open = 0;
  private target = 0;
  private leaves: Leaf[] = [];
  private colliders: Collider[] = [];
  private scratchPart: PartData[] = [];

  /** Parts this owns — the world builder and the collider grid must skip them. */
  static owns(p: PartData): boolean {
    return FLAP_NAMES.has(p.name);
  }

  constructor(parts: PartData[]) {
    this.group.name = 'Drawbridge';

    for (const side of ['West', 'East'] as const) {
      const flap = parts.find((p) => p.name === `Flap${side}`);
      const hinge = parts.find((p) => p.name === `Flap${side}Hinge`);
      if (!flap || !hinge) continue;

      // The exported flap is a plain box rotated about Z. Reading that angle
      // straight off the matrix means the closed pose is simply angle zero —
      // no hand-authored constants to drift out of sync with the world file.
      const raised = Math.atan2(flap.rot[3], flap.rot[0]);

      const pivot = new THREE.Group();
      pivot.position.set(hinge.pos[0], hinge.pos[1], hinge.pos[2]);
      this.group.add(pivot);

      const leaf: Leaf = { pivot, raised, parts: [] };
      for (const p of parts) {
        if (!FLAP_NAMES.has(p.name) || !p.name.includes(side)) continue;
        const localPos = new THREE.Vector3(
          p.pos[0] - hinge.pos[0], p.pos[1] - hinge.pos[1], p.pos[2] - hinge.pos[2],
        );
        const localRot = matFor(p);
        leaf.parts.push({ part: p, localPos, localRot });

        const mesh = new THREE.Mesh(
          new THREE.BoxGeometry(p.size[0], p.size[1], p.size[2]),
          new THREE.MeshStandardMaterial({
            color: new THREE.Color().setRGB(
              (p.color?.[0] ?? 160) / 255, (p.color?.[1] ?? 160) / 255, (p.color?.[2] ?? 160) / 255,
              THREE.SRGBColorSpace,
            ),
            roughness: p.material === 'Metal' ? 0.4 : 0.8,
            metalness: p.material === 'Metal' ? 0.8 : 0,
          }),
        );
        mesh.castShadow = true;
        mesh.receiveShadow = true;
        mesh.position.copy(localPos);
        mesh.setRotationFromMatrix(new THREE.Matrix4().setFromMatrix3(localRot));
        pivot.add(mesh);

        this.scratchPart.push({ ...p });
      }
      this.leaves.push(leaf);
    }

    this.apply();
  }

  toggle() {
    this.target = this.target > 0.5 ? 0 : 1;
  }

  get lowering(): boolean {
    return Math.abs(this.open - this.target) > 0.001;
  }

  update(dt: number) {
    if (!this.lowering) return;
    // Slow and heavy: a bridge this size shouldn't snap into place, and the
    // eight seconds are the point — you watch it come down.
    const rate = dt / 8;
    this.open = this.target > this.open
      ? Math.min(this.target, this.open + rate)
      : Math.max(this.target, this.open - rate);
    this.apply();
  }

  private apply() {
    // Ease so it settles rather than clunking to a stop.
    const t = this.open * this.open * (3 - 2 * this.open);
    this.colliders.length = 0;
    let n = 0;
    for (const leaf of this.leaves) {
      const angle = leaf.raised * (1 - t);
      leaf.pivot.rotation.z = angle - leaf.raised;

      const spin = new THREE.Matrix3().set(
        Math.cos(leaf.pivot.rotation.z), -Math.sin(leaf.pivot.rotation.z), 0,
        Math.sin(leaf.pivot.rotation.z), Math.cos(leaf.pivot.rotation.z), 0,
        0, 0, 1,
      );
      for (const q of leaf.parts) {
        const worldPos = q.localPos.clone().applyMatrix3(spin);
        const worldRot = spin.clone().multiply(q.localRot);
        const p = this.scratchPart[n++];
        p.pos = [
          leaf.pivot.position.x + worldPos.x,
          leaf.pivot.position.y + worldPos.y,
          leaf.pivot.position.z + worldPos.z,
        ];
        // Matrix3.elements is column-major; the extractor's rot[] is row-major.
        const e = worldRot.elements;
        p.rot = [e[0], e[3], e[6], e[1], e[4], e[7], e[2], e[5], e[8]];
        this.colliders.push(makeCollider(p));
      }
    }
  }

  /** Live colliders for the flaps in their current pose. */
  current(): Collider[] {
    return this.colliders;
  }
}

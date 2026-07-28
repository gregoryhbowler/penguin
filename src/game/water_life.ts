import * as THREE from 'three';
import type { PartData } from '../engine/world';
import { waterAt } from '../art/water';

/**
 * Fish and splashes.
 *
 * The `FishSchool` tags came across from the Roblox build complete with their
 * `Count` and `Radius` attributes and never had anything reading them here.
 * Nine schools, ~60 fish: cheap enough to animate every frame on one instanced
 * mesh, and they're most of what makes the water feel occupied rather than
 * painted on.
 */

interface Fish {
  cx: number;
  cz: number;
  /** Orbit radius and phase, so a school circles instead of milling. */
  r: number;
  phase: number;
  speed: number;
  y: number;
  bob: number;
  scale: number;
}

function fishGeometry(): THREE.BufferGeometry {
  // A body that tapers to a point at both ends, plus a fan of a tail. Facing
  // is -Z, the same convention Pip uses.
  const body = new THREE.OctahedronGeometry(0.5, 0);
  body.scale(0.42, 0.62, 1.5);
  const tail = new THREE.ConeGeometry(0.34, 0.5, 3);
  tail.rotateX(-Math.PI / 2);
  tail.rotateZ(Math.PI / 2);
  tail.translate(0, 0, 0.85);
  const merged = new THREE.BufferGeometry();
  const bp = body.attributes.position.array as Float32Array;
  const tp = tail.attributes.position.array as Float32Array;
  const bi = body.index ? Array.from(body.index.array) : null;
  const ti = tail.index ? Array.from(tail.index.array) : null;
  const pos = new Float32Array(bp.length + tp.length);
  pos.set(bp, 0);
  pos.set(tp, bp.length);
  merged.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  if (bi && ti) {
    const off = bp.length / 3;
    merged.setIndex([...bi, ...ti.map((i) => i + off)]);
  }
  merged.computeVertexNormals();
  return merged;
}

export class FishSchools {
  mesh: THREE.InstancedMesh;
  private fish: Fish[] = [];
  private t = 0;
  private m = new THREE.Matrix4();
  private q = new THREE.Quaternion();
  private e = new THREE.Euler();
  private p = new THREE.Vector3();
  private s = new THREE.Vector3();

  constructor(schools: PartData[]) {
    // The tagged schools total 57 fish across the entire map, which in a river
    // this size is empty water. Thicken each one, then seed the whole channel
    // and the cove so there is something alive wherever you get in.
    const seeded: { pos: [number, number, number]; count: number; radius: number }[] = [];
    for (const p of schools) {
      seeded.push({
        pos: [p.pos[0], p.pos[1], p.pos[2]],
        count: Math.round(Number(p.attrs?.Count ?? 5) * 2.6),
        radius: Number(p.attrs?.Radius ?? 6) * 1.25,
      });
    }
    for (let z = -260; z <= 400; z += 44) {
      for (const x of [468, 492, 516]) {
        if (!waterAt(x, z)) continue;
        // Offset each shoal so the river doesn't read as a grid of fish.
        const jx = x + Math.sin(z * 0.13) * 9;
        const jz = z + Math.cos(x * 0.21 + z) * 12;
        if (!waterAt(jx, jz)) continue;
        seeded.push({ pos: [jx, 0, jz], count: 5 + Math.round((Math.sin(z * 1.7) * 0.5 + 0.5) * 4), radius: 9 });
      }
    }

    for (const p of seeded) {
      const count = p.count;
      const radius = p.radius;
      const w = waterAt(p.pos[0], p.pos[2]);
      // Schools outside a carved basin (the city fountain) keep their own
      // height; the rest sit a comfortable way under the surface.
      const surface = w ? w.level : p.pos[1] + 0.4;
      for (let i = 0; i < count; i++) {
        const a = (i / count) * Math.PI * 2;
        const rr = radius * (0.35 + 0.65 * ((Math.sin(i * 12.9898) * 0.5 + 0.5)));
        this.fish.push({
          cx: p.pos[0],
          cz: p.pos[2],
          r: rr,
          phase: a,
          speed: (0.25 + ((Math.sin(i * 7.13) * 0.5 + 0.5)) * 0.3) * (i % 2 ? 1 : -1),
          y: surface - 0.9 - ((Math.sin(i * 3.77) * 0.5 + 0.5)) * 1.8,
          bob: i * 1.7,
          scale: 0.8 + ((Math.sin(i * 5.51) * 0.5 + 0.5)) * 0.7,
        });
      }
    }

    // Silvery, but not luminous: under the surface tint anything paler than
    // this reads as floating paper rather than as fish.
    const mat = new THREE.MeshStandardMaterial({
      color: '#7d968e',
      roughness: 0.5,
      metalness: 0.12,
      emissive: new THREE.Color('#22383c'),
      emissiveIntensity: 0.2,
    });
    this.mesh = new THREE.InstancedMesh(fishGeometry(), mat, Math.max(1, this.fish.length));
    this.mesh.castShadow = false;
    this.mesh.frustumCulled = false;
    this.mesh.count = this.fish.length;
    this.mesh.name = 'Fish';
  }

  update(dt: number, player: THREE.Vector3) {
    this.t += dt;
    for (let i = 0; i < this.fish.length; i++) {
      const f = this.fish[i];
      // Skip the far half of the map entirely — no point spending matrix
      // writes on fish nobody can see through the haze.
      if (Math.abs(f.cx - player.x) > 260 || Math.abs(f.cz - player.z) > 260) {
        this.m.makeScale(0, 0, 0);
        this.mesh.setMatrixAt(i, this.m);
        continue;
      }
      const a = f.phase + this.t * f.speed;
      this.p.set(
        f.cx + Math.cos(a) * f.r,
        f.y + Math.sin(this.t * 1.4 + f.bob) * 0.22,
        f.cz + Math.sin(a) * f.r,
      );
      // Tangent to the orbit, plus a wriggle.
      const heading = Math.atan2(-Math.sin(a), -Math.cos(a)) + (f.speed > 0 ? Math.PI / 2 : -Math.PI / 2);
      this.e.set(0, heading, Math.sin(this.t * 9 + f.bob) * 0.18);
      this.q.setFromEuler(this.e);
      this.s.setScalar(f.scale);
      this.m.compose(this.p, this.q, this.s);
      this.mesh.setMatrixAt(i, this.m);
    }
    this.mesh.instanceMatrix.needsUpdate = true;
  }
}

interface Droplet {
  pos: THREE.Vector3;
  vel: THREE.Vector3;
  life: number;
}

/**
 * The payoff for the diving board. A ring that spreads on the surface plus a
 * burst of droplets — no textures, no particle library, just enough motion that
 * hitting the water reads as an event.
 */
export class Splashes {
  group = new THREE.Group();
  private drops: Droplet[] = [];
  private mesh: THREE.InstancedMesh;
  private rings: { mesh: THREE.Mesh; life: number; max: number }[] = [];
  private m = new THREE.Matrix4();
  private p = new THREE.Vector3();
  private q = new THREE.Quaternion();
  private s = new THREE.Vector3();
  private static MAX = 90;

  constructor() {
    this.group.name = 'Splashes';
    const mat = new THREE.MeshBasicMaterial({ color: '#e8f4f2', transparent: true, opacity: 0.9 });
    this.mesh = new THREE.InstancedMesh(new THREE.SphereGeometry(0.22, 6, 5), mat, Splashes.MAX);
    this.mesh.frustumCulled = false;
    this.mesh.count = 0;
    this.group.add(this.mesh);
  }

  /** @param force impact speed — a belly-flop from the bridge throws more water. */
  burst(x: number, y: number, z: number, force: number) {
    const n = Math.min(26, 8 + Math.round(force * 0.5));
    const power = Math.min(16, 4 + force * 0.35);
    for (let i = 0; i < n && this.drops.length < Splashes.MAX; i++) {
      const a = (i / n) * Math.PI * 2 + Math.random() * 0.4;
      const out = 0.4 + Math.random() * 0.9;
      this.drops.push({
        pos: new THREE.Vector3(x + Math.cos(a) * 0.5, y, z + Math.sin(a) * 0.5),
        vel: new THREE.Vector3(
          Math.cos(a) * power * out * 0.45,
          power * (0.6 + Math.random() * 0.7),
          Math.sin(a) * power * out * 0.45,
        ),
        life: 0.75 + Math.random() * 0.5,
      });
    }

    const ring = new THREE.Mesh(
      new THREE.RingGeometry(0.6, 1.1, 24),
      new THREE.MeshBasicMaterial({
        color: '#dcecea', transparent: true, opacity: 0.75,
        side: THREE.DoubleSide, depthWrite: false,
      }),
    );
    ring.rotation.x = -Math.PI / 2;
    ring.position.set(x, y + 0.06, z);
    ring.renderOrder = 6;
    this.group.add(ring);
    this.rings.push({ mesh: ring, life: 0.9, max: 0.9 });
  }

  update(dt: number) {
    for (let i = this.drops.length - 1; i >= 0; i--) {
      const d = this.drops[i];
      d.vel.y -= 60 * dt;
      d.pos.addScaledVector(d.vel, dt);
      d.life -= dt;
      if (d.life <= 0) this.drops.splice(i, 1);
    }
    for (let i = 0; i < this.drops.length; i++) {
      const d = this.drops[i];
      this.p.copy(d.pos);
      this.s.setScalar(Math.max(0.25, Math.min(1, d.life * 1.6)));
      this.m.compose(this.p, this.q, this.s);
      this.mesh.setMatrixAt(i, this.m);
    }
    this.mesh.count = this.drops.length;
    if (this.drops.length) this.mesh.instanceMatrix.needsUpdate = true;

    for (let i = this.rings.length - 1; i >= 0; i--) {
      const r = this.rings[i];
      r.life -= dt;
      const t = 1 - r.life / r.max;
      r.mesh.scale.setScalar(1 + t * 5.5);
      (r.mesh.material as THREE.MeshBasicMaterial).opacity = 0.75 * (1 - t);
      if (r.life <= 0) {
        this.group.remove(r.mesh);
        r.mesh.geometry.dispose();
        (r.mesh.material as THREE.Material).dispose();
        this.rings.splice(i, 1);
      }
    }
  }
}

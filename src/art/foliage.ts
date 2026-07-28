import * as THREE from 'three';
import type { PartData } from '../engine/world';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { withWhiteColors } from './scene';

/**
 * The Roblox build's trees were stacked boxes tagged `Leaves`. They read as
 * Minecraft, not Miyazaki. Here each Leaves box becomes an irregular canopy
 * blob with baked colour variation and a wind shader, and the ferns get the
 * same breeze — which is most of the distance between "blocky" and "painterly".
 */

/** Injects wind sway into any MeshStandardMaterial, driven by world position. */
export function makeWindMaterial(
  base: THREE.MeshStandardMaterial,
  opts: { strength?: number; speed?: number; anchorY?: number } = {},
): THREE.MeshStandardMaterial {
  const strength = opts.strength ?? 0.35;
  const speed = opts.speed ?? 1.0;
  base.onBeforeCompile = (shader) => {
    shader.uniforms.uTime = { value: 0 };
    shader.uniforms.uWind = { value: strength };
    shader.uniforms.uSpeed = { value: speed };
    (base as any).userData.shader = shader;

    shader.vertexShader = shader.vertexShader
      .replace(
        '#include <common>',
        `#include <common>
         uniform float uTime;
         uniform float uWind;
         uniform float uSpeed;`,
      )
      .replace(
        '#include <begin_vertex>',
        `#include <begin_vertex>
         #ifdef USE_INSTANCING
           vec3 instOrigin = vec3(instanceMatrix[3][0], instanceMatrix[3][1], instanceMatrix[3][2]);
         #else
           vec3 instOrigin = vec3(modelMatrix[3][0], modelMatrix[3][1], modelMatrix[3][2]);
         #endif
         // Sway grows toward the top of each element so trunks stay planted.
         float sway = clamp(position.y + 0.5, 0.0, 1.5);
         float phase = instOrigin.x * 0.09 + instOrigin.z * 0.11;
         float t = uTime * uSpeed;
         transformed.x += sin(t * 1.3 + phase) * uWind * sway;
         transformed.z += cos(t * 0.9 + phase * 1.7) * uWind * sway * 0.7;
         transformed.y += sin(t * 2.1 + phase) * uWind * sway * 0.12;`,
      );
  };
  return base;
}

export function tickWind(mat: THREE.Material, t: number) {
  const shader = (mat as any).userData?.shader;
  if (shader) shader.uniforms.uTime.value = t;
}

/**
 * Fake leaf translucency. Real foliage glows where light passes *through* it,
 * and that rim of lit green against shadow is most of what makes Breath of the
 * Wild's trees look alive. Cheap approximation: brighten toward the silhouette
 * edge, tinted by the leaf's own colour.
 */
export function addLeafTranslucency(mat: THREE.MeshStandardMaterial, amount = 0.5) {
  const prev = mat.onBeforeCompile;
  mat.onBeforeCompile = (shader, renderer) => {
    prev?.call(mat, shader, renderer);
    shader.uniforms.uSSS = { value: amount };
    shader.fragmentShader = shader.fragmentShader
      .replace('#include <common>', '#include <common>\nuniform float uSSS;')
      .replace(
        '#include <dithering_fragment>',
        `#include <dithering_fragment>
         // vViewPosition points from the fragment to the camera in view space.
         float facing = abs(dot(normalize(normal), normalize(vViewPosition)));
         float rim = pow(1.0 - facing, 2.2);
         gl_FragColor.rgb += diffuseColor.rgb * rim * uSSS;`,
      );
  };
}

/** A lumpy, hand-carved-looking canopy blob. */
function canopyGeometry(): THREE.BufferGeometry {
  const geo = new THREE.IcosahedronGeometry(0.5, 2);
  const pos = geo.attributes.position as THREE.BufferAttribute;
  const v = new THREE.Vector3();
  for (let i = 0; i < pos.count; i++) {
    v.fromBufferAttribute(pos, i);
    const n =
      Math.sin(v.x * 7.3) * Math.cos(v.y * 6.1) * 0.5 +
      Math.sin(v.z * 9.7 + v.x * 3.1) * 0.5;
    v.multiplyScalar(1 + n * 0.16);
    // Flatten slightly so canopies read as layered fans, not beach balls.
    v.y *= 0.86;
    pos.setXYZ(i, v.x, v.y, v.z);
  }
  geo.computeVertexNormals();
  return geo;
}

export interface FoliageResult {
  group: THREE.Group;
  /** Parts consumed here so the generic world builder skips them. */
  consumed: Set<PartData>;
  materials: THREE.Material[];
}

export function buildFoliage(parts: PartData[]): FoliageResult {
  const group = new THREE.Group();
  group.name = 'Foliage';
  const consumed = new Set<PartData>();
  const materials: THREE.Material[] = [];

  const leaves = parts.filter((p) => p.name === 'Leaves' || p.name === 'Blossoms');
  const ferns = parts.filter((p) => p.name === 'FernFan');

  // ---------------- canopies ----------------
  if (leaves.length) {
    const mat = makeWindMaterial(
      new THREE.MeshStandardMaterial({
        vertexColors: true,
        roughness: 0.92,
        metalness: 0,
        flatShading: true,
      }),
      { strength: 0.42, speed: 0.85 },
    );
    addLeafTranslucency(mat, 0.55);
    materials.push(mat);

    const geo = withWhiteColors(canopyGeometry());
    const mesh = new THREE.InstancedMesh(geo, mat, leaves.length * 3);
    mesh.castShadow = true;
    mesh.receiveShadow = true;

    const m = new THREE.Matrix4();
    const q = new THREE.Quaternion();
    const e = new THREE.Euler();
    const scale = new THREE.Vector3();
    const posv = new THREE.Vector3();
    const color = new THREE.Color();
    let i = 0;

    leaves.forEach((p, li) => {
      consumed.add(p);
      const base = p.color
        ? new THREE.Color(p.color[0] / 255, p.color[1] / 255, p.color[2] / 255)
        : new THREE.Color('#3d6030');
      // Three overlapping blobs per box: a fuller, less regular silhouette.
      for (let k = 0; k < 3; k++) {
        const rnd = (n: number) => Math.sin(li * 12.9898 + k * 78.233 + n) * 0.5;
        const sx = p.size[0] * (1.02 + rnd(1) * 0.22);
        const sy = p.size[1] * (1.0 + rnd(2) * 0.22);
        const sz = p.size[2] * (1.02 + rnd(3) * 0.22);
        posv.set(
          p.pos[0] + rnd(4) * p.size[0] * 0.3,
          p.pos[1] + rnd(5) * p.size[1] * 0.22,
          p.pos[2] + rnd(6) * p.size[2] * 0.3,
        );
        e.set(rnd(7) * 0.7, rnd(8) * 3.14, rnd(9) * 0.7);
        q.setFromEuler(e);
        scale.set(sx, sy, sz);
        m.compose(posv, q, scale);
        mesh.setMatrixAt(i, m);
        // Vary each blob a little; sunlit tops slightly warmer-green.
        color.copy(base)
          .offsetHSL(rnd(10) * 0.03, rnd(11) * 0.06, rnd(12) * 0.09 + k * 0.015);
        mesh.setColorAt(i, color);
        i++;
      }
    });
    mesh.count = i;
    mesh.instanceMatrix.needsUpdate = true;
    if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
    group.add(mesh);
  }

  // ---------------- ferns ----------------
  if (ferns.length) {
    const mat = makeWindMaterial(
      new THREE.MeshStandardMaterial({
        vertexColors: true,
        roughness: 0.95,
        metalness: 0,
        side: THREE.DoubleSide,
        flatShading: true,
      }),
      { strength: 0.22, speed: 1.5 },
    );
    addLeafTranslucency(mat, 0.4);
    materials.push(mat);

    // A frond: a tapered blade, not a flat rectangle.
    const blade = new THREE.PlaneGeometry(1, 1, 1, 4);
    const bp = blade.attributes.position as THREE.BufferAttribute;
    for (let i = 0; i < bp.count; i++) {
      const y = bp.getY(i) + 0.5;
      bp.setX(i, bp.getX(i) * (1 - y * 0.75));
      bp.setZ(i, Math.sin(y * 2.2) * 0.14);
    }
    blade.translate(0, 0.5, 0);
    blade.computeVertexNormals();

    const mesh = new THREE.InstancedMesh(withWhiteColors(blade), mat, ferns.length);
    mesh.castShadow = false;
    mesh.receiveShadow = true;
    const m = new THREE.Matrix4();
    const q = new THREE.Quaternion();
    const e = new THREE.Euler();
    const color = new THREE.Color();
    ferns.forEach((p, i) => {
      consumed.add(p);
      const len = Math.max(p.size[0], p.size[2]);
      e.set(-0.25, Math.atan2(p.rot[2], p.rot[0]), 0);
      q.setFromEuler(e);
      m.compose(
        new THREE.Vector3(p.pos[0], p.pos[1] - 0.2, p.pos[2]),
        q,
        new THREE.Vector3(len * 0.55, len * 1.15, len * 0.55),
      );
      mesh.setMatrixAt(i, m);
      const base = p.color
        ? new THREE.Color(p.color[0] / 255, p.color[1] / 255, p.color[2] / 255)
        : new THREE.Color('#4a6b3c');
      color.copy(base).offsetHSL(0, 0, (Math.sin(i * 3.7) * 0.5) * 0.08);
      mesh.setColorAt(i, color);
    });
    mesh.instanceMatrix.needsUpdate = true;
    if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
    group.add(mesh);
  }

  return { group, consumed, materials };
}

/**
 * Ground cover around the player.
 *
 * Scattering into a disc centred on Pip made the whole field slide with him —
 * a very visible travelling circle of grass. Instead the world is diced into
 * fixed tiles, each seeded from its own coordinates, and only the tiles near
 * Pip are populated. Tufts therefore stay put: you walk past them, and the
 * boundary lives far enough out that haze hides it.
 */
export class GrassField {
  mesh: THREE.InstancedMesh;
  material: THREE.MeshStandardMaterial;
  private tile: number;
  private tilesAcross: number;
  private perTile: number;
  private lastTile = { x: 1e9, z: 1e9 };

  constructor(
    private count: number,
    private radius: number,
    private groundY: (x: number, z: number) => number,
    private blocked?: (x: number, z: number, y: number) => boolean,
  ) {
    // Tiles roughly 14 studs across gives a 7x7 neighbourhood at radius ~49.
    this.tile = 14;
    this.tilesAcross = Math.max(3, Math.ceil((radius * 2) / this.tile) | 1);
    this.perTile = Math.max(1, Math.floor(count / (this.tilesAcross ** 2)));
    // A tuft of three crossed blades reads far softer than a single spike.
    const blades: THREE.BufferGeometry[] = [];
    for (let b = 0; b < 3; b++) {
      const g = new THREE.PlaneGeometry(0.26, 0.5, 1, 3);
      const gp = g.attributes.position as THREE.BufferAttribute;
      for (let i = 0; i < gp.count; i++) {
        const t = gp.getY(i) / 0.55 + 0.5;      // 0 at base, 1 at tip
        gp.setX(i, gp.getX(i) * (1 - t * 0.7)); // taper
        gp.setZ(i, t * t * 0.16);               // gentle forward curl
      }
      g.translate(0, 0.275, 0);
      g.rotateY((b / 3) * Math.PI);
      g.rotateZ((b - 1) * 0.12);
      blades.push(g);
    }
    const blade = mergeGeometries(blades);

    // Grass blades stand vertically, so their true normals face sideways and
    // an overhead sun leaves them almost black. Pointing the normals up makes
    // them catch sky light the way real turf reads.
    const bn = blade.attributes.normal as THREE.BufferAttribute;
    for (let i = 0; i < bn.count; i++) {
      const n = new THREE.Vector3(bn.getX(i), bn.getY(i), bn.getZ(i));
      n.lerp(new THREE.Vector3(0, 1, 0), 0.82).normalize();
      bn.setXYZ(i, n.x, n.y, n.z);
    }
    bn.needsUpdate = true;

    this.material = makeWindMaterial(
      new THREE.MeshStandardMaterial({
        vertexColors: true,
        roughness: 0.96,
        metalness: 0,
        side: THREE.DoubleSide,
      }),
      { strength: 0.14, speed: 2.1 },
    );
    // Double-sided blades flip their normal on back faces, which turned half
    // the field black. Turf doesn't need real shading — pin the lighting
    // normal to world-up so every blade catches the sky evenly.
    const windCompile = this.material.onBeforeCompile;
    this.material.onBeforeCompile = (shader, renderer) => {
      windCompile?.call(this.material, shader, renderer);
      shader.fragmentShader = shader.fragmentShader.replace(
        '#include <normal_fragment_begin>',
        `#include <normal_fragment_begin>
         normal = normalize(vec3(0.0, 1.0, 0.0));`,
      );
    };
    this.mesh = new THREE.InstancedMesh(withWhiteColors(blade), this.material, count);
    this.mesh.castShadow = false;
    this.mesh.receiveShadow = true;
    this.mesh.frustumCulled = false;
  }

  update(center: THREE.Vector3) {
    const tx = Math.round(center.x / this.tile);
    const tz = Math.round(center.z / this.tile);
    // Nothing to do until Pip crosses into a new tile.
    if (tx === this.lastTile.x && tz === this.lastTile.z) return;
    this.lastTile.x = tx;
    this.lastTile.z = tz;

    const m = new THREE.Matrix4();
    const q = new THREE.Quaternion();
    const e = new THREE.Euler();
    const pos = new THREE.Vector3();
    const scale = new THREE.Vector3();
    const color = new THREE.Color();
    const green = new THREE.Color('#5f7d43');
    const half = (this.tilesAcross - 1) / 2;
    // Positions hash off absolute tile coords, so a tuft occupies the same
    // patch of world every time that tile comes back into range.
    const hash = (a: number, b: number, salt: number) => {
      const s = Math.sin(a * 127.1 + b * 311.7 + salt * 74.7) * 43758.5453;
      return s - Math.floor(s);
    };

    let i = 0;
    for (let ox = -half; ox <= half; ox++) {
      for (let oz = -half; oz <= half; oz++) {
        const cellX = tx + ox;
        const cellZ = tz + oz;
        for (let k = 0; k < this.perTile && i < this.count; k++, i++) {
          const x = (cellX + hash(cellX, cellZ, k) - 0.5) * this.tile;
          const z = (cellZ + hash(cellZ, cellX, k + 91) - 0.5) * this.tile;
          const y = this.groundY(x, z);

          // Fade the outermost ring out rather than ending on a hard circle.
          const d = Math.hypot(x - center.x, z - center.z);
          const fade = 1 - THREE.MathUtils.smoothstep(d, this.radius * 0.72, this.radius);

          if (fade <= 0.02 || this.blocked?.(x, z, y)) {
            m.makeScale(0, 0, 0); // a path, a deck, a floor — or out of range
            this.mesh.setMatrixAt(i, m);
            continue;
          }
          pos.set(x, y, z);
          e.set(0, hash(cellX, cellZ, k + 17) * Math.PI, (hash(cellX, cellZ, k + 43) - 0.5) * 0.24);
          q.setFromEuler(e);
          const h = (0.42 + hash(cellX, cellZ, k + 5) * 0.4) * fade;
          scale.set(1, h, 1);
          m.compose(pos, q, scale);
          this.mesh.setMatrixAt(i, m);
          color.copy(green).offsetHSL(
            (hash(cellX, cellZ, k + 3) - 0.5) * 0.04,
            0,
            (hash(cellX, cellZ, k + 7) - 0.5) * 0.09,
          );
          this.mesh.setColorAt(i, color);
        }
      }
    }
    // Park any leftovers out of sight.
    for (; i < this.count; i++) {
      m.makeScale(0, 0, 0);
      this.mesh.setMatrixAt(i, m);
    }
    this.mesh.instanceMatrix.needsUpdate = true;
    if (this.mesh.instanceColor) this.mesh.instanceColor.needsUpdate = true;
  }
}

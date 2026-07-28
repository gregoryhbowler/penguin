import * as THREE from 'three';
import type { PartData } from '../engine/world';
import { partMatrix } from '../engine/world';
import { BODIES, GROUND_DATUM, RIVER, carve, shoreBlend } from './water';

/**
 * Palette law.
 *
 * The world sheets are bright: deep blue skies, big cumulus, saturated meadow
 * greens, real sun. So the old overcast-teal grade is gone, but the half of the
 * law that mattered stays — warm colour is RESERVED. Fires, lanterns and embers
 * are the only warm things in Ember Grove and the only things bright enough to
 * bloom. Spirits glow cool. That is what keeps a fire readable as the one thing
 * in the frame that matters.
 */
export const PALETTE = {
  // Distance haze is the signature Breath-of-the-Wild move: far geometry
  // washes toward a pale sky tint, which reads as scale and open air. Bluer
  // and lighter than before, so distance reads as air rather than as murk.
  fog: new THREE.Color('#bcd8e6'),
  sun: new THREE.Color('#fff6e2'),
  skyLight: new THREE.Color('#8ec6ec'),
  bounce: new THREE.Color('#6d9459'),
  ground: new THREE.Color('#71a047'),
  groundDark: new THREE.Color('#4c7434'),
  groundDry: new THREE.Color('#a0ac5e'),
  // The shore reads as a place, not a boundary: pale wet shingle at the
  // waterline, darkening to silt as the bed drops away.
  shore: new THREE.Color('#a49a78'),
  bed: new THREE.Color('#3f5750'),
};

interface MatSpec { roughness: number; metalness: number; emissive?: boolean }

const MATERIALS: Record<string, MatSpec> = {
  Grass: { roughness: 0.96, metalness: 0 },
  LeafyGrass: { roughness: 0.98, metalness: 0 },
  Wood: { roughness: 0.82, metalness: 0 },
  WoodPlanks: { roughness: 0.8, metalness: 0 },
  Brick: { roughness: 0.9, metalness: 0 },
  Concrete: { roughness: 0.92, metalness: 0 },
  Slate: { roughness: 0.62, metalness: 0.08 },
  Cobblestone: { roughness: 0.88, metalness: 0 },
  Rock: { roughness: 0.86, metalness: 0 },
  Pebble: { roughness: 0.84, metalness: 0 },
  Sand: { roughness: 0.96, metalness: 0 },
  Snow: { roughness: 0.7, metalness: 0 },
  Ice: { roughness: 0.12, metalness: 0.1 },
  Glacier: { roughness: 0.18, metalness: 0.08 },
  Metal: { roughness: 0.36, metalness: 0.9 },
  CorrodedMetal: { roughness: 0.74, metalness: 0.6 },
  DiamondPlate: { roughness: 0.4, metalness: 0.85 },
  Foil: { roughness: 0.24, metalness: 0.95 },
  Fabric: { roughness: 0.97, metalness: 0 },
  Plastic: { roughness: 0.52, metalness: 0 },
  SmoothPlastic: { roughness: 0.42, metalness: 0 },
  Neon: { roughness: 0.4, metalness: 0, emissive: true },
  Ground: { roughness: 0.94, metalness: 0 },
  Asphalt: { roughness: 0.88, metalness: 0 },
  Sandstone: { roughness: 0.88, metalness: 0 },
  ClayRoofTiles: { roughness: 0.82, metalness: 0 },
  Carpet: { roughness: 0.99, metalness: 0 },
};

export function createRenderer(canvas: HTMLCanvasElement, pixelRatio: number): THREE.WebGLRenderer {
  const renderer = new THREE.WebGLRenderer({
    canvas,
    antialias: true,
    powerPreference: 'high-performance',
    stencil: false,
  });
  renderer.setPixelRatio(pixelRatio);
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.1;
  return renderer;
}

export function createScene(shadowSize: number): {
  scene: THREE.Scene;
  sun: THREE.DirectionalLight;
  sunDir: THREE.Vector3;
} {
  const scene = new THREE.Scene();
  scene.fog = new THREE.FogExp2(PALETTE.fog.clone(), 0.0011);

  // Less ambient wash than before: an overcast sky fills every crevice, a sunny
  // one does not, and the shadows are most of what makes the sheet's landscapes
  // read as three-dimensional.
  const hemi = new THREE.HemisphereLight(PALETTE.skyLight, PALETTE.bounce, 1.05);
  scene.add(hemi);

  const sunDir = new THREE.Vector3(-0.55, 0.68, 0.48).normalize();
  const sun = new THREE.DirectionalLight(PALETTE.sun, 3.3);
  sun.position.copy(sunDir).multiplyScalar(160);
  sun.castShadow = true;
  sun.shadow.mapSize.set(shadowSize, shadowSize);
  sun.shadow.camera.near = 1;
  sun.shadow.camera.far = 520;
  const S = 95; // tight frustum, kept centred on Pip for crisp contact shadows
  sun.shadow.camera.left = -S;
  sun.shadow.camera.right = S;
  sun.shadow.camera.top = S;
  sun.shadow.camera.bottom = -S;
  sun.shadow.bias = -0.0004;
  sun.shadow.normalBias = 0.05;
  scene.add(sun);
  scene.add(sun.target);

  // A cool fill from the opposite side stops shadowed faces going to mud.
  const fill = new THREE.DirectionalLight(new THREE.Color('#9cc7e8'), 0.5);
  fill.position.set(80, 40, -70);
  scene.add(fill);

  return { scene, sun, sunDir };
}

/**
 * The dry-land datum.
 *
 * Roblox terrain is a voxel blob that doesn't survive export, so this is
 * authored — and away from water it must stay FLAT at y=2, because every one of
 * the 3,748 parts was placed against flat terrain. An earlier version rolled by
 * +-2.6 studs and buried 113 collidable parts outright while slicing through
 * 361 more: logs and curbs sunk out of sight became invisible walls you had to
 * jump. Keep the variation well under a step height.
 */
export function datumHeight(x: number, z: number): number {
  const a = Math.sin(x * 0.0121) * Math.cos(z * 0.0138) * 0.05;
  const b = Math.sin((x + z) * 0.0295) * 0.03;
  return GROUND_DATUM + a + b;
}

/**
 * The walkable ground: the datum with the river, cove and ponds cut into it.
 * Every basin is carved well clear of the placed geometry (see `water.ts` for
 * how the bank lines were derived from the world's own piers and slipways), so
 * the flat-terrain guarantee still holds everywhere a part actually sits.
 */
export function groundHeight(x: number, z: number): number {
  return carve(x, z, datumHeight(x, z));
}

const PLANE = 2600;
const COARSE = PLANE / 300;   // 8.67 studs — plenty for flat ground
const FINE = COARSE / 3;      // ~2.9 studs — resolves a 12-stud river bank

/** Regions cut out of the coarse grid and re-tessellated finely. */
function waterPatches(): { x0: number; x1: number; z0: number; z1: number }[] {
  const snap = (v: number, dir: number) => {
    const i = (v + PLANE / 2) / COARSE;
    return (dir < 0 ? Math.floor(i) : Math.ceil(i)) * COARSE - PLANE / 2;
  };
  const out: { x0: number; x1: number; z0: number; z1: number }[] = [];
  for (const b of BODIES) {
    // The river spans the whole plane in z; everything else gets its bounds
    // plus a bank's worth of margin.
    const m = 16;
    const x0 = snap(b.bounds.x0 - m, -1);
    const x1 = snap(b.bounds.x1 + m, 1);
    const z0 = b === RIVER ? -PLANE / 2 : snap(b.bounds.z0 - m, -1);
    const z1 = b === RIVER ? PLANE / 2 : snap(b.bounds.z1 + m, 1);
    // The cove sits inside the river's patch already.
    if (out.some((r) => x0 >= r.x0 && x1 <= r.x1 && z0 >= r.z0 && z1 <= r.z1)) continue;
    out.push({ x0, x1, z0, z1 });
  }
  return out;
}

/**
 * One merged terrain mesh built by hand rather than from PlaneGeometry, because
 * the water needs four times the resolution the rest of the map does and a
 * uniform grid fine enough for a river bank would be 750k vertices. Coarse
 * quads are simply omitted where a fine patch covers them; the patches align to
 * the coarse lattice, so the seam is between two flat pieces of ground and does
 * not show.
 */
export function createGround(): THREE.Mesh {
  const patches = waterPatches();
  const positions: number[] = [];
  const colors: number[] = [];
  const indices: number[] = [];
  const c = new THREE.Color();

  const inPatch = (x: number, z: number) =>
    patches.some((r) => x >= r.x0 && x < r.x1 && z >= r.z0 && z < r.z1);

  const emit = (
    x0: number, x1: number, z0: number, z1: number, step: number,
    skipCell?: (cx: number, cz: number) => boolean,
  ) => {
    const nx = Math.round((x1 - x0) / step);
    const nz = Math.round((z1 - z0) / step);
    const base = positions.length / 3;

    for (let iz = 0; iz <= nz; iz++) {
      const z = z0 + iz * step;
      for (let ix = 0; ix <= nx; ix++) {
        const x = x0 + ix * step;
        const datum = datumHeight(x, z);
        const y = carve(x, z, datum);
        positions.push(x, y, z);

        // Blend moss / dark hollow / dry patch by a couple of noise octaves so
        // a huge plane never reads as one flat colour...
        const n1 = (Math.sin(x * 0.031) * Math.cos(z * 0.027) + 1) / 2;
        const n2 = (Math.sin(x * 0.0071 + 2.1) * Math.cos(z * 0.0083) + 1) / 2;
        c.copy(PALETTE.ground)
          .lerp(PALETTE.groundDark, n1 * 0.55)
          .lerp(PALETTE.groundDry, Math.pow(n2, 3) * 0.4);
        // ...then wash it out to shingle at the waterline and silt below.
        //
        // The band is keyed to how far into the basin the point is, NOT to how
        // far it has dropped. Depth put the whole beach inside two studs — the
        // banks are steep — and green grass ran straight into the water with no
        // shore at all. Proximity gives it the width it needs to read.
        const shore = shoreBlend(x, z);
        if (shore > -0.5) {
          c.lerp(PALETTE.shore, THREE.MathUtils.smoothstep(shore, -0.45, 0.22) * 0.9);
          c.lerp(PALETTE.bed, THREE.MathUtils.smoothstep(datum - y, 1.2, 5.5) * 0.8);
        }
        colors.push(c.r, c.g, c.b);
      }
    }

    for (let iz = 0; iz < nz; iz++) {
      for (let ix = 0; ix < nx; ix++) {
        if (skipCell?.(x0 + ix * step, z0 + iz * step)) continue;
        const a = base + iz * (nx + 1) + ix;
        const b = a + 1;
        const d = a + (nx + 1);
        const e = d + 1;
        indices.push(a, d, b, b, d, e);
      }
    }
  };

  emit(-PLANE / 2, PLANE / 2, -PLANE / 2, PLANE / 2, COARSE, inPatch);
  for (const r of patches) emit(r.x0, r.x1, r.z0, r.z1, FINE);

  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geo.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
  geo.setIndex(indices);
  geo.computeVertexNormals();
  geo.computeBoundingSphere();

  const mesh = new THREE.Mesh(
    geo,
    new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.97, metalness: 0 }),
  );
  mesh.receiveShadow = true;
  mesh.name = 'Ground';
  return mesh;
}

/** InstancedMesh.setColorAt only reaches the shader when the material has
 *  vertexColors on, and that in turn requires a `color` attribute to exist —
 *  without it every instance renders black. */
export function withWhiteColors(geo: THREE.BufferGeometry): THREE.BufferGeometry {
  const n = geo.attributes.position.count;
  if (!geo.attributes.color) {
    geo.setAttribute('color', new THREE.BufferAttribute(new Float32Array(n * 3).fill(1), 3));
  }
  return geo;
}

function geometryFor(shape: string): THREE.BufferGeometry {
  switch (shape) {
    case 'Ball':
      return new THREE.SphereGeometry(0.5, 18, 14);
    case 'Cylinder': {
      const g = new THREE.CylinderGeometry(0.5, 0.5, 1, 22);
      g.rotateZ(Math.PI / 2); // Roblox cylinders lie along local X
      return g;
    }
    case 'Wedge': {
      // Ramp geometry: low at -Z, high at +Z, matching what the collider in
      // world.ts assumes.
      //
      // Every one of these eight triangles used to be wound the other way, so
      // computeVertexNormals pointed all of them inward and back-face culling
      // ate the surfaces you were meant to be looking at. That is every ramp in
      // the game — the lookout tower's 26 steps, the sky stairs, the boat
      // slipways, the Lido — rendering inside-out and reading as not solid.
      const g = new THREE.BufferGeometry();
      const v = new Float32Array([
        -0.5,-0.5,-0.5,  0.5, 0.5, 0.5,  0.5,-0.5,-0.5,   // slope
        -0.5,-0.5,-0.5, -0.5, 0.5, 0.5,  0.5, 0.5, 0.5,   // slope
        -0.5,-0.5,-0.5,  0.5,-0.5, 0.5, -0.5,-0.5, 0.5,   // underside
        -0.5,-0.5,-0.5,  0.5,-0.5,-0.5,  0.5,-0.5, 0.5,   // underside
        -0.5,-0.5, 0.5,  0.5, 0.5, 0.5, -0.5, 0.5, 0.5,   // tall end (+Z)
        -0.5,-0.5, 0.5,  0.5,-0.5, 0.5,  0.5, 0.5, 0.5,   // tall end (+Z)
        -0.5,-0.5,-0.5, -0.5,-0.5, 0.5, -0.5, 0.5, 0.5,   // side (-X)
         0.5,-0.5,-0.5,  0.5, 0.5, 0.5,  0.5,-0.5, 0.5,   // side (+X)
      ]);
      g.setAttribute('position', new THREE.BufferAttribute(v, 3));
      g.computeVertexNormals();
      return g;
    }
    default:
      return new THREE.BoxGeometry(1, 1, 1);
  }
}

/**
 * One InstancedMesh per (shape, material) with colour supplied per instance.
 * Keying on colour too would give ~500 buckets; this gives a few dozen, which
 * is the difference between smooth and unplayable on a tablet.
 */
export function buildWorldMeshes(parts: PartData[], skip?: Set<PartData>): THREE.Group {
  const group = new THREE.Group();
  group.name = 'World';

  const buckets = new Map<string, { spec: MatSpec; shape: string; parts: PartData[]; transparent: boolean }>();
  for (const p of parts) {
    if (skip?.has(p)) continue;
    const tr = p.transparency ?? 0;
    if (tr >= 0.98) continue; // invisible markers and zone volumes
    const shape = p.shape ?? (p.class === 'WedgePart' ? 'Wedge' : 'Block');
    const mat = p.material ?? 'SmoothPlastic';
    const key = `${shape}|${mat}|${tr > 0 ? 't' : 'o'}`;
    let b = buckets.get(key);
    if (!b) {
      buckets.set(key, (b = {
        spec: MATERIALS[mat] ?? { roughness: 0.8, metalness: 0 },
        shape, parts: [], transparent: tr > 0,
      }));
    }
    b.parts.push(p);
  }

  const m = new THREE.Matrix4();
  const scale = new THREE.Matrix4();
  const color = new THREE.Color();

  for (const b of buckets.values()) {
    const material = new THREE.MeshStandardMaterial({
      roughness: b.spec.roughness,
      metalness: b.spec.metalness,
      transparent: b.transparent,
      opacity: b.transparent ? 1 - (b.parts[0].transparency ?? 0) : 1,
      vertexColors: true,
    });
    if (b.spec.emissive) {
      // Emission can't vary per instance, so a white emissive threw away the
      // authored colour of all 204 lit bands and 90 windows and rendered every
      // one of them as a blown-out white rectangle. Tint the glow by the
      // instance colour in the shader instead, and keep the intensity under the
      // bloom threshold: a lit window should read as lit, not as a floodlight,
      // and warm bloom stays reserved for fire.
      material.emissive = new THREE.Color(0xffffff);
      material.emissiveIntensity = 0.5;
      material.onBeforeCompile = (shader) => {
        shader.fragmentShader = shader.fragmentShader.replace(
          '#include <emissivemap_fragment>',
          // `.rgb` matters: three declares vColor as a vec4 here, and assigning
          // it straight to the vec3 radiance fails to compile — which silently
          // drops every window and lit band in the city.
          '#include <emissivemap_fragment>\n\ttotalEmissiveRadiance *= vColor.rgb;',
        );
      };
    }

    const mesh = new THREE.InstancedMesh(withWhiteColors(geometryFor(b.shape)), material, b.parts.length);
    mesh.castShadow = !b.spec.emissive;
    mesh.receiveShadow = true;

    b.parts.forEach((p, i) => {
      scale.makeScale(p.size[0], p.size[1], p.size[2]);
      m.copy(partMatrix(p)).multiply(scale);
      mesh.setMatrixAt(i, m);
      const c = p.color ?? [160, 160, 160];
      color.setRGB(c[0] / 255, c[1] / 255, c[2] / 255, THREE.SRGBColorSpace);
      mesh.setColorAt(i, color);
    });
    mesh.instanceMatrix.needsUpdate = true;
    if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
    group.add(mesh);
  }

  return group;
}

import * as THREE from 'three';
import type { PartData } from '../engine/world';
import { partMatrix } from '../engine/world';

/**
 * The Ember Inspo palette law, enforced by the renderer rather than by hand:
 * the world is graded to moss / cold stone / overcast teal, and ONLY emissive
 * things (fire, spirits, lanterns) are allowed to be warm — so they bloom and
 * nothing else does.
 */
export const PALETTE = {
  fogNear: new THREE.Color('#7fa3a0'),
  fogFar: new THREE.Color('#5b7f86'),
  skyTop: new THREE.Color('#5d8894'),
  skyBottom: new THREE.Color('#9db9b3'),
  sun: new THREE.Color('#dfeae4'),
  bounce: new THREE.Color('#4d6b58'),
  ground: new THREE.Color('#5b7247'),
};

interface MatSpec {
  roughness: number;
  metalness: number;
  emissive?: boolean;
  /** Multiplied into the part's own colour to pull it toward the palette. */
  tint?: THREE.Color;
}

const MATERIALS: Record<string, MatSpec> = {
  Grass:        { roughness: 0.96, metalness: 0 },
  LeafyGrass:   { roughness: 0.98, metalness: 0 },
  Wood:         { roughness: 0.85, metalness: 0 },
  WoodPlanks:   { roughness: 0.82, metalness: 0 },
  Brick:        { roughness: 0.92, metalness: 0 },
  Concrete:     { roughness: 0.94, metalness: 0 },
  Slate:        { roughness: 0.7,  metalness: 0.05 },
  Cobblestone:  { roughness: 0.9,  metalness: 0 },
  Rock:         { roughness: 0.88, metalness: 0 },
  Pebble:       { roughness: 0.86, metalness: 0 },
  Sand:         { roughness: 0.97, metalness: 0 },
  Snow:         { roughness: 0.75, metalness: 0 },
  Ice:          { roughness: 0.16, metalness: 0.05 },
  Glacier:      { roughness: 0.2,  metalness: 0.05 },
  Metal:        { roughness: 0.42, metalness: 0.85 },
  CorrodedMetal:{ roughness: 0.78, metalness: 0.55 },
  DiamondPlate: { roughness: 0.45, metalness: 0.8 },
  Foil:         { roughness: 0.3,  metalness: 0.9 },
  Fabric:       { roughness: 0.98, metalness: 0 },
  Plastic:      { roughness: 0.55, metalness: 0 },
  SmoothPlastic:{ roughness: 0.45, metalness: 0 },
  Neon:         { roughness: 0.4,  metalness: 0, emissive: true },
  Ground:       { roughness: 0.95, metalness: 0 },
  Asphalt:      { roughness: 0.9,  metalness: 0 },
  Sandstone:    { roughness: 0.9,  metalness: 0 },
  ClayRoofTiles:{ roughness: 0.85, metalness: 0 },
  Carpet:       { roughness: 0.99, metalness: 0 },
};

export function createRenderer(canvas: HTMLCanvasElement): THREE.WebGLRenderer {
  const renderer = new THREE.WebGLRenderer({
    canvas,
    antialias: true,
    powerPreference: 'high-performance',
  });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.02;
  return renderer;
}

export function createScene(): { scene: THREE.Scene; sun: THREE.DirectionalLight } {
  const scene = new THREE.Scene();
  scene.background = PALETTE.fogFar.clone();
  scene.fog = new THREE.Fog(PALETTE.fogFar.clone(), 90, 420);

  const hemi = new THREE.HemisphereLight(PALETTE.skyTop, PALETTE.bounce, 1.15);
  scene.add(hemi);

  // Low, soft key light — overcast, not a bright noon sun.
  const sun = new THREE.DirectionalLight(PALETTE.sun, 1.5);
  sun.position.set(-90, 120, 60);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  sun.shadow.camera.near = 1;
  sun.shadow.camera.far = 400;
  const S = 120;
  sun.shadow.camera.left = -S;
  sun.shadow.camera.right = S;
  sun.shadow.camera.top = S;
  sun.shadow.camera.bottom = -S;
  sun.shadow.bias = -0.0006;
  sun.shadow.normalBias = 0.04;
  scene.add(sun);
  scene.add(sun.target);

  return { scene, sun };
}

/** Gentle rolling ground. Roblox terrain doesn't survive export, so the
 *  walkable surface is rebuilt here — and looks better than the voxels did. */
export function groundHeight(x: number, z: number): number {
  const a = Math.sin(x * 0.0121) * Math.cos(z * 0.0138) * 0.9;
  const b = Math.sin((x + z) * 0.0295) * 0.35;
  return 2 + a + b;
}

export function createGround(): THREE.Mesh {
  const SIZE = 1900;
  const SEG = 190;
  const geo = new THREE.PlaneGeometry(SIZE, SIZE, SEG, SEG);
  geo.rotateX(-Math.PI / 2);
  const pos = geo.attributes.position as THREE.BufferAttribute;
  const colors: number[] = [];
  const base = PALETTE.ground.clone();
  const dark = new THREE.Color('#42583a');
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    const z = pos.getZ(i);
    pos.setY(i, groundHeight(x, z));
    // Mottled moss: subtle variation keeps a huge plane from reading flat.
    const n = (Math.sin(x * 0.07) * Math.cos(z * 0.061) + 1) / 2;
    const c = base.clone().lerp(dark, n * 0.5);
    colors.push(c.r, c.g, c.b);
  }
  geo.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
  geo.computeVertexNormals();

  const mesh = new THREE.Mesh(
    geo,
    new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.97, metalness: 0 }),
  );
  mesh.receiveShadow = true;
  mesh.name = 'Ground';
  return mesh;
}

function geometryFor(shape: string): THREE.BufferGeometry {
  switch (shape) {
    case 'Ball':
      return new THREE.SphereGeometry(0.5, 16, 12);
    case 'Cylinder': {
      // Roblox cylinders lie along local X.
      const g = new THREE.CylinderGeometry(0.5, 0.5, 1, 20);
      g.rotateZ(Math.PI / 2);
      return g;
    }
    case 'Wedge': {
      // Ramp rising toward local +Z, matching Roblox WedgePart.
      const g = new THREE.BufferGeometry();
      const v = new Float32Array([
        // sloped face
        -0.5, -0.5, -0.5,  0.5, -0.5, -0.5,  0.5, 0.5, 0.5,
        -0.5, -0.5, -0.5,  0.5,  0.5,  0.5, -0.5, 0.5, 0.5,
        // bottom
        -0.5, -0.5, -0.5, -0.5, -0.5, 0.5,  0.5, -0.5, 0.5,
        -0.5, -0.5, -0.5,  0.5, -0.5, 0.5,  0.5, -0.5, -0.5,
        // back
        -0.5, -0.5, 0.5, -0.5, 0.5, 0.5,  0.5, 0.5, 0.5,
        -0.5, -0.5, 0.5,  0.5, 0.5, 0.5,  0.5, -0.5, 0.5,
        // sides
        -0.5, -0.5, -0.5, -0.5, 0.5, 0.5, -0.5, -0.5, 0.5,
         0.5, -0.5, -0.5,  0.5, -0.5, 0.5,  0.5, 0.5, 0.5,
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
 * Build the visible world as one InstancedMesh per (shape, material, colour)
 * bucket. 3700 parts collapse to a few dozen draw calls, which is what makes
 * this run on an iPad.
 */
export function buildWorldMeshes(parts: PartData[]): THREE.Group {
  const group = new THREE.Group();
  group.name = 'World';

  const buckets = new Map<string, { spec: MatSpec; parts: PartData[]; shape: string; color: string; transparency: number }>();
  for (const p of parts) {
    if (p.transparency !== undefined && p.transparency >= 0.98) continue; // invisible markers
    const shape = p.shape ?? (p.class === 'WedgePart' ? 'Wedge' : 'Block');
    const mat = p.material ?? 'SmoothPlastic';
    const col = p.color ? `${p.color[0]},${p.color[1]},${p.color[2]}` : '160,160,160';
    const tr = p.transparency ?? 0;
    const key = `${shape}|${mat}|${col}|${tr.toFixed(2)}`;
    let b = buckets.get(key);
    if (!b) {
      buckets.set(key, (b = {
        spec: MATERIALS[mat] ?? { roughness: 0.8, metalness: 0 },
        parts: [], shape, color: col, transparency: tr,
      }));
    }
    b.parts.push(p);
  }

  for (const b of buckets.values()) {
    const [r, g, bl] = b.color.split(',').map(Number);
    const color = new THREE.Color(r / 255, g / 255, bl / 255);
    const material = new THREE.MeshStandardMaterial({
      color,
      roughness: b.spec.roughness,
      metalness: b.spec.metalness,
      transparent: b.transparency > 0,
      opacity: 1 - b.transparency,
    });
    if (b.spec.emissive) {
      // The only warm light in the world comes from here.
      material.emissive = color.clone();
      material.emissiveIntensity = 1.1;
    }

    const geo = geometryFor(b.shape);
    const mesh = new THREE.InstancedMesh(geo, material, b.parts.length);
    mesh.castShadow = !b.spec.emissive;
    mesh.receiveShadow = true;
    const m = new THREE.Matrix4();
    const scale = new THREE.Matrix4();
    b.parts.forEach((p, i) => {
      scale.makeScale(p.size[0], p.size[1], p.size[2]);
      m.copy(partMatrix(p)).multiply(scale);
      mesh.setMatrixAt(i, m);
    });
    mesh.instanceMatrix.needsUpdate = true;
    group.add(mesh);
  }

  return group;
}

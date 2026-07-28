import * as THREE from 'three';
import type { PartData } from '../engine/world';
import { partMatrix } from '../engine/world';

/**
 * Palette law, straight off the Ember Inspo board: deep moss and fern greens,
 * cold stone greys, overcast teal light. Warm colour is reserved — fires,
 * spirits and lanterns are the only warm things, and they're the only things
 * bright enough to bloom.
 */
export const PALETTE = {
  fog: new THREE.Color('#7d9c9d'),
  sun: new THREE.Color('#f2ece0'),
  skyLight: new THREE.Color('#88a8b4'),
  bounce: new THREE.Color('#4a6247'),
  ground: new THREE.Color('#546b41'),
  groundDark: new THREE.Color('#3b4f33'),
  groundDry: new THREE.Color('#6d7a4e'),
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
  renderer.toneMappingExposure = 1.05;
  return renderer;
}

export function createScene(shadowSize: number): {
  scene: THREE.Scene;
  sun: THREE.DirectionalLight;
  sunDir: THREE.Vector3;
} {
  const scene = new THREE.Scene();
  scene.fog = new THREE.FogExp2(PALETTE.fog.clone(), 0.0026);

  const hemi = new THREE.HemisphereLight(PALETTE.skyLight, PALETTE.bounce, 1.0);
  scene.add(hemi);

  const sunDir = new THREE.Vector3(-0.55, 0.68, 0.48).normalize();
  const sun = new THREE.DirectionalLight(PALETTE.sun, 2.1);
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
  const fill = new THREE.DirectionalLight(new THREE.Color('#93b3c4'), 0.32);
  fill.position.set(80, 40, -70);
  scene.add(fill);

  return { scene, sun, sunDir };
}

/** Rolling ground. Roblox terrain is a voxel blob that doesn't export, so the
 *  walkable surface is authored here around the world's known y=2 datum. */
export function groundHeight(x: number, z: number): number {
  const a = Math.sin(x * 0.0121) * Math.cos(z * 0.0138) * 0.9;
  const b = Math.sin((x + z) * 0.0295) * 0.35;
  const c = Math.sin(x * 0.0043 + 1.7) * Math.sin(z * 0.0051) * 1.4;
  return 2 + a + b + c;
}

export function createGround(): THREE.Mesh {
  const SIZE = 2600;
  const SEG = 300;
  const geo = new THREE.PlaneGeometry(SIZE, SIZE, SEG, SEG);
  geo.rotateX(-Math.PI / 2);
  const pos = geo.attributes.position as THREE.BufferAttribute;
  const colors: number[] = [];
  const c = new THREE.Color();

  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    const z = pos.getZ(i);
    const y = groundHeight(x, z);
    pos.setY(i, y);

    // Blend moss / dark hollow / dry patch by a couple of noise octaves so a
    // huge plane never reads as one flat colour.
    const n1 = (Math.sin(x * 0.031) * Math.cos(z * 0.027) + 1) / 2;
    const n2 = (Math.sin(x * 0.0071 + 2.1) * Math.cos(z * 0.0083) + 1) / 2;
    c.copy(PALETTE.ground)
      .lerp(PALETTE.groundDark, n1 * 0.55)
      .lerp(PALETTE.groundDry, Math.pow(n2, 3) * 0.4);
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
      const g = new THREE.BufferGeometry();
      const v = new Float32Array([
        -0.5,-0.5,-0.5,  0.5,-0.5,-0.5,  0.5, 0.5, 0.5,
        -0.5,-0.5,-0.5,  0.5, 0.5, 0.5, -0.5, 0.5, 0.5,
        -0.5,-0.5,-0.5, -0.5,-0.5, 0.5,  0.5,-0.5, 0.5,
        -0.5,-0.5,-0.5,  0.5,-0.5, 0.5,  0.5,-0.5,-0.5,
        -0.5,-0.5, 0.5, -0.5, 0.5, 0.5,  0.5, 0.5, 0.5,
        -0.5,-0.5, 0.5,  0.5, 0.5, 0.5,  0.5,-0.5, 0.5,
        -0.5,-0.5,-0.5, -0.5, 0.5, 0.5, -0.5,-0.5, 0.5,
         0.5,-0.5,-0.5,  0.5,-0.5, 0.5,  0.5, 0.5, 0.5,
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
      material.emissive = new THREE.Color(0xffffff);
      material.emissiveIntensity = 1.0;
      material.toneMapped = false; // let emissives punch past 1.0 into bloom
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

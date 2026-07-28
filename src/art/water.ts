import * as THREE from 'three';

/**
 * The river, the cove and the ponds.
 *
 * Roblox terrain water is a voxel blob and did not survive the export, so the
 * whole waterway arrived as nothing but a handful of invisible `WaterSource`
 * trigger boxes: a 60x60 box at the campsite, another in the woods, and twelve
 * thin strips down the middle of the Waterfront. Everything that made the water
 * READ as water — the channel, the surface, the shore — has to be authored here.
 *
 * Two rules fell out of the earlier failed attempt:
 *
 * 1. A flat sheet laid on top of the flat y=2 ground bleeds through grass and
 *    roads as shimmering patches. The ground has to be carved BELOW the surface
 *    first, so ordinary depth testing hides the water everywhere it shouldn't
 *    be. That is what `carve()` is for, and `scene.ts:groundHeight` applies it.
 * 2. The channel can't be a straight canal. The world's own geometry says where
 *    the old shoreline ran, and it wandered: boat slipways cut inland at three
 *    points down each bank, while the Hungry Statue and the stone spiral stand
 *    on little headlands. `SHORE` encodes those as bumps on the bank line.
 */

/** World datum the whole map was built against. */
export const GROUND_DATUM = 2;

/** Push (+) or pull (-) the bank line at a point along the river, in studs. */
interface ShoreFeature {
  /** Centre of the feature along z. */
  z: number;
  /** Half-width of its influence along z. */
  w: number;
  /** How far it moves the bank. Positive = land juts into the river. */
  a: number;
}

/** West bank: land juts out under the statue and the spiral, and is notched
 *  where the three boat slipways run down into the water. */
const SHORE_W: ShoreFeature[] = [
  { z: 130, w: 17, a: 15 },   // the Hungry Statue's plinth
  { z: 158, w: 17, a: 15 },   // the stone spiral
  { z: 176, w: 14, a: 12 },   // ring stone 4
  { z: -30, w: 10, a: -5 },   // slipways
  { z: 90, w: 10, a: -5 },
  { z: 200, w: 10, a: -5 },
];

/** East bank, mirrored: negative pushes the water further east (inland). */
const SHORE_E: ShoreFeature[] = [
  { z: -20, w: 10, a: 5 },
  { z: 60, w: 10, a: 5 },
  { z: 180, w: 10, a: 5 },
];

function shore(features: ShoreFeature[], z: number): number {
  // Bumps take the strongest, not the sum — two headlands 28 studs apart would
  // otherwise stack into one absurd promontory.
  let pos = 0;
  let neg = 0;
  for (const f of features) {
    const t = (z - f.z) / f.w;
    const v = f.a * Math.exp(-t * t);
    if (v > 0) pos = Math.max(pos, v);
    else neg = Math.min(neg, v);
  }
  return pos + neg;
}

/** Where the west bank meets the water plain, as a function of z. */
export function riverWest(z: number): number {
  return 430
    + 4.0 * Math.sin(z * 0.011 + 0.6)
    + 2.5 * Math.sin(z * 0.027 + 2.2)
    + shore(SHORE_W, z);
}

/** Where the east bank does. */
export function riverEast(z: number): number {
  return 542
    - 4.0 * Math.sin(z * 0.013 - 1.1)
    - 2.5 * Math.sin(z * 0.023 + 0.4)
    + shore(SHORE_E, z);
}

export interface WaterBody {
  id: string;
  /** Surface height. */
  level: number;
  /** Height of the deepest part of the bed. */
  bed: number;
  /**
   * How far into the basin a point is, in bank-widths. 1 at full depth, 0 at
   * the top of the bank, and NEGATIVE on the dry ground beyond it — which is
   * the bit that matters for the shore. The waterline sits around 0.2, so an
   * unsigned measure puts the entire beach underwater and the grass runs
   * straight into the river.
   */
  signed(x: number, z: number): number;
  /** The same value clamped to 0..1, which is what shapes the bed. */
  amount(x: number, z: number): number;
  /** XZ bounds of the basin, used to size meshes and terrain patches. */
  bounds: { x0: number; x1: number; z0: number; z1: number };
}

/** Bank width, in studs, over which the bed rises back to the datum. */
const BANK = 12;

function circular(
  id: string, cx: number, cz: number, r: number, bank: number,
  level: number, bed: number,
): WaterBody {
  const signed = (x: number, z: number) => (r - Math.hypot(x - cx, z - cz)) / bank;
  return {
    id, level, bed,
    signed,
    amount: (x, z) => clamp01(signed(x, z)),
    bounds: { x0: cx - r, x1: cx + r, z0: cz - r, z1: cz + r },
  };
}

function clamp01(v: number) {
  return v < 0 ? 0 : v > 1 ? 1 : v;
}

/** How far north and south the river is modelled in detail. */
const RIVER_Z0 = -820;
const RIVER_Z1 = 720;

function riverSigned(x: number, z: number): number {
  return Math.min((x - riverWest(z)) / BANK, (riverEast(z) - x) / BANK);
}

export const RIVER: WaterBody = {
  id: 'river',
  level: 1.0,
  bed: -7,
  signed: riverSigned,
  amount: (x, z) => clamp01(riverSigned(x, z)),
  bounds: { x0: 400, x1: 572, z0: RIVER_Z0, z1: RIVER_Z1 },
};

/** The Mossy Lido's cove — the river opening out where the slides come down. */
export const COVE = circular('cove', 455, 362, 50, BANK, 1.0, -7);

export const BODIES: WaterBody[] = [
  RIVER,
  COVE,
  circular('campsitePond', -620, -520, 20, 10, 1.35, -3.5),
  circular('forestPool', -367, -252, 11, 7, 1.45, -2.2),
];

/**
 * The ground height at (x, z) once every basin has been cut into it. `datum` is
 * the gently-rolling surface the rest of the world sits on.
 *
 * Smoothstep on the way down means the banks meet the flat ground tangentially:
 * no crease along the shoreline, and nothing near the edge drops by more than a
 * step height per stride.
 */
export function carve(x: number, z: number, datum: number): number {
  let y = datum;
  for (const b of BODIES) {
    const a = b.amount(x, z);
    if (a <= 0) continue;
    const s = a * a * (3 - 2 * a);
    const cut = datum + (b.bed - datum) * s;
    if (cut < y) y = cut;
  }
  return y;
}

export interface WaterSample {
  level: number;
  /** How far into the basin, 0 at the bank, 1 in the deep. */
  amount: number;
}

/**
 * How close a point is to being in water, in bank-widths — negative on dry
 * land, 0 at the top of the nearest bank, 1 in the deep. Drives the shingle
 * band on the ground and keeps turf off the beach.
 */
export function shoreBlend(x: number, z: number): number {
  let best = -Infinity;
  for (const b of BODIES) {
    const s = b.signed(x, z);
    if (s > best) best = s;
  }
  return best;
}

/** The water body over a point, or null on dry land. */
export function waterAt(x: number, z: number): WaterSample | null {
  let best: WaterSample | null = null;
  for (const b of BODIES) {
    const a = b.amount(x, z);
    if (a > 0 && (!best || a > best.amount)) best = { level: b.level, amount: a };
  }
  return best;
}

// ---------------------------------------------------------------- rendering

const VERT = /* glsl */ `
uniform float uTime;
attribute float aDepth;
varying vec3 vWorld;
varying float vWave;
varying float vDepth;

float wave(vec2 p, vec2 dir, float freq, float speed, float t) {
  return sin(dot(p, dir) * freq + t * speed);
}

void main() {
  vec3 p = position;
  vec4 wp = modelMatrix * vec4(p, 1.0);
  float t = uTime;
  // Swell dies away in the shallows so the shoreline doesn't chop up and down.
  float shallow = smoothstep(0.0, 2.5, aDepth);
  float w =
      wave(wp.xz, normalize(vec2(1.0, 0.35)), 0.055, 1.1, t) * 0.30
    + wave(wp.xz, normalize(vec2(-0.4, 1.0)), 0.09, 1.6, t) * 0.16
    + wave(wp.xz, normalize(vec2(0.7, -0.8)), 0.17, 2.3, t) * 0.07;
  w *= shallow;
  p.y += w;
  vWave = w;
  vDepth = aDepth;
  wp = modelMatrix * vec4(p, 1.0);
  vWorld = wp.xyz;
  gl_Position = projectionMatrix * viewMatrix * wp;
}`;

const FRAG = /* glsl */ `
uniform float uTime;
uniform vec3 uShallow;
uniform vec3 uDeep;
uniform vec3 uFoam;
uniform vec3 uSky;
varying vec3 vWorld;
varying float vWave;
varying float vDepth;

float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p){
  vec2 i = floor(p), f = fract(p);
  vec2 u = f*f*(3.0-2.0*f);
  return mix(mix(hash(i), hash(i+vec2(1,0)), u.x),
             mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), u.x), u.y);
}

void main() {
  // Everything shoreward of the waterline is thrown away outright. The terrain
  // would occlude it anyway, but discarding kills the z-fighting shimmer that
  // made the first attempt at water look like a bug.
  if (vDepth <= 0.02) discard;

  vec3 viewDir = normalize(cameraPosition - vWorld);

  float e = 1.2;
  float nx = noise(vWorld.xz * 0.06 + uTime * 0.05) - noise(vWorld.xz * 0.06 - vec2(e,0.0) + uTime * 0.05);
  float nz = noise(vWorld.xz * 0.06 + uTime * 0.05) - noise(vWorld.xz * 0.06 - vec2(0.0,e) + uTime * 0.05);
  vec3 n = normalize(vec3(nx * 2.2, 1.0, nz * 2.2));

  float fres = pow(1.0 - max(dot(n, viewDir), 0.0), 3.0);

  // Depth does the heavy lifting: you can see the bed in the shallows and lose
  // it in the channel, which is most of what makes water read as deep.
  float deep01 = smoothstep(0.3, 5.5, vDepth);
  vec3 col = mix(uShallow, uDeep, deep01);
  col = mix(col, uShallow, clamp(vWave * 0.7 + 0.5, 0.0, 1.0) * 0.22);
  col = mix(col, uSky, fres * 0.45);

  // Glitter on the crests. Kept on a very tight exponent so only the rarest
  // peaks reach the bloom threshold — an earlier, generous version lit the
  // whole surface past it and every pond rendered as a sheet of white — and
  // faded out with distance, where three-stud glints stop reading as sparkle
  // and start reading as smears of paint.
  // Gating on the swell crest is what keeps it from reading as a snowstorm:
  // glints then fall in drifting bands the way they do on real water, instead
  // of speckling every square stud of the surface at once.
  float far = 1.0 - smoothstep(80.0, 200.0, distance(cameraPosition, vWorld));
  float crest = smoothstep(0.12, 0.38, vWave);
  float sparkle = pow(max(noise(vWorld.xz * 0.5 + uTime * 0.30), 0.0), 30.0) * 1.8 * far * crest;
  col += vec3(0.80, 0.92, 1.0) * sparkle;

  // Foam: a soft band that hugs the shoreline, plus a hint on the swell peaks.
  float edge = 1.0 - smoothstep(0.08, 1.1, vDepth);
  float ripple = noise(vWorld.xz * 0.42 + vec2(uTime * 0.22, uTime * -0.17));
  float foam = clamp(edge * (0.30 + ripple * 0.45), 0.0, 1.0);
  foam = max(foam, smoothstep(0.32, 0.46, vWave) * 0.18);
  col = mix(col, uFoam, foam);

  float alpha = mix(0.50, 0.90, deep01);
  alpha = max(alpha, foam * 0.75);
  alpha *= smoothstep(0.02, 0.5, vDepth);   // feather the very edge
  gl_FragColor = vec4(col, alpha);
}`;

export interface Water {
  group: THREE.Group;
  update(t: number): void;
}

/** Depth of water over a point — 0 on dry land. */
export function waterDepth(x: number, z: number, datum: number): number {
  const w = waterAt(x, z);
  if (!w) return 0;
  return w.level - carve(x, z, datum);
}

/**
 * Surface meshes for every body. Each vertex carries the water depth beneath
 * it, which is what drives colour, foam and the shoreline cutoff — no depth
 * buffer read required, so this is as cheap on an iPad as it is on a desktop.
 */
export function createWater(datum: (x: number, z: number) => number): Water {
  const uniforms = {
    uTime: { value: 0 },
    uShallow: { value: new THREE.Color('#5c9490') },
    uDeep: { value: new THREE.Color('#1b3a48') },
    uFoam: { value: new THREE.Color('#dcecea') },
    uSky: { value: new THREE.Color('#93b3b8') },
  };

  const mat = new THREE.ShaderMaterial({
    uniforms,
    vertexShader: VERT,
    fragmentShader: FRAG,
    transparent: true,
    depthWrite: false,
    side: THREE.DoubleSide, // so a dive shows a surface from below too
  });

  const group = new THREE.Group();
  group.name = 'Water';

  const addSheet = (
    x0: number, x1: number, z0: number, z1: number, level: number, step: number,
  ) => {
    const nx = Math.max(1, Math.round((x1 - x0) / step));
    const nz = Math.max(1, Math.round((z1 - z0) / step));
    const geo = new THREE.PlaneGeometry(x1 - x0, z1 - z0, nx, nz);
    geo.rotateX(-Math.PI / 2);
    geo.translate((x0 + x1) / 2, level, (z0 + z1) / 2);

    const pos = geo.attributes.position as THREE.BufferAttribute;
    const depth = new Float32Array(pos.count);
    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i);
      const z = pos.getZ(i);
      depth[i] = level - carve(x, z, datum(x, z));
    }
    geo.setAttribute('aDepth', new THREE.BufferAttribute(depth, 1));

    const mesh = new THREE.Mesh(geo, mat);
    mesh.renderOrder = 5;
    mesh.frustumCulled = true;
    group.add(mesh);
  };

  // River + cove share one sheet: the cove is a widening of the river, and one
  // mesh means one draw call and no seam where they meet.
  addSheet(398, 574, RIVER_Z0, RIVER_Z1, RIVER.level, 3.2);

  for (const b of BODIES) {
    if (b === RIVER || b === COVE) continue;
    const m = 4;
    addSheet(b.bounds.x0 - m, b.bounds.x1 + m, b.bounds.z0 - m, b.bounds.z1 + m, b.level, 1.6);
  }

  return {
    group,
    update(t) {
      uniforms.uTime.value = t;
    },
  };
}

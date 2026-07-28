import * as THREE from 'three';

/**
 * Stylised water for the river and ponds. Roblox terrain water doesn't survive
 * export, so this is authored: a shader plane with layered swell, fresnel
 * depth, sparkle, and a soft foam line where it meets the shore.
 */
const VERT = /* glsl */ `
uniform float uTime;
varying vec3 vWorld;
varying vec2 vUv;
varying float vWave;

float wave(vec2 p, vec2 dir, float freq, float speed, float t) {
  return sin(dot(p, dir) * freq + t * speed);
}

void main() {
  vUv = uv;
  vec3 p = position;
  vec4 wp = modelMatrix * vec4(p, 1.0);
  float t = uTime;
  float w =
      wave(wp.xz, normalize(vec2(1.0, 0.35)), 0.055, 1.1, t) * 0.34
    + wave(wp.xz, normalize(vec2(-0.4, 1.0)), 0.09, 1.6, t) * 0.18
    + wave(wp.xz, normalize(vec2(0.7, -0.8)), 0.17, 2.3, t) * 0.08;
  p.y += w;
  vWave = w;
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
varying vec2 vUv;
varying float vWave;

float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p){
  vec2 i = floor(p), f = fract(p);
  vec2 u = f*f*(3.0-2.0*f);
  return mix(mix(hash(i), hash(i+vec2(1,0)), u.x),
             mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), u.x), u.y);
}

void main() {
  vec3 viewDir = normalize(cameraPosition - vWorld);

  // Perturbed normal from the same swell that moved the vertices.
  float e = 1.2;
  float nx = noise(vWorld.xz * 0.06 + uTime * 0.05) - noise(vWorld.xz * 0.06 - vec2(e,0.0) + uTime * 0.05);
  float nz = noise(vWorld.xz * 0.06 + uTime * 0.05) - noise(vWorld.xz * 0.06 - vec2(0.0,e) + uTime * 0.05);
  vec3 n = normalize(vec3(nx * 2.2, 1.0, nz * 2.2));

  float fres = pow(1.0 - max(dot(n, viewDir), 0.0), 3.0);
  vec3 col = mix(uDeep, uShallow, clamp(vWave * 0.8 + 0.5, 0.0, 1.0));
  col = mix(col, uSky, fres * 0.65);

  // Glitter on the crests — cool white, never warm.
  float sparkle = pow(max(noise(vWorld.xz * 0.9 + uTime * 0.35), 0.0), 14.0) * 26.0;
  col += vec3(0.85, 0.95, 1.0) * sparkle * 0.5;

  // Foam banding where swell peaks.
  float foam = smoothstep(0.28, 0.42, vWave) * 0.5;
  col = mix(col, uFoam, foam);

  gl_FragColor = vec4(col, 0.88);
}`;

export interface Water {
  mesh: THREE.Mesh;
  update(t: number): void;
  level: number;
}

export function createWater(
  center: THREE.Vector2,
  size: THREE.Vector2,
  level: number,
): Water {
  const geo = new THREE.PlaneGeometry(size.x, size.y, Math.min(160, size.x / 6), Math.min(160, size.y / 6));
  geo.rotateX(-Math.PI / 2);

  const uniforms = {
    uTime: { value: 0 },
    uShallow: { value: new THREE.Color('#4d7f80') },
    uDeep: { value: new THREE.Color('#1e3b46') },
    uFoam: { value: new THREE.Color('#cfe3e2') },
    uSky: { value: new THREE.Color('#8fb0b4') },
  };

  const mat = new THREE.ShaderMaterial({
    uniforms,
    vertexShader: VERT,
    fragmentShader: FRAG,
    transparent: true,
    depthWrite: false,
  });

  const mesh = new THREE.Mesh(geo, mat);
  mesh.position.set(center.x, level, center.y);
  mesh.renderOrder = 5;
  mesh.name = 'Water';

  return {
    mesh,
    level,
    update(t) {
      uniforms.uTime.value = t;
    },
  };
}

import * as THREE from 'three';

/**
 * Overcast sky dome with drifting cloud banks, and the environment map derived
 * from it. The env map matters more than it sounds: without one, PBR materials
 * have nothing to reflect and metal/ice read as flat grey plastic.
 */
const SKY_VERT = /* glsl */ `
varying vec3 vWorld;
void main() {
  vWorld = (modelMatrix * vec4(position, 1.0)).xyz;
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}`;

const SKY_FRAG = /* glsl */ `
uniform vec3 top;
uniform vec3 horizon;
uniform vec3 bottom;
uniform vec3 sunDir;
uniform vec3 sunColor;
uniform float time;
varying vec3 vWorld;

// cheap value noise for cloud banding
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1,0)), u.x),
             mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), u.x), u.y);
}
float fbm(vec2 p) {
  float v = 0.0, a = 0.5;
  for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
  return v;
}

void main() {
  vec3 dir = normalize(vWorld);
  float h = dir.y;

  vec3 col = mix(horizon, top, smoothstep(0.0, 0.55, h));
  col = mix(bottom, col, smoothstep(-0.25, 0.02, h));

  // A real sun with a warm bloom around it, not the old flat overcast wash.
  float sd = max(dot(dir, normalize(sunDir)), 0.0);
  col += sunColor * pow(sd, 5.0) * 0.30;
  col += sunColor * pow(sd, 90.0) * 0.75;

  // Cumulus. Two layers at different scales and speeds: the lower one big and
  // sharp-edged so the clouds have shape, a thinner veil drifting above it.
  if (h > 0.0) {
    vec2 uv = dir.xz / max(h + 0.16, 0.07);
    // Frequency matters more than it looks: at 0.26 a single noise cell was
    // wider than the visible sky, so the whole cloud layer read as one flat
    // tint. These values put several cloud masses in view at once.
    float c = fbm(uv * 0.58 + vec2(time * 0.0055, time * 0.003));
    // The threshold sets coverage, and coverage is the whole difference
    // between "cumulus in a blue sky" and "overcast". fbm averages about 0.48,
    // so cutting in at 0.54 leaves roughly a quarter of the sky clouded.
    c = smoothstep(0.54, 0.78, c);
    float veil = fbm(uv * 1.25 + vec2(time * 0.011, -time * 0.004));
    veil = smoothstep(0.52, 0.9, veil) * 0.45;
    float fade = smoothstep(0.0, 0.30, h) * (1.0 - smoothstep(0.80, 1.0, h) * 0.28);

    // Shade the underside of the big clouds so they have volume, and let the
    // sun catch their edges.
    vec3 lit = mix(vec3(1.0, 1.0, 1.0), sunColor, 0.35);
    vec3 shade = mix(vec3(0.72, 0.78, 0.86), horizon, 0.35);
    vec3 cloud = mix(shade, lit, smoothstep(0.42, 0.72, c) * 0.85 + pow(sd, 8.0) * 0.5);
    // max(), not sum — adding the veil put a floor of cloud over every part of
    // the sky at once, which is exactly what overcast is.
    col = mix(col, cloud, clamp(max(c, veil), 0.0, 1.0) * fade * 0.92);
  }

  gl_FragColor = vec4(col, 1.0);
}`;

export interface SkyHandle {
  mesh: THREE.Mesh;
  update(t: number): void;
  environment: THREE.Texture;
}

export function createSky(renderer: THREE.WebGLRenderer, sunDir: THREE.Vector3): SkyHandle {
  const uniforms = {
    top: { value: new THREE.Color('#2b78c4') },
    horizon: { value: new THREE.Color('#d6ecf4') },
    bottom: { value: new THREE.Color('#93ada4') },
    sunDir: { value: sunDir.clone().normalize() },
    sunColor: { value: new THREE.Color('#fff6e2') },
    time: { value: 0 },
  };

  const mat = new THREE.ShaderMaterial({
    uniforms,
    vertexShader: SKY_VERT,
    fragmentShader: SKY_FRAG,
    side: THREE.BackSide,
    depthWrite: false,
    fog: false,
  });

  const mesh = new THREE.Mesh(new THREE.SphereGeometry(1, 32, 20), mat);
  mesh.scale.setScalar(700);
  mesh.frustumCulled = false;
  mesh.renderOrder = -1000;
  mesh.name = 'Sky';

  // Bake the dome into an environment map once; it gives every PBR surface
  // something believable to reflect.
  const pmrem = new THREE.PMREMGenerator(renderer);
  pmrem.compileEquirectangularShader();
  const envScene = new THREE.Scene();
  const envSky = new THREE.Mesh(new THREE.SphereGeometry(1, 32, 20), mat.clone());
  envSky.scale.setScalar(10);
  envScene.add(envSky);
  const rt = pmrem.fromScene(envScene, 0.04);
  pmrem.dispose();

  return {
    mesh,
    environment: rt.texture,
    update(t: number) {
      uniforms.time.value = t;
    },
  };
}

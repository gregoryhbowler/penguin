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

  // A pale, diffuse sun — the light is overcast, never a hard disc.
  float sd = max(dot(dir, normalize(sunDir)), 0.0);
  col += sunColor * pow(sd, 6.0) * 0.28;
  col += sunColor * pow(sd, 64.0) * 0.35;

  // Cloud sheets, denser toward the horizon, drifting slowly.
  if (h > 0.0) {
    vec2 uv = dir.xz / max(h + 0.18, 0.08);
    float c = fbm(uv * 0.55 + vec2(time * 0.006, time * 0.0035));
    c = smoothstep(0.42, 0.95, c);
    float fade = smoothstep(0.0, 0.35, h) * (1.0 - smoothstep(0.75, 1.0, h) * 0.35);
    col = mix(col, mix(vec3(0.80, 0.85, 0.86), sunColor, 0.25), c * fade * 0.75);
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
    top: { value: new THREE.Color('#4d7f92') },
    horizon: { value: new THREE.Color('#9fb9b5') },
    bottom: { value: new THREE.Color('#667b74') },
    sunDir: { value: sunDir.clone().normalize() },
    sunColor: { value: new THREE.Color('#f2ece0') },
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

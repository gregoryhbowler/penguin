import * as THREE from 'three';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from 'three/examples/jsm/postprocessing/ShaderPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import { GTAOPass } from 'three/examples/jsm/postprocessing/GTAOPass.js';

/**
 * Grade + vignette + a touch of edge softening.
 *
 * The colour grade is where the Ember Inspo palette law becomes literal: cool
 * shadows, desaturated midtones, and warmth allowed only where the image is
 * already bright (i.e. fire and spirits, which are the only emissive things).
 */
const GradeShader = {
  uniforms: {
    tDiffuse: { value: null as THREE.Texture | null },
    uVignette: { value: 0.9 },
    uSaturation: { value: 0.92 },
    uLift: { value: new THREE.Color('#151f23') },
    uGain: { value: new THREE.Color('#eef3ee') },
    uWarmHighlights: { value: 0.16 },
  },
  vertexShader: /* glsl */ `
    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }`,
  fragmentShader: /* glsl */ `
    uniform sampler2D tDiffuse;
    uniform float uVignette;
    uniform float uSaturation;
    uniform vec3 uLift;
    uniform vec3 uGain;
    uniform float uWarmHighlights;
    varying vec2 vUv;

    void main() {
      vec4 c = texture2D(tDiffuse, vUv);
      vec3 col = c.rgb;

      // lift / gain: cool the shadows, keep highlights clean
      col = mix(uLift, uGain, col);

      // desaturate slightly toward luminance — overcast, not candy
      float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
      col = mix(vec3(l), col, uSaturation);

      // let only the brightest parts of the frame go warm
      float hi = smoothstep(0.55, 1.0, l);
      col += vec3(0.9, 0.45, 0.12) * hi * uWarmHighlights;

      // vignette
      vec2 d = vUv - 0.5;
      float v = 1.0 - dot(d, d) * uVignette;
      col *= v;

      gl_FragColor = vec4(col, c.a);
    }`,
};

export interface Quality {
  bloom: boolean;
  ao: boolean;
  pixelRatio: number;
  shadowSize: number;
  grass: number;
}

export function detectQuality(): Quality {
  const coarse = matchMedia('(pointer: coarse)').matches;
  const mem = (navigator as any).deviceMemory ?? 8;
  const weak = coarse || mem <= 4;
  return {
    bloom: true,
    ao: !weak,                        // GTAO is the first thing to go on tablets
    pixelRatio: Math.min(devicePixelRatio, weak ? 1.5 : 2),
    shadowSize: weak ? 1024 : 2048,
    grass: weak ? 1400 : 5000,
  };
}

export interface PostFX {
  composer: EffectComposer;
  setSize(w: number, h: number): void;
  quality: Quality;
}

export function createPostFX(
  renderer: THREE.WebGLRenderer,
  scene: THREE.Scene,
  camera: THREE.PerspectiveCamera,
  quality: Quality,
): PostFX {
  const composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, camera));

  if (quality.ao) {
    const ao = new GTAOPass(scene, camera, innerWidth, innerHeight);
    // Contact shadows where geometry meets — this is what stops everything
    // looking like it's floating a centimetre above the ground.
    ao.output = GTAOPass.OUTPUT.Default;
    (ao as any).updateGtaoMaterial?.({
      radius: 0.9,
      distanceExponent: 1.4,
      thickness: 1.0,
      scale: 1.1,
      samples: 12,
    });
    composer.addPass(ao);
  }

  if (quality.bloom) {
    // Tight threshold: ordinary lit surfaces must never bloom, only emissives.
    const bloom = new UnrealBloomPass(
      new THREE.Vector2(innerWidth, innerHeight),
      0.62,  // strength
      0.75,  // radius
      0.82,  // threshold
    );
    composer.addPass(bloom);
  }

  composer.addPass(new ShaderPass(GradeShader));
  composer.addPass(new OutputPass());

  return {
    composer,
    quality,
    setSize(w, h) {
      composer.setSize(w, h);
    },
  };
}

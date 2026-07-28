import * as THREE from 'three';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';

/**
 * Shared toolkit for building characters out of primitives.
 *
 * Every figure in the game — penguins, people, cats, kodama — is assembled the
 * same way: stack simple shapes, then `freeze()` the result down to a couple of
 * draw calls. That last step is what makes a cast of two dozen costumed
 * characters affordable. A dressed penguin is roughly twenty meshes; twenty-odd
 * of them loose in the scene would cost more per frame than the entire 3,748
 * part world does, because the world is instanced and they would not be.
 */

export interface PieceOpts {
  pos?: [number, number, number];
  /** Euler XYZ in radians. */
  rot?: [number, number, number];
  scale?: [number, number, number] | number;
  rough?: number;
  metal?: number;
  /** >0 makes the piece glow — lanterns, embers, spirit eyes. */
  glow?: number;
  side?: THREE.Side;
  opacity?: number;
  shadow?: boolean;
}

const matCache = new Map<string, THREE.MeshStandardMaterial>();

function materialFor(color: THREE.ColorRepresentation, o: PieceOpts): THREE.MeshStandardMaterial {
  const c = new THREE.Color(color);
  const rough = o.rough ?? 0.82;
  const metal = o.metal ?? 0;
  const glow = o.glow ?? 0;
  const opacity = o.opacity ?? 1;
  const side = o.side ?? THREE.FrontSide;
  const key = `${c.getHexString()}|${rough}|${metal}|${glow}|${opacity}|${side}`;
  let m = matCache.get(key);
  if (!m) {
    m = new THREE.MeshStandardMaterial({
      color: c,
      roughness: rough,
      metalness: metal,
      transparent: opacity < 1,
      opacity,
      side,
    });
    if (glow > 0) {
      m.emissive = c.clone();
      m.emissiveIntensity = glow;
      m.toneMapped = false; // let it punch past 1.0 into the bloom pass
    }
    matCache.set(key, m);
  }
  return m;
}

/** Add one shape to a figure. Returns it so callers can keep a handle for animation. */
export function piece(
  parent: THREE.Object3D,
  geo: THREE.BufferGeometry,
  color: THREE.ColorRepresentation,
  o: PieceOpts = {},
): THREE.Mesh {
  const mesh = new THREE.Mesh(geo, materialFor(color, o));
  if (o.pos) mesh.position.set(...o.pos);
  if (o.rot) mesh.rotation.set(...o.rot);
  if (o.scale !== undefined) {
    if (typeof o.scale === 'number') mesh.scale.setScalar(o.scale);
    else mesh.scale.set(...o.scale);
  }
  mesh.castShadow = o.shadow ?? true;
  mesh.receiveShadow = true;
  parent.add(mesh);
  return mesh;
}

// ---- geometry the figures reuse constantly, built once ----
export const G = {
  sphere: new THREE.SphereGeometry(0.5, 16, 12),
  ball: new THREE.SphereGeometry(0.5, 10, 8),
  box: new THREE.BoxGeometry(1, 1, 1),
  cone: new THREE.ConeGeometry(0.5, 1, 12),
  cyl: new THREE.CylinderGeometry(0.5, 0.5, 1, 14),
  capsule: new THREE.CapsuleGeometry(0.5, 1, 5, 10),
  torus: new THREE.TorusGeometry(0.5, 0.14, 8, 20),
};

/**
 * A ring of a given radius and thickness. Scaling the shared torus instead
 * fattens the tube along with the radius, which turned Pip's scarf and satchel
 * strap into a pair of swim rings — belts and collars need the tube to stay
 * thin as the ring grows.
 */
export function ring(r: number, tube = 0.09, seg = 20): THREE.BufferGeometry {
  return new THREE.TorusGeometry(r, tube, 7, seg);
}

/** A strap: a thin band across the body, for satchels and bandoliers. */
export function strap(
  length: number, width = 0.16, thickness = 0.08,
): THREE.BufferGeometry {
  return new THREE.BoxGeometry(width, length, thickness);
}

/** An open cone shell — the basis of every cloak, robe and skirt. */
export function shell(
  topR: number, botR: number, height: number, openFront = 0,
): THREE.BufferGeometry {
  const arc = Math.PI * 2 - openFront;
  return new THREE.CylinderGeometry(
    topR, botR, height, 18, 1, true, -arc / 2 + Math.PI, arc,
  );
}

/** A shallow dome — hoods, helmets, hat crowns, mushroom caps. */
export function dome(r: number, cut = 0.55): THREE.BufferGeometry {
  return new THREE.SphereGeometry(r, 16, 12, 0, Math.PI * 2, 0, Math.PI * cut);
}

/**
 * Collapse a finished figure to a handful of draw calls, baking each piece's
 * colour into vertex colours. Pieces are bucketed by surface treatment, so a
 * character usually ends up as one solid mesh plus one for anything glowing.
 *
 * Use for anything that stands still. Pip stays un-frozen because his limbs
 * have to move independently.
 */
export function freeze(root: THREE.Object3D, name = 'Figure'): THREE.Group {
  root.updateMatrixWorld(true);
  const toRoot = new THREE.Matrix4().copy(root.matrixWorld).invert();

  const buckets = new Map<string, {
    mat: THREE.MeshStandardMaterial;
    geos: THREE.BufferGeometry[];
    shadow: boolean;
  }>();

  const meshes: THREE.Mesh[] = [];
  root.traverse((o) => { if ((o as THREE.Mesh).isMesh) meshes.push(o as THREE.Mesh); });

  for (const mesh of meshes) {
    const m = mesh.material as THREE.MeshStandardMaterial;
    // `emissiveIntensity` defaults to 1 on every MeshStandardMaterial ever
    // made — it only does anything because `emissive` defaults to black. Test
    // the colour, not the intensity, or every character in the game merges
    // into one white-hot glowing bucket.
    const e = m.emissive;
    const glowing = !!e && e.r + e.g + e.b > 0.001;
    // Quantise the surface values before bucketing. Nobody can see the
    // difference between roughness 0.82 and 0.85, but keeping them apart split
    // a fisherman into ten draw calls instead of four.
    const rough = Math.round(m.roughness / 0.15) * 0.15;
    const metal = Math.round(m.metalness / 0.25) * 0.25;
    const key = `${rough}|${metal}|${m.opacity}|${m.side}|` +
      (glowing ? `${e.getHexString()}|${m.emissiveIntensity}` : 'lit');
    let b = buckets.get(key);
    if (!b) {
      const mat = new THREE.MeshStandardMaterial({
        roughness: rough,
        metalness: metal,
        transparent: m.transparent,
        opacity: m.opacity,
        side: m.side,
        vertexColors: true,
      });
      if (glowing) {
        // Emission can't vary per vertex, so glowing pieces are bucketed by
        // their own emissive colour and each bucket keeps it.
        mat.emissive = e.clone();
        mat.emissiveIntensity = m.emissiveIntensity;
        mat.toneMapped = false;
      }
      buckets.set(key, (b = { mat, geos: [], shadow: mesh.castShadow }));
    }

    const g = mesh.geometry.clone().toNonIndexed();
    g.applyMatrix4(new THREE.Matrix4().multiplyMatrices(toRoot, mesh.matrixWorld));
    // Bake the piece colour in. Without an explicit attribute the merged mesh
    // renders black under vertexColors — the same trap the world instancing hit.
    const n = g.attributes.position.count;
    const col = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) {
      col[i * 3] = m.color.r; col[i * 3 + 1] = m.color.g; col[i * 3 + 2] = m.color.b;
    }
    g.setAttribute('color', new THREE.BufferAttribute(col, 3));
    for (const attr of Object.keys(g.attributes)) {
      if (attr !== 'position' && attr !== 'normal' && attr !== 'color') g.deleteAttribute(attr);
    }
    b.geos.push(g);
  }

  const out = new THREE.Group();
  out.name = name;
  for (const b of buckets.values()) {
    const merged = mergeGeometries(b.geos);
    if (!merged) continue;
    merged.computeBoundingSphere();
    const mesh = new THREE.Mesh(merged, b.mat);
    mesh.castShadow = b.shadow;
    mesh.receiveShadow = true;
    out.add(mesh);
  }
  return out;
}

import * as THREE from 'three';
import { loadWorld, indexByTag, makeCollider, ColliderGrid } from './engine/world';
import { CharacterController } from './engine/controller';
import {
  createRenderer, createScene, createGround, buildWorldMeshes, groundHeight,
} from './art/scene';
import { createSky } from './art/sky';
import { buildFoliage, GrassField, tickWind } from './art/foliage';
import { createPostFX, detectQuality } from './art/postfx';
import { Pip } from './game/pip';
import { Interactables } from './game/interact';
import { UI } from './game/ui';
import { Input } from './engine/input';

async function boot() {
  const canvas = document.getElementById('view') as HTMLCanvasElement;
  const quality = detectQuality();
  const renderer = createRenderer(canvas, quality.pixelRatio);
  const { scene, sun, sunDir } = createScene(quality.shadowSize);
  const camera = new THREE.PerspectiveCamera(60, innerWidth / innerHeight, 0.3, 1400);

  const ui = new UI();
  const world = await loadWorld(`${import.meta.env.BASE_URL}data/world.json`);
  const parts = world.parts; // the whole map now, not one region

  // ---------------- sky + environment ----------------
  const sky = createSky(renderer, sunDir);
  scene.add(sky.mesh);
  scene.environment = sky.environment;
  scene.environmentIntensity = 0.55;

  // ---------------- geometry ----------------
  scene.add(createGround());
  const foliage = buildFoliage(parts);
  scene.add(foliage.group);
  scene.add(buildWorldMeshes(parts, foliage.consumed));

  // NOTE: no water yet. A flat sheet under a flat y=2 ground plane just bleeds
  // through the grass and road as shimmer. Real water needs the ground carved
  // into a river channel first — see createWater(), which is ready for it.

  // ---------------- collision ----------------
  const grid = new ColliderGrid();
  for (const p of parts) {
    if (p.canCollide === false) continue;
    if ((p.transparency ?? 0) >= 0.98) continue;
    if (p.class === 'SpawnLocation') continue;
    if (foliage.consumed.has(p)) continue; // walk through leaves and ferns
    grid.add(makeCollider(p));
  }

  // Turf, but never growing up through paths, decks or floors.
  const grassProbe: any[] = [];
  const grassLocal = new THREE.Vector3();
  const noGrassHere = (x: number, z: number, y: number) => {
    const list = grid.query(new THREE.Vector3(x, y, z), 2, grassProbe);
    for (const c of list) {
      if (c.center.y + c.half.y < y - 0.1) continue;  // entirely below the turf line
      if (c.center.y - c.half.y > y + 2.5) continue;  // high above it
      grassLocal.set(x - c.center.x, 0, z - c.center.z).applyMatrix3(c.inv);
      if (Math.abs(grassLocal.x) <= c.half.x + 0.3 && Math.abs(grassLocal.z) <= c.half.z + 0.3) {
        return true;
      }
    }
    return false;
  };
  const grass = new GrassField(quality.grass, 40, groundHeight, noGrassHere);
  scene.add(grass.mesh);

  const controller = new CharacterController(grid, {
    radius: 1.0,
    height: 3.2,
    walkSpeed: 14,
    slideSpeed: 30,
    jumpSpeed: 42,
    gravity: 100,
    stepHeight: 1.4,
    groundY: groundHeight,
  });

  const spawn = parts.find((p) => p.class === 'SpawnLocation')
    ?? parts.find((p) => p.tags?.includes('Checkpoint'));
  const sp = spawn ? spawn.pos : [-660, 6, -430];
  controller.pos.set(sp[0], sp[1] + 3, sp[2]);

  const pip = new Pip();
  scene.add(pip.root);

  const byTag = indexByTag(parts);
  const interact = new Interactables(scene, byTag, ui);
  const zones = byTag.get('Zone') ?? [];

  const input = new Input(canvas);
  ui.setScheme(input.scheme);

  // ---------------- post ----------------
  const post = createPostFX(renderer, scene, camera, quality);

  // ---------------- camera ----------------
  let camYaw = Math.PI;
  let camPitch = 0.34;
  let camDist = 24;
  const camTarget = new THREE.Vector3(controller.pos.x, controller.pos.y + 3.2, controller.pos.z);
  camera.position.set(camTarget.x, camTarget.y + 10, camTarget.z + 24);

  function resize() {
    camera.aspect = innerWidth / innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(innerWidth, innerHeight);
    post.setSize(innerWidth, innerHeight);
  }
  addEventListener('resize', resize);
  resize();
  ui.ready();

  let last = performance.now();
  let elapsed = 0;
  let currentZone = '';

  function tick(dt: number, override?: { dir?: THREE.Vector2; jump?: boolean; slide?: boolean }) {
    elapsed += dt;
    input.update();

    // ---- camera orbit ----
    const look = input.consumeLook();
    camYaw -= look.x * 0.0045;
    camPitch = THREE.MathUtils.clamp(camPitch + look.y * 0.0035, -0.15, 1.2);
    camDist = THREE.MathUtils.clamp(camDist + input.consumeZoom(), 9, 46);

    // ---- movement, relative to the camera ----
    // The camera sits at (sin yaw, ., cos yaw) * dist from Pip and looks back at
    // him, so "into the screen" is the NEGATIVE of that offset. Forgetting the
    // sign here is what made W walk backwards and A/D mirror.
    const mv = input.move.clone();
    if (mv.lengthSq() > 1) mv.normalize();
    const sin = Math.sin(camYaw);
    const cos = Math.cos(camYaw);
    const fwd = new THREE.Vector2(-sin, -cos);   // away from the camera
    const right = new THREE.Vector2(cos, -sin);  // fwd x up
    const dir = override?.dir ?? new THREE.Vector2(
      right.x * mv.x + fwd.x * mv.y,
      right.y * mv.x + fwd.y * mv.y,
    );

    controller.update(dt, {
      dir,
      jump: override?.jump ?? input.consumeJump(),
      slide: override?.slide ?? input.slide,
    });

    const speed01 = Math.min(1, Math.hypot(controller.vel.x, controller.vel.z) / 14);
    pip.root.position.copy(controller.pos);
    pip.update(dt, speed01, controller.facing, controller.sliding, !controller.onGround);

    // ---- follow camera ----
    camTarget.lerp(
      new THREE.Vector3(controller.pos.x, controller.pos.y + 3.2, controller.pos.z),
      Math.min(1, dt * 10),
    );
    const cp = new THREE.Vector3(
      camTarget.x + Math.sin(camYaw) * Math.cos(camPitch) * camDist,
      camTarget.y + Math.sin(camPitch) * camDist,
      camTarget.z + Math.cos(camYaw) * Math.cos(camPitch) * camDist,
    );
    const floor = groundHeight(cp.x, cp.z) + 2.5;
    if (cp.y < floor) cp.y = floor;
    camera.position.lerp(cp, Math.min(1, dt * 12));
    camera.lookAt(camTarget);

    // ---- world updates ----
    sun.position.copy(controller.pos).addScaledVector(sunDir, 170);
    sun.target.position.copy(controller.pos);
    sky.mesh.position.copy(camera.position);
    sky.update(elapsed);
    grass.update(controller.pos);
    for (const m of foliage.materials) tickWind(m, elapsed);
    tickWind(grass.material, elapsed, controller.pos);

    // ---- region banner, straight off the Zone tags ----
    for (const z of zones) {
      const half = [z.size[0] / 2, z.size[1] / 2, z.size[2] / 2];
      if (Math.abs(controller.pos.x - z.pos[0]) <= half[0] &&
          Math.abs(controller.pos.y - z.pos[1]) <= half[1] &&
          Math.abs(controller.pos.z - z.pos[2]) <= half[2]) {
        const name = String(z.attrs?.DisplayName ?? z.attrs?.ZoneId ?? '');
        if (name && name !== currentZone) {
          currentZone = name;
          ui.showRegion(name);
        }
        break;
      }
    }

    interact.update(dt, controller.pos, input.consumeAction());
    ui.tick(dt);
    post.composer.render();
  }

  function frame() {
    requestAnimationFrame(frame);
    const now = performance.now();
    const dt = Math.min((now - last) / 1000, 0.05);
    last = now;
    tick(dt);
  }
  frame();

  (window as any).__game = { controller, camera, pip, parts, tick, THREE, quality };
}

boot().catch((err) => {
  console.error(err);
  const el = document.getElementById('loading');
  if (el) el.innerHTML = `<p style="max-width:36ch;text-align:center">The grove didn't wake.<br><small>${err}</small></p>`;
});

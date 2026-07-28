import * as THREE from 'three';
import { loadWorld, indexByTag, makeCollider, ColliderGrid } from './engine/world';
import { CharacterController } from './engine/controller';
import { createRenderer, createScene, createGround, buildWorldMeshes, groundHeight } from './art/scene';
import { Pip } from './game/pip';
import { Interactables } from './game/interact';
import { UI } from './game/ui';
import { Input } from './engine/input';

const REGION = 'World/Campsite';

async function boot() {
  const canvas = document.getElementById('view') as HTMLCanvasElement;
  const renderer = createRenderer(canvas);
  const { scene, sun } = createScene();
  const camera = new THREE.PerspectiveCamera(58, innerWidth / innerHeight, 0.3, 900);

  const ui = new UI();
  const world = await loadWorld(`${import.meta.env.BASE_URL}data/world.json`);

  // Slice: one region at a time while systems are ported over.
  const parts = world.parts.filter((p) => p.path.startsWith(REGION));

  scene.add(createGround());
  scene.add(buildWorldMeshes(parts));

  // ---- collision ----
  const grid = new ColliderGrid();
  for (const p of parts) {
    if (p.canCollide === false) continue;
    if ((p.transparency ?? 0) >= 0.98) continue; // zone volumes & markers
    if (p.class === 'SpawnLocation') continue;
    grid.add(makeCollider(p));
  }

  const controller = new CharacterController(grid, {
    radius: 1.0,
    height: 3.2,
    walkSpeed: 14,
    slideSpeed: 30,
    jumpSpeed: 42,
    gravity: 100,
    stepHeight: 1.4, // generous on purpose: the Roblox rig's 0.3 broke everything
    groundY: groundHeight,
  });

  // Spawn on the region's SpawnLocation if it has one.
  const spawn = parts.find((p) => p.class === 'SpawnLocation')
    ?? parts.find((p) => p.tags?.includes('Checkpoint'));
  const sp = spawn ? spawn.pos : [-630, 6, -460];
  controller.pos.set(sp[0], sp[1] + 3, sp[2]);

  const pip = new Pip();
  scene.add(pip.root);

  const byTag = indexByTag(parts);
  const interact = new Interactables(scene, byTag, ui);

  const input = new Input(canvas);
  ui.showRegion('Abandoned Campsite');

  // dev inspection hook
  (window as any).__game = { controller, camera, pip, parts, spawn };

  // ---- camera rig ----
  let camYaw = 0;
  let camPitch = 0.32;
  let camDist = 22;
  const camTarget = new THREE.Vector3();

  function resize() {
    camera.aspect = innerWidth / innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(innerWidth, innerHeight);
  }
  addEventListener('resize', resize);
  resize();

  ui.ready();

  let last = performance.now();

  function tick(dt: number, override?: { dir?: THREE.Vector2; jump?: boolean; slide?: boolean }) {

    // ---- camera orbit from mouse/touch look ----
    camYaw -= input.look.x * 0.0032;
    camPitch = THREE.MathUtils.clamp(camPitch + input.look.y * 0.0026, -0.25, 1.15);
    input.look.set(0, 0);

    // Movement is relative to where the camera is pointing.
    const move = input.move.clone();
    if (move.lengthSq() > 1) move.normalize();
    const sin = Math.sin(camYaw);
    const cos = Math.cos(camYaw);
    const dir = override?.dir ?? new THREE.Vector2(
      move.x * cos - move.y * sin,
      move.x * sin + move.y * cos,
    );

    controller.update(dt, {
      dir,
      jump: override?.jump ?? input.jump,
      slide: override?.slide ?? input.slide,
    });
    input.jump = false;

    const speed01 = Math.min(1, Math.hypot(controller.vel.x, controller.vel.z) / 14);
    pip.root.position.copy(controller.pos);
    pip.update(dt, speed01, controller.facing, controller.sliding, !controller.onGround);

    // ---- follow camera ----
    camTarget.lerp(
      new THREE.Vector3(controller.pos.x, controller.pos.y + 3.2, controller.pos.z),
      Math.min(1, dt * 9),
    );
    const cp = new THREE.Vector3(
      camTarget.x + Math.sin(camYaw) * Math.cos(camPitch) * camDist,
      camTarget.y + Math.sin(camPitch) * camDist,
      camTarget.z + Math.cos(camYaw) * Math.cos(camPitch) * camDist,
    );
    // Keep the camera above ground so it never dives under the world.
    const floor = groundHeight(cp.x, cp.z) + 2;
    if (cp.y < floor) cp.y = floor;
    camera.position.lerp(cp, Math.min(1, dt * 11));
    camera.lookAt(camTarget);

    // Shadow frustum follows Pip so the map size doesn't blur shadows.
    sun.position.set(controller.pos.x - 90, controller.pos.y + 120, controller.pos.z + 60);
    sun.target.position.copy(controller.pos);

    interact.update(dt, controller.pos, input.consumeAction());
    ui.tick(dt);

    renderer.render(scene, camera);
  }

  function frame() {
    requestAnimationFrame(frame);
    const now = performance.now();
    const dt = Math.min((now - last) / 1000, 0.05);
    last = now;
    tick(dt);
  }
  frame();

  (window as any).__game.tick = tick;
  (window as any).__game.THREE = THREE;
}

boot().catch((err) => {
  console.error(err);
  const el = document.getElementById('loading');
  if (el) el.innerHTML = `<p style="max-width:36ch;text-align:center">The grove didn't wake.<br><small>${err}</small></p>`;
});

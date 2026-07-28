import * as THREE from 'three';
import { loadWorld, indexByTag, makeCollider, ColliderGrid } from './engine/world';
import { CharacterController } from './engine/controller';
import {
  createRenderer, createScene, createGround, buildWorldMeshes, groundHeight, datumHeight,
} from './art/scene';
import { createSky } from './art/sky';
import { createHorizon } from './art/horizon';
import { buildFoliage, GrassField, tickWind } from './art/foliage';
import { createPostFX, detectQuality } from './art/postfx';
import { createWater, shoreBlend, waterAt } from './art/water';
import { Pip } from './game/penguin';
import { PIP_KIT } from './game/cast';
import { Interactables } from './game/interact';
import { Drawbridge } from './game/drawbridge';
import { Wonders } from './game/wonders';
import { FishSchools, Splashes } from './game/water_life';
import { UI } from './game/ui';
import { Input } from './engine/input';

async function boot() {
  const canvas = document.getElementById('view') as HTMLCanvasElement;
  const quality = detectQuality();
  const renderer = createRenderer(canvas, quality.pixelRatio);
  const { scene, sun, sunDir } = createScene(quality.shadowSize);
  // Far plane reaches past the horizon ring, which sits out at ~1300 studs.
  const camera = new THREE.PerspectiveCamera(60, innerWidth / innerHeight, 0.3, 2600);

  const ui = new UI();
  const world = await loadWorld(`${import.meta.env.BASE_URL}data/world.json`);
  const parts = world.parts; // the whole map now, not one region
  const byTag = indexByTag(parts);

  // ---------------- sky + environment ----------------
  const sky = createSky(renderer, sunDir);
  scene.add(sky.mesh);
  scene.environment = sky.environment;
  scene.environmentIntensity = 0.55;

  // ---------------- geometry ----------------
  scene.add(createGround());
  const foliage = buildFoliage(parts);
  scene.add(foliage.group);

  // The drawbridge flaps are the one thing in the world that moves, so they
  // come out of the static instanced build and get their own meshes.
  const drawbridge = new Drawbridge(parts);
  scene.add(drawbridge.group);
  const staticSkip = new Set(foliage.consumed);
  for (const p of parts) if (Drawbridge.owns(p)) staticSkip.add(p);
  // NOTE: do NOT add roofs to the buildings. They already have them — the
  // world file has 11 `Roof` decks, 46 `Parapet` walls, 41 `TowerRoof`s, 17
  // water tanks and a spire, and those flat decks are a deliberate traversal
  // layer carrying the wingsuit crate and beacon, the clock gear, a cache and
  // a 26-stud plank between rooftops. A generated pitched roof buries all of
  // it inside geometry that has no collider, which is exactly how you end up
  // falling through a house.
  scene.add(buildWorldMeshes(parts, staticSkip));

  // Water goes in after the ground, which by now has the river, the cove and
  // both ponds cut into it — that carve is what stops a flat sheet bleeding
  // through the grass and roads the way the first attempt did.
  const water = createWater(datumHeight);
  scene.add(water.group);
  const fish = new FishSchools(byTag.get('FishSchool') ?? []);
  scene.add(fish.mesh);
  const splashes = new Splashes();
  scene.add(splashes.group);

  // ---------------- collision ----------------
  const grid = new ColliderGrid();
  for (const p of parts) {
    if (p.canCollide === false) continue;
    if ((p.transparency ?? 0) >= 0.98) continue;
    if (p.class === 'SpawnLocation') continue;
    if (staticSkip.has(p)) continue; // walk through leaves and ferns
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
  // Turf stops at the beach, not at the waterline: grass growing to the very
  // edge of the water is the thing that makes a shore look pasted on.
  const dryLand = (x: number, z: number, y: number) => {
    if (shoreBlend(x, z) > -0.35) return true;
    return noGrassHere(x, z, y);
  };
  const grass = new GrassField(quality.grass, 40, groundHeight, dryLand);
  scene.add(grass.mesh);
  scene.add(grass.flowers);

  const horizon = createHorizon();
  scene.add(horizon.group);

  const waterY = (x: number, z: number) => waterAt(x, z)?.level ?? null;

  const controller = new CharacterController(grid, {
    radius: 1.0,
    height: 3.2,
    walkSpeed: 14,
    slideSpeed: 30,
    swimSpeed: 17,
    jumpSpeed: 42,
    gravity: 100,
    stepHeight: 1.4,
    groundY: groundHeight,
    waterY,
    moving: () => drawbridge.current(),
  });

  const spawn = parts.find((p) => p.class === 'SpawnLocation')
    ?? parts.find((p) => p.tags?.includes('Checkpoint'));
  const sp = spawn ? spawn.pos : [-660, 6, -430];
  controller.pos.set(sp[0], sp[1] + 3, sp[2]);

  const pip = new Pip(PIP_KIT);
  scene.add(pip.root);

  const groundUnder = (x: number, z: number, near: number) => controller.surfaceY(x, z, near + 1.2);
  const wonders = new Wonders(byTag, ui, groundUnder);
  scene.add(wonders.group);

  const interact = new Interactables(scene, byTag, ui, {
    // Characters stand on whatever is actually solid under their marker — a
    // rooftop for Cindercoo, the tunnel floor for Sam — rather than at the
    // marker's own height, which was only ever where a builder dropped a part.
    place: (x, z, near, wader) => {
      if (wader) {
        const w = waterAt(x, z);
        if (w) return w.level - 1.1;
      }
      return groundUnder(x, z, near);
    },
    bridgeLever: () => {
      if (drawbridge.lowering) return;
      drawbridge.toggle();
      ui.toast(
        drawbridge.open < 0.5
          ? 'The winch groans. The great bridge begins to lower…'
          : 'The winch groans. The great bridge begins to rise…',
        'story',
      );
    },
  });
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

    drawbridge.update(dt);

    controller.update(dt, {
      dir,
      jump: override?.jump ?? input.consumeJump(),
      slide: override?.slide ?? input.slide,
    });

    const speed01 = Math.min(1, Math.hypot(controller.vel.x, controller.vel.z) / 14);
    pip.root.position.copy(controller.pos);
    pip.update(dt, speed01, controller.facing, controller.sliding,
      !controller.onGround && !controller.swimming, controller.swimming);

    if (controller.splashed > 0 && controller.waterLevel !== null) {
      splashes.burst(controller.pos.x, controller.waterLevel, controller.pos.z, controller.splashed);
    }
    splashes.update(dt);
    fish.update(dt, controller.pos);
    wonders.update(dt, controller.pos);

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
    // Duck the camera under with him. Without this it stays up in the air on
    // its orbit and a dive is something you only ever watch from above — which
    // throws away the best thing about having water at all.
    if (controller.waterLevel !== null && controller.pos.y + controller.height < controller.waterLevel - 0.4) {
      cp.y = Math.min(cp.y, Math.max(floor, controller.waterLevel - 0.8));
    }
    camera.position.lerp(cp, Math.min(1, dt * 12));
    camera.lookAt(camTarget);

    // ---- world updates ----
    sun.position.copy(controller.pos).addScaledVector(sunDir, 170);
    sun.target.position.copy(controller.pos);
    sky.mesh.position.copy(camera.position);
    sky.update(elapsed);
    water.update(elapsed);

    // Under the surface the whole frame goes green-blue. Cheapest possible
    // version — a DOM overlay — and it does the entire job.
    const camWater = waterAt(camera.position.x, camera.position.z);
    ui.setUnderwater(!!camWater && camera.position.y < camWater.level);
    grass.update(controller.pos);
    horizon.update(controller.pos);
    for (const m of foliage.materials) tickWind(m, elapsed);
    tickWind(grass.material, elapsed, controller.pos);
    tickWind(grass.flowers.material as THREE.Material, elapsed, controller.pos);

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

  let paused = false;
  function frame() {
    requestAnimationFrame(frame);
    const now = performance.now();
    const dt = Math.min((now - last) / 1000, 0.05);
    last = now;
    if (!paused) tick(dt);
  }
  frame();

  // Debug surface. `tick` drives the simulation by hand, which is the only way
  // to measure anything reliably — the Browser pane parks requestAnimationFrame
  // whenever it isn't visible, so the live loop stops and every reading lies.
  (window as any).__game = {
    controller, camera, pip, parts, tick, THREE, quality, scene, drawbridge,
    /** Place Pip and settle the camera behind him at a chosen heading. */
    look(x: number, y: number, z: number, yaw = Math.PI, pitch = 0.34, dist = 24) {
      controller.pos.set(x, y, z);
      controller.vel.set(0, 0, 0);
      camYaw = yaw; camPitch = pitch; camDist = dist;
      camTarget.set(x, y + 3.2, z);
      camera.position.set(
        x + Math.sin(yaw) * Math.cos(pitch) * dist,
        y + 3.2 + Math.sin(pitch) * dist,
        z + Math.cos(yaw) * Math.cos(pitch) * dist,
      );
      for (let i = 0; i < 4; i++) tick(1 / 60, { dir: new THREE.Vector2(0, 0) });
    },
    /**
     * Park the camera anywhere and render one frame. Pauses the loop first —
     * otherwise the follow-cam yanks it back to Pip on the very next frame and
     * every inspection shot comes out identical.
     */
    shot(from: number[], at: number[], hidePip = true) {
      paused = true;
      pip.root.visible = !hidePip;
      camera.position.set(from[0], from[1], from[2]);
      camera.lookAt(at[0], at[1], at[2]);
      camera.updateMatrixWorld();
      // The sky dome and the horizon ring both ride with the player. Without
      // moving them too, a parked camera ends up outside the dome and the sky
      // renders black — an artifact of the harness, not of the game.
      sky.mesh.position.copy(camera.position);
      horizon.group.position.set(camera.position.x, 0, camera.position.z);
      post.composer.render();
    },
    resume() {
      paused = false;
      pip.root.visible = true;
    },
  };
}

boot().catch((err) => {
  console.error(err);
  const el = document.getElementById('loading');
  if (el) el.innerHTML = `<p style="max-width:36ch;text-align:center">The grove didn't wake.<br><small>${err}</small></p>`;
});

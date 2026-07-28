import * as THREE from 'three';
import { colliderTopAt, type Collider, type ColliderGrid } from './world';

/**
 * Kinematic character controller for Pip.
 *
 * Deliberately NOT a rigid body: the Roblox build lost weeks to physics
 * quirks (a 0.3-stud step height that broke every staircase, humanoids
 * gripping slopes so slides needed conveyor hacks). Here we own the rules —
 * generous step-up, predictable slides, no tunnelling.
 */
export interface ControllerConfig {
  radius: number;
  height: number;
  walkSpeed: number;
  slideSpeed: number;
  jumpSpeed: number;
  gravity: number;
  stepHeight: number;
  groundY: (x: number, z: number) => number;
}

export interface MoveInput {
  /** Desired horizontal direction in world space, length <= 1. */
  dir: THREE.Vector2;
  jump: boolean;
  slide: boolean;
}

export class CharacterController {
  pos = new THREE.Vector3();
  vel = new THREE.Vector3();
  onGround = false;
  sliding = false;
  facing = 0;
  private slideTime = 0;
  private scratch: Collider[] = [];

  constructor(
    private grid: ColliderGrid,
    private cfg: ControllerConfig,
  ) {}

  /** Highest solid surface under a point, including static parts and ramps. */
  surfaceY(x: number, z: number, from: number): number {
    let best = this.cfg.groundY(x, z);
    const probe = new THREE.Vector3(x, from, z);
    const list = this.grid.query(probe, this.cfg.radius + 2, this.scratch);
    for (const c of list) {
      const top = colliderTopAt(c, x, z);
      if (top === null) continue;
      if (top <= from + 0.35 && top > best) best = top;
    }
    return best;
  }

  private resolveHorizontal(next: THREE.Vector3) {
    const r = this.cfg.radius;
    const feet = next.y;
    const head = next.y + this.cfg.height;
    const list = this.grid.query(next, r + 3, this.scratch);
    const local = new THREE.Vector3();

    for (const c of list) {
      const bottom = c.center.y - c.worldHalfY;
      if (bottom >= head) continue; // clears our head entirely

      // A ramp is only a wall where its slope has risen out of reach. Sampling
      // the surface height at our own footprint is what lets Pip walk up every
      // wedge in the world instead of bouncing off its bounding box.
      const surface = colliderTopAt(c, next.x, next.z, true);
      const top = surface ?? c.center.y + c.worldHalfY;
      if (top <= feet + this.cfg.stepHeight) continue;

      local.set(next.x - c.center.x, 0, next.z - c.center.z).applyMatrix3(c.inv);
      const dx = c.half.x + r - Math.abs(local.x);
      const dz = c.half.z + r - Math.abs(local.z);
      if (dx <= 0 || dz <= 0) continue; // no overlap on this axis pair

      // Push out along the shallower axis (classic AABB depenetration).
      const push = new THREE.Vector3();
      if (dx < dz) push.set(Math.sign(local.x) * dx, 0, 0);
      else push.set(0, 0, Math.sign(local.z) * dz);
      push.applyMatrix3(c.rot);
      next.x += push.x;
      next.z += push.z;
    }
  }

  update(dt: number, input: MoveInput) {
    const cfg = this.cfg;

    // ---- slide state ----
    if (input.slide && this.onGround && !this.sliding && input.dir.lengthSq() > 0.04) {
      this.sliding = true;
      this.slideTime = 1.1;
    }
    if (this.sliding) {
      this.slideTime -= dt;
      if (this.slideTime <= 0 || !this.onGround) this.sliding = false;
    }

    // ---- horizontal velocity ----
    const speed = this.sliding ? cfg.slideSpeed : cfg.walkSpeed;
    const want = new THREE.Vector3(input.dir.x, 0, input.dir.y).multiplyScalar(speed);
    // Snappy on the ground, floatier in the air so jumps feel committed.
    const accel = this.onGround ? (this.sliding ? 2 : 14) : 4;
    this.vel.x = THREE.MathUtils.damp(this.vel.x, want.x, accel, dt);
    this.vel.z = THREE.MathUtils.damp(this.vel.z, want.z, accel, dt);

    if (input.dir.lengthSq() > 0.001) {
      // Pip is modelled facing -Z (beak toward -Z), so a yaw of 0 already points
      // him "north". Rotating by θ sends -Z to (-sin θ, -cos θ).
      this.facing = Math.atan2(-input.dir.x, -input.dir.y);
    }

    // ---- jump + gravity ----
    if (input.jump && this.onGround) {
      this.vel.y = cfg.jumpSpeed;
      this.onGround = false;
    }
    this.vel.y -= cfg.gravity * dt;
    if (this.vel.y < -160) this.vel.y = -160;

    // ---- integrate ----
    const next = this.pos.clone();
    next.x += this.vel.x * dt;
    next.z += this.vel.z * dt;
    this.resolveHorizontal(next);
    next.y += this.vel.y * dt;

    // ---- ground ----
    const ground = this.surfaceY(next.x, next.z, this.pos.y + this.cfg.stepHeight);
    if (next.y <= ground) {
      // Step up onto ledges and ramps within reach rather than being stopped.
      next.y = ground;
      if (this.vel.y < 0) this.vel.y = 0;
      this.onGround = true;
    } else if (this.onGround && this.vel.y <= 0 && next.y - ground <= this.cfg.stepHeight) {
      // Walking *down* a step or ramp: stay glued rather than launching into a
      // fall on every tread, which is what made stairs feel like a landing test.
      next.y = ground;
      this.vel.y = 0;
      this.onGround = true;
    } else {
      this.onGround = false;
    }

    this.pos.copy(next);
  }
}

import * as THREE from 'three';
import { colliderTopAt, THIN_STEP, type Collider, type ColliderGrid } from './world';

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
  /** Penguins are faster in the water than out of it, and Pip is no exception. */
  swimSpeed: number;
  jumpSpeed: number;
  gravity: number;
  stepHeight: number;
  groundY: (x: number, z: number) => number;
  /** Surface height of the water over a point, or null on dry land. */
  waterY: (x: number, z: number) => number | null;
  /** Colliders that move — currently just the two drawbridge flaps. Too few to
   *  be worth re-hashing into the spatial grid every frame. */
  moving?: () => Collider[];
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
  swimming = false;
  /** Water surface over Pip right now, or null when he's on dry land. */
  waterLevel: number | null = null;
  /** How deep his feet are below the surface. Negative when he's above it. */
  submersion = 0;
  /** Set for one frame when he breaks the surface, with the speed he hit at. */
  splashed = 0;
  facing = 0;
  private slideTime = 0;
  private wasUnderwater = false;
  private scratch: Collider[] = [];

  constructor(
    private grid: ColliderGrid,
    private cfg: ControllerConfig,
  ) {}

  get height(): number {
    return this.cfg.height;
  }

  /** Every collider near a point: the static grid plus anything in motion. */
  private near(p: THREE.Vector3, radius: number): Collider[] {
    const list = this.grid.query(p, radius, this.scratch);
    const moving = this.cfg.moving?.();
    if (moving) for (const c of moving) if (!list.includes(c)) list.push(c);
    return list;
  }

  /**
   * Highest solid surface under Pip's FOOTPRINT, including static parts and
   * ramps. `feet` is where he actually is; rails and parapets are only
   * reachable from within a kerb's height of it, so he can't perch on one.
   *
   * Sampling his whole footprint rather than a single centre point is what
   * stops him dropping through gaps narrower than he is. The neighbourhood's
   * roof stair has 2-stud treads spaced 3.2 apart — a 1.2-stud hole between
   * every step — and a centre-point test drops you straight down the first one.
   */
  surfaceY(x: number, z: number, from: number, feet = from): number {
    let best = this.cfg.groundY(x, z);
    const probe = new THREE.Vector3(x, from, z);
    const list = this.near(probe, this.cfg.radius + 2);
    const o = this.cfg.radius * 0.8;
    const SAMPLES: [number, number][] = [[0, 0], [o, 0], [-o, 0], [0, o], [0, -o]];
    for (const c of list) {
      const reach = c.thin ? Math.min(from + 0.35, feet + THIN_STEP) : from + 0.35;
      for (const [ox, oz] of SAMPLES) {
        const top = colliderTopAt(c, x + ox, z + oz);
        if (top === null) continue;
        if (top <= reach && top > best) best = top;
      }
    }
    return best;
  }

  private resolveHorizontal(next: THREE.Vector3) {
    const r = this.cfg.radius;
    const feet = next.y;
    const head = next.y + this.cfg.height;
    const list = this.near(next, r + 3);
    const local = new THREE.Vector3();

    for (const c of list) {
      const bottom = c.center.y - c.worldHalfY;
      if (bottom >= head) continue; // clears our head entirely

      // A ramp is only a wall where its slope has risen out of reach. Sampling
      // the surface height at our own footprint is what lets Pip walk up every
      // wedge and every tilted slab in the world instead of bouncing off its
      // bounding box.
      //
      // A null here means the search never found the part at all, and that is
      // decisive: the box test below projects a world-flat offset through the
      // part's inverse rotation, which for anything tilted about X or Z claims
      // a footprint several studs wider than the part really is. Trusting the
      // box there is what stood an eighteen-stud wall across the bridge
      // approach and a fourteen-stud one across the deck.
      const top = colliderTopAt(c, next.x, next.z, true);
      if (top === null) continue;
      // A rail is a wall the moment it is more than a kerb above your feet.
      //
      // The non-thin limit has to match what surfaceY will actually lift him
      // onto (stepHeight + its 0.35 of slack). With the two out of step, any
      // riser between 1.4 and 1.75 — the fire escape's are 1.55 — was blocked
      // horizontally before the ground check ever got the chance to climb it.
      const limit = c.thin ? THIN_STEP : this.cfg.stepHeight + 0.35;
      if (top <= feet + limit) continue;

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

    // ---- water ----
    // Feet-relative, because that's what decides whether Pip is wading through
    // a puddle or actually swimming. WADE_DEPTH is roughly knee height on him.
    const WADE_DEPTH = 1.3;
    this.waterLevel = cfg.waterY(this.pos.x, this.pos.z);
    this.submersion = this.waterLevel === null ? -Infinity : this.waterLevel - this.pos.y;
    const inWater = this.submersion > 0;
    // Hysteresis: without it, bobbing at the surface flickers between swimming
    // and walking and the animation strobes.
    this.swimming = this.submersion > (this.swimming ? WADE_DEPTH * 0.7 : WADE_DEPTH);

    this.splashed = 0;
    if (inWater !== this.wasUnderwater) {
      if (inWater) this.splashed = Math.abs(this.vel.y);
      this.wasUnderwater = inWater;
    }

    // ---- slide state ----
    if (input.slide && this.onGround && !this.swimming && !this.sliding && input.dir.lengthSq() > 0.04) {
      this.sliding = true;
      this.slideTime = 1.1;
    }
    if (this.sliding) {
      this.slideTime -= dt;
      if (this.slideTime <= 0 || (!this.onGround && !this.swimming)) this.sliding = false;
    }

    // ---- horizontal velocity ----
    const speed = this.swimming ? cfg.swimSpeed : this.sliding ? cfg.slideSpeed : cfg.walkSpeed;
    const want = new THREE.Vector3(input.dir.x, 0, input.dir.y).multiplyScalar(speed);
    // Snappy on the ground, floatier in the air so jumps feel committed, and
    // heavier still in the water so it has some body to it.
    const accel = this.swimming ? 5 : this.onGround ? (this.sliding ? 2 : 14) : 4;
    this.vel.x = THREE.MathUtils.damp(this.vel.x, want.x, accel, dt);
    this.vel.z = THREE.MathUtils.damp(this.vel.z, want.z, accel, dt);

    if (input.dir.lengthSq() > 0.001) {
      // Pip is modelled facing -Z (beak toward -Z), so a yaw of 0 already points
      // him "north". Rotating by θ sends -Z to (-sin θ, -cos θ).
      this.facing = Math.atan2(-input.dir.x, -input.dir.y);
    }

    // ---- vertical ----
    if (this.swimming) {
      // Buoyancy is a damped spring toward a float line just under the surface,
      // so a dive from the bridge sinks, slows and pops him back up on its own.
      // Floats him high enough that the prone swim pose actually breaks the
      // surface — at -1.8 a horizontal penguin was completely submerged.
      const floatY = this.waterLevel! - 1.35;
      const toward = floatY - this.pos.y;
      // A properly damped spring, not a constant shove: a constant one never
      // sheds the energy of the entry and leaves him porpoising up and down.
      this.vel.y += THREE.MathUtils.clamp(toward, -5, 5) * 15 * dt;
      this.vel.y *= Math.exp(-4.2 * dt);                              // drag
      if (input.jump) this.vel.y = Math.max(this.vel.y, 11);          // a kick upward
      if (input.slide) this.vel.y -= 44 * dt;                         // hold to duck under
      this.vel.y = THREE.MathUtils.clamp(this.vel.y, -26, 16);
      this.onGround = false;
    } else {
      if (input.jump && this.onGround) {
        this.vel.y = cfg.jumpSpeed;
        this.onGround = false;
      }
      this.vel.y -= cfg.gravity * dt;
      if (this.vel.y < -160) this.vel.y = -160;
    }

    // ---- integrate ----
    const next = this.pos.clone();
    next.x += this.vel.x * dt;
    next.z += this.vel.z * dt;
    this.resolveHorizontal(next);
    next.y += this.vel.y * dt;

    // ---- ground ----
    const ground = this.surfaceY(next.x, next.z, this.pos.y + this.cfg.stepHeight, this.pos.y);
    if (next.y <= ground) {
      // Step up onto ledges and ramps within reach rather than being stopped.
      // This still applies while swimming: it's what lets him touch down on the
      // bed and wade back up the bank instead of treading water at the shore.
      next.y = ground;
      if (this.vel.y < 0) this.vel.y = 0;
      this.onGround = !this.swimming;
    } else if (!this.swimming && this.onGround && this.vel.y <= 0 && next.y - ground <= this.cfg.stepHeight) {
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

import * as THREE from 'three';

/**
 * Pip. Built from primitives like the Roblox rig — the chunky silhouette is
 * the character — but with rounder forms and softer materials than parts
 * allowed. Animation is fully procedural: waddle, flipper flap, belly slide.
 */
export class Pip {
  root = new THREE.Group();
  private body!: THREE.Mesh;
  private head!: THREE.Group;
  private flipperL!: THREE.Mesh;
  private flipperR!: THREE.Mesh;
  private footL!: THREE.Mesh;
  private footR!: THREE.Mesh;
  private t = 0;

  constructor() {
    const BLACK = new THREE.Color('#2b2f36');
    const WHITE = new THREE.Color('#f2ece1');
    const BEAK = new THREE.Color('#e8a33d');

    const skin = (c: THREE.Color, rough = 0.72) =>
      new THREE.MeshStandardMaterial({ color: c, roughness: rough, metalness: 0 });

    // ---- body: egg-shaped, slightly squashed sphere ----
    const bodyGeo = new THREE.SphereGeometry(1, 24, 18);
    bodyGeo.scale(0.92, 1.18, 0.86);
    this.body = new THREE.Mesh(bodyGeo, skin(BLACK));
    this.body.position.y = 1.25;
    this.body.castShadow = true;
    this.root.add(this.body);

    // belly patch, pushed slightly forward so it reads from the front
    const bellyGeo = new THREE.SphereGeometry(1, 20, 16);
    bellyGeo.scale(0.7, 0.95, 0.6);
    const belly = new THREE.Mesh(bellyGeo, skin(WHITE, 0.8));
    belly.position.set(0, 1.2, -0.35);
    this.root.add(belly);

    // ---- head ----
    this.head = new THREE.Group();
    this.head.position.y = 2.5;
    this.root.add(this.head);

    const headGeo = new THREE.SphereGeometry(0.72, 22, 16);
    headGeo.scale(1, 0.95, 0.95);
    const headMesh = new THREE.Mesh(headGeo, skin(BLACK));
    headMesh.castShadow = true;
    this.head.add(headMesh);

    const faceGeo = new THREE.SphereGeometry(0.6, 18, 14);
    faceGeo.scale(0.8, 0.85, 0.5);
    const face = new THREE.Mesh(faceGeo, skin(WHITE, 0.8));
    face.position.set(0, -0.04, -0.42);
    this.head.add(face);

    const beak = new THREE.Mesh(new THREE.ConeGeometry(0.17, 0.44, 12), skin(BEAK, 0.55));
    beak.rotation.x = -Math.PI / 2;
    beak.position.set(0, -0.06, -0.78);
    this.head.add(beak);

    for (const side of [-1, 1]) {
      const eye = new THREE.Mesh(
        new THREE.SphereGeometry(0.1, 12, 10),
        skin(new THREE.Color('#15171c'), 0.35),
      );
      eye.position.set(side * 0.25, 0.12, -0.6);
      this.head.add(eye);
      const glint = new THREE.Mesh(
        new THREE.SphereGeometry(0.032, 8, 6),
        new THREE.MeshBasicMaterial({ color: '#ffffff' }),
      );
      glint.position.set(side * 0.28, 0.17, -0.66);
      this.head.add(glint);
    }

    // ---- flippers ----
    const flipperGeo = new THREE.SphereGeometry(0.5, 14, 10);
    flipperGeo.scale(0.2, 0.95, 0.5);
    this.flipperL = new THREE.Mesh(flipperGeo, skin(BLACK));
    this.flipperL.position.set(-0.88, 1.35, 0);
    this.flipperL.castShadow = true;
    this.root.add(this.flipperL);
    this.flipperR = this.flipperL.clone();
    this.flipperR.position.x = 0.88;
    this.root.add(this.flipperR);

    // ---- feet ----
    const footGeo = new THREE.SphereGeometry(0.4, 12, 9);
    footGeo.scale(0.55, 0.3, 0.95);
    this.footL = new THREE.Mesh(footGeo, skin(BEAK, 0.6));
    this.footL.position.set(-0.34, 0.16, -0.16);
    this.footL.castShadow = true;
    this.root.add(this.footL);
    this.footR = this.footL.clone();
    this.footR.position.x = 0.34;
    this.root.add(this.footR);
  }

  /**
   * @param speed01 horizontal speed normalised to walk speed
   * @param facing  yaw in radians
   */
  update(dt: number, speed01: number, facing: number, sliding: boolean, airborne: boolean) {
    this.t += dt * (1 + speed01 * 5.5);
    const swing = Math.sin(this.t * 2.2);

    // Turn smoothly toward the direction of travel.
    const target = facing;
    let delta = target - this.root.rotation.y;
    while (delta > Math.PI) delta -= Math.PI * 2;
    while (delta < -Math.PI) delta += Math.PI * 2;
    this.root.rotation.y += delta * Math.min(1, dt * 12);

    if (sliding) {
      // Belly-down, flippers swept back, nose forward.
      this.root.rotation.x = THREE.MathUtils.damp(this.root.rotation.x, -Math.PI / 2.2, 10, dt);
      this.root.position.y = THREE.MathUtils.damp(this.root.position.y, -0.55, 10, dt);
      this.flipperL.rotation.x = THREE.MathUtils.damp(this.flipperL.rotation.x, 0.9, 10, dt);
      this.flipperR.rotation.x = this.flipperL.rotation.x;
      this.flipperL.rotation.z = -0.5;
      this.flipperR.rotation.z = 0.5;
      this.head.rotation.x = THREE.MathUtils.damp(this.head.rotation.x, 0.7, 10, dt);
      return;
    }

    this.root.rotation.x = THREE.MathUtils.damp(this.root.rotation.x, 0, 10, dt);
    this.root.position.y = THREE.MathUtils.damp(this.root.position.y, 0, 10, dt);
    this.head.rotation.x = THREE.MathUtils.damp(this.head.rotation.x, 0, 8, dt);

    // The waddle: body rocks side to side, feet paddle, head bobs a beat behind.
    const rock = swing * 0.17 * speed01;
    this.root.rotation.z = rock;
    this.body.position.y = 1.25 + Math.abs(swing) * 0.07 * speed01;
    this.head.position.y = 2.5 + Math.abs(Math.sin(this.t * 2.2 - 0.5)) * 0.05 * speed01;
    this.head.rotation.z = -rock * 0.5;

    this.footL.position.z = -0.16 + swing * 0.42 * speed01;
    this.footR.position.z = -0.16 - swing * 0.42 * speed01;
    this.footL.position.y = 0.16 + Math.max(0, swing) * 0.18 * speed01;
    this.footR.position.y = 0.16 + Math.max(0, -swing) * 0.18 * speed01;

    if (airborne) {
      // Flap! Penguins can't fly, but Pip is an optimist.
      this.flipperL.rotation.z = THREE.MathUtils.damp(this.flipperL.rotation.z, -0.5 + Math.sin(this.t * 9) * 0.5, 14, dt);
      this.flipperR.rotation.z = -this.flipperL.rotation.z;
      this.flipperL.rotation.x = 0;
      this.flipperR.rotation.x = 0;
    } else {
      this.flipperL.rotation.x = -swing * 0.5 * speed01;
      this.flipperR.rotation.x = swing * 0.5 * speed01;
      this.flipperL.rotation.z = THREE.MathUtils.damp(this.flipperL.rotation.z, 0.12, 10, dt);
      this.flipperR.rotation.z = -this.flipperL.rotation.z;
    }
  }
}

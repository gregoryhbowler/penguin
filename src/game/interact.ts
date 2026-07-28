import * as THREE from 'three';
import type { PartData } from '../engine/world';
import type { UI } from './ui';

/**
 * Ports the Roblox InteractionService idea: the world is data, and tagged
 * parts become interactions. Same tags, same attributes — the design carried
 * over from the .rbxlx intact, only the runtime changed.
 */
interface Interactable {
  part: PartData;
  pos: THREE.Vector3;
  kind: string;
  label: string;
  verb: string;
  range: number;
  object3D?: THREE.Object3D;
  done?: boolean;
}

const NPC_LINES: Record<string, { name: string; lines: string[] }> = {
  AshCat: {
    name: 'Ash the Cat',
    lines: [
      'Mew… mew! Ash is tangled in the collapsed tent.',
      'Mrrow! Ash scrambles free and shakes the soot off.',
      'Ash bumps your flipper with a grateful head-boop.',
    ],
  },
  RangerMaple: {
    name: 'Ranger Maple',
    lines: [
      'A penguin! You must be from the old firehouse across the river.',
      'A strange storm swept through. Now memory fires keep sparking, and the forest spirits are… troubled.',
      "They aren't bad — just hurting. Help them remember what they love, and the way home will open.",
    ],
  },
};

export class Interactables {
  private items: Interactable[] = [];
  private fires: { part: PartData; group: THREE.Group; health: number; out: boolean }[] = [];
  private hasBucket = false;
  private bucketFull = false;
  private t = 0;

  constructor(
    private scene: THREE.Scene,
    byTag: Map<string, PartData[]>,
    private ui: UI,
  ) {
    for (const p of byTag.get('Pickup') ?? []) {
      const kind = String(p.attrs?.Kind ?? 'QuestItem');
      this.items.push({
        part: p,
        pos: new THREE.Vector3(...p.pos),
        kind: 'Pickup:' + kind,
        label: String(p.attrs?.Label ?? p.name),
        verb: kind === 'Food' ? 'Eat' : 'Pick up',
        range: 9,
        object3D: this.spawnPickupVisual(p, kind),
      });
    }

    for (const p of byTag.get('NPCSpot') ?? []) {
      const id = String(p.attrs?.NpcId ?? '');
      this.items.push({
        part: p,
        pos: new THREE.Vector3(...p.pos),
        kind: 'NPC:' + id,
        label: NPC_LINES[id]?.name ?? id,
        verb: id === 'AshCat' ? 'Rescue' : 'Talk',
        range: 10,
        object3D: this.spawnNpcVisual(p, id),
      });
    }

    for (const p of byTag.get('WaterSource') ?? []) {
      this.items.push({
        part: p,
        pos: new THREE.Vector3(...p.pos),
        kind: 'Water',
        label: 'Water',
        verb: 'Fill Bucket',
        range: 12,
      });
    }

    for (const p of byTag.get('FireSpot') ?? []) {
      this.fires.push({ part: p, group: this.spawnFire(p), health: 1, out: false });
    }
  }

  private spawnPickupVisual(p: PartData, kind: string): THREE.Object3D {
    const g = new THREE.Group();
    const color = kind === 'Food' ? '#d94c58' : '#b9c6c2';
    const mesh = new THREE.Mesh(
      new THREE.BoxGeometry(1.1, 1.1, 1.1),
      new THREE.MeshStandardMaterial({ color, roughness: 0.6, metalness: 0.15 }),
    );
    mesh.castShadow = true;
    g.add(mesh);
    // A cool sparkle — never warm, per the palette law.
    const halo = new THREE.Mesh(
      new THREE.SphereGeometry(0.28, 10, 8),
      new THREE.MeshBasicMaterial({ color: '#cfe6ee', transparent: true, opacity: 0.75 }),
    );
    halo.position.y = 1.4;
    g.add(halo);
    g.position.set(...p.pos);
    this.scene.add(g);
    return g;
  }

  private spawnNpcVisual(p: PartData, id: string): THREE.Object3D {
    const g = new THREE.Group();
    if (id === 'AshCat') {
      const grey = new THREE.MeshStandardMaterial({ color: '#7e7c84', roughness: 0.85 });
      const body = new THREE.Mesh(new THREE.SphereGeometry(0.9, 16, 12), grey);
      body.scale.set(0.85, 0.7, 1.2);
      body.position.y = 0.85;
      body.castShadow = true;
      g.add(body);
      const head = new THREE.Mesh(new THREE.SphereGeometry(0.55, 14, 11), grey);
      head.position.set(0, 1.6, -0.85);
      head.castShadow = true;
      g.add(head);
      for (const s of [-1, 1]) {
        const ear = new THREE.Mesh(new THREE.ConeGeometry(0.17, 0.4, 6), grey);
        ear.position.set(s * 0.25, 2.05, -0.85);
        g.add(ear);
        const eye = new THREE.Mesh(
          new THREE.SphereGeometry(0.09, 8, 6),
          new THREE.MeshStandardMaterial({ color: '#8ec87a', roughness: 0.3 }),
        );
        eye.position.set(s * 0.2, 1.68, -1.3);
        g.add(eye);
      }
    } else {
      // Simple stand-in figure until the full NPC kit is ported.
      const coat = new THREE.MeshStandardMaterial({ color: '#5c7350', roughness: 0.9 });
      const torso = new THREE.Mesh(new THREE.CapsuleGeometry(0.75, 1.5, 6, 12), coat);
      torso.position.y = 2.6;
      torso.castShadow = true;
      g.add(torso);
      const head = new THREE.Mesh(
        new THREE.SphereGeometry(0.6, 16, 12),
        new THREE.MeshStandardMaterial({ color: '#e0b291', roughness: 0.8 }),
      );
      head.position.y = 4.1;
      head.castShadow = true;
      g.add(head);
      const hat = new THREE.Mesh(
        new THREE.CylinderGeometry(0.85, 0.85, 0.18, 14),
        new THREE.MeshStandardMaterial({ color: '#6b5136', roughness: 0.9 }),
      );
      hat.position.y = 4.6;
      g.add(hat);
    }
    g.position.set(p.pos[0], p.pos[1], p.pos[2]);
    g.rotation.y = THREE.MathUtils.degToRad(Number(p.attrs?.FaceYaw ?? 0));
    this.scene.add(g);
    return g;
  }

  /** Fire is the one warm thing in the world — so it's the only thing that glows. */
  private spawnFire(p: PartData): THREE.Group {
    const g = new THREE.Group();
    g.position.set(p.pos[0], p.pos[1], p.pos[2]);
    for (let i = 0; i < 7; i++) {
      const flame = new THREE.Mesh(
        new THREE.ConeGeometry(0.55, 2.2, 7),
        new THREE.MeshBasicMaterial({
          color: i % 2 ? '#ff8b3d' : '#ffc25e',
          transparent: true,
          opacity: 0.85,
        }),
      );
      flame.position.set((Math.random() - 0.5) * 1.9, 1 + Math.random() * 0.5, (Math.random() - 0.5) * 1.9);
      flame.userData.phase = Math.random() * Math.PI * 2;
      flame.userData.baseY = flame.position.y;
      g.add(flame);
    }
    const light = new THREE.PointLight('#ff9645', 3.2, 42, 2);
    light.position.y = 2.2;
    g.add(light);
    this.scene.add(g);
    return g;
  }

  update(dt: number, playerPos: THREE.Vector3, act: boolean) {
    this.t += dt;

    // flicker
    for (const f of this.fires) {
      if (f.out) continue;
      for (const child of f.group.children) {
        if ((child as THREE.Mesh).isMesh) {
          const ph = child.userData.phase as number;
          child.position.y = child.userData.baseY + Math.sin(this.t * 7 + ph) * 0.18;
          child.scale.setScalar(0.85 + Math.sin(this.t * 9 + ph) * 0.16);
        } else if ((child as THREE.PointLight).isPointLight) {
          (child as THREE.PointLight).intensity = 2.8 + Math.sin(this.t * 11) * 0.7;
        }
      }
    }

    // bob pickups
    for (const it of this.items) {
      if (it.done || !it.object3D || !it.kind.startsWith('Pickup')) continue;
      it.object3D.position.y = it.pos.y + Math.sin(this.t * 2 + it.pos.x) * 0.22;
      it.object3D.rotation.y += dt * 0.8;
    }

    // nearest interactable
    let best: Interactable | null = null;
    let bestD = Infinity;
    for (const it of this.items) {
      if (it.done) continue;
      const d = it.pos.distanceTo(playerPos);
      if (d < it.range && d < bestD) { best = it; bestD = d; }
    }

    // a burning fire in bucket range is also an "interaction"
    let fireTarget: typeof this.fires[number] | null = null;
    for (const f of this.fires) {
      if (f.out) continue;
      const d = new THREE.Vector3(...f.part.pos).distanceTo(playerPos);
      if (d < 12) fireTarget = f;
    }

    if (fireTarget && this.bucketFull) {
      this.ui.showPrompt('Throw water on the fire');
    } else if (best) {
      this.ui.showPrompt(`${best.verb} ${best.label}`);
    } else {
      this.ui.hidePrompt();
    }

    if (!act) return;

    if (fireTarget && this.bucketFull) {
      this.bucketFull = false;
      fireTarget.out = true;
      this.scene.remove(fireTarget.group);
      this.ui.toast('The flames hiss out in a cloud of steam!', 'good');
      this.ui.setTask('A Small Rescue', 'Rescue Ash the cat from the smoky tent.',
        'Walk up to Ash and press E.');
      this.ui.addSparks(10);
      return;
    }
    if (!best) return;

    if (best.kind === 'Water') {
      if (!this.hasBucket) { this.ui.toast('You need a bucket to carry water.', 'hint'); return; }
      if (this.bucketFull) { this.ui.toast('Your bucket is already full!', 'hint'); return; }
      this.bucketFull = true;
      this.ui.toast('Bucket filled! Carry it to the flames.', 'good');
      this.ui.setTask('The First Fire', 'Put out the campfire that is scorching the path.',
        'Get close to the flames and press E.');
      return;
    }

    if (best.kind.startsWith('Pickup')) {
      const item = String(best.part.attrs?.Item ?? '');
      if (best.kind === 'Pickup:Food') {
        this.ui.toast(`Ate ${best.label}. Energy restored!`, 'good');
        this.ui.addEnergy(18);
        return;
      }
      best.done = true;
      if (best.object3D) this.scene.remove(best.object3D);
      this.ui.toast(`Picked up: ${best.label}`, 'good');
      if (item === 'Bucket') {
        this.hasBucket = true;
        this.ui.setTask('Cold, Clear Water', 'Fill your bucket at the pond.',
          "Stand at the water's edge and press E.");
      }
      return;
    }

    if (best.kind.startsWith('NPC:')) {
      const id = best.kind.slice(4);
      const def = NPC_LINES[id];
      if (def) this.ui.dialogue(def.name, def.lines);
      if (id === 'AshCat') {
        best.done = true;
        this.ui.addSparks(20);
        this.ui.setTask("The Ranger's Warning", 'Talk to Ranger Maple at the forest gate.',
          'Follow the lanterns north out of the campsite.');
      }
    }
  }
}

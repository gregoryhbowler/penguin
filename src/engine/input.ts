import * as THREE from 'three';

/** Keyboard + mouse on desktop, virtual stick + buttons on touch. */
export class Input {
  move = new THREE.Vector2();
  look = new THREE.Vector2();
  jump = false;
  slide = false;
  private action = false;
  private keys = new Set<string>();
  private pointerLocked = false;

  constructor(private canvas: HTMLCanvasElement) {
    addEventListener('keydown', (e) => {
      if (e.repeat) return;
      this.keys.add(e.code);
      if (e.code === 'Space') { this.jump = true; e.preventDefault(); }
      if (e.code === 'KeyE') this.action = true;
    });
    addEventListener('keyup', (e) => this.keys.delete(e.code));
    addEventListener('blur', () => this.keys.clear());

    // Drag to look; pointer lock when held, so it feels like a game not a page.
    canvas.addEventListener('pointerdown', (e) => {
      if (e.pointerType === 'mouse') canvas.requestPointerLock?.();
    });
    document.addEventListener('pointerlockchange', () => {
      this.pointerLocked = document.pointerLockElement === canvas;
    });
    addEventListener('pointermove', (e) => {
      if (this.pointerLocked) this.look.set(e.movementX, e.movementY);
    });

    if (matchMedia('(pointer: coarse)').matches) this.setupTouch();
  }

  private setupTouch() {
    const wrap = document.getElementById('touch')!;
    wrap.hidden = false;
    const stick = document.getElementById('stick')!;
    const knob = stick.querySelector('i') as HTMLElement;
    let stickId: number | null = null;
    let origin = { x: 0, y: 0 };

    stick.addEventListener('pointerdown', (e) => {
      stickId = e.pointerId;
      const r = stick.getBoundingClientRect();
      origin = { x: r.left + r.width / 2, y: r.top + r.height / 2 };
      stick.setPointerCapture(e.pointerId);
    });
    stick.addEventListener('pointermove', (e) => {
      if (e.pointerId !== stickId) return;
      const dx = e.clientX - origin.x;
      const dy = e.clientY - origin.y;
      const max = 52;
      const len = Math.hypot(dx, dy) || 1;
      const cl = Math.min(len, max);
      const nx = (dx / len) * cl;
      const ny = (dy / len) * cl;
      knob.style.transform = `translate(${nx}px, ${ny}px)`;
      this.move.set(nx / max, -ny / max);
    });
    const endStick = (e: PointerEvent) => {
      if (e.pointerId !== stickId) return;
      stickId = null;
      knob.style.transform = '';
      this.move.set(0, 0);
    };
    stick.addEventListener('pointerup', endStick);
    stick.addEventListener('pointercancel', endStick);

    document.getElementById('btnJump')!.addEventListener('pointerdown', () => { this.jump = true; });
    document.getElementById('btnAct')!.addEventListener('pointerdown', () => { this.action = true; });

    // Drag anywhere on the right half of the screen to look around.
    let lookId: number | null = null;
    let lastX = 0, lastY = 0;
    this.canvas.addEventListener('pointerdown', (e) => {
      if (e.clientX < innerWidth * 0.4) return;
      lookId = e.pointerId; lastX = e.clientX; lastY = e.clientY;
    });
    this.canvas.addEventListener('pointermove', (e) => {
      if (e.pointerId !== lookId) return;
      this.look.set(e.clientX - lastX, e.clientY - lastY);
      lastX = e.clientX; lastY = e.clientY;
    });
    const endLook = (e: PointerEvent) => { if (e.pointerId === lookId) lookId = null; };
    this.canvas.addEventListener('pointerup', endLook);
    this.canvas.addEventListener('pointercancel', endLook);
  }

  consumeAction(): boolean {
    const a = this.action;
    this.action = false;
    return a;
  }

  /** Sample the keyboard. Touch writes `move`/`slide` directly from handlers. */
  update() {
    if (matchMedia('(pointer: coarse)').matches) return;
    const k = this.keys;
    this.move.set(
      (k.has('KeyD') || k.has('ArrowRight') ? 1 : 0) - (k.has('KeyA') || k.has('ArrowLeft') ? 1 : 0),
      (k.has('KeyW') || k.has('ArrowUp') ? 1 : 0) - (k.has('KeyS') || k.has('ArrowDown') ? 1 : 0),
    );
    this.slide = k.has('ControlLeft') || k.has('ShiftLeft');
  }
}

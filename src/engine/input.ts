import * as THREE from 'three';

export type Scheme = 'desktop' | 'touch';

/**
 * Two first-class control schemes.
 *
 * Desktop: WASD + mouse-drag look + scroll zoom, the way you'd expect a
 * third-person PC game to behave.
 * Touch: laid out the way Roblox mobile does it, because that's the muscle
 * memory a Roblox player already has — a thumbstick that appears wherever
 * your left thumb lands, right-side drag to swing the camera, a big jump
 * button, and a contextual action button.
 */
export class Input {
  scheme: Scheme;
  move = new THREE.Vector2();   // x = strafe, y = forward
  look = new THREE.Vector2();   // consumed each frame by the camera
  zoom = 0;                     // accumulated zoom delta
  jump = false;
  slide = false;

  private action = false;
  private keys = new Set<string>();
  private lookPointer: number | null = null;
  private lookLast = new THREE.Vector2();
  private stickPointer: number | null = null;
  private stickOrigin = new THREE.Vector2();
  private pinchDist = 0;
  private activePinch = new Map<number, THREE.Vector2>();

  constructor(private canvas: HTMLCanvasElement) {
    this.scheme = matchMedia('(pointer: coarse)').matches ? 'touch' : 'desktop';
    this.bindKeyboard();
    if (this.scheme === 'touch') this.bindTouch();
    else this.bindMouse();
  }

  // ---------------------------------------------------------------- keyboard
  private bindKeyboard() {
    const onDown = (e: KeyboardEvent) => {
      // Never swallow keys while the player is typing somewhere.
      if ((e.target as HTMLElement)?.tagName === 'INPUT') return;
      this.keys.add(e.code);
      if (e.code === 'Space') { this.jump = true; e.preventDefault(); }
      if (e.code === 'KeyE' || e.code === 'Enter') this.action = true;
      if (['KeyW','KeyA','KeyS','KeyD','ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(e.code)) {
        e.preventDefault(); // stop arrow keys scrolling the page
      }
    };
    addEventListener('keydown', onDown, { passive: false });
    addEventListener('keyup', (e) => this.keys.delete(e.code));
    // Losing focus mid-stride would otherwise leave Pip walking forever.
    addEventListener('blur', () => { this.keys.clear(); this.move.set(0, 0); });
  }

  // ------------------------------------------------------------------- mouse
  private bindMouse() {
    const c = this.canvas;
    c.addEventListener('contextmenu', (e) => e.preventDefault());

    c.addEventListener('pointerdown', (e) => {
      this.lookPointer = e.pointerId;
      this.lookLast.set(e.clientX, e.clientY);
      c.setPointerCapture(e.pointerId);
      c.style.cursor = 'grabbing';
    });
    c.addEventListener('pointermove', (e) => {
      if (e.pointerId !== this.lookPointer) return;
      this.look.x += e.clientX - this.lookLast.x;
      this.look.y += e.clientY - this.lookLast.y;
      this.lookLast.set(e.clientX, e.clientY);
    });
    const end = (e: PointerEvent) => {
      if (e.pointerId !== this.lookPointer) return;
      this.lookPointer = null;
      c.style.cursor = 'grab';
    };
    c.addEventListener('pointerup', end);
    c.addEventListener('pointercancel', end);
    c.style.cursor = 'grab';

    addEventListener('wheel', (e) => {
      this.zoom += Math.sign(e.deltaY) * 2.2;
      e.preventDefault();
    }, { passive: false });
  }

  // ------------------------------------------------------------------- touch
  private bindTouch() {
    const wrap = document.getElementById('touch')!;
    wrap.hidden = false;
    const stick = document.getElementById('stick') as HTMLElement;
    const knob = stick.querySelector('i') as HTMLElement;
    const MAX = 56;

    // The stick is invisible until the thumb lands, then springs up there —
    // exactly the Roblox mobile feel.
    const showStick = (x: number, y: number) => {
      stick.style.left = `${x - 70}px`;
      stick.style.top = `${y - 70}px`;
      stick.style.opacity = '1';
      this.stickOrigin.set(x, y);
    };
    const hideStick = () => {
      stick.style.opacity = '0';
      knob.style.transform = '';
      this.move.set(0, 0);
    };
    hideStick();

    this.canvas.addEventListener('pointerdown', (e) => {
      this.activePinch.set(e.pointerId, new THREE.Vector2(e.clientX, e.clientY));
      if (e.clientX < innerWidth * 0.45 && this.stickPointer === null) {
        this.stickPointer = e.pointerId;
        showStick(e.clientX, e.clientY);
      } else if (this.lookPointer === null) {
        this.lookPointer = e.pointerId;
        this.lookLast.set(e.clientX, e.clientY);
      }
    });

    this.canvas.addEventListener('pointermove', (e) => {
      if (this.activePinch.has(e.pointerId)) {
        this.activePinch.get(e.pointerId)!.set(e.clientX, e.clientY);
      }
      // Two fingers down = pinch to zoom, and neither drives movement.
      if (this.activePinch.size >= 2) {
        const [a, b] = [...this.activePinch.values()];
        const d = a.distanceTo(b);
        if (this.pinchDist > 0) this.zoom += (this.pinchDist - d) * 0.06;
        this.pinchDist = d;
        return;
      }
      if (e.pointerId === this.stickPointer) {
        const dx = e.clientX - this.stickOrigin.x;
        const dy = e.clientY - this.stickOrigin.y;
        const len = Math.hypot(dx, dy) || 1;
        const cl = Math.min(len, MAX);
        const nx = (dx / len) * cl;
        const ny = (dy / len) * cl;
        knob.style.transform = `translate(${nx}px, ${ny}px)`;
        this.move.set(nx / MAX, -ny / MAX);
      } else if (e.pointerId === this.lookPointer) {
        this.look.x += e.clientX - this.lookLast.x;
        this.look.y += e.clientY - this.lookLast.y;
        this.lookLast.set(e.clientX, e.clientY);
      }
    });

    const end = (e: PointerEvent) => {
      this.activePinch.delete(e.pointerId);
      if (this.activePinch.size < 2) this.pinchDist = 0;
      if (e.pointerId === this.stickPointer) { this.stickPointer = null; hideStick(); }
      if (e.pointerId === this.lookPointer) this.lookPointer = null;
    };
    this.canvas.addEventListener('pointerup', end);
    this.canvas.addEventListener('pointercancel', end);

    const btn = (id: string, fn: () => void) => {
      const el = document.getElementById(id)!;
      el.addEventListener('pointerdown', (e) => { e.preventDefault(); e.stopPropagation(); fn(); });
    };
    btn('btnJump', () => { this.jump = true; });
    btn('btnAct', () => { this.action = true; });
    btn('btnSlide', () => { this.slide = true; setTimeout(() => (this.slide = false), 350); });
  }

  // ------------------------------------------------------------------ public
  /** Sample held keys. Touch writes move/slide directly from its handlers. */
  update() {
    if (this.scheme === 'desktop') {
      const k = this.keys;
      const x = (k.has('KeyD') || k.has('ArrowRight') ? 1 : 0) - (k.has('KeyA') || k.has('ArrowLeft') ? 1 : 0);
      const y = (k.has('KeyW') || k.has('ArrowUp') ? 1 : 0) - (k.has('KeyS') || k.has('ArrowDown') ? 1 : 0);
      this.move.set(x, y);
      this.slide = k.has('ControlLeft') || k.has('ShiftLeft') || k.has('ShiftRight');
    }
  }

  consumeAction(): boolean {
    const a = this.action;
    this.action = false;
    return a;
  }

  consumeLook(): THREE.Vector2 {
    const l = this.look.clone();
    this.look.set(0, 0);
    return l;
  }

  consumeZoom(): number {
    const z = this.zoom;
    this.zoom = 0;
    return z;
  }

  consumeJump(): boolean {
    const j = this.jump;
    this.jump = false;
    return j;
  }
}

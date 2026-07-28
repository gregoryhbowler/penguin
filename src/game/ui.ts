/** All HUD/dialogue chrome. Plain DOM — far easier than canvas, and it keeps
 *  the parchment field-journal look the Roblox version established. */
export class UI {
  private sparks = 0;
  private energy = 100;
  private health = 100;
  private dialogueLines: string[] = [];
  private dialogueIndex = 0;
  private bannerTimer = 0;

  private el = {
    loading: document.getElementById('loading')!,
    hud: document.getElementById('hud')!,
    health: document.getElementById('healthFill')!,
    energy: document.getElementById('energyFill')!,
    sparks: document.getElementById('sparkCount')!,
    taskCard: document.getElementById('taskCard')!,
    taskToggle: document.getElementById('taskToggle')!,
    taskTitle: document.getElementById('taskTitle')!,
    taskBody: document.getElementById('taskBody')!,
    taskHint: document.getElementById('taskHint')!,
    banner: document.getElementById('banner')!,
    toasts: document.getElementById('toasts')!,
    prompt: document.getElementById('promptHint')!,
    dialogue: document.getElementById('dialogue')!,
    help: document.getElementById('help')!,
    helpKeys: document.getElementById('helpKeys')!,
    helpOpen: document.getElementById('helpOpen')!,
    helpClose: document.getElementById('helpClose')!,
    underwater: document.getElementById('underwater')!,
  };

  private underwater = false;

  private scheme: 'desktop' | 'touch' = 'desktop';

  constructor() {
    // The task card blocking dialogue was a real complaint in the Roblox build;
    // here it both collapses on demand and yields automatically.
    this.el.taskToggle.addEventListener('click', () => {
      this.el.taskCard.classList.toggle('collapsed');
      this.el.taskToggle.textContent =
        this.el.taskCard.classList.contains('collapsed') ? '+' : '–';
    });
    this.el.dialogue.querySelector('.next')!.addEventListener('click', () => this.advance());

    const closeHelp = () => {
      this.el.help.classList.add('gone');
      this.el.helpOpen.hidden = false;
    };
    this.el.helpClose.addEventListener('click', closeHelp);
    this.el.helpOpen.addEventListener('click', () => {
      this.el.help.classList.remove('gone');
      this.el.helpOpen.hidden = true;
    });
    addEventListener('keydown', (e) => {
      if (e.code === 'Escape' && !this.el.help.classList.contains('gone')) closeHelp();
    });
    addEventListener('keydown', (e) => {
      if (this.el.dialogue.hidden) return;
      if (e.code === 'Space' || e.code === 'Enter' || e.code === 'KeyE') {
        e.preventDefault();
        this.advance();
      }
    });
  }

  /** Fill the help card with the right scheme's controls. */
  setScheme(scheme: 'desktop' | 'touch') {
    this.scheme = scheme;
    const rows: [string, string][] = scheme === 'touch'
      ? [
          ['Left thumb', 'Touch anywhere on the left to steer — the stick appears under your thumb'],
          ['Right drag', 'Swing the camera around Pip'],
          ['Pinch', 'Zoom in and out'],
          ['\u2934', 'Jump, or swim upward when you are in the water'],
          ['E', 'Interact — grab things, talk, put out fires'],
          ['\u2261', 'Belly-slide, or hold it in the water to dive under'],
        ]
      : [
          ['W A S D', 'Waddle around, and swim once you are in the water'],
          ['Drag mouse', 'Swing the camera'],
          ['Scroll', 'Zoom in and out'],
          ['Space', 'Jump, or swim upward when you are in the water'],
          ['Shift', 'Belly-slide, or hold it in the water to dive under'],
          ['E', 'Interact — grab things, talk, put out fires'],
        ];
    this.el.helpKeys.innerHTML = rows
      .map(([k, v]) => `<dt>${k}</dt><dd>${v}</dd>`)
      .join('');
  }

  ready() {
    this.el.loading.classList.add('gone');
    this.el.hud.hidden = false;
    setTimeout(() => (this.el.loading.style.display = 'none'), 900);
    this.setTask('A Strange Morning', 'Look around the campsite and pick up the old Bucket.',
      'The bucket sits by the fallen tent, glinting in the light.');
  }

  setTask(title: string, body: string, hint?: string) {
    this.el.taskTitle.textContent = title;
    this.el.taskBody.textContent = body;
    this.el.taskHint.textContent = hint ? `Hint: ${hint}` : '';
  }

  setUnderwater(on: boolean) {
    if (on === this.underwater) return;
    this.underwater = on;
    this.el.underwater.classList.toggle('on', on);
  }

  showRegion(name: string) {
    this.el.banner.textContent = `—  ${name}  —`;
    this.el.banner.classList.add('show');
    this.bannerTimer = 3.4;
  }

  toast(text: string, kind: 'good' | 'hint' | 'story' = 'hint') {
    const div = document.createElement('div');
    div.className = `toast ${kind}`;
    div.textContent = text;
    this.el.toasts.appendChild(div);
    setTimeout(() => div.remove(), kind === 'story' ? 6000 : 4000);
  }

  showPrompt(text: string) {
    this.el.prompt.hidden = false;
    this.el.prompt.querySelector('b')!.textContent = this.scheme === 'touch' ? 'E' : 'E';
    this.el.prompt.querySelector('span')!.textContent = text;
  }

  hidePrompt() {
    this.el.prompt.hidden = true;
  }

  dialogue(name: string, lines: string[]) {
    this.dialogueLines = lines;
    this.dialogueIndex = -1;
    this.el.dialogue.querySelector('.who')!.textContent = name;
    this.el.dialogue.hidden = false;
    this.el.taskCard.classList.add('hidden-for-dialogue');
    this.advance();
  }

  private advance() {
    this.dialogueIndex++;
    if (this.dialogueIndex >= this.dialogueLines.length) {
      this.el.dialogue.hidden = true;
      this.el.taskCard.classList.remove('hidden-for-dialogue');
      return;
    }
    this.el.dialogue.querySelector('.line')!.textContent = this.dialogueLines[this.dialogueIndex];
    (this.el.dialogue.querySelector('.next') as HTMLElement).textContent =
      this.dialogueIndex === this.dialogueLines.length - 1 ? 'Done ✔' : 'Continue ▸';
  }

  addSparks(n: number) {
    this.sparks += n;
    this.el.sparks.textContent = String(this.sparks);
    this.toast(`+${n} Sparks`, 'good');
  }

  addEnergy(n: number) {
    this.energy = Math.min(100, this.energy + n);
  }

  tick(dt: number) {
    // Gentle hunger, exactly as in GameConfig: never lethal, just a nudge home.
    this.energy = Math.max(0, this.energy - dt * 0.045);
    this.el.energy.style.transform = `scaleX(${this.energy / 100})`;
    this.el.health.style.transform = `scaleX(${this.health / 100})`;
    if (this.bannerTimer > 0) {
      this.bannerTimer -= dt;
      if (this.bannerTimer <= 0) this.el.banner.classList.remove('show');
    }
  }
}

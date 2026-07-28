# QA Report — Ember Grove: A Penguin's Way Home

Testing was performed in Roblox Studio via the MCP bridge: real play sessions with
simulated keyboard/mouse input for prompts and tools, plus a server-side
stage-machine sweep. "Real input" below means actual E-key holds / mouse clicks
routed through the live client, not API shortcuts.

## Summary

- **Result: playable start-to-finish.** The full 30-stage story was completed in a
  single live session using real prompts, tool clicks, and traversal; a separate
  automated sweep validated every stage trigger, reward, tool grant, badge, and
  world unlock.
- 9 defects found; **all fixed and re-verified** except two environment-limited
  items documented in the README (live DataStore round-trip, simultaneous
  2-client co-op session).

## What was tested and results

| Area | Method | Result |
|---|---|---|
| Server boot | fresh Play sessions ×8 | ✅ no errors/warnings in Output |
| Full story chain (30 stages) | automated trigger sweep | ✅ completes; 5 tools, 7 badges, all unlocks |
| Tutorial end-to-end | real input (walk, E-prompts, clicks) | ✅ bucket → fill → douse → rescue → ranger |
| Bucket fill/douse | real prompts + clicks | ✅ pond, forest pool verified; Medium fire needs 2 douses |
| Fire blanket | real click at cook fire & stove fire | ✅ smothers small fires only |
| Axe debris | real clicks (branch ×3, hydrant debris ×3, beam ×4) | ✅ hit counters, chips FX, path opens |
| Hose + hydrant | real click-to-spray | ✅ street fire + memory fire extinguished; auto-stops away from hydrant |
| Spirit turn-ins | real E (Mossmitt, Marla, Cindercoo, Old Span, Watchkeeper) | ✅ items consumed, transformations, unlocks |
| NPC rescues | real E / medkit clicks (Ash, Theo, Nora, Sam) | ✅ |
| Valve puzzle | real E, wrong order first | ✅ wrong order resets with feedback; correct order restores pressure |
| Great Bridge traversal | walked the full deck incl. restored span | ✅ |
| Zone system | region banners, checkpoints, crossing trigger | ✅ |
| Death & respawn | died in void + died at memory fires | ✅ respawn at last checkpoint, tools restored |
| Shop | client purchase calls | ✅ food, scarf (equips + persists), bogus item rejected, price enforced |
| Cosmetics | scarf color applied to rig | ✅ |
| Quest journal / HUD / objective / toasts / dialogue / credits | screenshots during play | ✅ render and update correctly |
| Touch / tablet layout | Device Simulator (iPad Pro 13") live playtest | ✅ joystick, Jump, custom Slide button, no overlaps after fix |
| Post-game ember incidents | waited a full incident cycle in a completed session | ✅ incident fire spawned + announced |
| Duplicate rewards | re-triggered collected pickups/caches | ✅ server ignores repeats (collected map) |
| Save safety | Studio mock mode; failure paths code-reviewed | ✅ mock verified; live round-trip pending publish |
| Performance sanity | StreamingEnabled, part-count discipline, no per-frame server work | ✅ by construction; profile on device after publish |

## Defects found → fixed

1. **Default Animate script errors on custom rig** — Roblox injects its R6 Animate;
   fixed with stub Animate/Health in `StarterCharacterScripts` (the correct
   override location, not inside StarterCharacter).
2. **Tools fell out of the world on equip** — the engine never welds tools to
   custom rigs (no "Right Arm"/R15 parts it recognizes). Rewrote tools as
   handle-less (`RequiresHandle=false`) with an anchored Visual model welded to
   the flipper on equip. Verified across all five tools and after death.
3. **Campsite pond had no water** (terrain fill clipped) — refilled; verified by
   voxel sampling and by filling the bucket from the shore.
4. **Water-fill prompts unreachable** — prompt range was measured from the part
   center of large water volumes; switched to box-aware distance and raised the
   markers above the waterline.
5. **HydrantsLive not persisted** — a player who solved the valves and rejoined
   would find dry hydrants and be stuck; the unlock is now granted by the stage
   and re-applied on join.
6. **Void fall at the tunnel exit shaft** — missing floor slab under the ladder
   let players fall out of the world; floor added (death/checkpoint recovery
   worked as designed during the repro).
7. **Memory fire #3 unreachable by hose** — no hydrant within range; third yard
   hydrant added.
8. **Memory fires relit mid-finale** — the 25 s story-relight window made the
   4-fire finale nearly impossible solo; memory fires now use a 120 s window and
   are permanently extinguished once the Watchkeeper is calmed.
9. **Dialogue nameplate showed "???"** — NPC display name wasn't copied onto the
   npc instance; fixed.

Minor polish applied along the way: giant terrain grass decoration removed
(dwarfed the penguin), tutorial tip card raised above the touch joystick,
emoji that don't render in Roblox fonts replaced.

## Emergent observations (not defects)

- Hidden caches near quest NPCs can win the prompt priority for one press
  (player picks up the cache first, then talks) — harmless, arguably delightful.
- Standing inside a Large fire's damage radius while hosing will down a careless
  penguin (~8.6 dps vs. hose kill time ~7 s); standing at proper hose range is
  safe. Judged fair and readable; respawn cost is a walk, not lost progress.

## Quality pass (round 2) — feedback-driven

Changes: all NPCs rebuilt with detailed models (hair/faces/outfits, species detail);
client-side ambient idle animation (breathe/hover/glances) + server patrols for
Bram, two firefighters, and post-rescue Ash; ~130 additional trees (round/elm/
conifer), park perimeter wall, flower beds, schist outcrops; full city skyline
(park ring, neighborhood infill, warehouses, east-bank towers, NYC water towers);
street props (cars, awnings, mailbox); the bridge gap replaced with a readable
raised drawbridge that tweens down; region smoke beacons that clear with story
notifications as each region is restored; 8 readable lore inscriptions; storm
prologue; woods ruins + fireflies.

Defects found & fixed during this pass:
10. **Ash invisible** — spawned embedded inside the collapsed-tent geometry; NPC
    spawning now raycasts to the true ground surface and Ash sits at the tent
    opening (also fixed NPCs half-buried by the raised terrain overlay).
11. **NPC drift** — models had no PrimaryPart, so ambient yaw rotation shifted the
    bounding-box pivot every frame; the cat random-walked ~300 studs. PrimaryPart
    set on all NPCs + rebase threshold added. Verified zero drift over 8 s.
12. **Skyline tower loomed over the spirit clearing** — two west-row towers
    relocated south; the clearing feels like deep forest again.

## Inspo pass (round 3) — art direction + emergent discovery

Applied the `Ember Inspo` moodboard: global regrade (cool luminous light, moss
terrain palette, teal river, 510 canopies recolored, trunk moss, fern understory)
and an unmarked discovery layer — 5 Spirit Circles, the 5-stone Ring-Stone Trail
leading to a hidden Dolmen Grove with the Watcher Stone (badge + secret scarf),
a 10-specimen Collection page in the journal, bird flocks that scatter, and fish
rising in the river. Verified live: circle whisper/reward, dolmen gating (n of 5),
ring-stone reads, specimen pickup ceremony + Collection sync, bird scatter,
clean console. See HANDOFF.md for the style bible and next steps.

## The Great Unburying (round 4) — systemic terrain fix

Owner reported half-buried objects (Ash sinking while wandering, an "invisible"
water source, suspected missing mittens). Root cause discovered: **Roblox's
terrain collision/render isosurface sits ~2 studs above the voxel-grid boundary**
— the walkable surface was y=2 while the entire world had been authored against
y=0. A full audit (534 gameplay parts raycast against the true surface) found
**392 partially or fully buried objects**: all campsite/woods paths, the campfire
stone ring, benches, flower-bed rims, street surfaces, pickups (including
mitten #1 and the recipe book), NPC markers, and the forest pool (also filled
over by a terrain overlay).

Fixes, all verified in a live playtest:
13. **The +2 shift** — every world part (3,055) translated up exactly 2 studs,
    preserving all part-to-part relationships; drawbridge stored target CFrames
    shifted to match. Re-audit: **0 of 534 buried**.
14. **Forest pool re-carved and refilled** (it had been terrain-filled over —
    the "invisible water source").
15. **Ground-conforming NPC movement** — Ash's rescue teleport and all patrols
    now raycast the real surface every step (worst measured sink over a 20 s
    wander: 0.00 studs); raycasts ignore non-collidable canopies so nobody
    spawns or walks on treetops.
16. Two terrain overlay bumps (the original ~1-stud raisers) flattened.

Visual verification: campsite paths/fire ring/benches, neighborhood asphalt and
sidewalks, and the forest pool are all visible for the first time; the world
reads dramatically more finished.

## Bridge access, swimming & diving (round 5)

Owner reported the bridge was unreachable (approach ramps looked vertical) and
asked for swim crossings plus a diving board with tricks.

17. **Approach ramps were sideways slabs** — a bad compound rotation
    (`Angles(0, 90°, ±20.5°)`) sloped them north–south while the bridge runs
    east–west; they'd never been walked (QA had teleported onto the deck).
    Rebuilt along the bridge axis with curbs. Verified by walking a penguin
    from the promenade (y≈4) up onto the deck (y≈20) with Humanoid movement.
18. **Six riverbank slipways** (3 per side) so swimmers can enter and exit the
    river anywhere along both banks. First version didn't reach below swim
    depth (penguins swam *under* the tip); rebuilt to reach y=−3.4. Verified:
    dropped mid-river, swam east, walked out onto the east bank (Running).
19. **Diving board** mid-span over open water + **dive tricks**: leaping off
    the board starts a swan dive; mid-air **W = front flip, A/D = barrel roll,
    S = cannonball** (touch: the Slide button flips). Client announces the trick,
    the server validates and stamps a replicated character attribute, every
    client's PenguinMotion animates it, and a splash + cleanup fire on water
    entry. Verified live: mid-air swan screenshot, trick switching, attribute
    cleanup, swim-out. Board approach fixed twice: plank made flush with the
    deck (the custom rig can only step ~0.3 studs) and a gap cut in the deck
    curb at the board.

Tooling notes from this round (not player-facing): VirtualInput cannot send
Space (jump) or the 1–5 toolbar keys — real input is unaffected;
`Humanoid:ChangeState(Jumping)` is the test surrogate. One play session ran
stale service code despite the edit being present in the Edit DM — if a change
inexplicably doesn't fire, stop/restart play and re-verify before debugging.

## Environment-limited items (do once after publishing)

1. Live DataStore save/reload round-trip (Studio ran in intentional mock mode).
2. One manual 2-player *Clients and Servers* pass (tutorial + one spirit quest +
   one shared fire) to observe co-op visually. The underlying mechanics (shared
   fire state, 70-stud assist credit, per-player pickups, relight-for-needers,
   late-join auto-complete) are implemented server-side and were exercised by
   the automated sweep.

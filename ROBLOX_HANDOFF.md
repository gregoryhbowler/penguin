# HANDOFF — Ember Grove: A Penguin's Way Home

For the next working session (fresh context). Read this + README.md first; QA_REPORT.md
has the defect history. **The place file must be saved in Studio (Ctrl+S) after every
MCP working session — nothing persists otherwise.**

## The vision (owner's brief)

"As if Miyazaki, Tezuka, and Miyamoto collaborated with a brilliant art director on
the best, most immersive, most wonder-inducing penguin quest Roblox game ever."

- **Miyazaki**: quiet melancholy, spirits with inner lives, nature reclaiming the
  built world, weather/atmosphere as emotion, nonviolence, small domestic warmth.
- **Tezuka**: expressive charming characters, clear silhouettes, big-hearted story.
- **Miyamoto**: the world teaches through play; discovery is the reward; secrets
  placed where curiosity naturally goes; toys, not menus.
- **The art director** = the `Ember Inspo` folder (are.na moodboard, 74 images).

## The Ember Inspo board, decoded (keep this as the style bible)

Dominant threads across the images:
1. **Spirals & ancient marks** — Newgrange kerbstones, spiral-carved dolmen,
   Carrington's spiral labyrinth painting, spiral line-art. Sacred geometry as a
   recurring world-motif.
2. **Land art (Goldsworthy)** — rings of sticks, balanced stone stacks, patient
   arrangements found in woods. Art nobody signs.
3. **Moss & reclamation** — moss-sleeved trunks, fairy bridges, gravestones
   swallowed by ferns, sheep grazing in an overgrown cemetery.
4. **Rousseau naive jungle** — dense, layered, flat graphic foliage planes.
5. **Specimen collections** — mineral plates, stones, bones: the joy of the
   *named, individual find*.
6. **Dream figures** (Takano/Carrington) — pale, wide-eyed, calm; cool muted
   palettes where warm color is rare and meaningful.
7. **Water as mystery** — the frozen pond like an eye; winding moss pools.

**Palette law:** deep moss/fern greens + cold stone greys + overcast teal-blue
light. Ember orange/red is *reserved* — fires, spirits, and the guardian are the
only warm things in the world. Never spend warm color on scenery.

## What shipped in the traversal & fixes pass (July 2026, session 3)

Bug fixes (all playtested):
- **Fire-escape treads** on Brick Row were rotated 90° (read as floating shelves) —
  resized to proper treads; the climb is a hop-up (jump each step), as originally
  designed and used by the clockgear quest.
- **Lido entry**: the platform-1 slide ran directly OVER the entry ramp in the
  same lane (1-stud headroom = unusable). Slide moved to a west lane with a
  run-off wedge + ground exit mat; P2's north slide extended to the ground
  (it used to end 10 studs in the air).
- **Pier access**: the boardwalk railing ran continuously across both pier
  entrances — gaps cut, plus small ramps (decks were a 1.1-stud step).
- **Park gate at Alder Street**: arch beam was perpendicular to its columns
  (yaw 45 vs the −45 column diagonal), the quest branch's leaf ball clipped a
  column, and ParkWallR crossed the road with no gap. All fixed; wall now has a
  capped gateway at the street.
- **Pond fish in the air**: FishSchool anchors sat above the water line (and the
  park anchor was at the fountain with a 12-stud wander radius vs a 6-stud bowl).
  Anchors lowered into water, radii capped.
- **Tunnels were sealed**: the entrance shed's stair shaft was capped by TWO
  coplanar floors (ShedFloor + the waterfront Promenade) and the shaft's west
  wall poked 2.6 studs above the floor inside the doorway. Both floors now have
  the stair hole, wall lowered, threshold ramp added. Verified open by raycast +
  drop test (descend by walking; climb out by hopping, or Sam's grate).
- **Blanket vs weakened fires**: `FireService:FindSmotherableFireNear` — the
  blanket now finishes ANY fire doused to ≤1 health (water big fires down, then
  smother), with a clearer hint message.
- **River fill by E**: 12 invisible `WaterSource` strips along both banks + pier
  ends (the click-to-fill terrain check already worked). Verified via E-press.

New features (all playtested):
- **Drawbridge winches**: a lever at the foot of each bridge approach lowers the
  span via the BridgeSpan unlock (Old Span's quest still does it too — whichever
  comes first; any-order philosophy). One pull = span tweens down, verified.
- **Seed pouch chip** next to the fish chip (🌱 count, from questItems.Seed).
- **Fish become food after Prisma**: eating is gated on the statue quest
  (`FishEdible` player attribute; set on feed + on load for returning players).
  Pre-quest the HUD says "saving for someone hungry…" and the server refuses.
  Prisma's freeing dialogue announces the unlock. Verified both ways.
- **Prisma's wander cycle** (`startPrismaWander` in SideQuestService): hops off
  his plinth, patters the pier, waddles the boardwalk, climbs the Great Bridge,
  springs off the diving board with a full flip + splash, belly-glides home, and
  suns himself on the plinth (~20-40 s rest, loops). Ground raycasts are capped
  at (current height + 3) so he never sky-walks suspension cables or lamp heads.
  Full loop observed: dive → splash → swim → plinth → second departure.
- **Rooftop traversal route**: switchback stairs up the Brick Row south building
  (two-lane flights, railed pads), sky bridge to the neighbor roof, **Wingsuit**
  pickup there (crate on the roof). Third tall building (280,155) has stairs and
  an empty roof (a launch spot). Route walked end-to-end by automation.
- **Wingsuit** (ItemDefs + InventoryService visual + `WingsuitGlide` LocalScript):
  equip + fall = ~10 s glide, steer with movement (34 studs/s, gentle sink),
  drift straight down when idle; charge refills on landing/water. Verified:
  106-stud tower drop took 7.1 s airborne with ~100 studs of carry (a plain fall
  is ~1 s). Client-side like the belly-slide.
- **Lookout tower** at the map's center point (75, −60): ~107 studs tall, 26
  interior switchback flights (the penguin rig cannot climb TrussParts — tested),
  railed platform, ember lantern (palette law: the only warm light), and a leap
  plank through a south rail gap. Climb + platform exit verified; pairs with the
  wingsuit for cross-map flights.

Builder gotchas added to memory: wedge +Z ascent convention, two-lane switchback
requirement, momentum overshoot at ramp crests (deep pads + rails), coplanar
double floors, parapets needing gaps wherever a route meets a roof edge.

**Lookout tower rebuilt as an exterior spiral** (follow-up to a clearance report):
the interior two-lane switchback only gave ~4 studs of headroom at each crest —
jumping mid-climb bonked the flight above. The stairs now wrap the tower's
OUTSIDE (classic fire-lookout): 26 flights around the four faces at 23°, corner
pads with outer guard rails, 16+ studs of headroom everywhere. Three clearance
traps found and fixed during verification: (1) tower legs at ±5 pinched the
original ±6.5 lanes — lanes moved outboard to ±7.3; (2) the platform slab and
its guard-rail ring overhung the final flight at head height — platform's north
edge trimmed and the last flight shifted to an outer lane (z −68.8) with a
connector plate through the NW rail-gap; (3) `CFrame.lookAt` aims −Z but wedges
ascend toward +Z — flights built with lookAt must be flipped 180°. Full climb
verified: ground → all 26 flights → arrival pad → platform → leap plank,
zero failed waypoints.

## Moderation incident & publishing rules (July 2026 — IMPORTANT)

The first publish was auto-removed for "Misusing Roblox Systems" (2 strikes,
one appeal auto-denied in 12 minutes). Root cause, near-certain: **TestHook**
— the QA BindableFunction command dispatcher (`signal`/`granttool`/`getdata`)
in Main. To Roblox's exploit scanner, a string-command executor that grants
items and skips progression is indistinguishable from an admin backdoor.

Rules going forward:
- TestHook is **deleted from the shipped file**. For automated QA sessions,
  paste the hook block back into Main via multi_edit, test, and REMOVE IT
  again before any save that might be published. Never publish a file whose
  source contains the dispatcher strings.
- The residue sweep (test StringValues, odd-parented scripts, loadstring/
  getfenv/VirtualInputManager greps) came back clean and should be re-run
  before every publish.
- Republish the cleaned build as a NEW experience with the real title; do
  not keep re-uploading to a flagged place ID.

## What shipped in the wayfinding pass (July 2026, session 5)

- **Clock-tower ladder access restored**: session 4's name-based cleanup
  (`LadderStep`) deleted the step plate bridging the ledge to the truss,
  leaving the "scaffolding beam you can't reach" Greg found. Rebuilt as
  `TowerLadderAccess` (cleanup-proof name) and re-verified: ledge → climb →
  balcony. Lesson: never sweep parts by name patterns shared across kits.
- **Wingsuit route made findable** (Greg couldn't locate it organically):
  "SKY RUN ↗ maintenance stairs" sign + lantern at the foot of building A's
  spiral, a pointer sign on the clock-tower ledge linking the two rooftop
  circuits, and a tall cool-glow beacon column + sparkles on the wingsuit
  crate — visible from building A's roof the moment you top the stairs.

## What shipped in the stairs-forensics pass (July 2026, session 4)

Greg reported stairs embedded in brick on the rooftop route and "tricky
clearances" in the lookout-tower climb. Root causes found and fixed:

- **Clock-tower ladder was buried in the wall** (rungs slid 0.55 deeper per
  step; nest + cache + top ledge fully inside the tower body). Replaced with a
  climbable TrussPart proud of the south face + a real balcony (nest + cache
  visible) at walk-off height. Verified: climb + hop-off onto the balcony.
- **Buildings A/C sky-stairs rebuilt as exterior perimeter spirals** (the
  lookout-tower pattern) after the alley switchback design proved unfixable —
  wall-hugging stacked flights create dead slots Pip wedges into. Verified
  end-to-end: ground → 3 wrapped flights → roof A → parapet gap → sky bridge →
  building B → wingsuit crate, **zero failures**.
- **The big bug: lookAt-built wedges can face backwards** (`CFrame.lookAt`
  aims −Z; WedgePart ascends +Z). Buildings A/C's flights were 10-stud
  vertical walls with the slope descending away. Flipped 180° in place and
  verified. The lookout tower did NOT need the flip (already correct) — a
  blanket flip broke it and was reverted. Raycast slopes before flipping.
- **Lookout tower "tricky clearances" = the cross-braces**: they poked 0.4
  studs into the north/south stair lanes at four heights, floating 0–3 studs
  above flight surfaces (head bonks). Pulled all 8 braces inside the leg box.
  Also added an arrival apron + rails at the top corner (momentum falls).
  Verified: all 26 flights + platform, zero retries.
- Testing discipline that finally cracked it (now in auto-memory): restart
  Play between bot runs (stale loops fight new MoveTos), read waypoints from
  live parts not remembered math, trace positions at 0.35 s before blaming
  geometry, and remember MoveTo "passes" on XZ alone.

## What shipped in the co-op & polish pass (July 2026, session 2)

- **Frostfell knoll climb rebuilt** (was unclimbable: ramps stranded mid-air
  after the tier pullback, and the low chute's mouth was buried inside tier 2).
  New: flight 1 (ground→tier1, west), flight 2 (tier1→tier2 riding tier1's west
  strip), widened tier2 back-ledge corridor, flight 3 (tier2→top, hanging east
  with entry plate), low chute relocated to launch from tier1's south strip.
  Automated walk: ground→top zero fails; low chute ridden onto the rink at 35.
- **Co-op pump-and-hose** (the FUTURE_IMPROVEMENTS flagship): every hydrant has
  a second ProximityPrompt — **"Pump!" on R** (ButtonY pad) — each stroke
  pressurizes the hydrant for 5 s; hoses drawing from it do **2.2× DPS** with a
  visibly bigger spray (rate 90 vs 40). Both players get a notify on the first
  stroke; tutorial tips mention it. Verified live: spray rate 90 during window.
  Solo players can pre-pump and dash back.
- **Co-op correctness fixes**: feeding an already-freed Prisma now gets proper
  "old custom" dialogue instead of stone-statue lines; Mossmitt's worn mittens
  and Sirelen's antler blooms no longer duplicate when a second player helps.
- Known co-op cosmetic limit (accepted): ProximityPrompt ActionText is shared
  per-server, so an NPC's verb reflects the *most recent* interactor's
  progress; the underlying interaction is always evaluated per-player.
- Testing gotcha for the record: the hose auto-stops after 12 s per activation
  (by design) — slow MCP test sequences kept tripping it; single-script pollers
  with one keyboard call are the reliable pattern.

## What shipped in the penguin-simulator pass (July 2026 session)

**Bug fixes (all verified in live playtests):**
- **Out-of-order quests.** QuestService now records EVERY signal in `data.counters`
  (whether or not it matches the current stage) and chain-auto-completes any
  satisfied stage the moment it becomes current. The whole 30-stage story was
  verified completing with its signals fired in REVERSE order. Fixes the lost
  mitten softlock (items grabbed early now count; `stageSatisfied` also seeds
  from `questItems` for old saves). NPC dialogue gating switched from
  stage-equality to signal-based (`done(player, key)` in NPCService).
- **Post-quest prompts relax**: `doneKey`/`doneAction` per NPC def — Ash's
  "Rescue" becomes "Pet", Nora's "Check on" becomes "Talk", etc. Refreshed on
  every recorded signal via `NPCService:RefreshPromptsFor`.
- **Warden Bram** was raycast-grounding onto the bandstand roof: spot + patrol
  moved clear of the roof footprint; bandstand steps replaced with a ramp.
- **Theo's cook fire**: water on a Blanket-only fire now explains what's needed
  instead of "no flames in reach"; Bram (reachable now) also hands the blanket
  idempotently at dialogue time (as do Maple/med kit and Nora/hose).
- **Bucket fills from the river** (any terrain water) via voxel check.
- **Diving-board tricks**: coach card teaches the moves when near the board and
  mid-dive; detection radius widened.
- **Objective card**: minimize toggle (– / ▸) and auto-collapses while dialogue
  is open so it never covers the words.
- **Training tower** rebuilt: wedge-ramp flights with landing pads + corner
  aprons (the penguin walked ground→roof in an automated test, zero fails);
  the flight-to-nowhere above the roof was removed.

**The penguin-simulator layer:**
- **Fish everywhere** (`FishSchool` tag; FishService server-validates catches,
  StarterPlayerScripts.FishLife renders/animates fish 100% client-side —
  wander, flee, catch by swimming close). Fish counter chip in the HUD; tap it
  to eat one (+energy). Signals: `Catch:Fish` counts lifetime catches.
- **The Hungry Statue** (riverbank promenade, x≈434 z≈130): stone Magellanic
  penguin, begs for 100 fish, transforms band-by-band into **Prisma** the
  rainbow penguin (150 Sparks + "Friend of Stone"). `HungryStatue` tag,
  logic in SideQuestService, `WakeColor`/`WakeMaterial` attributes drive the
  color bloom.
- **The Mossy Lido** (new region, bay south of the Waterfront, ~x400 z360):
  3-platform mossy tower (kit flights), three slides — The Plunge (straight,
  y26), The Wiggle (two turns), The Lazy Drift (long, gentle) — all ride on
  **anchored conveyor velocity** (`AssemblyLinearVelocity` on SlideFloor/Pan/
  Lip parts; humanoids grip low-friction slopes, so friction alone never works).
  Boardwalk + lanterns from the Waterfront, pebble-spiral land art, cache with
  specimen, fish school in the bay, zone + checkpoint. Sudsy the otter attends.
- **Frostfell Hollow** (new region, snowfield north of City Park, ~x100 z-360):
  snow-painted terrain, big ice rink (real Ice material + 0.01 friction — you
  glide), three ice chutes off a snow knoll aimed across the rink, and a
  **CrashMound** on the far rim that bursts when hit >12 studs/s revealing the
  Glacier Tear cache (`HiddenUntilCrash` attribute). PenguinMotion shows the
  belly-slide pose automatically when skimming ice fast. Glint the frost
  sprite keeps the rink. Verified: chute → 66 studs/s → across rink → burst.
- **Community garden** (City Park lawn): 20 `Seed` pickups scattered world-wide,
  plant at the `GardenPlot` bed — blooms in 5 stages, "City Gardener" at 20.
  Gardener Fern anchors it.
- **Rattly the Recycler** (Neighborhood): 15 `Can` pickups, 5 Sparks each,
  "Bin Friend" badge; funds the **Top Hat** (75 Sparks) — hats are a new
  cosmetic slot (`cosmetics.equippedHat`, HATS in GameConfig, built/welded in
  InventoryService, sold at Marla's kiosk alongside a Flower Crown).
- **New characters** (9 DEFS + ambient): Sudsy, Glint, Gardener Fern, Baker
  Lena, Old Moss the sailor (hints statue + fishing), kids Juno & Bee,
  **Sirelen the Fern Elk** (bring 3 Antler Blossoms → antlers bloom, badge),
  the Mist Heron. Plus **client-side wonder creatures** (WonderSprites):
  7 kodama-style shy sprites that vanish when approached, a river loon that
  dives; and the **Sleeping Stone Turtle** by the forest pool — stand on it
  4 s and it wakes ("Patient Friend").
- **Graduation finale**: completing the story now runs
  `NPCService:RunGraduation` — the crew gathers, Captain Rosa reveals Pip's
  lifelong training, grants the **Firefighter's Helmet** (equipped hat) and
  "Full-Fledged Firefighter" badge, confetti, then credits. Firefighters have
  post-graduation dialogue.
- **Land art pass**: 5 stone cairns, cove pebble spiral, Frostfell stick ring
  + ring-carved stone, moss sleeves on lido posts.

**New tags:** `FishSchool` (Radius/Count), `HungryStatue`, `GardenPlot`,
`Recycler`, `CrashMound`, `SleepyTurtle`, `ShySpot` (Style=kodama|loon).
**New services:** FishService, SideQuestService (both in Main's ORDER).
**New client scripts:** FishLife, WonderSprites.
**New remotes:** FishCatch, EatFish (FishSync reserved, unused).
**Gotchas learned this session:**
- Humanoids grip walkable slopes regardless of friction — slides need conveyor
  `AssemblyLinearVelocity` on the floor parts.
- Client boot scripts must handle StreamingEnabled: use
  `CS:GetInstanceAddedSignal(tag)` alongside `GetTagged` (FishLife/WonderSprites do).
- Server code cannot MoveTo a player character (client owns it); disable the
  client control module first for scripted walk tests, and restart Play if
  physics ever freezes (it happened once).

## What shipped in the final pass (previous session)

- **Global regrade** to the board's palette: cooler luminous light, greener fog,
  mossy terrain colors, deep-teal river, foliage recolor (510 canopies), trunk
  moss, fern understory (Rousseau layers).
- **Emergent discovery layer** (none of it appears in the quest log or UI):
  - **5 Spirit Circles** (stick ring, riverbank stone spiral, rooftop pebble
    stacks, park moss ring, ember-glass circle) — stepping in triggers a whisper,
    rising wisps, one-time Sparks. Tag: `SpiritCircle`.
  - **Ring-Stone Trail** — 5 ring-carved stones (readable Lore pickups with
    `RingStone=true`) whose texts point east toward…
  - **The Dolmen Grove** — hidden conifer hollow on the east bank north of the
    bridge ramp (~585, 0, −68). The **Watcher Stone** (tag `Dolmen`) opens its
    stone eye only after all 5 ring stones are read: awards "The Old Ways" badge,
    100 Sparks, and the secret **Old Ways Moss scarf** (`secret=true` in
    `GameConfig.SCARF_COLORS`, never sold).
  - **The Collection** — caches now hold named specimens (River Glass, Storm
    Ember, Soot Feather… 10 total, registry in `Shared/SpecimenDefs`) shown with
    flavor text on a Collection page in the journal.
  - **Ambient creatures** — 3 bird flocks that scatter and drift back; fish
    rising in the river (4 spots).
- Verified in live playtests: circle whisper+reward, dolmen gating (n/5),
  ring-stone reads, specimen pickup ceremony, bird scatter, clean console.

## Current architecture (unchanged; see README for the full map)

Data-driven via CollectionService tags — `FireSpot`, `WaterSource`, `Pickup`
(Kinds: Tool/QuestItem/Food/Cache/Lore), `NPCSpot`, `Debris`, `Valve`, `Zone`,
`Checkpoint`, `Unlockable` (Actions: Show/Hide/Sink/Lower), `RegionBeacon`,
`SpiritCircle`, `Dolmen`, `BirdFlock`, `FishSpot`, `Shrine`, `Shop`.
Server services in `ServerScriptService/Services`; all client UI in
`StarterPlayerScripts/ClientMain`; NPC idle life in `NPCAmbience`; penguin
animation in `PenguinMotion`. QA hook: `ServerScriptService.TestHook`
(BindableFunction: `signal`, `getdata`, `stageid`, `unlocked`, `granttool`).

### Hard-won gotchas (do not rediscover these)
- **The penguin rig can only step up ~0.3 studs** (tiny HipHeight): any walkable
  transition (board planks, curbs, ledges) must be flush or ramped — never a
  step. The deck curbs have a cut gap at the diving board for this reason.
- **MCP VirtualInput cannot send Space or the 1–5 toolbar keys** (core-bound);
  use `Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)` / `Humanoid:EquipTool`
  as test surrogates. Real player input is unaffected.
- **Play sessions can (rarely) snapshot stale service code** even when the edit
  is present in the Edit DM — if new server code inexplicably doesn't fire,
  stop/restart play before debugging the code itself.
- **Water/diving system map:** slipways (6, both banks) let swimmers exit the
  river; the diving board is tagged `DivingBoard`; tricks flow
  client-detect → `ToolAction` remote ("Trick", type) → server validation in
  PlayerStateService → replicated `Trick` character attribute → animated in
  PenguinMotion's trick branch (swan/flip/roll/cannonball) → splash + attribute
  cleanup on water entry.
- **THE BIG ONE — terrain isosurface offset:** the walkable/renderable terrain
  surface sits **~2 studs above the voxel-grid boundary** (a full cell ending at
  y=0 collides at y=2.0). The whole world is now aligned to the true surface at
  **y=2** (every part was shifted +2; a 534-part audit reads zero buried). When
  placing ANYTHING new, never assume ground height — raycast it
  (`RaycastParams.RespectCanCollide = true`, include Terrain + workspace.World),
  or copy `surfaceYAt`/`groundedPivot` from NPCService. An audit script pattern
  lives in QA_REPORT round 4 if it ever needs re-running.
- Custom rigs: engine never welds Tools → tools are `RequiresHandle=false` with
  an anchored `Visual` model welded to the `Right Arm` part on equip.
- NPC models MUST have a PrimaryPart or `GetPivot` drifts under rotation
  (bounding-box pivot) — ambient animation will random-walk them across the map.
- Override default Animate/Health from `StarterCharacterScripts`, not from
  inside StarterCharacter.
- NPC spawns raycast to ground (terrain overlays vary height by ±1 stud).
- ProximityPrompts only accept input while *visible on screen*; markers must sit
  above ground/waterline.
- Studio saves are mocked unless Workspace attribute `EnableStudioSaves=true`.
- `Workspace.Terrain.Decoration` isn't scriptable here; animated grass was
  removed by converting Grass→LeafyGrass.
- MCP `execute_luau` gets a *separate* module registry — use TestHook, don't
  require services directly.
- Edits made in Play mode don't persist; redo them in Edit mode.

## Prioritized next steps

1. **Audio (biggest wonder-per-effort lever).** Replace the two labeled
   placeholder loops; add region-layered ambience (woods birds/wind, city hum,
   river, tunnel drips), fire crackle tied to `FireService.setIntensity`, a
   soft chime for spirit circles, and a music sting when the Watcher Stone opens.
2. **Meshes & silhouettes.** Replace blob trees with 3–4 authored tree meshes
   (or unioned primitives), penguin/NPC mesh upgrade second. Keep the palette law.
3. **More emergent systems** (the Miyamoto ladder):
   - Spirit sightings: brief, rare glimpses of small unnamed spirits at dusk
     edges (despawn when approached; no reward — pure wonder).
   - Weather moods: slow fog/light cycles; rare "ember rain" event post-storm
     lore tie-in.
   - Penguin toys: slidable ice patches, kickable pinecones, koi that follow
     you along the pier.
   - A second secret on the scale of the dolmen (e.g., the frozen-eye pond that
     opens in winter — seasonal).
4. **Co-op polish.** Manual 2-player Clients-and-Servers pass; pump-and-hose
   two-player interaction (hose loop already reads a rate value).
5. **Post-game depth.** Incident variety (animal rescues, debris), firefighter
   playable character (cosmetic, identity-presentation options).
6. **Ship checklist.** Live DataStore round-trip, device profiling, maturity
   questionnaire, remove TestHook if desired.

## Where things are

- Place: `Penguin Firefighter Adventure.rbxl` (open in Studio; everything is in
  the place file — no external assets, no build step).
- Docs: `README.md` (structure/how-to), `QA_REPORT.md` (12 fixed defects, test
  matrix), `FUTURE_IMPROVEMENTS.md`, this file.
- Moodboard: `Ember Inspo/` (webp files; filenames are hashed — view them, the
  images are the spec).

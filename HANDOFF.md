# HANDOFF — Ember Grove (web)

For the next session, fresh context. Read this, then `README.md`. The Roblox
history lives in `ROBLOX_HANDOFF.md` / `ROBLOX_README.md` / `QA_REPORT.md` —
still the reference for quest chains, dialogue and world design, but **the
Roblox place is no longer the product.**

- **Live:** https://gregoryhbowler.github.io/penguin/
- **Repo:** https://github.com/gregoryhbowler/penguin (push to `main` auto-deploys)
- **Working copy:** `/Users/gregbowler/Penguin Firefighter Adventure`
- **Owner:** Greg. Building this for his son **Lucien**, who is the intended
  player and bug-hunter. Lucien is a Roblox player — his expectations set the
  control scheme.

## Why this is a web game now

The Roblox build was auto-removed twice for "Misusing Roblox Systems," with one
appeal denied by a machine twelve minutes after filing. The near-certain trigger
was `TestHook`, a QA command dispatcher that pattern-matches an admin backdoor.
Rather than keep fighting a moderation system with no human in it, Lucien asked
for a website and that became the plan. No gatekeeper, ships by URL to an iPad,
and full control of the renderer.

## Where it stands

**Working:** the whole world loads (3,748 parts, all seven regions). Desktop and
touch control schemes. Region banners off the Zone tags. The Campsite quest chain
end-to-end — bucket, pond, tutorial fire, Ash, Ranger Maple. Ramps, stairs,
streets, both bridge approaches and the drawbridge are traversable. The river,
cove and both ponds exist: carved channels, a shore, swimming, diving off the
board, fish. All 23 NPCs are costumed penguins, people or animals. Three great
beasts, seven kodama, five spirit circles. Blue sky, cumulus, a mountain
horizon, wildflowers. Rails and parapets now hold you in; the tower, the fire
escape and the roof stair all climb. 0.5-2.2 ms/frame on an M-series Mac.

**Not done:**
- **Region-specific ground colour** — Frostfell should be snow, the woods
  darker. `createGround` takes no zone data yet; the hook would be a tint
  callback sampling the `Zone` parts.
- **The firehouse has no identity of its own.** The sheet's Brimstone Firehouse
  is red and brass with a tower; ours is the same brick box as everything else.
- **Only the Campsite's quests are wired.** This is now the single biggest gap
  in the game and the one a player notices first: every other region has NPCs,
  props and pickups but nothing to do. `data/scripts/Shared__QuestDefs.lua` and
  `Services__QuestService.lua` hold the full design. Other NPCs greet you with a stub
  line. The Lua in `data/scripts/` is the design reference — port behaviour from
  it, never try to run it.
- **iPad never tested on hardware.** Layout is verified at iPad dimensions in a
  desktop browser, nothing more. This is the single most valuable next check.
- **No audio, no save/load.** localStorage saves mirroring the old DataService
  schema are the obvious cheap win.
- Dry ground is still a fairly uniform green plane away from the water.
- The rooftop parkour layer (roof stair -> plank -> sky bridge -> wingsuit
  crate) is traversable but nothing reads it: `WingsuitCrate`, `WingsuitBeacon`
  and `TowerLadderTruss` are all still inert, and `WingsuitGlide.lua` in
  `data/scripts/` is the design for the glide that route exists to set up.
- The shoreline is authored, not exported — `water.ts:SHORE_W/SHORE_E` are hand
  bumps. Two places still read a little off: the wooden `SlidePan` at
  (434, 4.2, 342) hangs over the cove with nothing under it, and the two
  `PierPile`s at x=434 are buried in the bank.

## Architecture

```
tools/extract_world.py   .rbxlx -> data/world.json   (run once; already done)
public/data/world.json   3,748 parts, 205 tagged for gameplay
src/engine/  world.ts (parts, colliders, spatial hash), controller.ts, input.ts
src/art/     scene.ts (palette/lighting/instancing/terrain), sky.ts, foliage.ts,
             postfx.ts, water.ts (basins, terrain carve, surface shader),
             horizon.ts (the mountain ring), buildings.ts (roofs)
src/game/    figures.ts (primitive toolkit + freeze), penguin.ts, human.ts,
             critters.ts, cast.ts (who everybody is), wonders.ts (the beasts,
             kodama and spirit circles), interact.ts, ui.ts,
             drawbridge.ts (the one moving thing), water_life.ts (fish, splashes)
```

## How characters are built

Everything alive is assembled from primitives by `figures.ts:piece()` and then
`freeze()`d: the pieces are merged into two or three vertex-coloured meshes,
bucketed by surface treatment. That last step is not optional. A dressed penguin
is about twenty meshes, and two dozen of them loose in the scene would cost more
per frame than the entire 3,748-part world does, because the world is instanced
and they would not be. Pip is the ONLY figure left un-frozen, because his limbs
have to move independently.

Costumes are data, not code — `PenguinKit` / `HumanKit`, and `cast.ts` maps
every `NpcId` to one. Adding a character is a table entry.

The world was exported once from Roblox Studio. `extract_world.py` reads the XML
place file and emits engine-neutral JSON: transforms, colour, material, plus the
CollectionService tags (`FireSpot`, `Pickup`, `NPCSpot`, `WaterSource`, `Zone`…)
and attributes (`FireId`, `QuestKey`, `NpcId`…). **The tag-driven design ported
unchanged — only the runtime is new.** If you need to re-extract, the `.rbxlx`
is in `~/Documents` (gitignored); binary `.rbxl` can't be parsed, ask for a
"Save As → Roblox XML Place File".

## Hard-won gotchas — do not rediscover these

**Dry terrain must stay flat at y=2.** Roblox terrain is a voxel blob that
doesn't export, so the ground is authored in `scene.ts:datumHeight`. Every part
was placed against flat terrain. A version that rolled ±2.6 studs buried 113
collidable parts outright and cut through 361 more — sunken logs and curbs became
invisible walls you had to jump. Keep variation well under a step height.

The water basins are the one sanctioned exception, and only because each one was
checked against the parts inside it first (`carve()` in `water.ts`). Before
moving a bank line, re-run that check: dump every part whose footprint falls in
the new basin and confirm nothing lands submerged or floating that shouldn't be.
That check is what put the headlands under the Hungry Statue and the stone
spiral, and the notches where the boat slipways run down into the river.

**Collision, three separate traps, each of which reads to a player as "movement
is janky":**
1. `WedgePart`s must collide as *ramps* — sample the sloped surface at the
   player's footprint. Colliding them as bounding boxes makes every ramp in the
   world a wall.
2. That sample must **clamp to the footprint edge**. The player's centre is still
   a body-radius short of a ramp when the resolver first sees it; falling back to
   the box top there re-blocks every ramp one step before its base.
3. A rotated part's world top is **not** `center.y + half.y`. The bandstand deck
   is a cylinder lying on its side and was read as a 10-stud wall.
4. Nor is it `center.y + worldHalfY` — the AABB top. **Sample the real surface
   with a downward ray against the oriented box** (`obbTopAt`). The Great
   Bridge's approach ramps are ordinary `Part`s tilted 26° about Z, so the AABB
   top put an 18-stud wall across the only crossing in the world; the drawbridge
   flaps put a 14-stud one across the deck. Same for the slipways, the sky
   bridge and the Lido ramps.
5. When that ray **misses**, do not fall back to the box top — skip the part.
   The resolver's broad test projects a world-flat offset through the part's
   inverse rotation, which for anything tilted about X or Z claims a footprint
   several studs wider than the part is (the approach claims x 384..426 for a
   box that ends at 422.3). The search walks up to 6 studs back toward the
   part's centre first; if it still can't find it, you are not touching it.

Also: stick to the ground on downward steps within step height, or stairs feel
like a landing test on every tread.

**No water yet.** A flat sheet under the flat y=2 ground (depth-write off) bleeds
through grass and roads as shimmering patches. `water.ts` is written and ready;
it needs the ground carved into a real river channel first. Deriving the channel
from the pier/boardwalk/bridge geometry is the honest way to do it.

**Instanced colour renders black** unless the geometry carries a base `color`
attribute *and* the material has `vertexColors: true`. Both, not either.

**Vertical grass blades render black** under an overhead sun until the shading
normal is pinned to world-up (they're edge-on to the light).

**Scatter decoration by fixed world tiles, never a disc around the player** — a
disc visibly slides along with them. Do the distance fade in the *vertex shader*
against a live player uniform; fading at tile-rebuild time pops in whole rings.

**Testing:** the Browser pane pauses `requestAnimationFrame` when hidden, so the
game looks frozen and every measurement lies. `window.__game.tick(dt, override)`
drives the simulation manually — use it to verify physics and interactions
deterministically. Pattern that works well: walk Pip in a direction and project
the displacement onto the camera basis, or record climb height along a ramp.

**Verify your test before believing it.** A movement test with its own inverted
right-vector reported A/D broken when they were fine; a ramp test walked the
wrong axis because the wedge had a 90° yaw. Re-derive from a known case.

## Prioritized next steps

1. **Port the remaining quest chains.** Greg named this directly: "none of the
   other mission objectives are in place." Every region now has a costumed
   cast, props and pickups and nothing to do with any of them, so it is the
   first thing a player runs out of. `Shared__QuestDefs.lua` +
   `Services__QuestService.lua` are the design; the tags are already loaded, so
   this is mostly dialogue, state and completion conditions. Open question for
   Greg: all regions in one pass, or Whispering Woods first as a shape to react
   to.
2. **Lucien on the iPad.** Still never run on real hardware, and the frame cost
   has roughly doubled since it was last measured.
3. **Saves** — localStorage, mirroring the old DataService schema. The
   drawbridge's open state belongs in it.
4. **Fishing and the other water verbs.** `FishSpot` (4), `DivingBoard`,
   `Valve` (3, in the tunnels under the river) and `HungryStatue` are all tagged
   and all still inert. The water they need now exists.
5. **Art**: terrain shaping and material variation by region; authored meshes for
   the major buildings. Aesthetic target is BOTW/TOTK + Miyazaki — lush, bright,
   atmospheric haze on distance, warm colour reserved for fire and spirits.
6. Audio (nothing at all yet) — water and fire are the two that would carry most.

## Working agreement that's been paying off

Greg plays, reports concrete symptoms, and they have consistently turned out to
be real bugs with non-obvious causes — often several stacked behind one
complaint. Take the report seriously, find the actual mechanism, verify the fix
by driving the game, and say plainly what wasn't verified.

Two corollaries earned the hard way in the last session:

**Check what the world already has before building it.** "The buildings are bare
boxes" was wrong — they had roofs, parapets, water tanks, spires and a whole
rooftop route on them, and generating roofs on top buried the lot. Grep the part
names first; the `.rbxlx` author solved more than it looks like from a distance.

**A report of "it isn't solid" is usually literal.** Two of the three
fall-throughs were geometry and collision faults with exact, findable causes
(inverted winding, an edge search whose stride was wider than the rail it was
looking for). Reproduce it in `tick()` and read the numbers rather than adjusting
constants until it feels better.

## Driving the game without a player

`window.__game` exposes `controller`, `pip`, `scene`, `parts`, `drawbridge` and:

- `tick(dt, {dir, jump, slide})` — one simulation step, deterministic.
- `look(x, y, z, yaw?, pitch?, dist?)` — place Pip and settle the follow-cam.
- `shot([x,y,z], [tx,ty,tz], showPip?)` — park the camera anywhere and render
  one frame. It PAUSES the loop first, because the follow-cam otherwise yanks
  the camera back to Pip on the next frame and every inspection shot comes out
  identical. It also moves the sky dome and horizon ring to the camera — both
  ride with the player, and a parked camera outside the dome renders black sky.
- `resume()` — un-pause.

Keep a batch under a few thousand simulated frames per call or the browser tool
times out.

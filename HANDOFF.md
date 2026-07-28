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
end-to-end — bucket, pond, tutorial fire, Ash, Ranger Maple. Ramps, stairs and
streets are traversable. ~500 fps of headroom on an M-series Mac.

**Not done:**
- **Only the Campsite's quests are wired.** Other NPCs greet you with a stub
  line. The Lua in `data/scripts/` is the design reference — port behaviour from
  it, never try to run it.
- **No water.** See the gotcha below.
- **iPad never tested on hardware.** Layout is verified at iPad dimensions in a
  desktop browser, nothing more. This is the single most valuable next check.
- **No audio, no save/load.** localStorage saves mirroring the old DataService
  schema are the obvious cheap win.
- Buildings are still Roblox boxes; the ground is a fairly uniform green plane.

## Architecture

```
tools/extract_world.py   .rbxlx -> data/world.json   (run once; already done)
public/data/world.json   3,748 parts, 205 tagged for gameplay
src/engine/  world.ts (parts, colliders, spatial hash), controller.ts, input.ts
src/art/     scene.ts (palette/lighting/instancing), sky.ts, foliage.ts,
             postfx.ts, water.ts (built, not used)
src/game/    pip.ts (procedural penguin), interact.ts, ui.ts
```

The world was exported once from Roblox Studio. `extract_world.py` reads the XML
place file and emits engine-neutral JSON: transforms, colour, material, plus the
CollectionService tags (`FireSpot`, `Pickup`, `NPCSpot`, `WaterSource`, `Zone`…)
and attributes (`FireId`, `QuestKey`, `NpcId`…). **The tag-driven design ported
unchanged — only the runtime is new.** If you need to re-extract, the `.rbxlx`
is in `~/Documents` (gitignored); binary `.rbxl` can't be parsed, ask for a
"Save As → Roblox XML Place File".

## Hard-won gotchas — do not rediscover these

**Terrain must stay flat at y=2.** Roblox terrain is a voxel blob that doesn't
export, so the ground is authored in `scene.ts:groundHeight`. Every part was
placed against flat terrain. A version that rolled ±2.6 studs buried 113
collidable parts outright and cut through 361 more — sunken logs and curbs became
invisible walls you had to jump. Keep variation well under a step height.

**Collision, three separate traps, each of which reads to a player as "movement
is janky":**
1. `WedgePart`s must collide as *ramps* — sample the sloped surface at the
   player's footprint. Colliding them as bounding boxes makes every ramp in the
   world a wall.
2. That sample must **clamp to the footprint edge**. The player's centre is still
   a body-radius short of a ramp when the resolver first sees it; falling back to
   the box top there re-blocks every ramp one step before its base.
3. A rotated part's world top is **not** `center.y + half.y` — project the local
   extents onto world Y. The bandstand deck is a cylinder lying on its side and
   read as a 10-stud wall.

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

1. **Lucien on the iPad.** Everything else is guesswork until a real player on
   real hardware tries the touch controls.
2. **Port the remaining quest chains** region by region from `data/scripts/`.
   The tag data is already loaded; this is mostly dialogue and state.
3. **Saves** — localStorage, mirroring the old DataService schema.
4. **Water**, once the ground has a carved channel.
5. **Art**: terrain shaping and material variation by region; authored meshes for
   the major buildings. Aesthetic target is BOTW/TOTK + Miyazaki — lush, bright,
   atmospheric haze on distance, warm colour reserved for fire and spirits.
6. Audio (nothing at all yet).

## Working agreement that's been paying off

Greg plays, reports concrete symptoms, and they have consistently turned out to
be real bugs with non-obvious causes — often several stacked behind one
complaint. Take the report seriously, find the actual mechanism, verify the fix
by driving the game, and say plainly what wasn't verified.

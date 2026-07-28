# Ember Grove: A Penguin's Way Home

A cozy exploration / firefighting adventure. You are **Pip**, a firehouse penguin
separated from home by a strange storm. Waddle, swim and belly-slide through an
enchanted urban forest — put out fires, rescue people and animals, and help
troubled spirits remember who they are, all the way back to the firehouse.

Originally built in Roblox; now a standalone web game so it runs anywhere with a
browser — including an iPad — with no account, no install, and no gatekeeper.

**Play:** https://gregoryhbowler.github.io/penguin/

## Running locally

```bash
npm install
npm run dev
```

## Controls

| | Desktop | Touch |
|---|---|---|
| Move | WASD / arrows | left stick |
| Look | drag mouse | drag right side |
| Jump | Space | ▲ button |
| Belly-slide | Left Ctrl / Shift | — |
| Interact | E | E button |

## How it's built

```
tools/extract_world.py   Roblox .rbxlx -> data/world.json (geometry, tags, attributes)
public/data/world.json   3,748 parts; 205 of them tagged for gameplay
src/engine/              world loading, spatial hash, character controller, input
src/art/                 palette, lighting, instanced world meshes, ground
src/game/                Pip, interactions, UI
```

The world was authored in Roblox Studio and exported once. `extract_world.py`
reads the XML place file and emits engine-neutral JSON: every part's transform,
size, colour, material, plus the CollectionService tags (`FireSpot`, `Pickup`,
`NPCSpot`, `WaterSource`, `Zone`…) and attributes (`FireId`, `QuestKey`,
`NpcId`…) that drive gameplay. The tag-driven design carried over unchanged —
only the runtime is new.

### Notes on the port

- **Nothing physics-related was ported.** The character controller is kinematic
  and hand-written, which removes a whole class of bugs the Roblox build fought:
  a 0.3-stud step height that broke every staircase, humanoids gripping slopes,
  terrain sitting 2 studs above where it claimed to be.
- **Terrain doesn't survive export** (it's a voxel blob), so the walkable ground
  is regenerated procedurally around the known y=2 surface.
- **The palette law is enforced by the renderer.** The world grades to moss,
  cold stone and overcast teal; only emissive materials — fire, spirits,
  lanterns — are allowed to be warm. Nothing else glows.

## Status

All seven regions load and are walkable. The Campsite is playable end to end:
find the bucket, fill it, douse the tutorial fire, rescue Ash, meet Ranger
Maple. Other regions are built and traversable, but their NPCs are still stubs
until their quest chains are ported from `data/scripts/`.

Not yet done: water (needs a carved river channel), audio, saves, and a real
test on iPad hardware.

`HANDOFF.md` is the current state of play and the gotchas worth knowing before
touching collision, terrain or the art pipeline.

The original Roblox build's documentation is kept in `ROBLOX_README.md`,
`ROBLOX_HANDOFF.md` and `QA_REPORT.md` — they remain the reference for quest
chains, dialogue and world design.

## Art pipeline

`src/art/` is where the "console-like" push lives:

- **sky.ts** — shader dome with drifting cloud banks; a PMREM environment map
  is baked from it so PBR surfaces have something to reflect.
- **foliage.ts** — replaces the Roblox `Leaves` boxes with irregular canopy
  blobs (three per box, jittered and colour-varied), turns `FernFan` parts into
  curved fronds, and scatters a grass field around the player. All of it sways
  on a shared wind shader.
- **postfx.ts** — GTAO contact shadows, bloom gated to a high threshold, and a
  colour grade that cools the frame and permits warmth only in highlights.
  `detectQuality()` drops AO, pixel ratio and grass density on tablets.
- **water.ts** — stylised river: layered swell, fresnel depth, sparkle, foam.

Two non-obvious things worth remembering: `InstancedMesh.setColorAt` renders
black unless the geometry carries a base `color` attribute *and* the material
has `vertexColors: true`; and vertical grass blades read black under an
overhead sun until their shading normal is pinned to world-up.

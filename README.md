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

The Campsite is playable end to end: find the bucket, fill it, douse the
tutorial fire, rescue Ash, meet Ranger Maple. Remaining regions are extracted
and ready to switch on as their systems are ported.

The original Roblox build's documentation is kept in `ROBLOX_README.md`,
`HANDOFF.md` and `QA_REPORT.md` — they remain the reference for quest chains,
dialogue and world design.

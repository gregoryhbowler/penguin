# Ember Grove: A Penguin's Way Home

A family-friendly, third-person, cooperative action-adventure for Roblox. You are
**Pip**, a firehouse penguin separated from home by a strange storm. Waddle, swim,
and belly-slide through an enchanted urban forest — extinguish fires, rescue people
and animals, and help troubled spirits remember who they are, all the way back to
the firehouse across the Great Bridge.

- **Genre:** cozy exploration / firefighting & rescue puzzles / spirit quests
- **Audience:** family-friendly (target Minimal/Mild maturity; owner must complete
  Roblox's questionnaire honestly before publishing)
- **Players:** solo through 4-player co-op (architecture supports more; pick a
  server cap after load testing — 8 is a sensible starting point)
- **Platforms:** keyboard/mouse and touch (tablet layout verified); standard Roblox
  gamepad bindings work for movement/jump, and Slide is bound to L3

---

## How to open and run

1. Open `Penguin Firefighter Adventure.rbxl` in Roblox Studio.
2. Press **Play** (F5). You spawn at the Abandoned Campsite as Pip.
3. That's it — no build steps. All content is inside the place file.

**Controls (desktop):** WASD move · Space jump · **Left Ctrl belly-slide** ·
E interact (prompts) · click to use the equipped tool · 1–5 toolbar.
**Touch:** drag to move, on-screen Jump, a dedicated **Slide** button, tap prompts,
tap to use tools. Swimming works in any water.

## Project structure

Everything lives in the place file:

```
ReplicatedStorage
├─ Shared
│  ├─ GameConfig    -- every tunable number (speeds, fire sizes, prices, saves…)
│  ├─ QuestDefs     -- the 30 main-story stages (data-driven)
│  └─ ItemDefs      -- tool + quest-item display data
├─ Remotes          -- all RemoteEvents/Functions
└─ Characters.Penguin  -- reference copy of the penguin rig

ServerScriptService
├─ Main             -- bootstrap; requires/Init/Start all services (+ QA TestHook)
└─ Services
   ├─ DataService         -- DataStore persistence (retries, schema v1, Studio-safe)
   ├─ WorldService        -- world unlocks (gates, bridge span, hydrants, restore)
   ├─ InventoryService    -- builds/grants Tools, grip welds, scarf cosmetics
   ├─ PlayerStateService  -- health/energy/sparks/badges, checkpoints, state sync
   ├─ FireService         -- fire registry, damage, dousing, hose, relights, incidents
   ├─ QuestService        -- stage machine, co-op credit, auto-complete safety nets
   ├─ InteractionService  -- prompts: pickups, water, valves, shrine; zones/regions
   ├─ NPCService          -- all characters & spirits: models, dialogue, rescues, graduation finale
   ├─ ShopService         -- Marla's kiosk (food + scarf & hat cosmetics, Sparks only)
   ├─ FishService         -- validates fish catches; eat-a-fish energy (fish render client-side)
   └─ SideQuestService    -- hungry statue, community garden, recycler, crash mounds, stone turtle

StarterPlayer
├─ StarterCharacter        -- the part-based penguin rig (Motor6D joints)
├─ StarterCharacterScripts -- Animate/Health stubs (override Roblox defaults)
└─ StarterPlayerScripts
   ├─ ClientMain     -- all UI (HUD, dialogue, journal, shop, settings, credits…)
   ├─ PenguinMotion  -- procedural waddle/flap/swim/slide + diving-trick coach
   ├─ FishLife       -- client-side fish schools (render/wander/flee/catch FX)
   └─ WonderSprites  -- shy kodama sprites & the river loon (pure wonder, no rewards)

Workspace
├─ World.<Region>   -- Campsite, WhisperingWoods, CityPark, Neighborhood,
│                      Waterfront (+ GreatBridge), Tunnels, Firehouse
└─ NPCs / Fires / Pickups (runtime containers)
```

**Tag conventions (CollectionService)** — the world is data-driven; services scan
these tags at boot:

| Tag | Meaning | Key attributes |
|---|---|---|
| `FireSpot` | a fire location | `FireId`, `Size` (Small/Medium/Large), `ExtinguishBy` (Water/Blanket/Hose), `Auto`, `QuestKey`, `Memory` |
| `WaterSource` | bucket fill point | `SourceType` (Pond/Fountain/Hydrant), `Live`, `HydrantId` |
| `Pickup` | interactable item | `Kind` (Tool/QuestItem/Food/Cache), `Item`, `Label`, `QuestKey`, `RespawnSeconds`, `Sparks` |
| `NPCSpot` | character spawn | `NpcId` (must match a `DEFS` entry in NPCService), `HiddenUntil` |
| `Debris` | axe target | `DebrisId`, `Hits`, `QuestKey` |
| `Valve` | tunnel puzzle wheel | `ValveIndex`, `OrderPos` |
| `Zone` | region volume | `ZoneId`, `DisplayName`, `Checkpoint`, `QuestKey` |
| `Checkpoint` | respawn marker | `ZoneId` |
| `Unlockable` | gated world piece | `UnlockId`, `Action` (Show/Hide/Sink) |
| `Shrine` / `Shop` | finale shrine / kiosk prompt | `QuestKey` / `ShopId` |
| `FishSchool` | client-rendered fish school anchor | `Radius`, `Count` |
| `HungryStatue` / `GardenPlot` / `Recycler` | side-quest stations (SideQuestService) | — |
| `CrashMound` | bursts when hit fast, reveals `HiddenUntilCrash` pickups | — |
| `SleepyTurtle` / `ShySpot` | stand-on secret / client wonder-sprites | `Style` (kodama/loon) |

## Testing

**Solo:** press Play. The whole story is solo-completable (verified end-to-end).

**Multiplayer:** Studio → Test tab → *Clients and Servers* → 2 players → Start.
Co-op behaviors to check: shared fires (both players' douses count), assist credit
(players within 70 studs of a quest completion get credit for the same stage),
per-player pickups (one player taking a mitten never removes it for others),
story fires relighting for players who still need them.

**QA hook:** `ServerScriptService.TestHook` (BindableFunction, server-only) lets
you drive the quest machine from the command bar, e.g.
`require`-free: `SSS.TestHook:Invoke("signal", "FireOut:Camp_TutorialFire", player)`
or `:Invoke("getdata", player)` / `:Invoke("stageid", player)`. Remove it for
production if you prefer; clients can never reach it either way.

## Saving

- `DataService` persists: story stage, quest counters/items, tools, Sparks,
  badges, collected pickups/caches, world unlocks, cosmetics, completion flag,
  and volume settings. Schema is versioned (`v = 1`) with defaults merged on load.
- All store calls are wrapped in pcall with 3 retries + backoff, autosave every
  120 s, save on leave and on server close.
- **Studio never writes production data** unless you set the Workspace attribute
  `EnableStudioSaves = true`. Without it, Studio runs on an in-memory profile
  (a console line confirms this). This is the documented test-data strategy.
- If loading fails in production the session still plays; the player gets a
  friendly notice and the server refuses to overwrite their stored data with
  defaults.

## How to extend

- **Add a quest stage:** append an entry to `Shared/QuestDefs`. Triggers are
  string keys; emit them from anywhere via `QuestService:Signal(key, player, pos?)`.
- **Add a fire:** drop an invisible part, tag `FireSpot`, set attributes. Done —
  visuals, damage, dousing, rewards, and relights are automatic.
- **Add a tool:** add display data in `ItemDefs`, geometry + activation case in
  `InventoryService`, grant it from a stage's `onComplete.grantTool`.
- **Add an NPC/spirit:** place a marker part tagged `NPCSpot` with `NpcId`, then
  add a `DEFS` entry (builder + dialogue + onTrigger) in `NPCService`.
- **Add a region:** build under `Workspace.World.<Name>`, add a `Zone` +
  `Checkpoint`, and gate it with an `Unlockable` if needed.

## External assets & licenses

None. Every model, texture choice, script, and UI element is generated in-project
from Roblox primitives and built-in `rbxasset://` textures/sounds (Roblox-provided).
No Creator Store imports, no third-party scripts, no paid assets.

**Audio placeholders:** `SoundService` contains `PLACEHOLDER_WarmFirehouseTheme`
and `PLACEHOLDER_ForestAmbience` with empty SoundIds, and the client uses three
built-in Roblox UI/impact sounds for feedback. Before publishing, replace the
placeholders with licensed or original loops (fill in `SoundId`); volume routing
(Music/SFX groups + settings sliders) is already wired.

## Known limitations

- Ambient music/forest loops are silent placeholders (see above).
- Fire/water/spirit audio layers are minimal (three built-in SFX).
- Real DataStore round-trips were not exercised in Studio (mock mode by design);
  code-reviewed and defensive, but verify once after publishing.
- Two-simultaneous-client testing wasn't possible in this automated Studio
  session; co-op logic (assist radius, shared fires, per-player pickups,
  relights, auto-complete for late joiners) is implemented and unit-exercised
  server-side. Run one manual *Clients and Servers* pass before release.
- The firefighter as a playable post-game character is not included (listed as a
  future improvement; identity presentation options would ship with it).
- Belly-slide speed is client-applied (cosmetic-scale advantage only; all
  valuable state is server-authoritative).

## Publishing checklist

1. Replace the two placeholder audio loops with licensed/original music.
2. File → Publish to Roblox; set genre, icon, and description.
3. Complete the content-maturity questionnaire accurately (designed for Minimal/Mild).
4. Enable Studio API access if you want to test saves from Studio, or test on a
   live server; confirm a save/reload round-trip.
5. Run one *Clients and Servers* (2-player) pass over the tutorial + one spirit quest.
6. Set max players (suggest 8) and enable the platforms you support.
7. Optional: remove `ServerScriptService.TestHook`.

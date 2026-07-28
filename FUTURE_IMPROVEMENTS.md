# Future Improvements (optional)

None of these block release; the core game is complete and finishable.

## Content
- **Playable firefighter character** unlocked after the finale, with masculine /
  feminine / androgynous presentation options (cosmetic only, no power changes).
- More side quests: a rainwater spirit trapped in the city pipes and a rooftop
  moonlight-cat spirit were designed in the same nonviolent template and would
  slot into the Tunnels and Neighborhood via `NPCSpot` + `QuestDefs` entries.
- More penguin cosmetics: helmets, backpacks, species-inspired feather patterns
  (extend `GameConfig.SCARF_COLORS` pattern into a general cosmetics table).
- Apartment interiors 2–3 in Brick Row (currently sealed façades).
- Additional hidden caches + a collectible "field notes" set that fills the
  journal with world lore.

## Systems
- Co-op flourishes: two-player pump-and-hose interaction (one pumps at the
  hydrant to boost the other's spray) — the hose loop already reads a rate value
  that could be scaled by a pump state.
- Repeatable incident variety: trapped-animal rescues and debris blockages, not
  just relit fires (`FireService.maybeSpawnIncident` is the extension point).
- Photo mode / emotes for the waddle.
- Analytics counters (fires doused, rescues) surfaced on a firehouse plaque.

## Presentation
- Replace placeholder music/ambience with an original warm firehouse theme and
  region-layered forest/city/water ambience (SoundGroups and sliders are wired).
- Fire audio intensity layers tied to `FireService.setIntensity`.
- Painterly ground blends between regions (terrain material painting pass).
- Cutscene camera moves for spirit transformations and the finale (the
  `GuardianScene` remote is already the hook).
- Seasonal event dressing (winter lights along the Great Bridge).

## Tech
- Localization pass (all strings currently live in QuestDefs/NPCService/ClientMain).
- Session-locking for DataStores (UpdateAsync-based) if the game grows beyond
  small servers.
- MemoryStore-backed cross-server incident announcements.

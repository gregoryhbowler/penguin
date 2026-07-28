--!strict
-- SpecimenDefs: the collectible specimens hidden in caches (keyed by pickup id).
-- Shown in the journal's Collection page, like a naturalist's specimen board.

local SpecimenDefs: { [string]: { name: string, text: string } } = {
	["Campsite/Cache"] = { name = "River Glass", text = "A pebble of green glass, tumbled smooth. It holds the light like pond water." },
	["WhisperingWoods/Cache"] = { name = "Acorn Lantern", text = "An acorn cap someone very small once used as a lantern. The wax still smells warm." },
	["CityPark/Cache"] = { name = "Bandstand Token", text = "A brass token: ADMIT ONE - EVERYONE ADMITTED ANYWAY." },
	["Neighborhood/Cache"] = { name = "Clock Spring", text = "A coiled spring that still ticks, faintly, when you hold your breath." },
	["Waterfront/Cache"] = { name = "Pyrite Knuckle", text = "Fool's gold shaped like a tiny fist. Heavier than it has any right to be." },
	["Tunnels/Cache"] = { name = "Storm Ember", text = "A cooled ember from the night the river burned. It dreams in orange when nobody looks." },
	["Tunnels/CacheAlcove"] = { name = "Singing Pipe Scale", text = "A flake of old pipe. Struck gently, it hums the river's one long note." },
	["Neighborhood/CacheTowerLedge"] = { name = "Soot Feather", text = "A pigeon feather dipped in forty winters of chimney smoke." },
	["Waterfront/CacheBridgeFoot"] = { name = "Driftwood Bone", text = "Grey driftwood worn into a wishbone. The river's handwriting." },
	["DolmenGrove/CacheGrove"] = { name = "Spiral Core", text = "A stone core drilled by patient water over a thousand years. Rings all the way down." },
	["SlideCove/LidoCache"] = { name = "Tidewood Knot", text = "A knot of driftwood polished by a thousand slides down the old lido. It smells like summer rain." },
	["Frostfell/FrostCache"] = { name = "Glacier Tear", text = "A teardrop of ancient ice that never melts. Deep inside, a tiny bubble of some winter long ago." },
}

return SpecimenDefs

--!strict
-- QuestDefs: the ordered main-story stages for Ember Grove.
-- Each stage completes when QuestService receives its trigger event.
-- Trigger kinds:
--   event  : fires once when the exact key is signalled for (or near) the player
--   count  : requires `count` signals of the key (e.g. collecting 3 mittens)
-- onComplete can grant tools, sparks (currency), badges, and world unlocks.
-- Unlock keys are consumed by WorldService (gates, shortcuts, doors).

export type Trigger = { kind: string, key: string, count: number? }
export type Stage = {
	id: string,
	title: string,
	objective: string,
	hint: string?,
	region: string,
	trigger: Trigger,
	onComplete: {
		grantTool: string?,
		sparks: number?,
		badge: string?,
		unlock: string?,
		notify: string?,
	}?,
}

local Stages: { Stage } = {
	-- ================= ACT 1: THE CAMPSITE (tutorial) =================
	{ id = "wake", title = "A Strange Morning", region = "Campsite",
	  objective = "Look around the campsite and pick up the old Bucket.",
	  hint = "The bucket sits by the fallen tent, glinting in the light.",
	  trigger = { kind = "event", key = "Pickup:Bucket" },
	  onComplete = { grantTool = "Bucket", notify = "You found a Bucket! Equip it from your toolbar." } },

	{ id = "fill", title = "Cold, Clear Water", region = "Campsite",
	  objective = "Fill your bucket at the pond.",
	  hint = "Stand at the water's edge with the bucket equipped and press Interact.",
	  trigger = { kind = "event", key = "BucketFilled" } },

	{ id = "firstfire", title = "The First Fire", region = "Campsite",
	  objective = "Put out the campfire that is scorching the path.",
	  hint = "Get close and swing your full bucket at the flames.",
	  trigger = { kind = "event", key = "FireOut:Camp_TutorialFire" },
	  onComplete = { sparks = 10 } },

	{ id = "catrescue", title = "A Small Rescue", region = "Campsite",
	  objective = "Rescue Ash the cat from the smoky tent.",
	  hint = "Walk up to Ash and hold the Rescue prompt.",
	  trigger = { kind = "event", key = "Rescue:AshCat" },
	  onComplete = { sparks = 20 } },

	{ id = "ranger", title = "The Ranger's Warning", region = "Campsite",
	  objective = "Talk to Ranger Maple at the forest gate.",
	  hint = "Follow the lanterns north out of the campsite.",
	  trigger = { kind = "event", key = "Talk:RangerMaple" },
	  onComplete = { grantTool = "MedKit", badge = "Campsite Cadet", sparks = 10,
		notify = "Ranger Maple gave you a Med Kit and a Firehouse Badge!" } },

	-- ================= ACT 2: WHISPERING WOODS =================
	{ id = "grovefire", title = "Smoke in the Grove", region = "WhisperingWoods",
	  objective = "Put out the grove fire deeper in the woods. It will take two full buckets.",
	  hint = "There is a small forest pool near the burning grove.",
	  trigger = { kind = "event", key = "FireOut:Woods_GroveFire" },
	  onComplete = { sparks = 20 } },

	{ id = "mittens", title = "The Moss Spirit's Mittens", region = "WhisperingWoods",
	  objective = "Mossmitt has lost its three mittens. Search the woods and gather them.",
	  hint = "Look by the forest pool, on the hollow log, and up on the climbing stones.",
	  trigger = { kind = "count", key = "Collect:Mitten", count = 3 } },

	{ id = "mossmitt", title = "Warm Paws, Warm Heart", region = "WhisperingWoods",
	  objective = "Return the mittens to Mossmitt in the spirit clearing.",
	  trigger = { kind = "event", key = "SpiritHelped:Mossmitt" },
	  onComplete = { sparks = 50, badge = "Friend of the Woods", unlock = "RootGate",
		notify = "Mossmitt remembered its purpose! The root gate to the City Park has opened." } },

	-- ================= ACT 3: CITY PARK (hub) =================
	{ id = "bram", title = "The City Park", region = "CityPark",
	  objective = "Meet Warden Bram at the park bandstand.",
	  trigger = { kind = "event", key = "Talk:WardenBram" },
	  onComplete = { grantTool = "FireBlanket",
		notify = "Warden Bram lent you a Fire Blanket — perfect for small fires." } },

	{ id = "cookfire", title = "Lunch, Interrupted", region = "CityPark",
	  objective = "Smother the burning cooking fire near the picnic lawn with your Fire Blanket.",
	  trigger = { kind = "event", key = "FireOut:Park_CookFire" },
	  onComplete = { sparks = 10 } },

	{ id = "picnic", title = "Helping Hands", region = "CityPark",
	  objective = "Treat the dizzy picnicker with your Med Kit.",
	  trigger = { kind = "event", key = "Rescue:Picnicker" },
	  onComplete = { sparks = 30 } },

	{ id = "recipebook", title = "The Worried Squirrel", region = "CityPark",
	  objective = "A frantic squirrel guards the snack kiosk. Find the recipe book she lost near the gazebo.",
	  hint = "Something rectangular is tucked under the gazebo bench.",
	  trigger = { kind = "event", key = "Collect:RecipeBook" } },

	{ id = "marla", title = "Marla Remembers", region = "CityPark",
	  objective = "Give the recipe book back to the squirrel.",
	  trigger = { kind = "event", key = "SpiritHelped:Marla" },
	  onComplete = { sparks = 50, badge = "Park Keeper", unlock = "SnackKiosk", grantTool = "Axe",
		notify = "Marla is herself again — her kiosk is open! Warden Bram left you his trusty axe." } },

	{ id = "branch", title = "The Blocked Street", region = "CityPark",
	  objective = "Use Warden Bram's axe to clear the fallen branch blocking Alder Street.",
	  trigger = { kind = "event", key = "DebrisCleared:ParkBranch" },
	  onComplete = { sparks = 10,
		notify = "Alder Street is clear — the Brick Neighborhood is ahead." } },

	-- ================= ACT 4: BRICK NEIGHBORHOOD =================
	{ id = "stovefire", title = "Smoke on the Second Floor", region = "Neighborhood",
	  objective = "Someone needs help in the corner apartment! Smother the stove fire with your blanket.",
	  trigger = { kind = "event", key = "FireOut:Apt_StoveFire" } },

	{ id = "nora", title = "Nora's Way Out", region = "Neighborhood",
	  objective = "Check on Nora and help her out of the apartment.",
	  trigger = { kind = "event", key = "Rescue:Nora" },
	  onComplete = { grantTool = "Hose", sparks = 30,
		notify = "Nora gave you her building's hose nozzle. It attaches to any working hydrant!" } },

	{ id = "clockgear", title = "The Clock Tower Pigeon", region = "Neighborhood",
	  objective = "Cindercoo, the soot-pigeon spirit, lost the clock gear it guards. Search the rooftops.",
	  hint = "Climb the fire escape on Brick Row and follow the planks.",
	  trigger = { kind = "event", key = "Collect:ClockGear" } },

	{ id = "cindercoo", title = "Time Flies Home", region = "Neighborhood",
	  objective = "Return the gear to Cindercoo at the old station clock.",
	  trigger = { kind = "event", key = "SpiritHelped:Cindercoo" },
	  onComplete = { sparks = 50, unlock = "RoofStair",
		notify = "The station clock chimes again! A rooftop shortcut has unfolded." } },

	{ id = "hosedebris", title = "Clearing Harbor Lane", region = "Neighborhood",
	  objective = "A big fire blocks Harbor Lane. Chop the fallen debris off the hydrant with your axe.",
	  trigger = { kind = "event", key = "DebrisCleared:HoseDebris" } },

	{ id = "streetfire", title = "Water On!", region = "Neighborhood",
	  objective = "Attach your hose to the hydrant and spray down the Harbor Lane fire.",
	  hint = "Equip the Hose near the hydrant, then hold to spray. Aim at the flames!",
	  trigger = { kind = "event", key = "FireOut:Street_BigFire" },
	  onComplete = { sparks = 40, badge = "Neighborhood Hero", unlock = "WaterfrontGate",
		notify = "Harbor Lane is safe! The waterfront gate is open." } },

	-- ================= ACT 5: WATERFRONT & GREAT BRIDGE =================
	{ id = "mementos", title = "The Bridge That Forgot Itself", region = "Waterfront",
	  objective = "Old Span remembers every traveler but not itself. Find 3 traveler mementos along the waterfront.",
	  hint = "A ticket stub, a postcard, and a little toy boat are scattered near the piers.",
	  trigger = { kind = "count", key = "Collect:Memento", count = 3 } },

	{ id = "oldspan", title = "Every Crossing, Remembered", region = "Waterfront",
	  objective = "Bring the mementos to Old Span beneath the great stone tower.",
	  trigger = { kind = "event", key = "SpiritHelped:OldSpan" },
	  onComplete = { sparks = 50, badge = "Bridge Warden", unlock = "BridgeSpan",
		notify = "Old Span lowered its walkway. The far shore awaits!" } },

	{ id = "crossing", title = "The Long Crossing", region = "Waterfront",
	  objective = "Cross the Great Bridge toward the firehouse district.",
	  trigger = { kind = "event", key = "ZoneEnter:FirehouseDistrict" } },

	-- ================= ACT 6: OLD SERVICE TUNNELS =================
	{ id = "valves", title = "Dry Hydrants", region = "Tunnels",
	  objective = "The firehouse hydrants are dry. In the service tunnels, open the three valves in the order painted on the pipes.",
	  hint = "Read the numbers stenciled beside each valve wheel.",
	  trigger = { kind = "event", key = "ValvePuzzleSolved" },
	  onComplete = { sparks = 30, unlock = "HydrantsLive", notify = "Water pressure restored! The firehouse hydrants are live." } },

	{ id = "beam", title = "Someone's Down Here", region = "Tunnels",
	  objective = "Free Sam the maintenance worker: chop the fallen beam pinning the doorway.",
	  trigger = { kind = "event", key = "DebrisCleared:TunnelBeam" } },

	{ id = "sam", title = "Sam's Bruises", region = "Tunnels",
	  objective = "Treat Sam with your Med Kit.",
	  trigger = { kind = "event", key = "Rescue:Sam" },
	  onComplete = { sparks = 30, badge = "Tunnel Runner", unlock = "TunnelExit",
		notify = "Sam unlocked the ladder up to the firehouse yard!" } },

	-- ================= ACT 7: THE FIREHOUSE =================
	{ id = "memoryfires", title = "The Watchkeeper", region = "Firehouse",
	  objective = "A forgotten guardian burns with old fear. Put out all four memory fires around the firehouse yard.",
	  hint = "Use your hose on the live hydrants in the yard.",
	  trigger = { kind = "count", key = "MemoryFireOut", count = 4 },
	  onComplete = { sparks = 60 } },

	{ id = "memories", title = "What the Firehouse Remembers", region = "Firehouse",
	  objective = "Gather the three firehouse memories: the crew photo, the brass bell, and the old helmet.",
	  hint = "Look inside the firehouse, by the flag pole, and on the training tower.",
	  trigger = { kind = "count", key = "Collect:Memory", count = 3 } },

	{ id = "shrine", title = "The Watch Shrine", region = "Firehouse",
	  objective = "Place the memories at the watch shrine in front of the firehouse.",
	  trigger = { kind = "event", key = "MemoriesPlaced" } },

	{ id = "watchkeeper", title = "Home", region = "Firehouse",
	  objective = "Speak with the Watchkeeper.",
	  trigger = { kind = "event", key = "SpiritHelped:Watchkeeper" },
	  onComplete = { sparks = 100, badge = "Watchkeeper's Friend",
		unlock = "FirehouseRestored",
		notify = "The Watchkeeper is at peace. Welcome home, little firefighter." } },
}

local QuestDefs = {
	Stages = Stages,
	COMPLETED_STAGE = #Stages + 1,
}

function QuestDefs.getStage(index: number): Stage?
	return Stages[index]
end

function QuestDefs.stageIndexById(id: string): number?
	for i, s in ipairs(Stages) do
		if s.id == id then return i end
	end
	return nil
end

return QuestDefs

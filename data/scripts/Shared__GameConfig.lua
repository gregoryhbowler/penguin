--!strict
-- GameConfig: all tunable values for Ember Grove live here.
-- Designers should change numbers here rather than editing service code.

local GameConfig = {
	GAME_TITLE = "Ember Grove: A Penguin's Way Home",
	PENGUIN_NAME = "Pip",

	-- Player state -------------------------------------------------------
	MAX_HEALTH = 100,
	MAX_ENERGY = 100,
	ENERGY_DRAIN_PER_SECOND = 0.045, -- ~37 min from full to empty; gentle by design
	LOW_ENERGY_THRESHOLD = 25, -- warning shown below this
	LOW_ENERGY_SPEED_SCALE = 0.75, -- tired penguins waddle slower, never die from hunger
	HEALTH_REGEN_PER_SECOND = 2, -- regen when out of danger and energy > threshold
	FIRE_TOUCH_DAMAGE = 6, -- per tick while touching flames
	FIRE_DAMAGE_INTERVAL = 0.7,

	-- Movement ------------------------------------------------------------
	WALK_SPEED = 14,
	SLIDE_SPEED = 30,
	SLIDE_DURATION = 1.1,
	SLIDE_COOLDOWN = 1.6,
	JUMP_POWER = 42,

	-- Fires ----------------------------------------------------------------
	FIRE_SIZES = {
		Small = { health = 1, radius = 5, damageRadius = 4 }, -- one bucket / one blanket
		Medium = { health = 2, radius = 8, damageRadius = 6 }, -- two douses
		Large = { health = 4, radius = 12, damageRadius = 8 }, -- hose or many douses
	},
	DOUSE_RANGE = 14, -- max distance from fire for a bucket throw to count
	BLANKET_RANGE = 8,
	HOSE_RANGE = 26,
	HOSE_DPS = 0.55, -- fire health drained per second of hose spray
	FILL_RANGE = 12, -- distance to a water source to fill a bucket
	EMBER_RESPAWN_SECONDS = 25, -- story fires relight for players who still need them

	-- Economy ---------------------------------------------------------------
	CURRENCY_NAME = "Sparks",
	REWARD_SMALL_FIRE = 10,
	REWARD_MEDIUM_FIRE = 20,
	REWARD_LARGE_FIRE = 40,
	REWARD_RESCUE = 30,
	REWARD_SPIRIT = 50,
	REWARD_HIDDEN_CACHE = 15,
	COOP_ASSIST_RADIUS = 70, -- players inside this radius share quest credit

	-- Food (energy restored) --------------------------------------------------
	FOODS = {
		Fish = { energy = 12, price = 0, hidden = true, color = Color3.fromRGB(130, 160, 190) }, -- caught, never sold
		Strawberries = { energy = 15, price = 5, color = Color3.fromRGB(220, 60, 80) },
		EnergyBar = { energy = 25, price = 10, color = Color3.fromRGB(200, 150, 60) },
		HotDog = { energy = 30, price = 12, color = Color3.fromRGB(190, 120, 70) },
		Pizza = { energy = 40, price = 15, color = Color3.fromRGB(230, 180, 90) },
		MacAndCheese = { energy = 45, price = 18, color = Color3.fromRGB(240, 190, 70) },
		ChocolateMilk = { energy = 20, price = 8, color = Color3.fromRGB(140, 95, 60) },
		Soda = { energy = 10, price = 5, color = Color3.fromRGB(90, 170, 90) },
	},

	-- Saving --------------------------------------------------------------------
	DATASTORE_NAME = "EmberGrove_PlayerData",
	DATASTORE_SCHEMA_VERSION = 1,
	AUTOSAVE_INTERVAL = 120,
	SAVE_RETRIES = 3,
	-- Studio never writes to production data unless this Workspace attribute is true:
	STUDIO_SAVE_ATTRIBUTE = "EnableStudioSaves",

	-- Post-game ember incidents ---------------------------------------------------
	INCIDENT_INTERVAL = 90, -- seconds between random small rescue fires after story completion
	INCIDENT_REWARD = 12,

	-- Cosmetics: scarf colors purchasable at the Park kiosk ------------------------
	SCARF_COLORS = {
		{ id = "RedScarf", name = "Ember Red", price = 25, color = Color3.fromRGB(190, 60, 50) },
		{ id = "BlueScarf", name = "River Blue", price = 25, color = Color3.fromRGB(70, 110, 180) },
		{ id = "YellowScarf", name = "Lantern Gold", price = 25, color = Color3.fromRGB(220, 180, 70) },
		{ id = "GreenScarf", name = "Moss Green", price = 25, color = Color3.fromRGB(90, 140, 80) },
		{ id = "PurpleScarf", name = "Dusk Plum", price = 40, color = Color3.fromRGB(130, 90, 150) },
		-- secret = never sold; earned by finding the Old Ways (the dolmen grove)
		{ id = "SpiralScarf", name = "Old Ways Moss", price = 0, secret = true, color = Color3.fromRGB(104, 132, 88) },
	},

	-- Hat cosmetics: sold at the kiosk (or earned; secret = never sold) -----------
	HATS = {
		{ id = "TopHat", name = "Dapper Top Hat", price = 75 },
		{ id = "FlowerCrown", name = "Meadow Crown", price = 40 },
		-- earned at the graduation ceremony, never sold
		{ id = "FirefighterHat", name = "Firefighter's Helmet", price = 0, secret = true },
	},

	-- Penguin life: fish -----------------------------------------------------------
	FISH_CATCH_RANGE = 30, -- server sanity distance from the school anchor
	FISH_CATCH_COOLDOWN = 1.0,
	STATUE_FISH_REQUIRED = 100, -- the hungry statue's appetite

	-- Side quests --------------------------------------------------------------------
	GARDEN_SEEDS_REQUIRED = 20,
	CAN_SPARKS = 5, -- Sparks per recycled can
}

return GameConfig

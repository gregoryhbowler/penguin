--!strict
-- ItemDefs: display data for tools and quest items.
-- The actual Tool instances live in ServerStorage.Tools and are granted by InventoryService.

local ItemDefs = {
	Tools = {
		Bucket = {
			name = "Bucket",
			desc = "Fill it at any water source, then swing it at a fire.",
			tip = "Tap Interact near water to fill. Tap/click near flames to douse.",
			color = Color3.fromRGB(160, 90, 60),
		},
		MedKit = {
			name = "Med Kit",
			desc = "Patches up hurt friends (and penguins).",
			tip = "Use near an injured character, or use it on yourself to heal.",
			color = Color3.fromRGB(220, 220, 220),
		},
		FireBlanket = {
			name = "Fire Blanket",
			desc = "Smothers small fires safely.",
			tip = "Use right next to a small fire to smother it.",
			color = Color3.fromRGB(180, 60, 50),
		},
		Axe = {
			name = "Axe",
			desc = "Clears fallen branches and debris. Not for fighting — penguins don't fight.",
			tip = "Use on cracked, marked debris to clear a path.",
			color = Color3.fromRGB(120, 120, 130),
		},
		Hose = {
			name = "Hose Nozzle",
			desc = "Attach near a live hydrant to spray a strong stream of water.",
			tip = "Works near live (blue-capped) hydrants. Hold to spray the flames.",
			color = Color3.fromRGB(200, 170, 60),
		},
		Wingsuit = {
			name = "Wingsuit",
			desc = "Stubby penguin wings, finally aerodynamic. Jump from high places and glide!",
			tip = "Equip it, leap from somewhere high, and steer with your movement keys. About 10 seconds of glide per flight.",
			color = Color3.fromRGB(96, 148, 208),
		},
	},
	-- Quest items are tracked as counts in player data, not as Tools,
	-- so they can never be dropped or lost.
	QuestItems = {
		Mitten = { name = "Lost Mitten", icon = "\u{1F9E4}" },
		RecipeBook = { name = "Recipe Book", icon = "\u{1F4D6}" },
		ClockGear = { name = "Clock Gear", icon = "\u{2699}" },
		Memento = { name = "Traveler Memento", icon = "\u{1F39F}" },
		Memory = { name = "Firehouse Memory", icon = "\u{1F397}" },
		Fish = { name = "Fresh Fish", icon = "\u{1F41F}" },
		Seed = { name = "Garden Seed", icon = "\u{1F331}" },
		Can = { name = "Tin Can", icon = "\u{1F96B}" },
		AntlerBlossom = { name = "Antler Blossom", icon = "\u{1F338}" },
	},
}

return ItemDefs

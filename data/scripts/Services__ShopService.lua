-- ShopService: Marla's snack kiosk. Sells food (restores energy immediately) and
-- scarf cosmetics for Sparks. Purchases are validated entirely server-side:
-- kiosk unlocked, item exists, price paid. No Robux, no randomness, no pay-to-win.

local CS = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.GameConfig)

local ShopService = {}
local registry
local Notify

local function catalog()
	local items = {}
	for id, food in pairs(Config.FOODS) do
		if not food.hidden then
			table.insert(items, { id = "food:" .. id, name = id:gsub("(%l)(%u)", "%1 %2"), kind = "food", price = food.price, energy = food.energy })
		end
	end
	table.sort(items, function(a, b) return a.price < b.price end)
	for _, scarf in ipairs(Config.SCARF_COLORS) do
		if not scarf.secret then -- secret scarves are earned, never sold
			table.insert(items, { id = "scarf:" .. scarf.id, name = scarf.name .. " Scarf", kind = "scarf", price = scarf.price,
				color = { math.floor(scarf.color.R * 255), math.floor(scarf.color.G * 255), math.floor(scarf.color.B * 255) } })
		end
	end
	for _, hat in ipairs(Config.HATS) do
		if not hat.secret then -- the firefighter helmet is earned, never sold
			table.insert(items, { id = "hat:" .. hat.id, name = hat.name, kind = "hat", price = hat.price })
		end
	end
	return items
end

local function purchase(player, itemId)
	if type(itemId) ~= "string" then return { ok = false, msg = "Hmm?" } end
	if not registry.WorldService:IsUnlocked("SnackKiosk") then
		return { ok = false, msg = "The kiosk is closed." }
	end
	local kind, id = string.match(itemId, "^(%w+):(%w+)$")
	if kind == "food" then
		local food = Config.FOODS[id]
		if not food then return { ok = false, msg = "Sold out!" } end
		if not registry.PlayerStateService:SpendSparks(player, food.price) then
			return { ok = false, msg = "Not enough " .. Config.CURRENCY_NAME .. "." }
		end
		registry.PlayerStateService:Eat(player, id)
		return { ok = true }
	elseif kind == "hat" then
		local def
		for _, h in ipairs(Config.HATS) do
			if h.id == id then def = h break end
		end
		if not def or def.secret then return { ok = false, msg = "Sold out!" } end
		local data = registry.DataService:Get(player)
		if not data then return { ok = false, msg = "One moment…" } end
		if not data.cosmetics.owned[id] then
			if not registry.PlayerStateService:SpendSparks(player, def.price) then
				return { ok = false, msg = "Not enough " .. Config.CURRENCY_NAME .. "." }
			end
			data.cosmetics.owned[id] = true
		end
		-- tapping an owned, worn hat takes it off again
		if data.cosmetics.equippedHat == id then
			data.cosmetics.equippedHat = ""
			Notify:FireClient(player, { text = "Hat tucked away.", kind = "good" })
		else
			data.cosmetics.equippedHat = id
			Notify:FireClient(player, { text = "Looking dashing! " .. def.name .. " equipped.", kind = "good" })
		end
		registry.DataService:MarkDirty(player)
		registry.InventoryService:ApplyCosmetics(player)
		return { ok = true }
	elseif kind == "scarf" then
		local def
		for _, s in ipairs(Config.SCARF_COLORS) do
			if s.id == id then def = s break end
		end
		if not def then return { ok = false, msg = "Sold out!" } end
		local data = registry.DataService:Get(player)
		if not data then return { ok = false, msg = "One moment…" } end
		if not data.cosmetics.owned[id] then
			if not registry.PlayerStateService:SpendSparks(player, def.price) then
				return { ok = false, msg = "Not enough " .. Config.CURRENCY_NAME .. "." }
			end
			data.cosmetics.owned[id] = true
		end
		data.cosmetics.equipped = id
		registry.DataService:MarkDirty(player)
		registry.InventoryService:ApplyCosmetics(player)
		Notify:FireClient(player, { text = "Looking sharp! " .. def.name .. " scarf equipped.", kind = "good" })
		return { ok = true }
	end
	return { ok = false, msg = "Hmm?" }
end

function ShopService:Init(reg)
	registry = reg
	Notify = RS.Remotes.Notify
end

function ShopService:Start()
	for _, part in ipairs(CS:GetTagged("Shop")) do
		local prompt = registry.InteractionService:AddPrompt(part, "Browse Snacks", "Marla's Kiosk", 0.4)
		prompt.MaxActivationDistance = 10
		prompt.Triggered:Connect(function(player)
			if not registry.WorldService:IsUnlocked("SnackKiosk") then
				Notify:FireClient(player, { text = "The kiosk shutter is closed. Maybe that squirrel knows something…", kind = "hint" })
				return
			end
			RS.Remotes.ShopOpen:FireClient(player, { items = catalog(), currency = Config.CURRENCY_NAME })
		end)
	end
	RS.Remotes.Purchase.OnServerInvoke = function(player, itemId)
		local ok, result = pcall(purchase, player, itemId)
		if not ok then
			warn("[ShopService] purchase error: " .. tostring(result))
			return { ok = false, msg = "Something jammed the register." }
		end
		return result
	end
end

return ShopService

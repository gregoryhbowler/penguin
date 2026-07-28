-- InteractionService: turns tagged world parts into accessible, contextual
-- interactions (ProximityPrompts), and owns the region/zone loop.
--   Pickup      - tools, quest items, food, hidden caches (per-player, never stolen)
--   WaterSource - fill the bucket (ponds, fountain, live hydrants)
--   Valve       - the tunnel water-routing puzzle
--   Shrine      - the finale memory placement
--   Shop        - opens the snack kiosk
--   Debris      - axe targets (chopped via Tool activation, validated here)
-- All validation happens server-side: distance, ownership, state, cooldowns.

local CS = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.GameConfig)

local InteractionService = {}
local registry
local Notify
local foodCooldowns = {}   -- [player] = { [pickupId] = os.clock() }
local circleCooldowns = {} -- [player] = { [circleId] = os.clock() } (spirit circle re-whisper delay)
local valveState = { expected = 1, solved = false }
local checkpointByZone = {} -- [ZoneId] = Vector3

local function pickupId(part)
	return (part.Parent and part.Parent.Name or "World") .. "/" .. part.Name
end

-- distance from a point to a part's bounding box (0 when inside).
-- Needed for big water volumes like the pond, where center-distance is misleading.
local function distToPart(part, point)
	local rel = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	local dx = math.max(math.abs(rel.X) - half.X, 0)
	local dy = math.max(math.abs(rel.Y) - half.Y, 0)
	local dz = math.max(math.abs(rel.Z) - half.Z, 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function addPrompt(part, actionText, objectText, holdDuration)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText or ""
	prompt.HoldDuration = holdDuration or 0.4
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

-- ---------------- pickups ----------------
local function onPickup(player, part)
	local data = registry.DataService:Get(player)
	if not data then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - part.Position).Magnitude > 14 then return end

	local kind = part:GetAttribute("Kind")
	local item = part:GetAttribute("Item")
	local id = pickupId(part)

	if kind == "Lore" then
		-- readable inscriptions: always re-readable; small one-time discovery reward
		RS.Remotes.Dialogue:FireClient(player, {
			name = part:GetAttribute("LoreTitle") or "Inscription",
			lines = { part:GetAttribute("LoreText") or "…" },
			mood = "mysterious",
		})
		if not data.collected[id] then
			data.collected[id] = true
			registry.DataService:MarkDirty(player)
			registry.PlayerStateService:AddSparks(player, 5, "a story remembered")
		end
		return
	end

	if kind == "Food" then
		foodCooldowns[player] = foodCooldowns[player] or {}
		local last = foodCooldowns[player][id]
		local respawn = part:GetAttribute("RespawnSeconds") or 45
		if last and os.clock() - last < respawn then
			Notify:FireClient(player, { text = "That snack spot is empty for now — check back soon.", kind = "hint" })
			return
		end
		foodCooldowns[player][id] = os.clock()
		registry.PlayerStateService:Eat(player, item)
		return
	end

	if data.collected[id] then return end

	if kind == "Tool" then
		data.collected[id] = true
		registry.DataService:MarkDirty(player)
		registry.InventoryService:GrantTool(player, item)
	elseif kind == "QuestItem" then
		data.collected[id] = true
		registry.DataService:MarkDirty(player)
		registry.QuestService:AddQuestItem(player, item, 1)
		Notify:FireClient(player, { text = "Picked up: " .. (part:GetAttribute("Label") or item), kind = "good" })
	elseif kind == "Cache" then
		data.collected[id] = true
		registry.DataService:MarkDirty(player)
		local specimen = part:GetAttribute("Specimen")
		if specimen then
			-- a specimen for the journal's collection page: a small ceremony
			RS.Remotes.Dialogue:FireClient(player, {
				name = "Found: " .. specimen,
				lines = { part:GetAttribute("SpecimenText") or "A curious little find.", "(Added to the Collection page of your journal.)" },
				mood = "mysterious",
			})
		end
		registry.PlayerStateService:AddSparks(player, part:GetAttribute("Sparks") or Config.REWARD_HIDDEN_CACHE, specimen and ("found: " .. specimen) or "hidden cache!")
	end

	local questKey = part:GetAttribute("QuestKey")
	if questKey then
		registry.QuestService:Signal(questKey, player)
	end
	registry.QuestService:PushAll(player)
end

-- ---------------- bucket filling ----------------
local function findPlayerTool(player, toolName)
	local char = player.Character
	if char then
		local t = char:FindFirstChild(toolName)
		if t then return t end
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	return backpack and backpack:FindFirstChild(toolName) or nil
end

local function fillFrom(player, src) -- src == nil means open terrain water (river, pools)
	if src and src:GetAttribute("SourceType") == "Hydrant" and not src:GetAttribute("Live") then
		Notify:FireClient(player, { text = "This hydrant is dry. Something must be blocking the water…", kind = "hint" })
		return false
	end
	local bucket = findPlayerTool(player, "Bucket")
	if not bucket then
		Notify:FireClient(player, { text = "You need a bucket to carry water.", kind = "hint" })
		return false
	end
	if bucket:GetAttribute("Filled") then
		Notify:FireClient(player, { text = "Your bucket is already full!", kind = "hint" })
		return false
	end
	registry.InventoryService:SetBucketFilled(bucket, true)
	Notify:FireClient(player, { text = "Bucket filled! Carry it to the flames.", kind = "good" })
	registry.QuestService:Signal("BucketFilled", player)
	return true
end

-- any terrain water (the river!) within a few studs counts as a fill spot
local function nearTerrainWater(position)
	local terrain = workspace.Terrain
	local half = 6
	local region = Region3.new(position - Vector3.new(half, half, half), position + Vector3.new(half, half, half))
	region = region:ExpandToGrid(4)
	local ok, materials = pcall(function()
		local m = terrain:ReadVoxels(region, 4)
		return m
	end)
	if not ok or not materials then return false end
	local size = materials.Size
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				if materials[x][y][z] == Enum.Material.Water then return true end
			end
		end
	end
	return false
end

function InteractionService:TryFillBucket(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	for _, src in ipairs(CS:GetTagged("WaterSource")) do
		if distToPart(src, root.Position) <= Config.FILL_RANGE then
			return fillFrom(player, src)
		end
	end
	-- standing in / beside the river (or any terrain water) also works
	if nearTerrainWater(root.Position) then
		return fillFrom(player, nil)
	end
	return false
end

-- ---------------- axe / debris ----------------
function InteractionService:TryChop(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if not registry.InventoryService:HasTool(player, "Axe") then return end
	local best, bestDist
	for _, debris in ipairs(CS:GetTagged("Debris")) do
		if debris.Parent then
			local ref = debris:IsA("Model") and debris:FindFirstChildWhichIsA("BasePart") or debris
			if ref then
				local d = (ref.Position - root.Position).Magnitude
				if d <= 10 and (not bestDist or d < bestDist) then best, bestDist = debris, d end
			end
		end
	end
	if not best then
		Notify:FireClient(player, { text = "Swing the axe next to cracked branches or fallen debris.", kind = "hint" })
		return
	end
	local hits = (best:GetAttribute("Hits") or 1) - 1
	best:SetAttribute("Hits", hits)
	-- wood chip feedback
	local ref = best:IsA("Model") and best:FindFirstChildWhichIsA("BasePart") or best
	local chips = Instance.new("ParticleEmitter")
	chips.Texture = "rbxasset://textures/particles/smoke_main.dds"
	chips.Rate = 0
	chips.Lifetime = NumberRange.new(0.4, 0.7)
	chips.Speed = NumberRange.new(6, 9)
	chips.Size = NumberSequence.new(0.35)
	chips.Color = ColorSequence.new(Color3.fromRGB(150, 115, 80))
	chips.Parent = ref
	chips:Emit(12)
	task.delay(1, function() chips:Destroy() end)
	if hits <= 0 then
		local questKey = best:GetAttribute("QuestKey")
		local pos = ref.Position
		best:Destroy()
		Notify:FireClient(player, { text = "Path cleared!", kind = "good" })
		if questKey then
			registry.QuestService:Signal(questKey, player, pos)
		end
	else
		Notify:FireClient(player, { text = "Crack! It's coming loose… (" .. hits .. " more)", kind = "good" })
	end
end

-- ---------------- valves ----------------
local function resetValves()
	valveState.expected = 1
	for _, v in ipairs(CS:GetTagged("Valve")) do
		v.Color = Color3.fromRGB(170, 60, 50)
		v:SetAttribute("Open", false)
	end
end

local function onValve(player, valve)
	if valveState.solved then
		Notify:FireClient(player, { text = "Water is already flowing to the firehouse!", kind = "hint" })
		return
	end
	local orderPos = valve:GetAttribute("OrderPos")
	if valve:GetAttribute("Open") then return end
	if orderPos == valveState.expected then
		valve:SetAttribute("Open", true)
		valve.Color = Color3.fromRGB(80, 170, 90)
		valveState.expected += 1
		Notify:FireClient(player, { text = "Valve " .. orderPos .. " open! The pipes hum…", kind = "good" })
		if valveState.expected > 3 then
			valveState.solved = true
			registry.WorldService:Unlock("HydrantsLive", player)
			registry.QuestService:Signal("ValvePuzzleSolved", player, valve.Position)
		end
	else
		Notify:FireClient(player, { text = "CLUNK. The pipes rattle and the valves reset. Follow the painted numbers in order!", kind = "warn" })
		resetValves()
	end
end

-- ---------------- shrine ----------------
local function onShrine(player, part)
	local stageId = registry.QuestService:GetStageId(player)
	if stageId ~= "shrine" and stageId ~= "memories" then
		Notify:FireClient(player, { text = "A quiet stone shrine. It feels like it's waiting for something.", kind = "hint" })
		return
	end
	if registry.QuestService:CountQuestItem(player, "Memory") < 3 then
		Notify:FireClient(player, { text = "You need all three firehouse memories: the photo, the bell, and the helmet.", kind = "hint" })
		return
	end
	if registry.QuestService:ConsumeQuestItems(player, "Memory", 3) then
		-- place glowing memories on the sockets (once, shared visual)
		local shrineModel = part.Parent
		if shrineModel and not shrineModel:FindFirstChild("PlacedMemory1") then
			local colors = { Color3.fromRGB(235, 225, 200), Color3.fromRGB(200, 160, 70), Color3.fromRGB(220, 180, 60) }
			for i, dx in ipairs({ -2, 0, 2 }) do
				local m = Instance.new("Part")
				m.Name = "PlacedMemory" .. i
				m.Size = Vector3.new(1.1, 1.1, 1.1)
				m.Position = part.Parent.ShrinePlinth.Position + Vector3.new(dx, 1.6, 0)
				m.Anchored = true
				m.CanCollide = false
				m.Material = Enum.Material.Neon
				m.Color = colors[i]
				m.Parent = shrineModel
				local glow = Instance.new("PointLight")
				glow.Color = colors[i]
				glow.Range = 8
				glow.Parent = m
			end
		end
		registry.QuestService:Signal("MemoriesPlaced", player, part.Position)
		Notify:FireClient(player, { text = "The memories settle into place. The air grows warm and still…", kind = "story" })
	end
end

-- ---------------- zones ----------------
local function zoneContains(zone, point)
	local rel = zone.CFrame:PointToObjectSpace(point)
	local half = zone.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

function InteractionService:Init(reg)
	registry = reg
	Notify = RS.Remotes.Notify

	-- checkpoint lookup
	for _, cp in ipairs(CS:GetTagged("Checkpoint")) do
		local zid = cp:GetAttribute("ZoneId")
		if zid then checkpointByZone[zid] = cp.Position end
	end

	-- pickups
	for _, part in ipairs(CS:GetTagged("Pickup")) do
		local label = part:GetAttribute("Label") or "Item"
		local kind = part:GetAttribute("Kind")
		local action = kind == "Food" and "Eat" or (kind == "Lore" and "Read" or "Pick up")
		local prompt = addPrompt(part, action, label, kind == "Food" and 0.3 or 0.4)
		prompt.Triggered:Connect(function(player) onPickup(player, part) end)
		-- gentle idle spin/bob so pickups read as interactive
		if kind ~= "Food" then
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			sparkle.Rate = 1.5
			sparkle.Lifetime = NumberRange.new(0.8, 1.2)
			sparkle.Speed = NumberRange.new(0.5)
			sparkle.Size = NumberSequence.new(0.35)
			sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 230, 150))
			sparkle.Parent = part
		end
	end

	-- water sources (prompt range accounts for large volumes like the pond)
	for _, src in ipairs(CS:GetTagged("WaterSource")) do
		local prompt = addPrompt(src, "Fill Bucket", "Water", 0.5)
		prompt.MaxActivationDistance = Config.FILL_RANGE + math.max(src.Size.X, src.Size.Z) / 2
		prompt.Triggered:Connect(function(player) fillFrom(player, src) end)
	end

	-- valves
	for _, valve in ipairs(CS:GetTagged("Valve")) do
		local prompt = addPrompt(valve, "Turn Valve", "Old Valve", 0.6)
		prompt.Triggered:Connect(function(player) onValve(player, valve) end)
	end
	resetValves()

	-- shrine
	for _, s in ipairs(CS:GetTagged("Shrine")) do
		local prompt = addPrompt(s, "Place Memories", "Watch Shrine", 0.8)
		prompt.Triggered:Connect(function(player) onShrine(player, s) end)
	end

	-- drawbridge winches: a lever at the foot of each bridge ramp lowers the span
	-- (the Old Span spirit quest lowers it too — whichever the player finds first)
	for _, lever in ipairs(CS:GetTagged("BridgeLever")) do
		local prompt = addPrompt(lever, "Pull Lever", "Drawbridge Winch", 0.8)
		prompt.Triggered:Connect(function(player)
			if registry.WorldService:IsUnlocked("BridgeSpan") then
				Notify:FireClient(player, { text = "The span is already down — the far shore awaits.", kind = "hint" })
				return
			end
			local handle = lever.Parent and lever.Parent:FindFirstChild("WinchHandle")
			if handle then
				game:GetService("TweenService"):Create(handle, TweenInfo.new(0.6), { CFrame = handle.CFrame * CFrame.Angles(math.rad(-70), 0, 0) }):Play()
			end
			registry.WorldService:Unlock("BridgeSpan", player)
			Notify:FireAllClients({ text = "\u{2699} The old winch groans… chains rattle… the drawbridge is coming down!", kind = "story" })
		end)
	end

	-- shop prompts handled by ShopService (needs catalog); it reuses addPrompt via registry

	-- the dolmen's Watcher Stone (end of the ring-stone trail; entirely optional)
	for _, stone in ipairs(CS:GetTagged("Dolmen")) do
		local prompt = addPrompt(stone, "Touch", "The Watcher Stone", 1.2)
		prompt.Triggered:Connect(function(player)
			local data = registry.DataService:Get(player)
			if not data then return end
			local RING_IDS = { "Campsite/RingStone1", "WhisperingWoods/RingStone2", "CityPark/RingStone3", "Waterfront/RingStone4", "Firehouse/RingStone5" }
			local found = 0
			for _, rid in ipairs(RING_IDS) do
				if data.collected[rid] then found += 1 end
			end
			if found < 5 then
				RS.Remotes.Dialogue:FireClient(player, { name = "The Watcher Stone", lines = {
					"The stone eye is closed. Under your flipper it hums, very old and very patient.",
					"Somewhere in the world, ring-carved stones are humming back. (" .. found .. " of 5 found.)",
				}, mood = "mysterious" })
				return
			end
			if not data.collected["Dolmen/awakened"] then
				data.collected["Dolmen/awakened"] = true
				registry.DataService:MarkDirty(player)
				registry.PlayerStateService:AddSparks(player, 100, "the Old Ways")
				registry.PlayerStateService:AwardBadge(player, "The Old Ways")
				data.cosmetics.owned["SpiralScarf"] = true
				data.cosmetics.equipped = "SpiralScarf"
				registry.InventoryService:ApplyCosmetics(player)
				RS.Remotes.Dialogue:FireClient(player, { name = "The Watcher Stone", lines = {
					"The rings turn. Stone grinds on stone, soft as a sigh — and the eye opens.",
					"It looks at you the way the forest looks at rain: gratefully, and without a single word.",
					"Something warm settles around your neck. Moss-green, woven from nowhere. The Old Ways remember you now.",
				}, mood = "mysterious" })
			else
				RS.Remotes.Dialogue:FireClient(player, { name = "The Watcher Stone", lines = { "The open eye rests. The grove breathes. Nothing is asked of you here." }, mood = "mysterious" })
			end
			-- global visual: the eye opens once, for everyone
			if not stone:GetAttribute("Awakened") then
				stone:SetAttribute("Awakened", true)
				local iris = stone.Parent and stone.Parent:FindFirstChild("WatcherIris")
				if iris then
					iris.Material = Enum.Material.Neon
					iris.Color = Color3.fromRGB(200, 232, 190)
					local li = Instance.new("PointLight")
					li.Color = Color3.fromRGB(190, 230, 180)
					li.Range = 16
					li.Brightness = 1.2
					li.Parent = iris
				end
			end
		end)
	end
end

function InteractionService:AddPrompt(part, actionText, objectText, holdDuration)
	return addPrompt(part, actionText, objectText, holdDuration)
end

function InteractionService:Start()
	-- zone loop: region banner, checkpoints, ZoneEnter quest keys
	task.spawn(function()
		local zones = CS:GetTagged("Zone")
		while true do
			task.wait(1.2)
			for _, player in ipairs(Players:GetPlayers()) do
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root then
					for _, zone in ipairs(zones) do
						if zone.Parent and zoneContains(zone, root.Position) then
							local display = zone:GetAttribute("DisplayName") or zone:GetAttribute("ZoneId")
							if player:GetAttribute("CurrentZone") ~= display then
								player:SetAttribute("CurrentZone", display)
							end
							if zone:GetAttribute("Checkpoint") then
								local cp = checkpointByZone[zone:GetAttribute("ZoneId")]
								if cp then registry.PlayerStateService:SetCheckpoint(player, cp) end
							end
							local qk = zone:GetAttribute("QuestKey")
							if qk then
								-- signal once per player per zone so out-of-order visits still count
								local memoKey = "ZoneSignalled_" .. tostring(zone:GetAttribute("ZoneId"))
								if not player:GetAttribute(memoKey) then
									player:SetAttribute(memoKey, true)
									registry.QuestService:Signal(qk, player)
								end
							end
						end
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		foodCooldowns[player] = nil
		circleCooldowns[player] = nil
	end)

	-- ============ found wonders: spirit circles (never marked, never listed) ============
	task.spawn(function()
		local circles = CS:GetTagged("SpiritCircle")
		while true do
			task.wait(1.5)
			for _, player in ipairs(Players:GetPlayers()) do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root then
					for _, c in ipairs(circles) do
						if c.Parent and (c.Position - root.Position).Magnitude <= 8 then
							circleCooldowns[player] = circleCooldowns[player] or {}
							local cid = c:GetAttribute("CircleId")
							local last = circleCooldowns[player][cid]
							if not last or os.clock() - last > 150 then
								circleCooldowns[player][cid] = os.clock()
								Notify:FireClient(player, { text = c:GetAttribute("Whisper") or "The air stills here.", kind = "story" })
								-- rising wisps at the circle
								local pe = Instance.new("ParticleEmitter")
								pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
								pe.Rate = 0
								pe.Lifetime = NumberRange.new(1.6, 2.6)
								pe.Speed = NumberRange.new(1.5, 3)
								pe.SpreadAngle = Vector2.new(35, 35)
								pe.Size = NumberSequence.new(0.5)
								pe.Color = ColorSequence.new(Color3.fromRGB(214, 236, 190))
								pe.EmissionDirection = Enum.NormalId.Top
								pe.Parent = c
								pe:Emit(22)
								task.delay(3, function() pe:Destroy() end)
								local data = registry.DataService:GetIfLoaded(player)
								if data and not data.collected["SpiritCircles/" .. cid] then
									data.collected["SpiritCircles/" .. cid] = true
									registry.DataService:MarkDirty(player)
									registry.PlayerStateService:AddSparks(player, 15, "the old ways notice you")
								end
							end
						end
					end
				end
			end
		end
	end)

	-- ============ ambient creatures ============
	-- bird flocks scatter when a penguin waddles close, and drift back later
	task.spawn(function()
		local TweenService = game:GetService("TweenService")
		local flocks = {}
		for _, anchor in ipairs(CS:GetTagged("BirdFlock")) do
			local birds = {}
			for _, b in ipairs(anchor:GetChildren()) do
				if b:IsA("BasePart") then table.insert(birds, { part = b, home = b.CFrame }) end
			end
			flocks[anchor] = { birds = birds, scattered = false, returnAt = 0 }
		end
		while true do
			task.wait(0.8)
			for anchor, f in pairs(flocks) do
				if not anchor.Parent then flocks[anchor] = nil continue end
				if f.scattered then
					if os.clock() > f.returnAt then
						f.scattered = false
						for _, b in ipairs(f.birds) do
							b.part.CFrame = b.home
							TweenService:Create(b.part, TweenInfo.new(1.2), { Transparency = 0 }):Play()
						end
					end
				else
					for _, player in ipairs(Players:GetPlayers()) do
						local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
						if root and (anchor.Position - root.Position).Magnitude <= 11 then
							f.scattered = true
							f.returnAt = os.clock() + 45 + math.random() * 45
							for _, b in ipairs(f.birds) do
								local away = (b.part.Position - root.Position) * Vector3.new(1, 0, 1)
								away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
								local target = b.part.CFrame + away * (14 + math.random() * 10) + Vector3.new(0, 16 + math.random() * 8, 0)
								TweenService:Create(b.part, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = target, Transparency = 1 }):Play()
							end
							break
						end
					end
				end
			end
		end
	end)

	-- fish rising in the river
	task.spawn(function()
		local spots = CS:GetTagged("FishSpot")
		while #spots > 0 do
			task.wait(4 + math.random() * 9)
			local spot = spots[math.random(#spots)]
			local fx = spot and spot:FindFirstChild("SplashFX")
			if fx then fx:Emit(14) end
		end
	end)
end

return InteractionService

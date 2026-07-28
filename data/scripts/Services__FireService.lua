-- FireService: modular fire system.
-- Fires are declared in the world as invisible parts tagged "FireSpot" with attributes:
--   FireId, Size (Small/Medium/Large), ExtinguishBy (Water/Blanket/Hose), Auto (lit at start),
--   QuestKey (quest signal on extinguish), Memory (finale fires).
-- All state and extinguishing is server-authoritative. Visuals (Fire + light + smoke)
-- replicate automatically. Story fires relight for players who still need them, and
-- after the story is done small "ember incidents" relight fires as repeatable rescues.

local CS = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.GameConfig)

local FireService = {}
local registry
local fires = {}      -- [fireId] = state
local hoses = {}      -- [player] = { tool, sprayPart, startedAt }
local Notify

local SIZE_REWARD = { Small = "REWARD_SMALL_FIRE", Medium = "REWARD_MEDIUM_FIRE", Large = "REWARD_LARGE_FIRE" }

-- ---------- visuals ----------
local function makeVisuals(state)
	local part = state.part
	local sizeDef = Config.FIRE_SIZES[state.size]
	local fire = Instance.new("Fire")
	fire.Name = "FireFX"
	fire.Size = math.clamp(sizeDef.radius * 1.6, 5, 25)
	fire.Heat = math.clamp(sizeDef.radius, 5, 12)
	fire.Color = Color3.fromRGB(236, 139, 70)
	fire.SecondaryColor = Color3.fromRGB(180, 60, 40)
	fire.Parent = part
	local light = Instance.new("PointLight")
	light.Name = "FireLight"
	light.Color = Color3.fromRGB(255, 160, 90)
	light.Range = sizeDef.radius * 2.2
	light.Brightness = 1.4
	light.Parent = part
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "SmokeFX"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 4
	smoke.Lifetime = NumberRange.new(1.8, 2.8)
	smoke.Speed = NumberRange.new(2.5, 4)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, sizeDef.radius * 0.4), NumberSequenceKeypoint.new(1, sizeDef.radius * 1.1) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(90, 85, 82))
	smoke.Parent = part
	-- crackle loop (placeholder-free: Roblox built-in fire crackle not available as rbxasset;
	-- AudioController layers client-side sound based on the FireFX instance instead)
end

local function setIntensity(state, fraction)
	local part = state.part
	local sizeDef = Config.FIRE_SIZES[state.size]
	local fire = part:FindFirstChild("FireFX")
	local light = part:FindFirstChild("FireLight")
	if fire then
		fire.Size = math.clamp(sizeDef.radius * 1.6 * math.max(fraction, 0.35), 3, 25)
	end
	if light then
		light.Brightness = 0.5 + fraction
	end
end

local function clearVisuals(state)
	for _, n in ipairs({ "FireFX", "FireLight", "SmokeFX" }) do
		local c = state.part:FindFirstChild(n)
		if c then c:Destroy() end
	end
end

local function steamBurst(part)
	local steam = Instance.new("ParticleEmitter")
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Lifetime = NumberRange.new(0.8, 1.4)
	steam.Speed = NumberRange.new(5, 8)
	steam.Rate = 0
	steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
	steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	steam.Color = ColorSequence.new(Color3.fromRGB(230, 230, 235))
	steam.Parent = part
	steam:Emit(24)
	task.delay(2, function() steam:Destroy() end)
end

-- ---------- core state ----------
local function light(state)
	if state.burning then return end
	state.burning = true
	state.health = state.maxHealth
	state.contributors = {}
	makeVisuals(state)
end

local function extinguish(state, byPlayer)
	if not state.burning then return end
	state.burning = false
	state.lastOut = os.clock()
	clearVisuals(state)
	steamBurst(state.part)

	-- rewards to everyone who helped
	local rewardKey = SIZE_REWARD[state.size]
	local reward = state.incident and Config.INCIDENT_REWARD or (rewardKey and Config[rewardKey]) or 10
	local PlayerState = registry.PlayerStateService
	for contributor in pairs(state.contributors) do
		if contributor.Parent then
			PlayerState:AddSparks(contributor, reward, "fire out!")
		end
	end

	-- quest signal (with position: nearby helpers get co-op credit)
	if state.questKey and byPlayer then
		registry.QuestService:Signal(state.questKey, byPlayer, state.part.Position)
	end
	if state.incident then
		state.incident = false
		Notify:FireAllClients({ text = "Ember incident contained. Nice work, rescuers!", kind = "good" })
	end
end

-- ---------- public API ----------
function FireService:FindBurningFireNear(position, range, methods)
	local best, bestDist
	for _, state in pairs(fires) do
		if state.burning and (methods == nil or methods[state.extinguishBy]) then
			local d = (state.part.Position - position).Magnitude
			if d <= range and (not bestDist or d < bestDist) then
				best, bestDist = state, d
			end
		end
	end
	return best
end

-- blankets work on Blanket-type fires at any strength, and on ANY fire that has
-- been doused down to ember strength (health <= 1) — so water + blanket combos
-- finish big fires the way real crews smother the last flames.
function FireService:FindSmotherableFireNear(position, range)
	local best, bestDist
	for _, state in pairs(fires) do
		if state.burning and (state.extinguishBy == "Blanket" or state.health <= 1) then
			local d = (state.part.Position - position).Magnitude
			if d <= range and (not bestDist or d < bestDist) then
				best, bestDist = state, d
			end
		end
	end
	return best
end

function FireService:Douse(state, player, amount)
	if not state.burning then return end
	state.health = math.max(0, state.health - amount)
	state.contributors[player] = true
	steamBurst(state.part)
	if state.health <= 0 then
		extinguish(state, player)
	else
		setIntensity(state, state.health / state.maxHealth)
		Notify:FireClient(player, { text = "The flames shrink back! Keep going!", kind = "good" })
	end
end

-- ---------- hose ----------
local function nearLiveHydrant(position)
	for _, src in ipairs(CS:GetTagged("WaterSource")) do
		if src:GetAttribute("SourceType") == "Hydrant" and src:GetAttribute("Live") then
			if (src.Position - position).Magnitude <= 16 then return src end
		end
	end
	return nil
end

-- called when the Watchkeeper is calmed: the yard's memory fires go out for good
function FireService:ExtinguishAllMemoryFires()
	for _, state in pairs(fires) do
		if state.memory then
			state.questKey = nil -- never relight after the finale
			if state.burning then
				state.burning = false
				state.lastOut = os.clock()
				clearVisuals(state)
				steamBurst(state.part)
			end
		end
	end
end

function FireService:StopHose(player)
	local h = hoses[player]
	if not h then return end
	hoses[player] = nil
	if h.spray then h.spray:Destroy() end
end

-- ---------- co-op pump boost ----------
-- A second player can work the hydrant's pump handle: each stroke pressurizes
-- the hydrant for a few seconds and every hose drawing from it sprays at more
-- than double strength. Solo players can pre-pump and sprint back, but a
-- partner keeping the pressure up is the fast, fun way.
local PUMP_WINDOW = 5
local PUMP_MULT = 2.2
local pumped = {} -- [hydrantPart] = { until_ = clock, by = player }

function FireService:IsPumped(hydrant)
	local p = pumped[hydrant]
	return p ~= nil and os.clock() < p.until_
end

local function onPump(player, hydrant)
	if not hydrant:GetAttribute("Live") then
		Notify:FireClient(player, { text = "The pump handle moves, but the hydrant is dry…", kind = "hint" })
		return
	end
	local wasPumped = FireService:IsPumped(hydrant)
	pumped[hydrant] = { until_ = os.clock() + PUMP_WINDOW, by = player }
	-- a huff of spray from the cap
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.4, 0.7)
	pe.Speed = NumberRange.new(4, 7)
	pe.Size = NumberSequence.new(0.5)
	pe.Color = ColorSequence.new(Color3.fromRGB(140, 195, 235))
	pe.Parent = hydrant
	pe:Emit(10)
	task.delay(1, function() pe:Destroy() end)
	if not wasPumped then
		Notify:FireClient(player, { text = "You work the pump — pressure surging! Keep it up!", kind = "good" })
		for hosePlayer, h in pairs(hoses) do
			if h.hydrant == hydrant and hosePlayer ~= player then
				Notify:FireClient(hosePlayer, { text = "\u{1F4AA} " .. player.Name .. " is pumping — your hose ROARS with pressure!", kind = "good" })
			end
		end
	end
end

function FireService:ToggleHose(player, tool)
	if hoses[player] then
		FireService:StopHose(player)
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local hydrant = nearLiveHydrant(root.Position)
	if not hydrant then
		Notify:FireClient(player, { text = "The hose needs water! Stand near a live (blue-capped) hydrant.", kind = "hint" })
		return
	end
	local handle = tool:FindFirstChild("Grip", true)
	if not handle then return end
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "HoseSpray"
	spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spray.Rate = 40
	spray.Lifetime = NumberRange.new(0.5, 0.8)
	spray.Speed = NumberRange.new(30, 36)
	spray.SpreadAngle = Vector2.new(6, 6)
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.6) })
	spray.Color = ColorSequence.new(Color3.fromRGB(120, 180, 230))
	spray.EmissionDirection = Enum.NormalId.Back
	spray.Parent = handle
	hoses[player] = { tool = tool, spray = spray, startedAt = os.clock(), hydrant = hydrant }
	Notify:FireClient(player, { text = "Water on! Aim near the flames.", kind = "good" })
end

-- ---------- incidents (post-game repeatable rescues) ----------
local function maybeSpawnIncident()
	local players = Players:GetPlayers()
	if #players == 0 then return end
	for _, p in ipairs(players) do
		local data = registry.DataService:GetIfLoaded(p)
		if not (data and data.completed) then return end -- only when everyone online finished
	end
	local candidates = {}
	for _, state in pairs(fires) do
		if not state.burning and not state.memory and state.size ~= "Large" then
			table.insert(candidates, state)
		end
	end
	if #candidates == 0 then return end
	local state = candidates[math.random(#candidates)]
	state.incident = true
	light(state)
	Notify:FireAllClients({ text = "\u{1F525} An ember incident sparked near " .. (state.part.Parent and state.part.Parent.Name or "town") .. "! Rescuers wanted.", kind = "warn" })
end

-- ---------- lifecycle ----------
function FireService:Init(reg)
	registry = reg
	Notify = RS.Remotes.Notify
	for _, part in ipairs(CS:GetTagged("FireSpot")) do
		local id = part:GetAttribute("FireId")
		if id then
			local size = part:GetAttribute("Size") or "Small"
			fires[id] = {
				id = id,
				part = part,
				size = size,
				maxHealth = Config.FIRE_SIZES[size].health,
				health = 0,
				burning = false,
				extinguishBy = part:GetAttribute("ExtinguishBy") or "Water",
				questKey = part:GetAttribute("QuestKey"),
				memory = part:GetAttribute("Memory") == true,
				contributors = {},
				lastOut = 0,
			}
		end
	end
end

function FireService:Start()
	for _, state in pairs(fires) do
		if state.part:GetAttribute("Auto") then light(state) end
	end

	-- pump handles on every hydrant (R key so it never collides with Fill Bucket's E)
	for _, src in ipairs(CS:GetTagged("WaterSource")) do
		if src:GetAttribute("SourceType") == "Hydrant" then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Pump!"
			prompt.ObjectText = "Hydrant Pump"
			prompt.HoldDuration = 0.25
			prompt.KeyboardKeyCode = Enum.KeyCode.R
			prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt.Parent = src
			prompt.Triggered:Connect(function(player)
				local ok, err = pcall(onPump, player, src)
				if not ok then warn("[FireService] pump: " .. tostring(err)) end
			end)
		end
	end

	-- damage loop
	task.spawn(function()
		while true do
			task.wait(Config.FIRE_DAMAGE_INTERVAL)
			for _, state in pairs(fires) do
				if state.burning then
					local dmgRadius = Config.FIRE_SIZES[state.size].damageRadius
					for _, player in ipairs(Players:GetPlayers()) do
						local char = player.Character
						local root = char and char:FindFirstChild("HumanoidRootPart")
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						if root and hum and hum.Health > 0 then
							if (root.Position - state.part.Position).Magnitude <= dmgRadius then
								hum:TakeDamage(Config.FIRE_TOUCH_DAMAGE)
								registry.PlayerStateService:NoteDamage(player)
							end
						end
					end
				end
			end
		end
	end)

	-- hose spray loop
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player, h in pairs(hoses) do
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local stillEquipped = char and h.tool.Parent == char
				if not (root and stillEquipped) or os.clock() - h.startedAt > 12
					or (h.hydrant.Position - root.Position).Magnitude > 20 then
					FireService:StopHose(player)
				else
					-- a pumped hydrant more than doubles the spray (co-op boost)
					local boosted = FireService:IsPumped(h.hydrant)
					local rate = Config.HOSE_DPS * (boosted and 2.2 or 1)
					if h.spray then
						h.spray.Rate = boosted and 90 or 40
						h.spray.Speed = boosted and NumberRange.new(44, 52) or NumberRange.new(30, 36)
					end
					local fire = FireService:FindBurningFireNear(root.Position, Config.HOSE_RANGE, { Hose = true, Water = true })
					if fire then
						fire.contributors[player] = true
						fire.health = math.max(0, fire.health - rate * 0.25)
						if fire.health <= 0 then
							extinguish(fire, player)
						else
							setIntensity(fire, fire.health / fire.maxHealth)
						end
					end
				end
			end
		end
	end)

	-- relight loop: story fires relight when an online player still needs them.
	-- Memory fires (the 4-fire finale set) get a much longer window so a solo player
	-- can finish the whole set without earlier fires relighting mid-attempt.
	task.spawn(function()
		while true do
			task.wait(8)
			for _, state in pairs(fires) do
				local window = state.memory and 120 or Config.EMBER_RESPAWN_SECONDS
				if not state.burning and state.questKey and os.clock() - state.lastOut > window then
					for _, player in ipairs(Players:GetPlayers()) do
						if registry.QuestService:NeedsKey(player, state.questKey) then
							light(state)
							break
						end
					end
				end
			end
		end
	end)

	-- post-game ember incidents
	task.spawn(function()
		while true do
			task.wait(Config.INCIDENT_INTERVAL)
			pcall(maybeSpawnIncident)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		FireService:StopHose(player)
	end)
end

return FireService

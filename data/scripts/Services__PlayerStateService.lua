-- PlayerStateService: server-authoritative Health, Energy, Sparks, and Badges.
-- * Energy drains slowly; low energy slows the waddle but never kills the penguin.
-- * Health regenerates when out of danger.
-- * Checkpoints: entering a region sets a safe respawn point.
-- * All state changes flow to the client through the StateSync remote.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.GameConfig)

local PlayerStateService = {}
local registry
local energy = {}        -- [player] = number (session state; full on join)
local checkpoints = {}   -- [player] = Vector3
local lastDamage = {}    -- [player] = os.clock() of last damage taken
local syncQueued = {}

local StateSync, Notify, Celebration

function PlayerStateService:QueueSync(player)
	syncQueued[player] = true
end

local function pushSync(player)
	local data = registry.DataService:GetIfLoaded(player)
	if not data then return end
	local badgeList = {}
	for _, b in ipairs(data.badges) do table.insert(badgeList, b) end
	StateSync:FireClient(player, {
		energy = math.floor(energy[player] or Config.MAX_ENERGY),
		maxEnergy = Config.MAX_ENERGY,
		sparks = data.sparks,
		badges = badgeList,
		stageIndex = data.stageIndex,
		completed = data.completed,
		collected = data.collected,
		tools = data.tools,
		cosmetics = data.cosmetics,
		settings = data.settings,
	})
end

-- ---------- economy ----------
function PlayerStateService:AddSparks(player, amount, reason)
	local data = registry.DataService:Get(player)
	if not data then return end
	data.sparks = math.max(0, data.sparks + amount)
	registry.DataService:MarkDirty(player)
	if amount > 0 then
		Notify:FireClient(player, { text = "+" .. amount .. " " .. Config.CURRENCY_NAME .. (reason and (" — " .. reason) or ""), kind = "sparks" })
	end
	PlayerStateService:QueueSync(player)
end

function PlayerStateService:SpendSparks(player, amount)
	local data = registry.DataService:Get(player)
	if not data or data.sparks < amount then return false end
	data.sparks -= amount
	registry.DataService:MarkDirty(player)
	PlayerStateService:QueueSync(player)
	return true
end

function PlayerStateService:AwardBadge(player, badgeName)
	local data = registry.DataService:Get(player)
	if not data then return end
	for _, b in ipairs(data.badges) do
		if b == badgeName then return end
	end
	table.insert(data.badges, badgeName)
	registry.DataService:MarkDirty(player)
	Celebration:FireClient(player, { kind = "badge", title = "Firehouse Badge earned!", detail = badgeName })
	PlayerStateService:QueueSync(player)
end

-- ---------- energy ----------
function PlayerStateService:AddEnergy(player, amount)
	energy[player] = math.clamp((energy[player] or Config.MAX_ENERGY) + amount, 0, Config.MAX_ENERGY)
	PlayerStateService:QueueSync(player)
end

function PlayerStateService:Eat(player, foodId)
	local food = Config.FOODS[foodId]
	if not food then return false end
	PlayerStateService:AddEnergy(player, food.energy)
	Notify:FireClient(player, { text = "Yum! +" .. food.energy .. " energy.", kind = "good" })
	return true
end

function PlayerStateService:NoteDamage(player)
	lastDamage[player] = os.clock()
end

-- ---------- checkpoints ----------
function PlayerStateService:SetCheckpoint(player, position)
	checkpoints[player] = position
end

local function placeAtCheckpoint(player, char)
	local cp = checkpoints[player]
	if not cp then return end
	local root = char:WaitForChild("HumanoidRootPart", 5)
	if root then
		char:PivotTo(CFrame.new(cp + Vector3.new(0, 3, 0)))
	end
end

-- ---------- lifecycle ----------
local function onCharacter(player, char)
	local hum = char:WaitForChild("Humanoid", 5)
	if not hum then return end
	hum.MaxHealth = Config.MAX_HEALTH
	hum.Health = Config.MAX_HEALTH
	hum:SetAttribute("BaseWalkSpeed", Config.WALK_SPEED)
	hum.WalkSpeed = Config.WALK_SPEED
	hum.JumpPower = Config.JUMP_POWER
	task.defer(placeAtCheckpoint, player, char)
	hum.Died:Connect(function()
		Notify:FireClient(player, { text = "Ouch! Waddling back to the last safe spot…", kind = "warn" })
	end)
end

local function onPlayer(player)
	energy[player] = Config.MAX_ENERGY
	player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	if player.Character then onCharacter(player, player.Character) end
end

function PlayerStateService:Init(reg)
	registry = reg
	StateSync = RS.Remotes.StateSync
	Notify = RS.Remotes.Notify
	Celebration = RS.Remotes.Celebration
end

function PlayerStateService:Start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
	Players.PlayerRemoving:Connect(function(player)
		energy[player] = nil
		checkpoints[player] = nil
		lastDamage[player] = nil
		syncQueued[player] = nil
	end)

	registry.DataService.PlayerLoaded.Event:Connect(function(player)
		pushSync(player)
	end)

	-- diving tricks: client announces a trick off the diving board; the server
	-- stamps it as a replicated character attribute (cosmetic only — every client's
	-- PenguinMotion animates it), then clears it on landing with a splash.
	local TRICKS = { swan = true, flip = true, roll = true, cannonball = true }
	RS.Remotes.ToolAction.OnServerEvent:Connect(function(player, action, arg)
		if action ~= "Trick" or type(arg) ~= "string" or not TRICKS[arg] then return end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (char and hum) or hum.Health <= 0 then return end
		local already = char:GetAttribute("Trick") ~= nil
		char:SetAttribute("Trick", arg)
		if already then return end -- watcher already running; just switched the style
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 5 and char.Parent do
				local state = hum:GetState()
				if state == Enum.HumanoidStateType.Swimming then
					local root = char:FindFirstChild("HumanoidRootPart")
					if root then
						local splash = Instance.new("ParticleEmitter")
						splash.Texture = "rbxasset://textures/particles/sparkles_main.dds"
						splash.Rate = 0
						splash.Lifetime = NumberRange.new(0.6, 1.1)
						splash.Speed = NumberRange.new(9, 15)
						splash.SpreadAngle = Vector2.new(70, 70)
						splash.Size = NumberSequence.new(0.7)
						splash.Color = ColorSequence.new(Color3.fromRGB(180, 220, 220))
						splash.EmissionDirection = Enum.NormalId.Top
						splash.Parent = root
						splash:Emit(30)
						task.delay(1.5, function() splash:Destroy() end)
					end
					break
				elseif state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.Running then
					break
				end
				task.wait(0.08)
			end
			if char.Parent then char:SetAttribute("Trick", nil) end
		end)
	end)

	-- settings persistence (volume sliders)
	RS.Remotes.SettingsSave.OnServerEvent:Connect(function(player, settings)
		if type(settings) ~= "table" then return end
		local data = registry.DataService:GetIfLoaded(player)
		if not data then return end
		local music = tonumber(settings.music)
		local sfx = tonumber(settings.sfx)
		if music then data.settings.music = math.clamp(music, 0, 1) end
		if sfx then data.settings.sfx = math.clamp(sfx, 0, 1) end
		registry.DataService:MarkDirty(player)
	end)

	-- main state loop (1 Hz): energy drain, tired speed, health regen, sync flush
	task.spawn(function()
		local lowWarned = {}
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local e = energy[player]
				if e then
					local newE = math.max(0, e - Config.ENERGY_DRAIN_PER_SECOND)
					if math.floor(newE) ~= math.floor(e) then syncQueued[player] = true end
					energy[player] = newE
					local char = player.Character
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						-- tired penguins slow down (but never starve to death)
						local base = Config.WALK_SPEED
						local target = newE <= Config.LOW_ENERGY_THRESHOLD and base * Config.LOW_ENERGY_SPEED_SCALE or base
						if hum:GetAttribute("BaseWalkSpeed") ~= target then
							hum:SetAttribute("BaseWalkSpeed", target)
							hum.WalkSpeed = target
						end
						if newE <= Config.LOW_ENERGY_THRESHOLD and not lowWarned[player] then
							lowWarned[player] = true
							Notify:FireClient(player, { text = "You're getting hungry… find a snack to keep your energy up!", kind = "warn" })
						elseif newE > Config.LOW_ENERGY_THRESHOLD + 10 then
							lowWarned[player] = nil
						end
						-- gentle regen when not recently hurt and not exhausted
						local last = lastDamage[player]
						if hum.Health < hum.MaxHealth and (not last or os.clock() - last > 5) and newE > Config.LOW_ENERGY_THRESHOLD then
							hum.Health = math.min(hum.MaxHealth, hum.Health + Config.HEALTH_REGEN_PER_SECOND)
						end
					end
				end
				if syncQueued[player] then
					syncQueued[player] = nil
					pushSync(player)
				end
			end
		end
	end)
end

return PlayerStateService

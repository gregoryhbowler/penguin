-- WorldService: applies world "unlocks" (gates, shortcuts, restored scenery).
-- Any instance tagged "Unlockable" declares:
--   UnlockId (string)  - which unlock controls it
--   Action (string)    - "Show" | "Hide" | "Sink"
-- Unlocks are server-wide (co-op friendly): the union of every online player's
-- earned unlocks is applied, so a rejoining player finds their world restored.
-- Special unlock "HydrantsLive" flips firehouse-district hydrants to Live.

local CS = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local WorldService = {}
local applied = {}       -- [unlockId] = true once applied this server
local registry
local Notify

local function allParts(inst)
	local parts = {}
	if inst:IsA("BasePart") then table.insert(parts, inst) end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(parts, d) end
	end
	return parts
end

local function applyToInstance(inst)
	local action = inst:GetAttribute("Action") or "Show"
	if action == "Show" then
		for _, p in ipairs(allParts(inst)) do
			p.Transparency = p:GetAttribute("OrigTransparency") or 0
			p.CanCollide = true
		end
	elseif action == "Hide" then
		for _, p in ipairs(allParts(inst)) do
			p.Transparency = 1
			p.CanCollide = false
		end
	elseif action == "Sink" then
		for _, p in ipairs(allParts(inst)) do
			p.CanCollide = false
			local tween = TweenService:Create(p, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = p.CFrame * CFrame.new(0, -(p.Size.Y + 6), 0), Transparency = 1 })
			tween:Play()
		end
		task.delay(2.6, function()
			if inst.Parent then inst:Destroy() end
		end)
	elseif action == "Lower" then
		-- drawbridge-style: every part eases to its stored TargetCF attribute
		for _, p in ipairs(allParts(inst)) do
			local target = p:GetAttribute("TargetCF")
			if typeof(target) == "CFrame" then
				TweenService:Create(p, TweenInfo.new(4.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = target }):Play()
			end
		end
	end
end

-- set initial (locked) state for unlockables
local function applyLockedState(inst)
	local action = inst:GetAttribute("Action") or "Show"
	if action == "Show" then
		-- starts hidden until unlocked
		for _, p in ipairs(allParts(inst)) do
			p:SetAttribute("OrigTransparency", p.Transparency)
			p.Transparency = 1
			p.CanCollide = false
		end
	end
	-- "Hide"/"Sink" targets start visible; nothing to do
end

function WorldService:Init(reg)
	registry = reg
	Notify = game:GetService("ReplicatedStorage").Remotes.Notify
	for _, inst in ipairs(CS:GetTagged("Unlockable")) do
		applyLockedState(inst)
	end
end

-- trouble-beacons: tall smoke columns over unrestored regions.
-- When the matching unlock lands, the column dies down and everyone hears about it.
local function clearBeacons(unlockId)
	for _, b in ipairs(CS:GetTagged("RegionBeacon")) do
		if b:GetAttribute("ClearOnUnlock") == unlockId and not b:GetAttribute("Cleared") then
			b:SetAttribute("Cleared", true)
			for _, d in ipairs(b:GetChildren()) do
				if d:IsA("ParticleEmitter") then d.Enabled = false end
				if d:IsA("PointLight") then
					TweenService:Create(d, TweenInfo.new(6), { Brightness = 0, Range = 0 }):Play()
				end
			end
			local text = b:GetAttribute("ClearText")
			if text then
				Notify:FireAllClients({ text = text, kind = "story" })
			end
		end
	end
end

function WorldService:IsUnlocked(unlockId)
	return applied[unlockId] == true
end

function WorldService:Unlock(unlockId, byPlayer)
	if applied[unlockId] then return end
	applied[unlockId] = true
	clearBeacons(unlockId)
	for _, inst in ipairs(CS:GetTagged("Unlockable")) do
		if inst:GetAttribute("UnlockId") == unlockId then
			applyToInstance(inst)
		end
	end
	if unlockId == "HydrantsLive" then
		for _, src in ipairs(CS:GetTagged("WaterSource")) do
			local hid = src:GetAttribute("HydrantId")
			if hid and string.sub(hid, 1, 9) == "Firehouse" then
				src:SetAttribute("Live", true)
			end
		end
	elseif unlockId == "FirehouseRestored" and registry.FireService then
		-- the guardian is at peace: its memory fires go out for good
		registry.FireService:ExtinguishAllMemoryFires()
	end
end

-- called when a player's data loads: re-apply everything they had earned
function WorldService:ApplyPlayerUnlocks(player)
	local data = registry.DataService:GetIfLoaded(player)
	if not data then return end
	for unlockId in pairs(data.unlocks) do
		WorldService:Unlock(unlockId, player)
	end
end

function WorldService:Start()
	local DataService = registry.DataService
	DataService.PlayerLoaded.Event:Connect(function(player)
		WorldService:ApplyPlayerUnlocks(player)
	end)
end

return WorldService

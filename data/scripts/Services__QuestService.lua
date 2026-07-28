-- QuestService: the main-story stage machine (stages defined in Shared.QuestDefs).
-- Progress is per-player and server-authoritative. Events flow in via Signal():
--   QuestService:Signal("FireOut:Camp_TutorialFire", player, position?)
-- When a position is provided, every other player within COOP_ASSIST_RADIUS whose
-- current stage wants the same key gets credit too (co-op without item stealing).
-- EVERY signal is recorded in data.counters even when it isn't the current
-- stage's trigger, and each stage auto-completes the moment it becomes current
-- if its trigger was already satisfied earlier — so quest steps can be done in
-- any order (e.g. grabbing a mitten before Mossmitt asks still counts).
-- Stages whose world condition is already satisfied (debris gone, valves solved)
-- auto-complete so late joiners and rejoining players can never get stuck.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.GameConfig)
local QuestDefs = require(RS.Shared.QuestDefs)

local QuestService = {}
local registry
local ObjectiveUpdate, QuestSync, Notify, Celebration, Credits

local function currentStage(data)
	return QuestDefs.Stages[data.stageIndex]
end

function QuestService:NeedsKey(player, key)
	local data = registry.DataService:GetIfLoaded(player)
	if not data then return false end
	local stage = currentStage(data)
	return stage ~= nil and stage.trigger.key == key
end

local function pushObjective(player, data)
	local stage = currentStage(data)
	if stage then
		local progress
		if stage.trigger.kind == "count" then
			data.counters = data.counters or {}
			progress = { n = data.counters[stage.trigger.key] or 0, total = stage.trigger.count }
		end
		ObjectiveUpdate:FireClient(player, {
			title = stage.title,
			objective = stage.objective,
			hint = stage.hint,
			region = stage.region,
			progress = progress,
			stageIndex = data.stageIndex,
			totalStages = #QuestDefs.Stages,
			completed = data.completed,
		})
	else
		ObjectiveUpdate:FireClient(player, {
			title = "Home at last",
			objective = "Explore, collect, and answer ember incidents around the restored city.",
			completed = true,
			stageIndex = data.stageIndex,
			totalStages = #QuestDefs.Stages,
		})
	end
end

local function pushQuestSync(player, data)
	QuestSync:FireClient(player, {
		stageIndex = data.stageIndex,
		counters = data.counters or {},
		questItems = data.questItems,
		completed = data.completed,
		collected = data.collected,
	})
end

local advance -- fwd decl

-- has this stage's trigger already been satisfied by recorded signals / world state?
local function stageSatisfied(data, stage)
	local key = stage.trigger.key
	data.counters = data.counters or {}
	local n = data.counters[key] or 0
	-- items already in the satchel count too (covers saves from before signals were recorded)
	if string.sub(key, 1, 8) == "Collect:" then
		n = math.max(n, (data.questItems and data.questItems[string.sub(key, 9)]) or 0)
	end
	if stage.trigger.kind == "count" then
		if n >= stage.trigger.count then return true end
	else
		if n >= 1 then return true end
	end
	-- world-state fallbacks (shared world already in the right shape)
	if string.sub(key, 1, 14) == "DebrisCleared:" then
		local debrisId = string.sub(key, 15)
		for _, inst in ipairs(game:GetService("CollectionService"):GetTagged("Debris")) do
			if inst:GetAttribute("DebrisId") == debrisId and inst.Parent then return false end
		end
		return true
	elseif key == "ValvePuzzleSolved" and registry.WorldService:IsUnlocked("HydrantsLive") then
		return true
	end
	return false
end

local function checkAutoComplete(player, data)
	-- chain through every already-satisfied stage (out-of-order play)
	local guard = 0
	local stage = currentStage(data)
	while stage and stageSatisfied(data, stage) and guard < 100 do
		guard += 1
		advance(player, data)
		stage = currentStage(data)
	end
end

advance = function(player, data)
	local stage = currentStage(data)
	if not stage then return end
	local done = stage.onComplete
	data.stageIndex += 1
	data.counters = data.counters or {}

	if done then
		if done.grantTool then registry.InventoryService:GrantTool(player, done.grantTool) end
		if done.sparks then registry.PlayerStateService:AddSparks(player, done.sparks, stage.title) end
		if done.badge then registry.PlayerStateService:AwardBadge(player, done.badge) end
		if done.unlock then
			data.unlocks[done.unlock] = true
			registry.WorldService:Unlock(done.unlock, player)
		end
		if done.notify then
			Notify:FireClient(player, { text = done.notify, kind = "story" })
		end
	end

	-- story finished? the crew throws a graduation ceremony (NPCService owns the
	-- scene: the training reveal, the helmet, then the credits roll)
	if data.stageIndex > #QuestDefs.Stages and not data.completed then
		data.completed = true
		if registry.NPCService and registry.NPCService.RunGraduation then
			registry.NPCService:RunGraduation(player)
		else
			Celebration:FireClient(player, { kind = "story", title = "You made it home!", detail = "The firehouse glows warm again." })
			Credits:FireClient(player, {})
		end
	end

	registry.DataService:MarkDirty(player)
	pushObjective(player, data)
	pushQuestSync(player, data)
end

local function credit(player, key)
	local data = registry.DataService:GetIfLoaded(player)
	if not data then return end
	-- record every signal, whether or not it's the current objective;
	-- satisfied stages then complete (and chain) the moment they come up
	data.counters = data.counters or {}
	data.counters[key] = (data.counters[key] or 0) + 1
	registry.DataService:MarkDirty(player)
	if registry.NPCService and registry.NPCService.RefreshPromptsFor then
		registry.NPCService:RefreshPromptsFor(player)
	end
	local stage = currentStage(data)
	if stage and stageSatisfied(data, stage) then
		checkAutoComplete(player, data)
	elseif stage and stage.trigger.key == key then
		pushObjective(player, data) -- live count progress (e.g. 2 / 3 found)
	end
end

function QuestService:Signal(key, player, position)
	credit(player, key)
	if position then
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				local char = other.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - position).Magnitude <= Config.COOP_ASSIST_RADIUS then
					credit(other, key)
				end
			end
		end
	end
end

-- quest item helpers (mittens, mementos, memories...) --------------------------
function QuestService:AddQuestItem(player, item, n)
	local data = registry.DataService:Get(player)
	if not data then return end
	data.questItems[item] = (data.questItems[item] or 0) + (n or 1)
	registry.DataService:MarkDirty(player)
	pushQuestSync(player, data)
end

function QuestService:CountQuestItem(player, item)
	local data = registry.DataService:GetIfLoaded(player)
	return data and (data.questItems[item] or 0) or 0
end

function QuestService:ConsumeQuestItems(player, item, n)
	local data = registry.DataService:GetIfLoaded(player)
	if not data then return false end
	if (data.questItems[item] or 0) < n then return false end
	data.questItems[item] -= n
	registry.DataService:MarkDirty(player)
	pushQuestSync(player, data)
	return true
end

-- how many times a signal key has been recorded for this player (any stage)
function QuestService:SignalCount(player, key)
	local data = registry.DataService:GetIfLoaded(player)
	if not data then return 0 end
	return (data.counters and data.counters[key]) or 0
end

function QuestService:HasSignalled(player, key)
	return QuestService:SignalCount(player, key) >= 1
end

function QuestService:GetStageIndex(player)
	local data = registry.DataService:GetIfLoaded(player)
	return data and data.stageIndex or 1
end

function QuestService:GetStageId(player)
	local data = registry.DataService:GetIfLoaded(player)
	if not data then return nil end
	local stage = currentStage(data)
	return stage and stage.id or "completed"
end

function QuestService:IsCompleted(player)
	local data = registry.DataService:GetIfLoaded(player)
	return data ~= nil and data.completed
end

function QuestService:PushAll(player)
	local data = registry.DataService:GetIfLoaded(player)
	if not data then return end
	pushObjective(player, data)
	pushQuestSync(player, data)
end

function QuestService:Init(reg)
	registry = reg
	ObjectiveUpdate = RS.Remotes.ObjectiveUpdate
	QuestSync = RS.Remotes.QuestSync
	Notify = RS.Remotes.Notify
	Celebration = RS.Remotes.Celebration
	Credits = RS.Remotes.Credits
end

function QuestService:Start()
	registry.DataService.PlayerLoaded.Event:Connect(function(player)
		local data = registry.DataService:GetIfLoaded(player)
		if not data then return end
		pushObjective(player, data)
		pushQuestSync(player, data)
		checkAutoComplete(player, data)
	end)
	-- client asks for a fresh payload (e.g. after respawn or UI reload)
	RS.Remotes.GetData.OnServerInvoke = function(player)
		local data = registry.DataService:Get(player)
		if not data then return nil end
		QuestService:PushAll(player)
		return {
			sparks = data.sparks,
			badges = data.badges,
			stageIndex = data.stageIndex,
			completed = data.completed,
			settings = data.settings,
			collected = data.collected,
			cosmetics = data.cosmetics,
		}
	end
end

return QuestService

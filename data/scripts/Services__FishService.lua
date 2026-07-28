-- FishService: the penguin-simulator layer. Every water body holds a school of
-- fish (tagged "FishSchool" anchors; all fish rendering/motion is client-side in
-- StarterPlayerScripts.FishLife for zero network cost). The server owns the
-- numbers: it validates each catch against the school anchor's position, keeps
-- the per-player fish count in questItems.Fish, and lets players eat a fish for
-- energy from the HUD. Lifetime catches are recorded as the "Catch:Fish" signal
-- so quests (the hungry statue!) can read them.

local CS = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(RS.Shared.GameConfig)

local FishService = {}
local registry
local Notify
local lastCatch = {} -- [player] = os.clock()

local FLAVOR = {
	"A silver flash — got it!",
	"Caught one! It wriggles happily into your satchel.",
	"The river gives, and Pip receives.",
	"Snap! Quick flippers win again.",
}

function FishService:Init(reg)
	registry = reg
	Notify = RS.Remotes.Notify
end

function FishService:GetFishCount(player)
	return registry.QuestService:CountQuestItem(player, "Fish")
end

function FishService:Start()
	RS.Remotes.FishCatch.OnServerEvent:Connect(function(player, anchor)
		if typeof(anchor) ~= "Instance" or not anchor:IsA("BasePart") then return end
		if not CS:HasTag(anchor, "FishSchool") then return end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local radius = anchor:GetAttribute("Radius") or 12
		if (root.Position - anchor.Position).Magnitude > radius + Config.FISH_CATCH_RANGE then return end
		local now = os.clock()
		if lastCatch[player] and now - lastCatch[player] < Config.FISH_CATCH_COOLDOWN then return end
		lastCatch[player] = now
		registry.QuestService:AddQuestItem(player, "Fish", 1)
		registry.QuestService:Signal("Catch:Fish", player)
		local total = registry.QuestService:CountQuestItem(player, "Fish")
		-- celebrate milestones, whisper occasionally; never spam every catch
		if total == 1 then
			if player:GetAttribute("FishEdible") then
				Notify:FireClient(player, { text = "First catch! Fish fill your energy — tap the \u{1F41F} counter to eat one.", kind = "good" })
			else
				Notify:FireClient(player, { text = "First catch! Pip tucks it away — something out there is very, very hungry…", kind = "good" })
			end
		elseif total % 25 == 0 then
			Notify:FireClient(player, { text = "\u{1F41F} " .. total .. " fish! A proper penguin haul.", kind = "good" })
		elseif math.random(6) == 1 then
			Notify:FireClient(player, { text = FLAVOR[math.random(#FLAVOR)], kind = "good" })
		end
	end)

	RS.Remotes.EatFish.OnServerEvent:Connect(function(player)
		-- eating unlocks once Prisma has been freed (the statue fed 100 fish)
		if not player:GetAttribute("FishEdible") then
			Notify:FireClient(player, { text = "Pip saves his catch. Somewhere, a stone belly rumbles for one hundred fish…", kind = "hint" })
			return
		end
		if registry.QuestService:ConsumeQuestItems(player, "Fish", 1) then
			registry.PlayerStateService:Eat(player, "Fish")
		else
			Notify:FireClient(player, { text = "No fish in the satchel — the river is full of them!", kind = "hint" })
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastCatch[player] = nil
	end)
end

return FishService

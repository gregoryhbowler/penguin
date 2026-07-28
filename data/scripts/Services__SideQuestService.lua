-- SideQuestService: the discovery-driven side quests. None of these appear in
-- the main objective card — the world hints at them (a too-hungry statue, an
-- empty garden bed, a rattling recycler) and curiosity does the rest. All are
-- completable in any order, any time.
--   HungryStatue tag : feed it 100 fish -> a rainbow Magellanic penguin wakes
--   GardenPlot tag   : plant collected seeds -> the bed blooms in stages
--   Recycler tag     : trade collected cans for Sparks (buy the Top Hat!)

local CS = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(RS.Shared.GameConfig)

local SideQuestService = {}
local registry
local Notify, Dialogue, Celebration

local RAINBOW = {
	Color3.fromRGB(214, 84, 76), Color3.fromRGB(224, 158, 82), Color3.fromRGB(226, 208, 110),
	Color3.fromRGB(120, 186, 118), Color3.fromRGB(96, 148, 208), Color3.fromRGB(150, 108, 190),
}

-- ============ the hungry statue ============
local startPrismaWander -- defined below (needs freeStatue's neighborhood)

local function freeStatue(statueModel)
	if statueModel:GetAttribute("Freed") then return end
	statueModel:SetAttribute("Freed", true)
	-- stone wakes: color blooms band by band, dust puffs, a soft light grows
	local parts = {}
	for _, d in ipairs(statueModel:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(parts, d) end
	end
	table.sort(parts, function(a, b) return a.Position.Y < b.Position.Y end)
	for i, p in ipairs(parts) do
		task.delay(i * 0.28, function()
			local target = p:GetAttribute("WakeColor")
			local mat = p:GetAttribute("WakeMaterial")
			TweenService:Create(p, TweenInfo.new(1.2), { Color = target or RAINBOW[(i - 1) % #RAINBOW + 1] }):Play()
			if mat then p.Material = Enum.Material[mat] end
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			pe.Rate = 0
			pe.Lifetime = NumberRange.new(0.8, 1.4)
			pe.Speed = NumberRange.new(1, 2.5)
			pe.Size = NumberSequence.new(0.45)
			pe.Color = ColorSequence.new(RAINBOW[(i - 1) % #RAINBOW + 1])
			pe.Parent = p
			pe:Emit(14)
			task.delay(2, function() pe:Destroy() end)
		end)
	end
	task.delay(#parts * 0.28 + 1, function()
		local head = statueModel:FindFirstChild("Head", true)
		if head then
			local li = Instance.new("PointLight")
			li.Color = Color3.fromRGB(255, 235, 200)
			li.Range = 14
			li.Brightness = 0.9
			li.Parent = head
		end
		statueModel:SetAttribute("AmbientStyle", "spirit")
	end)
end

local function onStatue(player, statueModel, promptPart)
	local QS = registry.QuestService
	local data = registry.DataService:Get(player)
	if not data then return end
	local have = QS:CountQuestItem(player, "Fish")
	if data.collected["Statue/fed"] then
		Dialogue:FireClient(player, { name = "Prisma", lines = {
			"The rainbow penguin bows, feathers shimmering like sun through spray.",
			"\"Full and free, little friend. The sea sings in my chest again — and it sings of you.\"",
		}, mood = "happy" })
		return
	end
	if have < Config.STATUE_FISH_REQUIRED then
		if statueModel:GetAttribute("Freed") then
			-- a friend already freed Prisma; this player keeps the old custom alive
			Dialogue:FireClient(player, { name = "Prisma", lines = {
				"The rainbow penguin tilts its head, eyes bright.",
				"\"A friend fed the stone and set me free — but the old custom stands: one hundred fish for a hundred years of luck!\"",
				string.format("\"You carry %d, little fisher. The river is generous. I can wait — old habits.\"", have),
			}, mood = "happy" })
		else
			Dialogue:FireClient(player, { name = "The Hungry Statue", lines = {
				"The stone penguin's beak hangs open. A voice grinds out, slow as tide against rock…",
				"\"Hungry… so, so hungry. I could eat ONE HUNDRED FISH.\"",
				string.format("\"You carry %d. The river is generous, little fisher. I can wait. Stone is patient.\"", have),
			}, mood = "mysterious" })
		end
		return
	end
	if not QS:ConsumeQuestItems(player, "Fish", Config.STATUE_FISH_REQUIRED) then return end
	data.collected["Statue/fed"] = true
	registry.DataService:MarkDirty(player)
	player:SetAttribute("FishEdible", true) -- Prisma teaches Pip that fish are food
	QS:Signal("StatueFreed", player, promptPart.Position)
	registry.PlayerStateService:AddSparks(player, 150, "freeing Prisma")
	registry.PlayerStateService:AwardBadge(player, "Friend of Stone")
	Dialogue:FireClient(player, { name = "The Hungry Statue", lines = {
		"One hundred fish vanish in a blur of beak and gratitude.",
		"The stone CRACKS — color floods up from the ground like dawn climbing a cliff!",
		"\"FREE! Oh, taste the wind! I am Prisma, penguin of the painted tide — and you, small warden, are magnificent.\"",
		"\"A gift, fisher: eat your catch! Fresh fish is the finest fuel a penguin has. Tap your fish counter any time.\"",
	}, mood = "happy" })
	Celebration:FireClient(player, { kind = "side", title = "Prisma is free!", detail = "The rainbow Magellanic penguin thanks you." })
	freeStatue(statueModel)
	task.delay(#RAINBOW * 0.28 + 4, function()
		if statueModel.Parent then startPrismaWander(statueModel) end
	end)
end

-- ============ Prisma's wander cycle ============
-- Once freed, Prisma lives a loop: hop off the plinth, patter along the pier,
-- waddle up the Great Bridge, spring off the diving board with a flip, splash,
-- swim home, climb back onto the plinth for a long sunny rest. All server-side
-- pivots (the statue rig is anchored parts), surface-following like NPC patrols.
startPrismaWander = function(statueModel)
	if statueModel:GetAttribute("Wandering") then return end
	statueModel:SetAttribute("Wandering", true)

	-- gather the penguin (everything but plinth) into a pivotable sub-model
	local bird = Instance.new("Model")
	bird.Name = "Prisma"
	for _, d in ipairs(statueModel:GetChildren()) do
		if d:IsA("BasePart") and d.Name ~= "Plinth" and d.Name ~= "PlinthMoss" then
			d.Parent = bird
		end
	end
	bird.PrimaryPart = bird:FindFirstChild("Body")
	bird.Parent = statueModel

	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Include
	groundParams.RespectCanCollide = true
	-- cast from just above the bird's current height, never from the sky: otherwise
	-- the ray lands on suspension-cable tops / lamp heads and Prisma sky-walks them
	local function surfaceY(x, z, fromY)
		groundParams.FilterDescendantsInstances = { workspace.Terrain, workspace.World }
		local origin = (fromY or 60) + 3
		local hit = workspace:Raycast(Vector3.new(x, origin, z), Vector3.new(0, -120, 0), groundParams)
		return hit and hit.Position.Y or 2
	end
	local function pivotLift()
		local bboxCF, bboxSize = bird:GetBoundingBox()
		return bird:GetPivot().Position.Y - (bboxCF.Position.Y - bboxSize.Y / 2)
	end

	local function splashAt(pos)
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.Transparency = 1
		holder.Size = Vector3.new(1, 1, 1)
		holder.Position = pos
		holder.Parent = workspace
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Rate = 0
		pe.Lifetime = NumberRange.new(0.5, 0.9)
		pe.Speed = NumberRange.new(5, 9)
		pe.SpreadAngle = Vector2.new(70, 70)
		pe.Size = NumberSequence.new(0.7)
		pe.Color = ColorSequence.new(Color3.fromRGB(170, 210, 235))
		pe.Parent = holder
		pe:Emit(24)
		task.delay(2, function() holder:Destroy() end)
	end

	-- move modes ---------------------------------------------------------
	local function walkTo(x, z, speed, bob)
		local from = bird:GetPivot().Position
		local dist = (Vector3.new(x, 0, z) - Vector3.new(from.X, 0, from.Z)).Magnitude
		if dist < 0.5 then return end
		local lift = pivotLift()
		local look = CFrame.lookAt(Vector3.new(from.X, 0, from.Z), Vector3.new(x, 0, z))
		local dur = dist / speed
		local t0 = os.clock()
		local lastY = from.Y - lift
		while os.clock() - t0 < dur do
			if not bird.Parent then return end
			local a = math.clamp((os.clock() - t0) / dur, 0, 1)
			local px = from.X + (x - from.X) * a
			local pz = from.Z + (z - from.Z) * a
			local wob = (bob ~= false) and math.abs(math.sin(a * dist * 1.6)) * 0.18 or 0
			lastY = surfaceY(px, pz, lastY)
			bird:PivotTo(CFrame.new(px, lastY + lift + wob, pz) * look.Rotation)
			task.wait(0.06)
		end
	end
	local function diveTo(x, y, z, dur, flips)
		local from = bird:GetPivot().Position
		local look = CFrame.lookAt(Vector3.new(from.X, 0, from.Z), Vector3.new(x, 0, z))
		local t0 = os.clock()
		while os.clock() - t0 < dur do
			if not bird.Parent then return end
			local a = math.clamp((os.clock() - t0) / dur, 0, 1)
			local pos = Vector3.new(from.X + (x - from.X) * a, 0, from.Z + (z - from.Z) * a)
			local arc = from.Y + (y - from.Y) * a + math.sin(a * math.pi) * 6
			local spin = CFrame.Angles(-a * math.pi * 2 * flips, 0, 0)
			bird:PivotTo(CFrame.new(pos.X, arc, pos.Z) * look.Rotation * spin)
			task.wait(0.05)
		end
		splashAt(Vector3.new(x, y + 0.5, z))
	end
	local function swimTo(x, z, speed)
		local from = bird:GetPivot().Position
		local dist = (Vector3.new(x, 0, z) - Vector3.new(from.X, 0, from.Z)).Magnitude
		local look = CFrame.lookAt(Vector3.new(from.X, 0, from.Z), Vector3.new(x, 0, z))
		local dur = dist / speed
		local t0 = os.clock()
		while os.clock() - t0 < dur do
			if not bird.Parent then return end
			local a = math.clamp((os.clock() - t0) / dur, 0, 1)
			local px = from.X + (x - from.X) * a
			local pz = from.Z + (z - from.Z) * a
			local bob = math.sin(os.clock() * 3) * 0.15
			-- belly-glide: pitched nose-down a touch, riding the surface
			bird:PivotTo(CFrame.new(px, 1.1 + bob, pz) * look.Rotation * CFrame.Angles(math.rad(-78), 0, 0))
			task.wait(0.06)
		end
	end
	local function hopTo(x, y, z, dur)
		local from = bird:GetPivot().Position
		local look = CFrame.lookAt(Vector3.new(from.X, 0, from.Z), Vector3.new(x, 0, z))
		local t0 = os.clock()
		while os.clock() - t0 < dur do
			if not bird.Parent then return end
			local a = math.clamp((os.clock() - t0) / dur, 0, 1)
			local pos = Vector3.new(from.X + (x - from.X) * a, from.Y + (y - from.Y) * a + math.sin(a * math.pi) * 1.6, from.Z + (z - from.Z) * a)
			bird:PivotTo(CFrame.new(pos) * look.Rotation)
			task.wait(0.05)
		end
		bird:PivotTo(CFrame.new(x, y, z) * look.Rotation)
	end

	task.spawn(function()
		local plinthTopPivot = bird:GetPivot() -- home pose on the plinth
		task.wait(6) -- let the wake ceremony finish
		while bird.Parent do
			statueModel:SetAttribute("Patrolling", true)
			-- hop down to the boardwalk
			hopTo(428, surfaceY(428, 130, 8) + pivotLift(), 130, 0.7)
			-- patter out along the pier and admire the water
			walkTo(428, 121, 5)
			walkTo(466, 120, 5)
			statueModel:SetAttribute("Patrolling", false)
			task.wait(4)
			statueModel:SetAttribute("Patrolling", true)
			-- back in, north along the boardwalk, up the Great Bridge
			walkTo(430, 120, 5)
			walkTo(426, 60, 5.5)
			walkTo(426, 24, 5.5)
			walkTo(400, 21, 5)
			walkTo(388, 10, 5)   -- foot of the west approach
			walkTo(421, 10, 4.5) -- up the ramp (surface-following)
			walkTo(468, 10, 5)   -- along the deck
			walkTo(470, 14, 4)
			walkTo(470, 23.5, 3, false) -- out onto the diving board
			statueModel:SetAttribute("Patrolling", false)
			task.wait(2.5)
			statueModel:SetAttribute("Patrolling", true)
			-- the dive: one full front flip, splash, glide home
			diveTo(470, 1.1, 36, 1.6, 1)
			swimTo(462, 100, 7)
			swimTo(437, 126, 7)
			-- hop out and settle back on the plinth
			hopTo(428, surfaceY(428, 129, 8) + pivotLift(), 129, 0.8)
			walkTo(431, 130, 4)
			hopTo(plinthTopPivot.Position.X, plinthTopPivot.Position.Y, plinthTopPivot.Position.Z, 0.8)
			bird:PivotTo(plinthTopPivot)
			statueModel:SetAttribute("Patrolling", false)
			task.wait(18 + math.random() * 20)
		end
	end)
end

-- ============ the community garden ============
local function gardenStageCount(plot)
	return math.clamp(math.floor((plot:GetAttribute("Planted") or 0) / 4), 0, 5)
end

local function updateGardenVisual(plot)
	local stages = gardenStageCount(plot)
	local model = plot.Parent
	for i = 1, 5 do
		local cluster = model and model:FindFirstChild("BloomStage" .. i)
		if cluster then
			for _, d in ipairs(cluster:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Transparency = (i <= stages) and 0 or 1
				end
			end
		end
	end
end

local function onGarden(player, plot)
	local QS = registry.QuestService
	local carrying = QS:CountQuestItem(player, "Seed")
	local planted = QS:SignalCount(player, "Plant:Seed")
	if carrying == 0 then
		if planted >= Config.GARDEN_SEEDS_REQUIRED then
			Notify:FireClient(player, { text = "The garden hums with bees and color. Your work, gardener.", kind = "story" })
		elseif planted > 0 then
			Notify:FireClient(player, { text = planted .. " seeds sprouting. More seeds glint around the city and woods…", kind = "hint" })
		else
			Notify:FireClient(player, { text = "A bare garden bed, turned and waiting. Seeds must be scattered around the city…", kind = "hint" })
		end
		return
	end
	QS:ConsumeQuestItems(player, "Seed", carrying)
	for i = 1, carrying do
		QS:Signal("Plant:Seed", player)
	end
	plot:SetAttribute("Planted", math.max(plot:GetAttribute("Planted") or 0, QS:SignalCount(player, "Plant:Seed")))
	updateGardenVisual(plot)
	local total = QS:SignalCount(player, "Plant:Seed")
	Notify:FireClient(player, { text = string.format("Planted %d seed%s! (%d of %d)", carrying, carrying == 1 and "" or "s", math.min(total, Config.GARDEN_SEEDS_REQUIRED), Config.GARDEN_SEEDS_REQUIRED), kind = "good" })
	if total >= Config.GARDEN_SEEDS_REQUIRED then
		local data = registry.DataService:Get(player)
		if data and not data.collected["Garden/bloomed"] then
			data.collected["Garden/bloomed"] = true
			registry.DataService:MarkDirty(player)
			registry.PlayerStateService:AddSparks(player, 100, "the city garden")
			registry.PlayerStateService:AwardBadge(player, "City Gardener")
			QS:Signal("GardenBloomed", player, plot.Position)
			Celebration:FireClient(player, { kind = "side", title = "The garden blooms!", detail = "Twenty seeds, one small meadow in the city." })
		end
	end
end

-- ============ the recycler ============
local function onRecycler(player, bin)
	local QS = registry.QuestService
	local carrying = QS:CountQuestItem(player, "Can")
	if carrying == 0 then
		local returned = QS:SignalCount(player, "Recycle:Can")
		if returned > 0 then
			Notify:FireClient(player, { text = "CLUNK-whirr. \"" .. returned .. " cans recycled! Marla's kiosk sells a rather dapper top hat, you know.\"", kind = "hint" })
		else
			Notify:FireClient(player, { text = "A cheery bin whirrs: \"Feed me tin cans! 5 Sparks a can — the city stays clean, you get rich!\"", kind = "hint" })
		end
		return
	end
	QS:ConsumeQuestItems(player, "Can", carrying)
	for i = 1, carrying do QS:Signal("Recycle:Can", player) end
	registry.PlayerStateService:AddSparks(player, carrying * Config.CAN_SPARKS, "recycling " .. carrying .. " cans")
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.6, 1)
	pe.Speed = NumberRange.new(2, 4)
	pe.Size = NumberSequence.new(0.4)
	pe.Color = ColorSequence.new(Color3.fromRGB(150, 210, 160))
	pe.Parent = bin
	pe:Emit(12)
	task.delay(1.5, function() pe:Destroy() end)
	local total = QS:SignalCount(player, "Recycle:Can")
	if total >= 15 then
		local data = registry.DataService:Get(player)
		if data and not data.collected["Recycler/binfriend"] then
			data.collected["Recycler/binfriend"] = true
			registry.DataService:MarkDirty(player)
			registry.PlayerStateService:AwardBadge(player, "Bin Friend")
		end
	end
end

function SideQuestService:Init(reg)
	registry = reg
	Notify = RS.Remotes.Notify
	Dialogue = RS.Remotes.Dialogue
	Celebration = RS.Remotes.Celebration
end

function SideQuestService:Start()
	for _, part in ipairs(CS:GetTagged("HungryStatue")) do
		local model = part.Parent
		local prompt = registry.InteractionService:AddPrompt(part, "Offer Fish", "A stone penguin", 0.8)
		prompt.MaxActivationDistance = 10
		prompt.Triggered:Connect(function(player)
			local ok, err = pcall(onStatue, player, model, part)
			if not ok then warn("[SideQuestService] statue: " .. tostring(err)) end
		end)
	end
	for _, plot in ipairs(CS:GetTagged("GardenPlot")) do
		local prompt = registry.InteractionService:AddPrompt(plot, "Plant Seeds", "Garden Bed", 0.6)
		prompt.MaxActivationDistance = 10
		prompt.Triggered:Connect(function(player)
			local ok, err = pcall(onGarden, player, plot)
			if not ok then warn("[SideQuestService] garden: " .. tostring(err)) end
		end)
		updateGardenVisual(plot)
	end
	for _, bin in ipairs(CS:GetTagged("Recycler")) do
		local prompt = registry.InteractionService:AddPrompt(bin, "Recycle Cans", "Rattly the Recycler", 0.5)
		prompt.MaxActivationDistance = 10
		prompt.Triggered:Connect(function(player)
			local ok, err = pcall(onRecycler, player, bin)
			if not ok then warn("[SideQuestService] recycler: " .. tostring(err)) end
		end)
	end
	-- anything marked HiddenUntilCrash starts invisible and unpromptable
	for _, part in ipairs(CS:GetTagged("Pickup")) do
		if part:GetAttribute("HiddenUntilCrash") then
			part.Transparency = 1
			local prompt = part:FindFirstChildOfClass("ProximityPrompt")
			if prompt then prompt.Enabled = false end
			local pe = part:FindFirstChildOfClass("ParticleEmitter")
			if pe then pe.Enabled = false end
		end
	end

	-- crash mounds: skid into them fast enough and they burst, revealing a cache
	for _, mound in ipairs(CS:GetTagged("CrashMound")) do
		local burst = false
		mound.Touched:Connect(function(hit)
			if burst then return end
			local char = hit.Parent
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hum then return end
			local root = char:FindFirstChild("HumanoidRootPart")
			if not root or root.AssemblyLinearVelocity.Magnitude < 12 then return end
			burst = true
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
			pe.Rate = 0
			pe.Lifetime = NumberRange.new(0.7, 1.2)
			pe.Speed = NumberRange.new(4, 8)
			pe.Size = NumberSequence.new(1.4)
			pe.Color = ColorSequence.new(Color3.fromRGB(240, 245, 250))
			pe.Parent = mound
			pe:Emit(30)
			local player = game:GetService("Players"):GetPlayerFromCharacter(char)
			if player then
				Notify:FireClient(player, { text = "POOF! Something was hiding inside the snow mound…", kind = "good" })
			end
			task.delay(0.25, function()
				mound.Transparency = 1
				mound.CanCollide = false
				-- wake the cache hidden inside
				for _, sib in ipairs(mound.Parent:GetChildren()) do
					if sib:GetAttribute("HiddenUntilCrash") then
						sib.Transparency = 0
						local prompt = sib:FindFirstChildOfClass("ProximityPrompt")
						if prompt then prompt.Enabled = true end
						local pe2 = sib:FindFirstChildOfClass("ParticleEmitter")
						if pe2 then pe2.Enabled = true end
					end
				end
			end)
			task.delay(2, function() pe:Destroy() end)
		end)
	end

	-- the sleeping stone turtle: stand still on its shell and it wakes
	for _, shell in ipairs(CS:GetTagged("SleepyTurtle")) do
		task.spawn(function()
			local dwell = {} -- [player] = seconds so far
			local woken = false
			while shell.Parent do
				task.wait(0.5)
				for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					local onTop = false
					if root then
						local rel = shell.CFrame:PointToObjectSpace(root.Position)
						onTop = math.abs(rel.X) < shell.Size.X / 2 and math.abs(rel.Z) < shell.Size.Z / 2
							and rel.Y > 0 and rel.Y < shell.Size.Y
					end
					if onTop then
						dwell[player] = (dwell[player] or 0) + 0.5
						if dwell[player] >= 4 then
							dwell[player] = -30 -- long refractory
							local model = shell.Parent
							if not woken then
								woken = true
								for _, d in ipairs(model:GetChildren()) do
									if d.Name == "TurtleHead" or d.Name == "TurtleEye" then
										TweenService:Create(d, TweenInfo.new(1.4), { Transparency = 0 }):Play()
									end
								end
								-- a slow, seismic shrug
								local home = shell.CFrame
								TweenService:Create(shell, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true), { CFrame = home * CFrame.new(0, 0.5, 0) * CFrame.Angles(math.rad(2), 0, 0) }):Play()
							end
							local data = registry.DataService:GetIfLoaded(player)
							if data and not data.collected["Turtle/woken"] then
								data.collected["Turtle/woken"] = true
								registry.DataService:MarkDirty(player)
								registry.PlayerStateService:AddSparks(player, 40, "waking the oldest friend")
								registry.PlayerStateService:AwardBadge(player, "Patient Friend")
								Dialogue:FireClient(player, { name = "The Oldest Turtle", lines = {
									"The boulder beneath your feet… breathes. Two green-lit eyes blink open, slow as seasons.",
									"\"Mm. I was dreaming of the pool when it was young. You stand very politely, small one.\"",
									"\"Few wait long enough to meet me. Patience is its own little magic.\" The eyes close again, content.",
								}, mood = "mysterious" })
							elseif data then
								Notify:FireClient(player, { text = "The old turtle rumbles fondly beneath your feet.", kind = "story" })
							end
						end
					elseif dwell[player] and dwell[player] > 0 then
						dwell[player] = 0
					end
				end
			end
		end)
	end

	-- returning players: restore garden visuals & statue state
	registry.DataService.PlayerLoaded.Event:Connect(function(player)
		local QS = registry.QuestService
		for _, plot in ipairs(CS:GetTagged("GardenPlot")) do
			plot:SetAttribute("Planted", math.max(plot:GetAttribute("Planted") or 0, QS:SignalCount(player, "Plant:Seed")))
			updateGardenVisual(plot)
		end
		local data = registry.DataService:GetIfLoaded(player)
		if data and data.collected["Statue/fed"] then
			player:SetAttribute("FishEdible", true)
			for _, part in ipairs(CS:GetTagged("HungryStatue")) do
				freeStatue(part.Parent)
				task.delay(4, function()
					if part.Parent then startPrismaWander(part.Parent) end
				end)
			end
		end
	end)
end

return SideQuestService

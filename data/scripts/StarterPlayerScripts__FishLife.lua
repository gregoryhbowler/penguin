-- FishLife: client-side fish for every water body. Each "FishSchool" anchor
-- spawns a school rendered and animated locally (zero network traffic). Fish
-- wander, scatter from the swimming penguin, and can be caught by getting
-- close — the catch itself is validated server-side via Remotes.FishCatch.

local CS = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local FishCatch = RS.Remotes.FishCatch

local FISH_COLORS = {
	Color3.fromRGB(148, 172, 196), Color3.fromRGB(126, 158, 168),
	Color3.fromRGB(164, 180, 172), Color3.fromRGB(136, 150, 186),
}
local FLEE_RADIUS = 7
local CATCH_RADIUS = 3.2
local CATCH_COOLDOWN = 1.0

local folder = Instance.new("Folder")
folder.Name = "LocalFish"
folder.Parent = workspace

local fishes = {}
local lastCatchAt = 0

local function makeFish(anchor)
	local radius = anchor:GetAttribute("Radius") or 12
	local scale = 0.8 + math.random() * 0.5
	local model = Instance.new("Model")
	model.Name = "Fish"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(0.42, 0.36, 1.05) * scale
	body.Color = FISH_COLORS[math.random(#FISH_COLORS)]
	body.Material = Enum.Material.SmoothPlastic
	body.Reflectance = 0.08
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	local mesh = Instance.new("SpecialMesh") mesh.MeshType = Enum.MeshType.Sphere mesh.Parent = body
	body.Parent = model
	local tail = Instance.new("WedgePart")
	tail.Name = "Tail"
	tail.Size = Vector3.new(0.1, 0.34, 0.5) * scale
	tail.Color = body.Color
	tail.Material = Enum.Material.SmoothPlastic
	tail.Anchored = true
	tail.CanCollide = false
	tail.CanQuery = false
	tail.Parent = model
	model.PrimaryPart = body
	model.Parent = folder
	local a = math.random() * math.pi * 2
	local r = math.random() * radius * 0.8
	return {
		anchor = anchor,
		model = model,
		body = body,
		tail = tail,
		pos = anchor.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r),
		heading = math.random() * math.pi * 2,
		speed = 2 + math.random() * 1.5,
		wiggle = math.random() * math.pi * 2,
		radius = radius,
		respawnAt = nil,
		scale = scale,
	}
end

for _, anchor in ipairs(CS:GetTagged("FishSchool")) do
	local count = anchor:GetAttribute("Count") or 6
	for i = 1, count do
		table.insert(fishes, makeFish(anchor))
	end
end
CS:GetInstanceAddedSignal("FishSchool"):Connect(function(anchor)
	local count = anchor:GetAttribute("Count") or 6
	for i = 1, count do
		table.insert(fishes, makeFish(anchor))
	end
end)

local function catchFX(fish, rootPos)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.5, 0.9)
	pe.Speed = NumberRange.new(2, 5)
	pe.Size = NumberSequence.new(0.5)
	pe.Color = ColorSequence.new(Color3.fromRGB(200, 226, 240))
	pe.Parent = fish.body
	pe:Emit(16)
	-- dart toward the penguin's beak, then vanish
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < 0.28 do
			local a = (os.clock() - t0) / 0.28
			fish.body.CFrame = fish.body.CFrame:Lerp(CFrame.new(rootPos + Vector3.new(0, 0.4, 0)), a)
			fish.body.Size = Vector3.new(0.42, 0.36, 1.05) * fish.scale * (1 - a * 0.7)
			task.wait()
		end
		fish.body.Transparency = 1
		fish.tail.Transparency = 1
		fish.body.Size = Vector3.new(0.42, 0.36, 1.05) * fish.scale
	end)
end

RunService.Heartbeat:Connect(function(dt)
	local char = localPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local now = os.clock()
	for _, fish in ipairs(fishes) do
		if not fish.model.Parent then continue end
		if fish.respawnAt then
			if now >= fish.respawnAt then
				fish.respawnAt = nil
				local a = math.random() * math.pi * 2
				local r = math.random() * fish.radius * 0.8
				fish.pos = fish.anchor.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				fish.body.Transparency = 0
				fish.tail.Transparency = 0
			end
			continue
		end
		fish.wiggle += dt * 9
		-- steering: gentle wander + home pull + flee the penguin
		local turn = (math.noise(fish.wiggle * 0.15, fish.pos.X * 0.05) or 0) * 2.4 * dt
		local fleeing = false
		if root then
			local away = fish.pos - root.Position
			local dist = away.Magnitude
			if dist < FLEE_RADIUS then
				fleeing = true
				local desired = math.atan2(away.X, away.Z)
				local diff = math.atan2(math.sin(desired - fish.heading), math.cos(desired - fish.heading))
				turn = math.clamp(diff, -3.5 * dt, 3.5 * dt)
			end
			-- the catch: close enough while the fish is still in reach
			if dist < CATCH_RADIUS and now - lastCatchAt > CATCH_COOLDOWN and hum and hum.Health > 0 then
				lastCatchAt = now
				fish.respawnAt = now + 14 + math.random() * 12
				catchFX(fish, root.Position)
				FishCatch:FireServer(fish.anchor)
				continue
			end
		end
		local fromHome = fish.pos - fish.anchor.Position
		if fromHome.Magnitude > fish.radius then
			local desired = math.atan2(-fromHome.X, -fromHome.Z)
			local diff = math.atan2(math.sin(desired - fish.heading), math.cos(desired - fish.heading))
			turn = math.clamp(diff, -2.5 * dt, 2.5 * dt)
		end
		fish.heading += turn
		local speed = fish.speed * (fleeing and 2.6 or 1)
		local dir = Vector3.new(math.sin(fish.heading), 0, math.cos(fish.heading))
		fish.pos += dir * speed * dt
		local bob = math.sin(fish.wiggle * 0.5) * 0.15
		local cf = CFrame.lookAt(fish.pos + Vector3.new(0, bob, 0), fish.pos + dir + Vector3.new(0, bob, 0))
			* CFrame.Angles(0, math.sin(fish.wiggle) * 0.12, 0)
		fish.body.CFrame = cf
		fish.tail.CFrame = cf * CFrame.new(0, 0, fish.body.Size.Z / 2 + fish.tail.Size.Z / 2 - 0.05)
			* CFrame.Angles(0, math.sin(fish.wiggle) * 0.5, 0)
	end
end)

-- WonderSprites: small unnamed spirits, purely for wonder. Rendered locally at
-- tagged "ShySpot" markers. Kodama-style sprites sway beside trees and vanish
-- with a soft click when approached; the river loon floats and dives. No
-- rewards, no prompts, no quest log — seeing one is the whole prize.

local CS = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

local folder = Instance.new("Folder")
folder.Name = "LocalWonder"
folder.Parent = workspace

local sprites = {}

local function part(props)
	local p = Instance.new("Part")
	p.Name = props.name or "Part"
	p.Size = props.size
	p.CFrame = props.cf
	p.Color = props.color
	p.Material = props.mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = props.tr or 0
	if props.ball then local m = Instance.new("SpecialMesh") m.MeshType = Enum.MeshType.Sphere m.Parent = p end
	p.Parent = props.parent
	return p
end

local function buildKodama(cf, parent)
	local m = Instance.new("Model") m.Name = "Kodama" m.Parent = parent
	local pale = Color3.fromRGB(226, 232, 224)
	part{ name="Body", size=Vector3.new(0.8, 1.1, 0.7), cf=cf*CFrame.new(0, 0.55, 0), color=pale, tr=0.15, ball=true, parent=m }
	local head = part{ name="Head", size=Vector3.new(0.7, 0.75, 0.65), cf=cf*CFrame.new(0, 1.4, 0)*CFrame.Angles(0, 0, math.rad(10)), color=pale, tr=0.1, ball=true, parent=m }
	part{ name="EyeL", size=Vector3.new(0.14, 0.2, 0.06), cf=cf*CFrame.new(-0.16, 1.45, -0.3), color=Color3.fromRGB(40, 46, 44), parent=m }
	part{ name="EyeR", size=Vector3.new(0.12, 0.14, 0.06), cf=cf*CFrame.new(0.17, 1.4, -0.3), color=Color3.fromRGB(40, 46, 44), parent=m }
	part{ name="Mouth", size=Vector3.new(0.1, 0.12, 0.06), cf=cf*CFrame.new(0.02, 1.2, -0.31), color=Color3.fromRGB(40, 46, 44), parent=m }
	return m
end

local function buildLoon(cf, parent)
	local m = Instance.new("Model") m.Name = "Loon" m.Parent = parent
	local slate = Color3.fromRGB(70, 80, 92)
	part{ name="Body", size=Vector3.new(1.1, 0.8, 2.0), cf=cf*CFrame.new(0, 0.3, 0), color=slate, ball=true, parent=m }
	part{ name="Neck", size=Vector3.new(0.3, 0.9, 0.3), cf=cf*CFrame.new(0, 0.95, -0.75), color=slate, parent=m }
	local head = part{ name="Head", size=Vector3.new(0.45, 0.4, 0.6), cf=cf*CFrame.new(0, 1.45, -0.85), color=slate, ball=true, parent=m }
	part{ name="Beak", size=Vector3.new(0.12, 0.1, 0.5), cf=cf*CFrame.new(0, 1.45, -1.35), color=Color3.fromRGB(200, 190, 160), parent=m }
	part{ name="Speckles", size=Vector3.new(1.12, 0.4, 1.2), cf=cf*CFrame.new(0, 0.5, 0.2), color=Color3.fromRGB(210, 216, 220), tr=0.4, ball=true, parent=m }
	return m
end

local spawned = {}
local function addSpot(spotMarker)
	if spawned[spotMarker] then return end
	spawned[spotMarker] = true
	local style = spotMarker:GetAttribute("Style") or "kodama"
	local cf = CFrame.new(spotMarker.Position)
	local model = (style == "loon") and buildLoon(cf, folder) or buildKodama(cf, folder)
	table.insert(sprites, {
		style = style,
		home = spotMarker.Position,
		model = model,
		visible = true,
		hiddenUntil = 0,
		phase = math.random() * math.pi * 2,
		offset = Vector3.zero,
	})
end
for _, spotMarker in ipairs(CS:GetTagged("ShySpot")) do
	addSpot(spotMarker)
end
-- spots stream in later under StreamingEnabled
CS:GetInstanceAddedSignal("ShySpot"):Connect(addSpot)

local function setVisible(sprite, on, instant)
	sprite.visible = on
	for _, d in ipairs(sprite.model:GetDescendants()) do
		if d:IsA("BasePart") then
			local base = (d.Name == "Body" or d.Name == "Head") and (sprite.style == "kodama" and 0.12 or 0) or 0
			if instant then
				d.Transparency = on and base or 1
			else
				TweenService:Create(d, TweenInfo.new(0.5), { Transparency = on and base or 1 }):Play()
			end
		end
	end
end

local function poof(sprite)
	local head = sprite.model:FindFirstChild("Head") or sprite.model:FindFirstChild("Body")
	if head then
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Rate = 0
		pe.Lifetime = NumberRange.new(0.6, 1.1)
		pe.Speed = NumberRange.new(1, 2.5)
		pe.Size = NumberSequence.new(0.35)
		pe.Color = ColorSequence.new(Color3.fromRGB(214, 236, 210))
		pe.Parent = head
		pe:Emit(12)
		task.delay(1.5, function() pe:Destroy() end)
	end
end

RunService.Heartbeat:Connect(function(dt)
	local char = localPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local now = os.clock()
	for _, sprite in ipairs(sprites) do
		sprite.phase += dt
		if not sprite.visible then
			if now >= sprite.hiddenUntil then
				-- reappear somewhere a few steps away
				local a = math.random() * math.pi * 2
				local r = (sprite.style == "loon") and (6 + math.random() * 14) or (3 + math.random() * 6)
				sprite.offset = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				setVisible(sprite, true)
			end
			continue
		end
		local pos = sprite.home + sprite.offset
		if root and (root.Position - pos).Magnitude < (sprite.style == "loon" and 15 or 11) then
			-- too close! vanish (dive, for the loon)
			poof(sprite)
			setVisible(sprite, false)
			sprite.hiddenUntil = now + 18 + math.random() * 30
			continue
		end
		-- idle life: sway / bob; the loon drifts a slow circle
		if sprite.style == "loon" then
			local drift = CFrame.new(math.cos(sprite.phase * 0.12) * 3, math.sin(sprite.phase * 0.8) * 0.12, math.sin(sprite.phase * 0.12) * 3)
			sprite.model:PivotTo(CFrame.new(pos) * drift * CFrame.Angles(0, -sprite.phase * 0.12, math.rad(math.sin(sprite.phase * 0.7) * 2)))
		else
			sprite.model:PivotTo(CFrame.new(pos + Vector3.new(0, math.sin(sprite.phase * 1.4) * 0.06, 0))
				* CFrame.Angles(0, math.sin(sprite.phase * 0.23) * 0.5, math.rad(math.sin(sprite.phase * 1.1) * 4)))
		end
	end
end)

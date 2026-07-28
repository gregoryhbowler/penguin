-- NPCService: builds every character and spirit at its tagged "NPCSpot" marker,
-- owns their dialogue and quest interactions, and performs their visual
-- transformations when helped. All resolutions are nonviolent by design.
-- Dialogue is short and child-readable; lines live in the DEFS table below.

local CS = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NPCService = {}
local registry
local Dialogue, Notify, GuardianScene
local npcs = {}   -- [npcId] = { model = Model, spot = Part, def = def }

-- ============ tiny model kit ============
local function mp(o)
	local p = Instance.new("Part")
	p.Name = o.name or "Part"
	p.Size = o.size
	p.CFrame = o.cf
	p.Color = o.color
	p.Material = o.mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = o.tr or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.ball then
		local m = Instance.new("SpecialMesh") m.MeshType = Enum.MeshType.Sphere m.Parent = p
	end
	p.Parent = o.parent
	return p
end

local function nameTag(model, displayName, color)
	local head = model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
	if not head then return end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 130, 0, 28)
	bb.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y / 2 + 1.6, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 60
	bb.Parent = head
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = displayName
	tl.Font = Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.TextColor3 = color or Color3.fromRGB(255, 245, 220)
	tl.TextStrokeTransparency = 0.4
	tl.Parent = bb
end

local function glow(parent, color, range, brightness)
	local li = Instance.new("PointLight")
	li.Color = color
	li.Range = range or 10
	li.Brightness = brightness or 0.8
	li.Parent = parent
	return li
end

local function wisps(parent, color, rate, size)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = rate or 3
	pe.Lifetime = NumberRange.new(1.2, 2)
	pe.Speed = NumberRange.new(0.6, 1.4)
	pe.Size = NumberSequence.new(size or 0.5)
	pe.Color = ColorSequence.new(color)
	pe.Parent = parent
	return pe
end

local function happyBurst(part, color)
	local pe = wisps(part, color or Color3.fromRGB(255, 230, 150), 0, 0.7)
	pe:Emit(26)
	task.delay(2.5, function() pe:Destroy() end)
end

-- ============ model builders ============
local function buildCat(cf, parent)
	local m = Instance.new("Model") m.Name = "AshCat" m.Parent = parent
	local grey = Color3.fromRGB(120, 118, 124)
	local body = mp{name="Body", size=Vector3.new(1.6, 1.2, 2.2), cf=cf*CFrame.new(0, 0.8, 0), color=grey, ball=true, parent=m}
	local head = mp{name="Head", size=Vector3.new(1.1, 1, 1), cf=cf*CFrame.new(0, 1.7, -0.9), color=grey, ball=true, parent=m}
	mp{name="EarL", size=Vector3.new(0.35, 0.5, 0.2), cf=cf*CFrame.new(-0.3, 2.3, -0.9), color=grey, parent=m}
	mp{name="EarR", size=Vector3.new(0.35, 0.5, 0.2), cf=cf*CFrame.new(0.3, 2.3, -0.9), color=grey, parent=m}
	mp{name="Tail", size=Vector3.new(0.3, 0.3, 1.6), cf=cf*CFrame.new(0, 1.2, 1.6)*CFrame.Angles(math.rad(-30), 0, 0), color=grey, parent=m}
	mp{name="EyeL", size=Vector3.new(0.16, 0.22, 0.1), cf=cf*CFrame.new(-0.22, 1.78, -1.38), color=Color3.fromRGB(90, 200, 120), parent=m}
	mp{name="EyeR", size=Vector3.new(0.16, 0.22, 0.1), cf=cf*CFrame.new(0.22, 1.78, -1.38), color=Color3.fromRGB(90, 200, 120), parent=m}
	return m
end

local function buildHuman(cf, parent, opts)
	opts = opts or {}
	local m = Instance.new("Model") m.Name = opts.name or "Person" m.Parent = parent
	local skin = opts.skin or Color3.fromRGB(224, 178, 145)
	local shirt = opts.shirt or Color3.fromRGB(90, 120, 160)
	local pants = opts.pants or Color3.fromRGB(70, 76, 90)
	mp{name="Legs", size=Vector3.new(1.5, 1.8, 0.9), cf=cf*CFrame.new(0, 0.9, 0), color=pants, parent=m}
	mp{name="Torso", size=Vector3.new(1.7, 1.8, 1), cf=cf*CFrame.new(0, 2.7, 0), color=shirt, parent=m}
	mp{name="ArmL", size=Vector3.new(0.5, 1.7, 0.6), cf=cf*CFrame.new(-1.15, 2.7, 0), color=shirt, parent=m}
	mp{name="ArmR", size=Vector3.new(0.5, 1.7, 0.6), cf=cf*CFrame.new(1.15, 2.7, 0), color=shirt, parent=m}
	local head = mp{name="Head", size=Vector3.new(1.15, 1.15, 1.15), cf=cf*CFrame.new(0, 4.2, 0), color=skin, ball=true, parent=m}
	if opts.hat then
		mp{name="Hat", size=Vector3.new(1.4, 0.5, 1.4), cf=cf*CFrame.new(0, 4.85, 0), color=opts.hat, parent=m}
	end
	if opts.helmet then
		mp{name="Helmet", size=Vector3.new(1.35, 0.7, 1.5), cf=cf*CFrame.new(0, 4.85, 0), color=opts.helmet, ball=true, parent=m}
	end
	return m
end

local function buildSquirrel(cf, parent)
	local m = Instance.new("Model") m.Name = "Squirrel" m.Parent = parent
	local brown = Color3.fromRGB(150, 100, 65)
	mp{name="Body", size=Vector3.new(1.1, 1.3, 1.4), cf=cf*CFrame.new(0, 0.75, 0), color=brown, ball=true, parent=m}
	local head = mp{name="Head", size=Vector3.new(0.9, 0.85, 0.9), cf=cf*CFrame.new(0, 1.7, -0.4), color=brown, ball=true, parent=m}
	mp{name="Tail", size=Vector3.new(0.6, 2.2, 0.9), cf=cf*CFrame.new(0, 1.6, 1)*CFrame.Angles(math.rad(15), 0, 0), color=Color3.fromRGB(170, 120, 80), ball=true, parent=m}
	mp{name="EarL", size=Vector3.new(0.25, 0.4, 0.15), cf=cf*CFrame.new(-0.25, 2.2, -0.4), color=brown, parent=m}
	mp{name="EarR", size=Vector3.new(0.25, 0.4, 0.15), cf=cf*CFrame.new(0.25, 2.2, -0.4), color=brown, parent=m}
	mp{name="EyeL", size=Vector3.new(0.14, 0.18, 0.08), cf=cf*CFrame.new(-0.18, 1.78, -0.82), color=Color3.fromRGB(40, 30, 25), parent=m}
	mp{name="EyeR", size=Vector3.new(0.14, 0.18, 0.08), cf=cf*CFrame.new(0.18, 1.78, -0.82), color=Color3.fromRGB(40, 30, 25), parent=m}
	return m
end

local function buildMossSpirit(cf, parent)
	local m = Instance.new("Model") m.Name = "Mossmitt" m.Parent = parent
	local moss = Color3.fromRGB(105, 135, 95)
	local body = mp{name="Body", size=Vector3.new(3.2, 2.6, 3), cf=cf*CFrame.new(0, 1.4, 0), color=moss, mat=Enum.Material.Grass, ball=true, parent=m}
	local head = mp{name="Head", size=Vector3.new(2, 1.7, 1.9), cf=cf*CFrame.new(0, 3.3, 0), color=moss, mat=Enum.Material.Grass, ball=true, parent=m}
	mp{name="EyeL", size=Vector3.new(0.3, 0.42, 0.15), cf=cf*CFrame.new(-0.45, 3.4, -0.85), color=Color3.fromRGB(200, 240, 190), mat=Enum.Material.Neon, parent=m}
	mp{name="EyeR", size=Vector3.new(0.3, 0.42, 0.15), cf=cf*CFrame.new(0.45, 3.4, -0.85), color=Color3.fromRGB(200, 240, 190), mat=Enum.Material.Neon, parent=m}
	mp{name="Sprout", size=Vector3.new(0.2, 0.8, 0.2), cf=cf*CFrame.new(0, 4.4, 0), color=Color3.fromRGB(90, 150, 80), parent=m}
	mp{name="SproutLeaf", size=Vector3.new(0.8, 0.3, 0.5), cf=cf*CFrame.new(0.2, 4.8, 0), color=Color3.fromRGB(110, 170, 95), ball=true, parent=m}
	glow(body, Color3.fromRGB(170, 220, 160), 9, 0.5)
	wisps(head, Color3.fromRGB(190, 230, 170), 2.5)
	return m
end

local function buildPigeonSpirit(cf, parent)
	local m = Instance.new("Model") m.Name = "Cindercoo" m.Parent = parent
	local soot = Color3.fromRGB(105, 100, 110)
	local body = mp{name="Body", size=Vector3.new(1.6, 1.5, 2), cf=cf*CFrame.new(0, 0.9, 0), color=soot, ball=true, parent=m}
	local head = mp{name="Head", size=Vector3.new(1, 0.95, 1), cf=cf*CFrame.new(0, 1.9, -0.6), color=soot, ball=true, parent=m}
	mp{name="Beak", size=Vector3.new(0.25, 0.2, 0.5), cf=cf*CFrame.new(0, 1.85, -1.15), color=Color3.fromRGB(220, 170, 80), parent=m}
	mp{name="WingL", size=Vector3.new(0.3, 0.9, 1.4), cf=cf*CFrame.new(-0.85, 1, 0.1)*CFrame.Angles(0, 0, math.rad(15)), color=soot, ball=true, parent=m}
	mp{name="WingR", size=Vector3.new(0.3, 0.9, 1.4), cf=cf*CFrame.new(0.85, 1, 0.1)*CFrame.Angles(0, 0, math.rad(-15)), color=soot, ball=true, parent=m}
	mp{name="EyeL", size=Vector3.new(0.15, 0.2, 0.08), cf=cf*CFrame.new(-0.24, 2, -1.02), color=Color3.fromRGB(255, 170, 90), mat=Enum.Material.Neon, parent=m}
	mp{name="EyeR", size=Vector3.new(0.15, 0.2, 0.08), cf=cf*CFrame.new(0.24, 2, -1.02), color=Color3.fromRGB(255, 170, 90), mat=Enum.Material.Neon, parent=m}
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 2
	smoke.Lifetime = NumberRange.new(1, 1.6)
	smoke.Speed = NumberRange.new(0.5)
	smoke.Size = NumberSequence.new(0.6)
	smoke.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1)})
	smoke.Color = ColorSequence.new(Color3.fromRGB(90, 85, 90))
	smoke.Parent = body
	return m
end

local function buildBridgeSpirit(cf, parent)
	local m = Instance.new("Model") m.Name = "OldSpan" m.Parent = parent
	local stone = Color3.fromRGB(140, 150, 170)
	local body = mp{name="Body", size=Vector3.new(2.4, 4.2, 1.8), cf=cf*CFrame.new(0, 2.6, 0), color=stone, tr=0.35, ball=true, parent=m}
	local head = mp{name="Head", size=Vector3.new(1.5, 1.4, 1.4), cf=cf*CFrame.new(0, 5.2, 0), color=stone, tr=0.3, ball=true, parent=m}
	mp{name="EyeL", size=Vector3.new(0.28, 0.34, 0.12), cf=cf*CFrame.new(-0.35, 5.3, -0.62), color=Color3.fromRGB(180, 220, 255), mat=Enum.Material.Neon, parent=m}
	mp{name="EyeR", size=Vector3.new(0.28, 0.34, 0.12), cf=cf*CFrame.new(0.35, 5.3, -0.62), color=Color3.fromRGB(180, 220, 255), mat=Enum.Material.Neon, parent=m}
	mp{name="LanternHand", size=Vector3.new(0.6, 0.9, 0.6), cf=cf*CFrame.new(1.5, 3.2, -0.6), color=Color3.fromRGB(255, 220, 150), mat=Enum.Material.Neon, parent=m}
	glow(head, Color3.fromRGB(160, 200, 255), 12, 0.7)
	wisps(body, Color3.fromRGB(170, 210, 250), 2)
	return m
end

local function buildGuardian(cf, parent)
	local m = Instance.new("Model") m.Name = "Watchkeeper" m.Parent = parent
	local charcoal = Color3.fromRGB(55, 48, 46)
	local body = mp{name="Body", size=Vector3.new(5.5, 7, 4.5), cf=cf*CFrame.new(0, 4, 0), color=charcoal, mat=Enum.Material.Slate, ball=true, parent=m}
	local head = mp{name="Head", size=Vector3.new(3.2, 2.8, 3), cf=cf*CFrame.new(0, 8.6, 0), color=charcoal, mat=Enum.Material.Slate, ball=true, parent=m}
	mp{name="EyeL", size=Vector3.new(0.55, 0.7, 0.2), cf=cf*CFrame.new(-0.8, 8.8, -1.35), color=Color3.fromRGB(255, 120, 60), mat=Enum.Material.Neon, parent=m}
	mp{name="EyeR", size=Vector3.new(0.55, 0.7, 0.2), cf=cf*CFrame.new(0.8, 8.8, -1.35), color=Color3.fromRGB(255, 120, 60), mat=Enum.Material.Neon, parent=m}
	mp{name="CrackA", size=Vector3.new(0.4, 3, 0.3), cf=cf*CFrame.new(-1.2, 4.5, -2.05)*CFrame.Angles(0, 0, math.rad(15)), color=Color3.fromRGB(255, 140, 70), mat=Enum.Material.Neon, parent=m}
	mp{name="CrackB", size=Vector3.new(0.35, 2.2, 0.3), cf=cf*CFrame.new(1.4, 3.6, -2.02)*CFrame.Angles(0, 0, math.rad(-20)), color=Color3.fromRGB(255, 140, 70), mat=Enum.Material.Neon, parent=m}
	local fire = Instance.new("Fire")
	fire.Name = "GuardianFlame"
	fire.Size = 12
	fire.Heat = 9
	fire.Color = Color3.fromRGB(255, 120, 50)
	fire.SecondaryColor = Color3.fromRGB(120, 40, 30)
	fire.Parent = head
	glow(body, Color3.fromRGB(255, 120, 60), 20, 1.4)
	return m
end

-- ============ model builders v2 ============
-- Richer character kits. These reassign the v1 builder locals so all quest logic
-- and dialogue above/below stays untouched. Every model gets an AmbientStyle
-- attribute consumed by StarterPlayerScripts.NPCAmbience (idle life on clients).

local function addFace(m, cf, opts)
	opts = opts or {}
	local ec = opts.eyeColor or Color3.fromRGB(45, 38, 32)
	local w = opts.wide or 0.26
	for _, side in ipairs({ -1, 1 }) do
		mp{name="EyeWhite", size=Vector3.new(0.26, 0.34, 0.12), cf=cf*CFrame.new(side*w, 0.06, -0.52), color=Color3.fromRGB(245,245,240), ball=true, parent=m}
		mp{name="EyePupil", size=Vector3.new(0.13, 0.2, 0.08), cf=cf*CFrame.new(side*w, 0.05, -0.6), color=ec, ball=true, parent=m}
		if opts.brows then
			mp{name="Brow", size=Vector3.new(0.3, 0.08, 0.1), cf=cf*CFrame.new(side*w, 0.32, -0.52)*CFrame.Angles(0,0,side*math.rad(-8)), color=opts.browColor or Color3.fromRGB(70,55,45), parent=m}
		end
	end
end

buildCat = function(cf, parent)
	local m = Instance.new("Model") m.Name = "AshCat" m.Parent = parent
	local grey = Color3.fromRGB(126, 124, 132)
	local dark = Color3.fromRGB(96, 94, 104)
	local cream = Color3.fromRGB(228, 222, 210)
	local body = mp{name="Body", size=Vector3.new(1.5, 1.25, 2.3), cf=cf*CFrame.new(0, 0.85, 0), color=grey, ball=true, parent=m}
	mp{name="Chest", size=Vector3.new(1.1, 0.95, 1.2), cf=cf*CFrame.new(0, 0.72, -0.75), color=cream, ball=true, parent=m}
	for i, dz in ipairs({ -0.5, 0.1, 0.7 }) do
		mp{name="Stripe"..i, size=Vector3.new(1.2, 0.5, 0.34), cf=cf*CFrame.new(0, 1.32, dz), color=dark, ball=true, parent=m}
	end
	local head = mp{name="Head", size=Vector3.new(1.15, 1.05, 1.05), cf=cf*CFrame.new(0, 1.85, -0.95), color=grey, ball=true, parent=m}
	mp{name="Muzzle", size=Vector3.new(0.62, 0.45, 0.4), cf=cf*CFrame.new(0, 1.66, -1.42), color=cream, ball=true, parent=m}
	mp{name="Nose", size=Vector3.new(0.16, 0.12, 0.1), cf=cf*CFrame.new(0, 1.78, -1.6), color=Color3.fromRGB(200, 120, 120), ball=true, parent=m}
	for _, side in ipairs({ -1, 1 }) do
		mp{name="Ear", size=Vector3.new(0.34, 0.52, 0.16), cf=cf*CFrame.new(side*0.36, 2.42, -0.9)*CFrame.Angles(0, 0, side*math.rad(14)), color=grey, parent=m}
		mp{name="EarInner", size=Vector3.new(0.18, 0.3, 0.1), cf=cf*CFrame.new(side*0.36, 2.38, -0.95), color=Color3.fromRGB(214, 160, 160), parent=m}
		mp{name="EyeL", size=Vector3.new(0.2, 0.26, 0.1), cf=cf*CFrame.new(side*0.26, 1.95, -1.42), color=Color3.fromRGB(120, 190, 120), ball=true, parent=m}
		mp{name="Pupil", size=Vector3.new(0.08, 0.2, 0.06), cf=cf*CFrame.new(side*0.26, 1.94, -1.48), color=Color3.fromRGB(30, 30, 30), parent=m}
	end
	mp{name="TailA", size=Vector3.new(0.3, 0.3, 1.2), cf=cf*CFrame.new(0, 1.15, 1.35)*CFrame.Angles(math.rad(-40), 0, 0), color=grey, parent=m}
	mp{name="TailB", size=Vector3.new(0.26, 0.26, 0.9), cf=cf*CFrame.new(0, 1.85, 1.75)*CFrame.Angles(math.rad(-75), 0, 0), color=dark, parent=m}
	for _, off in ipairs({ {-0.45, -0.7}, {0.45, -0.7}, {-0.45, 0.7}, {0.45, 0.7} }) do
		mp{name="Leg", size=Vector3.new(0.34, 0.55, 0.34), cf=cf*CFrame.new(off[1], 0.28, off[2]), color=grey, parent=m}
	end
	m:SetAttribute("AmbientStyle", "cat")
	return m
end

buildHuman = function(cf, parent, opts)
	opts = opts or {}
	local m = Instance.new("Model") m.Name = opts.name or "Person" m.Parent = parent
	local skin = opts.skin or Color3.fromRGB(224, 178, 145)
	local shirt = opts.shirt or Color3.fromRGB(90, 120, 160)
	local pants = opts.pants or Color3.fromRGB(70, 76, 90)
	local hairC = opts.hairColor or Color3.fromRGB(74, 56, 42)
	-- legs + shoes
	for _, side in ipairs({ -1, 1 }) do
		mp{name="Leg", size=Vector3.new(0.62, 1.7, 0.72), cf=cf*CFrame.new(side*0.42, 1.15, 0), color=pants, parent=m}
		mp{name="Shoe", size=Vector3.new(0.68, 0.34, 1.05), cf=cf*CFrame.new(side*0.42, 0.17, -0.14), color=opts.boots or Color3.fromRGB(52, 44, 40), parent=m}
	end
	-- torso
	mp{name="Hips", size=Vector3.new(1.55, 0.6, 0.95), cf=cf*CFrame.new(0, 2.25, 0), color=pants, parent=m}
	local chest = mp{name="Torso", size=Vector3.new(1.7, 1.5, 1.0), cf=cf*CFrame.new(0, 3.3, 0), color=shirt, ball=opts.round and true or false, parent=m}
	if opts.vest then
		mp{name="Vest", size=Vector3.new(1.5, 1.3, 0.24), cf=cf*CFrame.new(0, 3.32, -0.52), color=opts.vest, parent=m}
		mp{name="VestStripe", size=Vector3.new(1.52, 0.28, 0.26), cf=cf*CFrame.new(0, 3.32, -0.53), color=Color3.fromRGB(240, 220, 140), mat=Enum.Material.Neon, parent=m}
	end
	if opts.apron then
		mp{name="Apron", size=Vector3.new(1.3, 1.9, 0.2), cf=cf*CFrame.new(0, 2.75, -0.54), color=opts.apron, parent=m}
	end
	-- arms + hands
	for _, side in ipairs({ -1, 1 }) do
		mp{name="Sleeve", size=Vector3.new(0.52, 1.15, 0.6), cf=cf*CFrame.new(side*1.12, 3.5, 0)*CFrame.Angles(0, 0, side*math.rad(4)), color=shirt, parent=m}
		mp{name="Hand", size=Vector3.new(0.44, 0.75, 0.5), cf=cf*CFrame.new(side*1.2, 2.6, 0), color=skin, parent=m}
	end
	-- neck + head
	mp{name="Neck", size=Vector3.new(0.5, 0.3, 0.5), cf=cf*CFrame.new(0, 4.15, 0), color=skin, parent=m}
	local headCF = cf*CFrame.new(0, 4.85, 0)
	local head = mp{name="Head", size=Vector3.new(1.15, 1.2, 1.1), cf=headCF, color=skin, ball=true, parent=m}
	addFace(m, headCF, { brows = true, browColor = hairC })
	-- hair / headgear
	local style = opts.hair or "short"
	if style == "short" then
		mp{name="Hair", size=Vector3.new(1.22, 0.7, 1.16), cf=headCF*CFrame.new(0, 0.34, 0.06), color=hairC, ball=true, parent=m}
	elseif style == "bun" then
		mp{name="Hair", size=Vector3.new(1.22, 0.66, 1.16), cf=headCF*CFrame.new(0, 0.34, 0.06), color=hairC, ball=true, parent=m}
		mp{name="Bun", size=Vector3.new(0.5, 0.5, 0.5), cf=headCF*CFrame.new(0, 0.62, 0.5), color=hairC, ball=true, parent=m}
	elseif style == "long" then
		mp{name="Hair", size=Vector3.new(1.24, 0.7, 1.18), cf=headCF*CFrame.new(0, 0.34, 0.06), color=hairC, ball=true, parent=m}
		mp{name="HairBack", size=Vector3.new(1.0, 1.3, 0.4), cf=headCF*CFrame.new(0, -0.25, 0.52), color=hairC, parent=m}
	end
	if opts.hat then
		mp{name="HatBrim", size=Vector3.new(0.2, 1.7, 1.7), cf=headCF*CFrame.new(0, 0.52, 0)*CFrame.Angles(0, 0, math.rad(90)), color=opts.hat, shape=nil, parent=m}
		local brim = m:FindFirstChild("HatBrim")
		brim.Shape = Enum.PartType.Cylinder
		mp{name="HatDome", size=Vector3.new(0.95, 0.6, 0.95), cf=headCF*CFrame.new(0, 0.78, 0), color=opts.hat, ball=true, parent=m}
	end
	if opts.helmet then
		mp{name="HelmetDome", size=Vector3.new(1.3, 0.75, 1.35), cf=headCF*CFrame.new(0, 0.5, 0.02), color=opts.helmet, ball=true, parent=m}
		mp{name="HelmetBrim", size=Vector3.new(1.45, 0.12, 1.7), cf=headCF*CFrame.new(0, 0.28, 0.12), color=opts.helmet, parent=m}
		mp{name="HelmetBadge", size=Vector3.new(0.3, 0.34, 0.08), cf=headCF*CFrame.new(0, 0.6, -0.62), color=Color3.fromRGB(230, 200, 120), mat=Enum.Material.Metal, parent=m}
	end
	if opts.satchel then
		mp{name="Satchel", size=Vector3.new(0.7, 0.6, 0.3), cf=cf*CFrame.new(0.75, 2.45, 0.45), color=Color3.fromRGB(120, 90, 60), parent=m}
		mp{name="Strap", size=Vector3.new(0.14, 1.9, 0.14), cf=cf*CFrame.new(-0.2, 3.5, 0.4)*CFrame.Angles(0, 0, math.rad(38)), color=Color3.fromRGB(100, 75, 50), parent=m}
	end
	m:SetAttribute("AmbientStyle", "breathe")
	return m
end

buildSquirrel = function(cf, parent)
	local m = Instance.new("Model") m.Name = "Squirrel" m.Parent = parent
	local brown = Color3.fromRGB(152, 100, 64)
	local cream = Color3.fromRGB(230, 210, 180)
	local tailC = Color3.fromRGB(172, 120, 78)
	mp{name="Body", size=Vector3.new(1.15, 1.35, 1.3), cf=cf*CFrame.new(0, 0.8, 0), color=brown, ball=true, parent=m}
	mp{name="Belly", size=Vector3.new(0.8, 1.0, 0.9), cf=cf*CFrame.new(0, 0.72, -0.34), color=cream, ball=true, parent=m}
	local headCF = cf*CFrame.new(0, 1.85, -0.35)
	mp{name="Head", size=Vector3.new(0.95, 0.9, 0.95), cf=headCF, color=brown, ball=true, parent=m}
	mp{name="Muzzle", size=Vector3.new(0.5, 0.4, 0.4), cf=headCF*CFrame.new(0, -0.16, -0.44), color=cream, ball=true, parent=m}
	mp{name="Teeth", size=Vector3.new(0.16, 0.18, 0.06), cf=headCF*CFrame.new(0, -0.34, -0.62), color=Color3.fromRGB(245, 240, 225), parent=m}
	mp{name="Nose", size=Vector3.new(0.14, 0.12, 0.1), cf=headCF*CFrame.new(0, -0.06, -0.66), color=Color3.fromRGB(80, 55, 45), ball=true, parent=m}
	for _, side in ipairs({ -1, 1 }) do
		mp{name="Ear", size=Vector3.new(0.26, 0.44, 0.14), cf=headCF*CFrame.new(side*0.3, 0.55, -0.05), color=brown, parent=m}
		mp{name="Eye", size=Vector3.new(0.18, 0.24, 0.1), cf=headCF*CFrame.new(side*0.24, 0.1, -0.44), color=Color3.fromRGB(35, 28, 24), ball=true, parent=m}
		mp{name="Paw", size=Vector3.new(0.24, 0.5, 0.24), cf=cf*CFrame.new(side*0.34, 1.1, -0.62)*CFrame.Angles(math.rad(-30), 0, 0), color=brown, parent=m}
		mp{name="Foot", size=Vector3.new(0.3, 0.24, 0.62), cf=cf*CFrame.new(side*0.34, 0.14, -0.1), color=brown, parent=m}
	end
	-- glorious tail: three arcing segments
	mp{name="Tail1", size=Vector3.new(0.55, 1.1, 0.6), cf=cf*CFrame.new(0, 0.7, 0.75)*CFrame.Angles(math.rad(25), 0, 0), color=tailC, ball=true, parent=m}
	mp{name="Tail2", size=Vector3.new(0.7, 1.3, 0.75), cf=cf*CFrame.new(0, 1.7, 1.0)*CFrame.Angles(math.rad(-5), 0, 0), color=tailC, ball=true, parent=m}
	mp{name="Tail3", size=Vector3.new(0.6, 1.0, 0.65), cf=cf*CFrame.new(0, 2.55, 0.7)*CFrame.Angles(math.rad(-35), 0, 0), color=brown, ball=true, parent=m}
	m:SetAttribute("AmbientStyle", "cat")
	return m
end

buildMossSpirit = function(cf, parent)
	local m = Instance.new("Model") m.Name = "Mossmitt" m.Parent = parent
	local moss = Color3.fromRGB(105, 135, 95)
	local mossDark = Color3.fromRGB(84, 112, 78)
	local body = mp{name="Body", size=Vector3.new(3.4, 2.7, 3.1), cf=cf*CFrame.new(0, 1.45, 0), color=moss, mat=Enum.Material.Grass, ball=true, parent=m}
	mp{name="MossLumpL", size=Vector3.new(1.6, 1.2, 1.7), cf=cf*CFrame.new(-1.3, 0.9, 0.5), color=mossDark, mat=Enum.Material.Grass, ball=true, parent=m}
	mp{name="MossLumpR", size=Vector3.new(1.4, 1.1, 1.5), cf=cf*CFrame.new(1.35, 0.8, -0.3), color=mossDark, mat=Enum.Material.Grass, ball=true, parent=m}
	local headCF = cf*CFrame.new(0, 3.45, 0)
	mp{name="Head", size=Vector3.new(2.1, 1.8, 2.0), cf=headCF, color=moss, mat=Enum.Material.Grass, ball=true, parent=m}
	mp{name="BrowMoss", size=Vector3.new(1.9, 0.55, 1.0), cf=headCF*CFrame.new(0, 0.62, -0.45)*CFrame.Angles(math.rad(-12), 0, 0), color=mossDark, mat=Enum.Material.Grass, ball=true, parent=m}
	for _, side in ipairs({ -1, 1 }) do
		mp{name="Eye", size=Vector3.new(0.4, 0.55, 0.16), cf=headCF*CFrame.new(side*0.5, 0.08, -0.92), color=Color3.fromRGB(205, 245, 195), mat=Enum.Material.Neon, ball=true, parent=m}
		-- bare, cold little paws (the mittens will warm them)
		mp{name="Paw", size=Vector3.new(0.85, 0.6, 0.9), cf=cf*CFrame.new(side*1.7, 1.0, -1.15), color=Color3.fromRGB(150, 138, 120), ball=true, parent=m}
	end
	for _, side in ipairs({ -1, 1 }) do
		mp{name="RootFoot", size=Vector3.new(0.9, 0.5, 1.2), cf=cf*CFrame.new(side*0.75, 0.25, 0.2), color=Color3.fromRGB(96, 78, 60), mat=Enum.Material.Wood, parent=m}
	end
	mp{name="Sprout", size=Vector3.new(0.18, 0.8, 0.18), cf=headCF*CFrame.new(0, 1.1, 0), color=Color3.fromRGB(96, 156, 84), parent=m}
	for _, side in ipairs({ -1, 1 }) do
		mp{name="SproutLeaf", size=Vector3.new(0.7, 0.22, 0.4), cf=headCF*CFrame.new(side*0.35, 1.42, 0)*CFrame.Angles(0, 0, side*math.rad(24)), color=Color3.fromRGB(120, 180, 100), ball=true, parent=m}
	end
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2
		mp{name="Flower"..i, size=Vector3.new(0.22, 0.14, 0.22), cf=cf*CFrame.new(math.cos(a)*1.45, 1.7 + math.sin(a*2)*0.5, math.sin(a)*1.35), color=Color3.fromRGB(235, 215, 150), mat=Enum.Material.Neon, ball=true, parent=m}
	end
	glow(body, Color3.fromRGB(170, 220, 160), 10, 0.5)
	wisps(m:FindFirstChild("Head"), Color3.fromRGB(190, 230, 170), 2.5)
	m:SetAttribute("AmbientStyle", "spirit")
	return m
end

buildPigeonSpirit = function(cf, parent)
	local m = Instance.new("Model") m.Name = "Cindercoo" m.Parent = parent
	local soot = Color3.fromRGB(108, 102, 112)
	local sootDark = Color3.fromRGB(78, 74, 84)
	local body = mp{name="Body", size=Vector3.new(1.7, 1.55, 2.15), cf=cf*CFrame.new(0, 1.0, 0), color=soot, ball=true, parent=m}
	mp{name="NeckSheen", size=Vector3.new(1.15, 0.9, 1.0), cf=cf*CFrame.new(0, 1.65, -0.55), color=Color3.fromRGB(96, 150, 140), mat=Enum.Material.Neon, ball=true, parent=m}
	local headCF = cf*CFrame.new(0, 2.25, -0.7)
	mp{name="Head", size=Vector3.new(1.0, 0.95, 1.0), cf=headCF, color=soot, ball=true, parent=m}
	mp{name="BeakTop", size=Vector3.new(0.24, 0.16, 0.5), cf=headCF*CFrame.new(0, -0.05, -0.6), color=Color3.fromRGB(225, 175, 85), parent=m}
	mp{name="BeakDot", size=Vector3.new(0.18, 0.1, 0.14), cf=headCF*CFrame.new(0, 0.06, -0.5), color=Color3.fromRGB(240, 238, 230), ball=true, parent=m}
	for _, side in ipairs({ -1, 1 }) do
		mp{name="Eye", size=Vector3.new(0.17, 0.22, 0.1), cf=headCF*CFrame.new(side*0.26, 0.1, -0.4), color=Color3.fromRGB(255, 170, 90), mat=Enum.Material.Neon, ball=true, parent=m}
		mp{name="Wing", size=Vector3.new(0.3, 1.0, 1.55), cf=cf*CFrame.new(side*0.85, 1.05, 0.15)*CFrame.Angles(math.rad(6), 0, side*math.rad(-14)), color=sootDark, ball=true, parent=m}
		mp{name="WingTip", size=Vector3.new(0.22, 0.6, 0.9), cf=cf*CFrame.new(side*0.95, 0.75, 0.95)*CFrame.Angles(math.rad(18), 0, 0), color=soot, ball=true, parent=m}
		mp{name="Foot", size=Vector3.new(0.3, 0.3, 0.5), cf=cf*CFrame.new(side*0.35, 0.15, -0.1), color=Color3.fromRGB(205, 130, 80), parent=m}
	end
	for i = -1, 1 do
		mp{name="TailFeather", size=Vector3.new(0.34, 0.14, 1.1), cf=cf*CFrame.new(i*0.3, 0.95, 1.35)*CFrame.Angles(math.rad(12), i*math.rad(-14), 0), color=sootDark, parent=m}
	end
	mp{name="EmberChest", size=Vector3.new(0.4, 0.5, 0.16), cf=cf*CFrame.new(0, 1.05, -1.02), color=Color3.fromRGB(255, 140, 80), mat=Enum.Material.Neon, ball=true, parent=m}
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 2
	smoke.Lifetime = NumberRange.new(1, 1.6)
	smoke.Speed = NumberRange.new(0.5)
	smoke.Size = NumberSequence.new(0.6)
	smoke.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1)})
	smoke.Color = ColorSequence.new(Color3.fromRGB(90, 85, 90))
	smoke.Parent = body
	m:SetAttribute("AmbientStyle", "bird")
	return m
end

buildBridgeSpirit = function(cf, parent)
	local m = Instance.new("Model") m.Name = "OldSpan" m.Parent = parent
	local stone = Color3.fromRGB(142, 152, 172)
	local stoneDeep = Color3.fromRGB(112, 124, 148)
	-- robed, architectural figure
	mp{name="SkirtBase", size=Vector3.new(3.2, 2.4, 2.6), cf=cf*CFrame.new(0, 1.3, 0), color=stoneDeep, tr=0.4, ball=true, parent=m}
	mp{name="Robe", size=Vector3.new(2.5, 3.0, 2.0), cf=cf*CFrame.new(0, 3.2, 0), color=stone, tr=0.35, ball=true, parent=m}
	-- a carved stone lintel rests across its shoulders like a yoke
	mp{name="ShoulderLintel", size=Vector3.new(4.6, 0.7, 1.1), cf=cf*CFrame.new(0, 4.8, 0), color=Color3.fromRGB(138, 128, 116), mat=Enum.Material.Sandstone, parent=m}
	local headCF = cf*CFrame.new(0, 5.9, 0)
	mp{name="Head", size=Vector3.new(1.6, 1.5, 1.5), cf=headCF, color=stone, tr=0.3, ball=true, parent=m}
	mp{name="Crown", size=Vector3.new(1.3, 0.5, 1.3), cf=headCF*CFrame.new(0, 0.85, 0), color=Color3.fromRGB(138, 128, 116), mat=Enum.Material.Sandstone, parent=m}
	for _, side in ipairs({ -1, 1 }) do
		mp{name="Eye", size=Vector3.new(0.3, 0.4, 0.14), cf=headCF*CFrame.new(side*0.38, 0.05, -0.66), color=Color3.fromRGB(180, 220, 255), mat=Enum.Material.Neon, ball=true, parent=m}
	end
	-- lantern heart, held out
	mp{name="Arm", size=Vector3.new(0.55, 2.2, 0.55), cf=cf*CFrame.new(1.55, 3.6, -0.7)*CFrame.Angles(math.rad(35), 0, math.rad(-15)), color=stone, tr=0.35, parent=m}
	local lantern = mp{name="Lantern", size=Vector3.new(0.7, 0.9, 0.7), cf=cf*CFrame.new(2.1, 2.6, -1.5), color=Color3.fromRGB(255, 222, 150), mat=Enum.Material.Neon, parent=m}
	mp{name="LanternCap", size=Vector3.new(0.8, 0.2, 0.8), cf=cf*CFrame.new(2.1, 3.15, -1.5), color=Color3.fromRGB(80, 88, 100), parent=m}
	-- floating stone fragments (drift with the spirit's hover)
	mp{name="FloatStoneA", size=Vector3.new(0.7, 0.5, 0.6), cf=cf*CFrame.new(-2.2, 4.6, 0.6)*CFrame.Angles(0.4, 0.7, 0.2), color=stoneDeep, mat=Enum.Material.Slate, parent=m}
	mp{name="FloatStoneB", size=Vector3.new(0.5, 0.4, 0.45), cf=cf*CFrame.new(-1.6, 5.7, -0.9)*CFrame.Angles(0.8, 0.2, 0.5), color=stoneDeep, mat=Enum.Material.Slate, parent=m}
	glow(lantern, Color3.fromRGB(255, 220, 150), 14, 1)
	glow(m:FindFirstChild("Head"), Color3.fromRGB(160, 200, 255), 12, 0.6)
	wisps(m:FindFirstChild("Robe"), Color3.fromRGB(170, 210, 250), 2)
	m:SetAttribute("AmbientStyle", "spirit")
	return m
end

buildGuardian = function(cf, parent)
	local m = Instance.new("Model") m.Name = "Watchkeeper" m.Parent = parent
	local charcoal = Color3.fromRGB(52, 46, 44)
	local charLight = Color3.fromRGB(72, 62, 58)
	local emberC = Color3.fromRGB(255, 130, 60)
	-- hunched mass
	local body = mp{name="Body", size=Vector3.new(6.5, 7.5, 5.2), cf=cf*CFrame.new(0, 4.2, 0)*CFrame.Angles(math.rad(8), 0, 0), color=charcoal, mat=Enum.Material.Slate, ball=true, parent=m}
	mp{name="ShoulderL", size=Vector3.new(3.0, 2.6, 3.2), cf=cf*CFrame.new(-2.9, 6.4, 0.2), color=charLight, mat=Enum.Material.Slate, ball=true, parent=m}
	mp{name="ShoulderR", size=Vector3.new(3.0, 2.6, 3.2), cf=cf*CFrame.new(2.9, 6.4, 0.2), color=charLight, mat=Enum.Material.Slate, ball=true, parent=m}
	for _, side in ipairs({ -1, 1 }) do
		mp{name="Arm", size=Vector3.new(1.5, 4.2, 1.6), cf=cf*CFrame.new(side*3.4, 3.6, 0.3)*CFrame.Angles(0, 0, side*math.rad(8)), color=charcoal, mat=Enum.Material.Slate, parent=m}
		mp{name="Knuckles", size=Vector3.new(1.8, 1.4, 1.9), cf=cf*CFrame.new(side*3.6, 1.2, 0.3), color=charLight, mat=Enum.Material.Slate, ball=true, parent=m}
	end
	local headCF = cf*CFrame.new(0, 9.0, -0.4)
	mp{name="Head", size=Vector3.new(3.4, 3.0, 3.2), cf=headCF, color=charcoal, mat=Enum.Material.Slate, ball=true, parent=m}
	-- it wears the oldest fire helmet, grown into the stone
	mp{name="OldHelm", size=Vector3.new(3.7, 1.4, 3.8), cf=headCF*CFrame.new(0, 1.15, 0.15), color=Color3.fromRGB(96, 60, 44), mat=Enum.Material.CorrodedMetal, ball=true, parent=m}
	mp{name="OldHelmBrim", size=Vector3.new(4.0, 0.3, 4.4), cf=headCF*CFrame.new(0, 0.55, 0.35), color=Color3.fromRGB(84, 52, 40), mat=Enum.Material.CorrodedMetal, parent=m}
	mp{name="HelmCrest", size=Vector3.new(0.5, 1.0, 1.8), cf=headCF*CFrame.new(0, 1.7, 0), color=Color3.fromRGB(150, 110, 60), mat=Enum.Material.CorrodedMetal, parent=m}
	for _, side in ipairs({ -1, 1 }) do
		mp{name="Eye", size=Vector3.new(0.6, 0.75, 0.22), cf=headCF*CFrame.new(side*0.85, 0.1, -1.42), color=emberC, mat=Enum.Material.Neon, ball=true, parent=m}
	end
	-- ember crack network
	local cracks = {
		{ -1.4, 4.6, -2.4, 3.2, 14 }, { 1.6, 3.8, -2.35, 2.4, -22 }, { 0.2, 5.8, -2.5, 1.8, 40 },
		{ -2.6, 6.2, -1.1, 1.4, 70 }, { 2.4, 2.2, -1.9, 1.6, -50 },
	}
	for i, c in ipairs(cracks) do
		mp{name="Crack"..i, size=Vector3.new(0.32, c[4], 0.24), cf=cf*CFrame.new(c[1], c[2], c[3])*CFrame.Angles(0, 0, math.rad(c[5])), color=emberC, mat=Enum.Material.Neon, parent=m}
	end
	-- orbiting ember shards
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		mp{name="FloatEmber"..i, size=Vector3.new(0.8, 0.6, 0.7), cf=cf*CFrame.new(math.cos(a)*4.6, 7.2 + math.sin(a)*0.8, math.sin(a)*3.4)*CFrame.Angles(a, a, 0), color=emberC, mat=Enum.Material.Neon, parent=m}
	end
	local fire = Instance.new("Fire")
	fire.Name = "GuardianFlame"
	fire.Size = 12
	fire.Heat = 9
	fire.Color = Color3.fromRGB(255, 120, 50)
	fire.SecondaryColor = Color3.fromRGB(120, 40, 30)
	fire.Parent = m:FindFirstChild("Head")
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 6
	smoke.Lifetime = NumberRange.new(2.4, 3.6)
	smoke.Speed = NumberRange.new(2, 3.5)
	smoke.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6)})
	smoke.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1)})
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 62, 58))
	smoke.Parent = body
	glow(body, Color3.fromRGB(255, 120, 60), 24, 1.4)
	m:SetAttribute("AmbientStyle", "guardian")
	return m
end

-- ============ model builders v3: the wider world ============
local function buildOtter(cf, parent)
	local m = Instance.new("Model") m.Name = "Otter" m.Parent = parent
	local brown = Color3.fromRGB(124, 94, 66)
	local cream = Color3.fromRGB(214, 192, 160)
	mp{name="Body", size=Vector3.new(1.3, 1.5, 1.9), cf=cf*CFrame.new(0, 1.0, 0), color=brown, ball=true, parent=m}
	mp{name="Belly", size=Vector3.new(0.95, 1.1, 1.0), cf=cf*CFrame.new(0, 0.95, -0.5), color=cream, ball=true, parent=m}
	local headCF = cf*CFrame.new(0, 2.05, -0.35)
	mp{name="Head", size=Vector3.new(0.95, 0.85, 0.95), cf=headCF, color=brown, ball=true, parent=m}
	mp{name="Muzzle", size=Vector3.new(0.5, 0.36, 0.4), cf=headCF*CFrame.new(0, -0.14, -0.44), color=cream, ball=true, parent=m}
	mp{name="Nose", size=Vector3.new(0.14, 0.1, 0.1), cf=headCF*CFrame.new(0, -0.02, -0.64), color=Color3.fromRGB(60, 45, 40), ball=true, parent=m}
	for _, side in ipairs({ -1, 1 }) do
		mp{name="Ear", size=Vector3.new(0.2, 0.2, 0.1), cf=headCF*CFrame.new(side*0.36, 0.4, -0.05), color=brown, ball=true, parent=m}
		mp{name="Eye", size=Vector3.new(0.16, 0.2, 0.1), cf=headCF*CFrame.new(side*0.22, 0.12, -0.42), color=Color3.fromRGB(35, 28, 24), ball=true, parent=m}
		mp{name="Paw", size=Vector3.new(0.24, 0.5, 0.24), cf=cf*CFrame.new(side*0.34, 1.2, -0.7)*CFrame.Angles(math.rad(-25), 0, 0), color=brown, parent=m}
	end
	mp{name="Tail", size=Vector3.new(0.4, 0.35, 1.5), cf=cf*CFrame.new(0, 0.5, 1.4)*CFrame.Angles(math.rad(12), 0, 0), color=brown, parent=m}
	m:SetAttribute("AmbientStyle", "cat")
	return m
end

local function buildFrostSprite(cf, parent)
	local m = Instance.new("Model") m.Name = "FrostSprite" m.Parent = parent
	local iceC = Color3.fromRGB(200, 224, 238)
	local body = mp{name="Body", size=Vector3.new(1.4, 1.8, 1.3), cf=cf*CFrame.new(0, 1.6, 0), color=iceC, mat=Enum.Material.Glass, tr=0.25, ball=true, parent=m}
	local headCF = cf*CFrame.new(0, 2.9, 0)
	mp{name="Head", size=Vector3.new(0.95, 0.9, 0.9), cf=headCF, color=iceC, mat=Enum.Material.Glass, tr=0.2, ball=true, parent=m}
	for _, side in ipairs({ -1, 1 }) do
		mp{name="Eye", size=Vector3.new(0.2, 0.28, 0.1), cf=headCF*CFrame.new(side*0.24, 0.05, -0.4), color=Color3.fromRGB(150, 200, 235), mat=Enum.Material.Neon, ball=true, parent=m}
	end
	mp{name="IceCrown", size=Vector3.new(0.2, 0.7, 0.2), cf=headCF*CFrame.new(0, 0.7, 0)*CFrame.Angles(0, 0, math.rad(8)), color=iceC, mat=Enum.Material.Glass, tr=0.15, parent=m}
	mp{name="IceCrownB", size=Vector3.new(0.16, 0.5, 0.16), cf=headCF*CFrame.new(0.28, 0.58, 0.1)*CFrame.Angles(0, 0, math.rad(-16)), color=iceC, mat=Enum.Material.Glass, tr=0.15, parent=m}
	glow(body, Color3.fromRGB(180, 215, 240), 10, 0.6)
	wisps(body, Color3.fromRGB(210, 235, 250), 2.5)
	m:SetAttribute("AmbientStyle", "spirit")
	return m
end

local function buildFernElk(cf, parent)
	local m = Instance.new("Model") m.Name = "FernElk" m.Parent = parent
	local fur = Color3.fromRGB(112, 104, 88)
	local moss = Color3.fromRGB(96, 124, 84)
	local body = mp{name="Body", size=Vector3.new(2.2, 2.4, 4.6), cf=cf*CFrame.new(0, 3.6, 0), color=fur, ball=true, parent=m}
	mp{name="MossBack", size=Vector3.new(2.3, 0.8, 3.4), cf=cf*CFrame.new(0, 4.7, 0.2), color=moss, mat=Enum.Material.Grass, ball=true, parent=m}
	for _, off in ipairs({ {-0.8, -1.6}, {0.8, -1.6}, {-0.8, 1.6}, {0.8, 1.6} }) do
		mp{name="Leg", size=Vector3.new(0.45, 2.6, 0.45), cf=cf*CFrame.new(off[1], 1.3, off[2]), color=fur, parent=m}
	end
	local neckCF = cf*CFrame.new(0, 5.3, -2.1)
	mp{name="Neck", size=Vector3.new(0.8, 2.2, 0.8), cf=neckCF*CFrame.Angles(math.rad(20), 0, 0), color=fur, parent=m}
	local headCF = cf*CFrame.new(0, 6.6, -2.7)
	mp{name="Head", size=Vector3.new(0.9, 0.9, 1.6), cf=headCF, color=fur, ball=true, parent=m}
	for _, side in ipairs({ -1, 1 }) do
		mp{name="Eye", size=Vector3.new(0.16, 0.22, 0.1), cf=headCF*CFrame.new(side*0.34, 0.12, -0.5), color=Color3.fromRGB(220, 235, 210), mat=Enum.Material.Neon, ball=true, parent=m}
		-- mossy antlers: three tines each
		local baseCF = headCF*CFrame.new(side*0.35, 0.5, 0.2)
		mp{name="Antler", size=Vector3.new(0.18, 1.6, 0.18), cf=baseCF*CFrame.Angles(0, 0, side*math.rad(-24)), color=Color3.fromRGB(140, 124, 96), mat=Enum.Material.Wood, parent=m}
		mp{name="Antler", size=Vector3.new(0.14, 1.1, 0.14), cf=baseCF*CFrame.new(side*0.45, 0.6, 0)*CFrame.Angles(0, 0, side*math.rad(-55)), color=Color3.fromRGB(140, 124, 96), mat=Enum.Material.Wood, parent=m}
		mp{name="Antler", size=Vector3.new(0.14, 0.9, 0.14), cf=baseCF*CFrame.new(side*0.2, 0.9, -0.3)*CFrame.Angles(math.rad(-18), 0, side*math.rad(-12)), color=Color3.fromRGB(140, 124, 96), mat=Enum.Material.Wood, parent=m}
	end
	glow(body, Color3.fromRGB(170, 210, 170), 9, 0.35)
	m:SetAttribute("AmbientStyle", "spirit")
	return m
end

local function buildHeron(cf, parent)
	local m = Instance.new("Model") m.Name = "MistHeron" m.Parent = parent
	local grey = Color3.fromRGB(168, 182, 192)
	for _, side in ipairs({ -0.4, 0.4 }) do
		mp{name="Leg", size=Vector3.new(0.14, 2.6, 0.14), cf=cf*CFrame.new(side, 1.3, 0), color=Color3.fromRGB(90, 96, 100), parent=m}
	end
	local body = mp{name="Body", size=Vector3.new(1.2, 1.2, 2.2), cf=cf*CFrame.new(0, 3.1, 0), color=grey, ball=true, parent=m}
	mp{name="Neck", size=Vector3.new(0.34, 1.8, 0.34), cf=cf*CFrame.new(0, 4.4, -0.8)*CFrame.Angles(math.rad(14), 0, 0), color=grey, parent=m}
	local headCF = cf*CFrame.new(0, 5.4, -1.1)
	mp{name="Head", size=Vector3.new(0.55, 0.5, 0.8), cf=headCF, color=grey, ball=true, parent=m}
	mp{name="Beak", size=Vector3.new(0.14, 0.12, 1.1), cf=headCF*CFrame.new(0, -0.05, -0.9), color=Color3.fromRGB(210, 190, 120), parent=m}
	mp{name="Crest", size=Vector3.new(0.1, 0.08, 0.7), cf=headCF*CFrame.new(0, 0.3, 0.4)*CFrame.Angles(math.rad(24), 0, 0), color=Color3.fromRGB(110, 124, 136), parent=m}
	for _, side in ipairs({ -1, 1 }) do
		mp{name="Eye", size=Vector3.new(0.1, 0.12, 0.08), cf=headCF*CFrame.new(side*0.2, 0.08, -0.28), color=Color3.fromRGB(240, 220, 120), mat=Enum.Material.Neon, ball=true, parent=m}
		mp{name="Wing", size=Vector3.new(0.25, 0.9, 1.7), cf=cf*CFrame.new(side*0.6, 3.15, 0.15)*CFrame.Angles(0, 0, side*math.rad(-8)), color=Color3.fromRGB(140, 156, 168), ball=true, parent=m}
	end
	wisps(body, Color3.fromRGB(200, 216, 226), 1.5)
	m:SetAttribute("AmbientStyle", "bird")
	return m
end

local function buildKid(cf, parent, opts)
	opts = opts or {}
	local m = Instance.new("Model") m.Name = opts.name or "Kid" m.Parent = parent
	local skin = opts.skin or Color3.fromRGB(224, 178, 145)
	local shirt = opts.shirt or Color3.fromRGB(150, 120, 170)
	local pants = opts.pants or Color3.fromRGB(80, 86, 100)
	local hairC = opts.hairColor or Color3.fromRGB(60, 46, 36)
	for _, side in ipairs({ -1, 1 }) do
		mp{name="Leg", size=Vector3.new(0.42, 1.0, 0.5), cf=cf*CFrame.new(side*0.28, 0.7, 0), color=pants, parent=m}
		mp{name="Shoe", size=Vector3.new(0.46, 0.24, 0.7), cf=cf*CFrame.new(side*0.28, 0.12, -0.08), color=Color3.fromRGB(52, 44, 40), parent=m}
	end
	local chest = mp{name="Torso", size=Vector3.new(1.1, 1.1, 0.7), cf=cf*CFrame.new(0, 1.75, 0), color=shirt, parent=m}
	for _, side in ipairs({ -1, 1 }) do
		mp{name="Arm", size=Vector3.new(0.36, 1.0, 0.42), cf=cf*CFrame.new(side*0.75, 1.75, 0)*CFrame.Angles(0, 0, side*math.rad(6)), color=shirt, parent=m}
	end
	local headCF = cf*CFrame.new(0, 2.85, 0)
	mp{name="Head", size=Vector3.new(0.95, 0.95, 0.9), cf=headCF, color=skin, ball=true, parent=m}
	addFace(m, headCF*CFrame.new(0, -0.12, 0.06), { wide = 0.2 })
	mp{name="Hair", size=Vector3.new(1.02, 0.55, 0.95), cf=headCF*CFrame.new(0, 0.3, 0.04), color=hairC, ball=true, parent=m}
	if opts.cap then
		mp{name="Cap", size=Vector3.new(1.0, 0.35, 1.0), cf=headCF*CFrame.new(0, 0.42, 0), color=opts.cap, ball=true, parent=m}
		mp{name="CapBrim", size=Vector3.new(0.8, 0.1, 0.5), cf=headCF*CFrame.new(0, 0.32, -0.6), color=opts.cap, parent=m}
	end
	m:SetAttribute("AmbientStyle", "breathe")
	return m
end

-- Ground helper: place a model's pivot so its bounding-box bottom rests on the
-- real walkable surface (terrain isosurface sits ~2 studs above the voxel grid,
-- so never trust authored Y values — always raycast).
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.RespectCanCollide = true -- ignore canopies/ferns; only real floors count

local function surfaceYAt(x, z)
	groundParams.FilterDescendantsInstances = { workspace.Terrain, workspace.World }
	local hit = workspace:Raycast(Vector3.new(x, 90, z), Vector3.new(0, -180, 0), groundParams)
	return hit and hit.Position.Y or nil
end

local function groundedPivot(model, x, z, rotation)
	local g = surfaceYAt(x, z)
	local bboxCF, bboxSize = model:GetBoundingBox()
	local pivotAboveBottom = model:GetPivot().Position.Y - (bboxCF.Position.Y - bboxSize.Y / 2)
	local y = (g or model:GetPivot().Position.Y - pivotAboveBottom) + pivotAboveBottom
	return CFrame.new(x, y, z) * (rotation or model:GetPivot().Rotation)
end

-- A stable PrimaryPart is essential: without one, GetPivot() uses the bounding
-- box, which shifts as the model rotates — ambient yaw then random-walks NPCs
-- across the map. Every NPC gets its Body/Torso as PrimaryPart.
local function ensurePrimary(model)
	if model.PrimaryPart then return end
	model.PrimaryPart = model:FindFirstChild("Body") or model:FindFirstChild("Torso") or model:FindFirstChildWhichIsA("BasePart")
end

-- ============ dialogue helper ============
local function say(player, name, lines, mood)
	Dialogue:FireClient(player, { name = name, lines = lines, mood = mood })
end

-- ============ NPC definitions ============
local DEFS -- assigned below (needs access to helpers)

local function stageAt(player)
	return registry.QuestService:GetStageId(player)
end

-- signal-based gating: quests can be done in any order, so NPCs ask "has this
-- player already done the thing?" rather than "is this the current stage?"
local function done(player, key)
	return registry.QuestService:HasSignalled(player, key)
end

local function stageIndexOf(id)
	local QuestDefs = require(RS.Shared.QuestDefs)
	return QuestDefs.stageIndexById(id)
end

-- has the player passed a given stage already?
local function passed(player, stageId)
	local idx = stageIndexOf(stageId)
	return idx ~= nil and registry.QuestService:GetStageIndex(player) > idx
end

DEFS = {
	AshCat = {
		display = "Ash the Cat",
		build = buildCat,
		prompt = { action = "Rescue", hold = 1.2 },
		doneKey = "Rescue:AshCat",
		doneAction = "Pet",
		onTrigger = function(self, player)
			if not done(player, "Rescue:AshCat") then
				registry.QuestService:Signal("Rescue:AshCat", player, self.spot.Position)
				say(player, self.display, { "Mrrow! Ash scrambles out of the smoky tent and shakes the soot off.", "Ash bumps your flipper with a grateful head-boop." }, "happy")
				happyBurst(self.model.Head)
				-- move Ash to a safe sunny spot by the fire ring; he wanders the camp after
				self.model:PivotTo(groundedPivot(self.model, self.spot.Position.X + 6, self.spot.Position.Z + 8))
				self.patrolEnabled = true
			else
				say(player, self.display, { "Purrrr. Ash leans into your flipper, warm and safe." }, "happy")
			end
		end,
	},
	RangerMaple = {
		display = "Ranger Maple",
		build = function(cf, parent) return buildHuman(cf, parent, { name = "RangerMaple", shirt = Color3.fromRGB(90, 120, 80), hat = Color3.fromRGB(120, 90, 60) }) end,
		prompt = { action = "Talk", hold = 0.4 },
		onTrigger = function(self, player)
			if not done(player, "Talk:RangerMaple") then
				say(player, self.display, {
					"A penguin! You must be from the old firehouse across the river.",
					"A strange storm swept through. Now memory fires keep sparking, and the forest spirits are… troubled.",
					"They aren't bad — just hurting. Help them remember what they love, and the way home will open.",
					"Take my med kit. The woods gate is open — follow the path north!",
				}, "warm")
				registry.QuestService:Signal("Talk:RangerMaple", player)
				registry.InventoryService:GrantTool(player, "MedKit")
			else
				say(player, self.display, { "The spirits calm a little more each time you help. Keep going, little one." }, "warm")
			end
		end,
	},
	Mossmitt = {
		display = "Mossmitt",
		build = buildMossSpirit,
		prompt = { action = "Talk", hold = 0.6 },
		doneKey = "SpiritHelped:Mossmitt",
		onTrigger = function(self, player)
			if not done(player, "SpiritHelped:Mossmitt") and registry.QuestService:CountQuestItem(player, "Mitten") >= 3 then
				registry.QuestService:ConsumeQuestItems(player, "Mitten", 3)
				registry.QuestService:Signal("SpiritHelped:Mossmitt", player, self.spot.Position)
				say(player, self.display, {
					"…warm. Warm paws. I remember now!",
					"I kept the lost-and-found by the old trail. Every mitten went home with warm hands.",
					"Thank you, little warden. The roots will open your way to the park.",
				}, "happy")
				happyBurst(self.model.Head, Color3.fromRGB(190, 240, 170))
				-- mittens appear on its paws (once, even when several friends help in co-op)
				if not self.model:FindFirstChild("WornMitten1") then
					local cf = self.model:GetPivot()
					for i, c in ipairs({ Color3.fromRGB(200, 80, 90), Color3.fromRGB(90, 110, 200), Color3.fromRGB(220, 180, 80) }) do
						mp{name="WornMitten"..i, size=Vector3.new(0.8, 0.5, 1), cf=cf*CFrame.new(-1.4 + i*0.9, 0.6, -1.2), color=c, mat=Enum.Material.Fabric, parent=self.model}
					end
				end
			elseif not done(player, "SpiritHelped:Mossmitt") then
				say(player, self.display, {
					"Mmm… cold. So cold. Something is missing…",
					"Three little warmths, lost in the woods. By the water… in the old log… up the stones…",
				}, "sad")
			else
				say(player, self.display, { "Warm paws, warm heart. Safe travels, little warden." }, "happy")
			end
		end,
	},
	WardenBram = {
		display = "Warden Bram",
		build = function(cf, parent) return buildHuman(cf, parent, { name = "WardenBram", shirt = Color3.fromRGB(140, 100, 60), pants = Color3.fromRGB(60, 66, 80), hat = Color3.fromRGB(80, 100, 80) }) end,
		prompt = { action = "Talk", hold = 0.4 },
		onTrigger = function(self, player)
			local s = stageAt(player)
			if not done(player, "Talk:WardenBram") then
				say(player, self.display, {
					"Well I'll be — a firehouse penguin, waddling through my park!",
					"It's been chaos: a cooking fire by the picnic lawn, a poor dizzy fellow, and our snack vendor… well, you'll see.",
					"Take this fire blanket. Smother that cooking fire first, would you?",
				}, "warm")
				registry.QuestService:Signal("Talk:WardenBram", player)
				registry.InventoryService:GrantTool(player, "FireBlanket")
			elseif s == "branch" then
				say(player, self.display, { "That old branch on Alder Street won't move itself. Give it a few good chops!" }, "warm")
			else
				say(player, self.display, { "The park feels brighter already. You're a natural, little one." }, "warm")
			end
		end,
	},
	Picnicker = {
		display = "Theo",
		build = function(cf, parent) return buildHuman(cf, parent, { name = "Picnicker", shirt = Color3.fromRGB(200, 150, 90) }) end,
		prompt = { action = "Talk", hold = 0.4 },
		treatSignal = "Rescue:Picnicker",
		onTrigger = function(self, player)
			if done(player, "Rescue:Picnicker") then
				say(player, self.display, { "Good as new thanks to you! Best picnic rescue ever." }, "happy")
			elseif not done(player, "FireOut:Park_CookFire") then
				say(player, self.display, { "Cough… the grill flared up! Careful!", "Woah… the smoke's made me dizzy…" }, "worried")
			else
				say(player, self.display, { "Woah… the smoke made me dizzy… my head's spinning…", "(Use your Med Kit right beside Theo!)" }, "worried")
			end
		end,
		onTreated = function(self, player)
			say(player, self.display, { "Phew! The dizziness is gone. You're a proper little medic!" }, "happy")
			happyBurst(self.model.Head)
		end,
	},
	Marla = {
		display = "Frantic Squirrel",
		build = function(cf, parent)
			local m = buildSquirrel(cf, parent)
			m.Name = "Marla"
			return m
		end,
		prompt = { action = "Talk", hold = 0.5 },
		doneKey = "SpiritHelped:Marla",
		onTrigger = function(self, player)
			if not done(player, "SpiritHelped:Marla") and registry.QuestService:CountQuestItem(player, "RecipeBook") >= 1 then
				registry.QuestService:ConsumeQuestItems(player, "RecipeBook", 1)
				registry.QuestService:Signal("SpiritHelped:Marla", player, self.spot.Position)
				say(player, "Marla", {
					"The squirrel clutches the recipe book… and suddenly remembers pancakes, cocoa, summer lemonade.",
					"In a swirl of leaves, Marla is herself again!",
					"\"My recipes! My kiosk! Oh, thank you, dear. First snack's on the house — well, cheap.\"",
				}, "happy")
				-- transform: squirrel -> human vendor
				happyBurst(self.model.Head, Color3.fromRGB(255, 210, 130))
				local pivot = self.model:GetPivot()
				self.model:Destroy()
				self.model = buildHuman(pivot, workspace.NPCs, { name = "Marla", shirt = Color3.fromRGB(190, 90, 90), pants = Color3.fromRGB(90, 70, 60), hair = "bun", apron = Color3.fromRGB(240, 230, 210) })
				local body = self.model:FindFirstChild("Torso")
				if body then self.model.PrimaryPart = body end
				nameTag(self.model, "Marla", Color3.fromRGB(255, 220, 180))
				self:attachPrompt()
			elseif not done(player, "SpiritHelped:Marla") then
				say(player, self.display, {
					"The squirrel chitters anxiously, guarding the shuttered snack kiosk.",
					"It keeps sketching little rectangles in the dust… like pages. Maybe it lost a book?",
				}, "worried")
			else
				say(player, "Marla", { "Welcome back, dear! Fresh snacks at the kiosk, penguin discount included." }, "happy")
			end
		end,
	},
	Nora = {
		display = "Nora",
		build = function(cf, parent) return buildHuman(cf, parent, { name = "Nora", shirt = Color3.fromRGB(150, 110, 170), pants = Color3.fromRGB(80, 80, 92) }) end,
		prompt = { action = "Check on", hold = 0.8 },
		doneKey = "Rescue:Nora",
		onTrigger = function(self, player)
			if done(player, "Rescue:Nora") then
				say(player, self.display, { "I've opened every window. Fresh air at last!" }, "happy")
			elseif not done(player, "FireOut:Apt_StoveFire") then
				say(player, self.display, { "Cough! The stove caught while I was napping — smother it, please!" }, "worried")
			else
				registry.QuestService:Signal("Rescue:Nora", player, self.spot.Position)
				say(player, self.display, {
					"You put it out! My hero — my tiny, waddling hero.",
					"Here — take the building's hose nozzle. It clips onto any live hydrant.",
					"There's a big fire on Harbor Lane. The hydrant there still works!",
				}, "happy")
				registry.InventoryService:GrantTool(player, "Hose")
				happyBurst(self.model.Head)
			end
		end,
	},
	Cindercoo = {
		display = "Cindercoo",
		build = buildPigeonSpirit,
		prompt = { action = "Talk", hold = 0.6 },
		doneKey = "SpiritHelped:Cindercoo",
		onTrigger = function(self, player)
			if not done(player, "SpiritHelped:Cindercoo") and registry.QuestService:CountQuestItem(player, "ClockGear") >= 1 then
				registry.QuestService:ConsumeQuestItems(player, "ClockGear", 1)
				registry.QuestService:Signal("SpiritHelped:Cindercoo", player, self.spot.Position)
				say(player, self.display, {
					"Coo… coo! The gear clicks into place behind the clock face.",
					"Cindercoo puffs up proudly. For years it kept the station clock running — and it never missed a chime.",
					"BONG! The old clock rings across the rooftops. A folding stair unfurls below.",
				}, "happy")
				happyBurst(self.model.Head, Color3.fromRGB(255, 190, 120))
			elseif not done(player, "SpiritHelped:Cindercoo") then
				say(player, self.display, {
					"Coo… coo… the soot-pigeon circles the silent clock, searching.",
					"Something round and toothed is missing. It glints somewhere on the rooftops…",
				}, "sad")
			else
				say(player, self.display, { "Coo! The clock ticks, the town breathes. All is well." }, "happy")
			end
		end,
	},
	OldSpan = {
		display = "Old Span",
		build = buildBridgeSpirit,
		prompt = { action = "Talk", hold = 0.6 },
		doneKey = "SpiritHelped:OldSpan",
		onTrigger = function(self, player)
			if not done(player, "SpiritHelped:OldSpan") and registry.QuestService:CountQuestItem(player, "Memento") >= 3 then
				registry.QuestService:ConsumeQuestItems(player, "Memento", 3)
				registry.QuestService:Signal("SpiritHelped:OldSpan", player, self.spot.Position)
				say(player, self.display, {
					"A ticket… a postcard… a little boat. I carried them all, once.",
					"I remember every traveler who ever crossed me. And now… I remember myself. I am the crossing.",
					"Rest your flippers, little traveler. Your walkway is lowering now.",
				}, "happy")
				happyBurst(self.model.Head, Color3.fromRGB(180, 220, 255))
			elseif not done(player, "SpiritHelped:OldSpan") then
				say(player, self.display, {
					"I know your face, small one. I know every face that crosses… but whose face is mine?",
					"Travelers dropped little treasures along my waterfront. Bring me three, and perhaps I'll remember.",
				}, "sad")
			else
				say(player, self.display, { "The far shore misses you already. Cross whenever you like." }, "happy")
			end
		end,
	},
	Sam = {
		display = "Sam",
		build = function(cf, parent) return buildHuman(cf, parent, { name = "Sam", shirt = Color3.fromRGB(200, 130, 60), pants = Color3.fromRGB(70, 76, 90), helmet = Color3.fromRGB(230, 190, 60) }) end,
		prompt = { action = "Talk", hold = 0.4 },
		treatSignal = "Rescue:Sam",
		doneKey = "Rescue:Sam",
		onTrigger = function(self, player)
			if done(player, "Rescue:Sam") then
				say(player, self.display, { "Ladder's open! Straight up to the firehouse yard. Good luck up there — it's… strange." }, "warm")
			elseif not done(player, "DebrisCleared:TunnelBeam") then
				say(player, self.display, { "Hey! Down here! A beam came down and I'm stuck behind it.", "Those chopping sounds… you have an axe? Get me out of here!" }, "worried")
			else
				say(player, self.display, { "Ow… my shin took a knock. Got anything in that med kit?" }, "worried")
			end
		end,
		onTreated = function(self, player)
			say(player, self.display, { "That's the stuff! Right — the exit ladder is this way. I'll unlock the grate." }, "happy")
			happyBurst(self.model.Head)
		end,
	},
	Watchkeeper = {
		display = "The Watchkeeper",
		build = buildGuardian,
		prompt = { action = "Approach", hold = 1.2 },
		doneKey = "SpiritHelped:Watchkeeper",
		doneAction = "Talk",
		onTrigger = function(self, player)
			local QS = registry.QuestService
			if QS:SignalCount(player, "MemoryFireOut") < 4 and not done(player, "SpiritHelped:Watchkeeper") then
				say(player, self.display, {
					"A huge shape of soot and cinders looms over the yard. Its eyes are tired embers.",
					"\"Stay back… everything I guard… burns. It always burns…\"",
					"(Its fear feeds the four memory fires. Put them out with the hose!)",
				}, "mysterious")
			elseif not done(player, "MemoriesPlaced") and not done(player, "SpiritHelped:Watchkeeper") then
				if QS:CountQuestItem(player, "Memory") >= 3 then
					say(player, self.display, { "\"Those things you carry… they hum with warm days. Bring them to my shrine.\"" }, "sad")
				else
					say(player, self.display, {
						"The flames are gone, but the great spirit still trembles.",
						"\"I was… keeper of this watch. But I forgot what I kept safe. I only remember the fear.\"",
						"(Find what the firehouse remembers: the photo, the bell, the helmet.)",
					}, "sad")
				end
			elseif not done(player, "SpiritHelped:Watchkeeper") then
				registry.QuestService:Signal("SpiritHelped:Watchkeeper", player, self.spot.Position)
				say(player, self.display, {
					"The Watchkeeper leans over the shrine. The photo. The bell. The helmet.",
					"\"…I remember. I am the firehouse watch. I kept the crew safe every night. I kept YOU safe, little one.\"",
					"The fear drains away like smoke in sunlight. Warm gold light spills across the yard.",
					"\"Welcome home, small warden. Welcome home.\"",
				}, "happy")
				self:calmGuardian()
			else
				say(player, self.display, { "The great spirit rests by the firehouse, glowing softly like a hearth." }, "happy")
			end
		end,
		calmGuardian = function(self)
			local m = self.model
			if not m or self.calmed then return end
			self.calmed = true
			local flame = m.Head:FindFirstChild("GuardianFlame")
			if flame then flame:Destroy() end
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					local target
					if d.Name == "EyeL" or d.Name == "EyeR" then target = Color3.fromRGB(170, 220, 255)
					elseif d.Name == "CrackA" or d.Name == "CrackB" then target = Color3.fromRGB(255, 215, 140)
					else target = Color3.fromRGB(96, 88, 84) end
					TweenService:Create(d, TweenInfo.new(3), { Color = target }):Play()
				elseif d:IsA("PointLight") then
					TweenService:Create(d, TweenInfo.new(3), { Color = Color3.fromRGB(255, 214, 150), Brightness = 1 }):Play()
				end
			end
			wisps(m.Body, Color3.fromRGB(255, 225, 160), 6, 0.8)
			GuardianScene:FireAllClients({ position = m.Body.Position })
		end,
	},
}

-- ============ the wider world: new friends & gentle spirits ============
DEFS.Sudsy = {
	display = "Sudsy",
	build = buildOtter,
	prompt = { action = "Talk", hold = 0.4 },
	onTrigger = function(self, player)
		local lines = {
			{ "Welcome to the old lido! Three slides, zero rules. Well — one rule: land with style.", "The tall one's called The Plunge. I've never screamed. Twice." },
			{ "Belly-slide down the chutes for extra speed. It's science. Otter science.", "There's something shiny up on the top platform, if you make the climb." },
			{ "The fish in the bay are quick — chase them while swimming and snap them up!" },
		}
		say(player, self.display, lines[math.random(#lines)], "happy")
	end,
}
DEFS.Glint = {
	display = "Glint",
	build = buildFrostSprite,
	prompt = { action = "Talk", hold = 0.5 },
	onTrigger = function(self, player)
		local lines = {
			{ "The Hollow keeps every winter that ever was. Skate softly — they're sleeping.", "Ride the chutes onto the rink. Belly first! The ice likes penguins best." },
			{ "Something sleeps in the far snowbank. The ice remembers speed… be fast, and you'll wake it." },
			{ "I polished the rink myself. With my face. Don't ask." },
		}
		say(player, self.display, lines[math.random(#lines)], "mysterious")
	end,
}
DEFS.GardenerFern = {
	display = "Gardener Fern",
	build = function(cf, parent) return buildHuman(cf, parent, { name = "GardenerFern", shirt = Color3.fromRGB(104, 130, 92), pants = Color3.fromRGB(84, 74, 60), hair = "bun", hairColor = Color3.fromRGB(168, 160, 150), apron = Color3.fromRGB(120, 104, 80), hat = Color3.fromRGB(150, 132, 96) }) end,
	prompt = { action = "Talk", hold = 0.4 },
	doneKey = "GardenBloomed",
	onTrigger = function(self, player)
		local QS = registry.QuestService
		if done(player, "GardenBloomed") then
			say(player, self.display, { "Look at it bloom! Bees came back the very same hour.", "You've got soil in your heart, little one. Highest compliment I know." }, "happy")
		elseif QS:SignalCount(player, "Plant:Seed") > 0 then
			say(player, self.display, { "They're sprouting already! " .. QS:SignalCount(player, "Plant:Seed") .. " of " .. 20 .. " in the ground.", "More seeds are scattered wherever the wind took them — gleaming little things." }, "warm")
		else
			say(player, self.display, {
				"This bed's been bare since the storm. Breaks my heart every morning.",
				"The wind scattered my seed pouch across the whole city — twenty seeds, gleaming like little lanterns.",
				"Bring what you find and plant them here. The park misses its colors.",
			}, "warm")
		end
	end,
}
DEFS.BakerLena = {
	display = "Baker Lena",
	build = function(cf, parent) return buildHuman(cf, parent, { name = "BakerLena", shirt = Color3.fromRGB(196, 186, 168), pants = Color3.fromRGB(90, 78, 70), hair = "bun", hairColor = Color3.fromRGB(88, 60, 44), apron = Color3.fromRGB(235, 228, 214) }) end,
	prompt = { action = "Talk", hold = 0.4 },
	onTrigger = function(self, player)
		local lines = {
			{ "Morning, little firefighter! The ovens never went out, you know. Not once, all through the storm.", "Warm bread waits by the door — help yourself when you're peckish." },
			{ "A penguin that fights fires and a baker that makes them behave. We're a fine pair." },
			{ "Marla's kiosk is back open in the park! Tell her Lena still owes her a pie." },
		}
		say(player, self.display, lines[math.random(#lines)], "warm")
	end,
}
DEFS.SailorMoss = {
	display = "Old Moss",
	build = function(cf, parent) return buildHuman(cf, parent, { name = "SailorMoss", shirt = Color3.fromRGB(78, 96, 120), pants = Color3.fromRGB(60, 66, 80), hair = "short", hairColor = Color3.fromRGB(200, 200, 200), hat = Color3.fromRGB(58, 70, 88), satchel = true }) end,
	prompt = { action = "Talk", hold = 0.4 },
	onTrigger = function(self, player)
		local caught = registry.QuestService:SignalCount(player, "Catch:Fish")
		if caught == 0 then
			say(player, self.display, {
				"Fifty years I fished this river. The trick? Be faster than the fish. That's the whole trick.",
				"A penguin ought to manage it — dive in and chase the silver flashes.",
			}, "warm")
		elseif not done(player, "StatueFreed") then
			say(player, self.display, {
				caught .. " fish so far? Not bad, flippers.",
				"You know the old stone penguin up the bank? Sailors used to leave it a fish for luck.",
				"They say it's been hungry three hundred years. Imagine the luck if someone filled it up proper.",
			}, "mysterious")
		else
			say(player, self.display, { "So the stone bird flies its colors again. Three hundred years of luck, kid — you've earned every fish of it." }, "happy")
		end
	end,
}
DEFS.JunoKid = {
	display = "Juno",
	build = function(cf, parent) return buildKid(cf, parent, { name = "JunoKid", shirt = Color3.fromRGB(150, 120, 170), cap = Color3.fromRGB(90, 110, 160) }) end,
	prompt = { action = "Talk", hold = 0.3 },
	onTrigger = function(self, player)
		local lines = {
			{ "A REAL penguin! Bee! BEE! Come see! …She's hiding again. She's SO good at hiding." },
			{ "I saw a little pale spirit in the woods once. It clicked like knuckles and vanished. Nobody believes me!" },
			{ "Can you really slide on your belly?? Show me show me show me!" },
		}
		say(player, self.display, lines[math.random(#lines)], "happy")
	end,
}
DEFS.BeeKid = {
	display = "Bee",
	build = function(cf, parent) return buildKid(cf, parent, { name = "BeeKid", shirt = Color3.fromRGB(196, 168, 100), hairColor = Color3.fromRGB(40, 32, 28) }) end,
	prompt = { action = "Talk", hold = 0.3 },
	onTrigger = function(self, player)
		local lines = {
			{ "Shhh! I'm winning hide-and-seek. I've been winning for two days." },
			{ "You found me… you're good. Okay new game: you hide, and I count to a MILLION." },
		}
		say(player, self.display, lines[math.random(#lines)], "happy")
	end,
}
DEFS.FernElk = {
	display = "Sirelen",
	build = buildFernElk,
	prompt = { action = "Approach", hold = 0.8 },
	doneKey = "SpiritHelped:FernElk",
	doneAction = "Talk",
	onTrigger = function(self, player)
		local QS = registry.QuestService
		if not done(player, "SpiritHelped:FernElk") and QS:CountQuestItem(player, "AntlerBlossom") >= 3 then
			QS:ConsumeQuestItems(player, "AntlerBlossom", 3)
			QS:Signal("SpiritHelped:FernElk", player, self.spot.Position)
			registry.PlayerStateService:AddSparks(player, 60, "Sirelen's blessing")
			registry.PlayerStateService:AwardBadge(player, "Elk's Blessing")
			say(player, self.display, {
				"The great elk lowers its head. You tuck the three blossoms among the moss of its antlers.",
				"Light moves under its fur like sun through leaves. Somewhere far off, a whole meadow sighs.",
				"\"The forest walks where I walk, small warden. Now a little of your kindness walks with it.\"",
			}, "happy")
			happyBurst(self.model:FindFirstChild("Head"), Color3.fromRGB(190, 230, 180))
			-- the antlers bloom (once, even when several friends help in co-op)
			if not self.model:FindFirstChild("AntlerBloom1") then
				local cfm = self.model:GetPivot()
				for i = 1, 6 do
					local a = i / 6 * math.pi * 2
					mp{name="AntlerBloom"..i, size=Vector3.new(0.26, 0.18, 0.26), cf=cfm*CFrame.new(math.cos(a)*0.9, 3.6 + (i%3)*0.4, -2.5 + math.sin(a)*0.5), color=Color3.fromRGB(226, 208, 140), mat=Enum.Material.Neon, ball=true, parent=self.model}
				end
			end
		elseif not done(player, "SpiritHelped:FernElk") then
			say(player, self.display, {
				"A tall shape stands at the wood's edge, moss draped over old antlers. It watches you calmly.",
				"\"The storm shook the blossoms from my crown. Three of them, pale as morning.\"",
				"\"They fell among the ferns of these woods. I cannot kneel to look. Would you?\"",
			}, "mysterious")
		else
			say(player, self.display, { "The blossoms hum in the old moss. The woods walk easy tonight." }, "happy")
		end
	end,
}
DEFS.MistHeron = {
	display = "The Mist Heron",
	build = buildHeron,
	prompt = { action = "Watch", hold = 0.6 },
	onTrigger = function(self, player)
		local lines = {
			{ "The heron stands perfectly still. So still that the river forgets it's there.", "One yellow eye follows you. It approves. Probably." },
			{ "\"Patience,\" the heron seems to say, without saying anything at all." },
			{ "It lifts one foot, considers the matter deeply, and puts it back down." },
		}
		say(player, self.display, lines[math.random(#lines)], "mysterious")
	end,
}

-- the firefighter family (post-finale)
for i = 1, 3 do
	local shirts = { Color3.fromRGB(190, 70, 60), Color3.fromRGB(190, 70, 60), Color3.fromRGB(160, 60, 55) }
	local names = { "Captain Rosa", "Firefighter Jude", "Firefighter Kit" }
	local lines = {
		{ "There you are! We searched every street for you, little one.", "The Watchkeeper kept the firehouse standing until you came home. You did the rest." },
		{ "You waddled the WHOLE way? Across the bridge and everything?", "That's it — you're officially crew now. Tiny helmet and all." },
		{ "The kettle's on and the pole is polished.", "Home's not a building, you know. It's everyone in it — including you." },
	}
	local gradLines = {
		{ "That's FIREFIGHTER Pip to everyone now. Captain's orders!", "The whole city's talking about the little penguin who brought the light back." },
		{ "The hat suits you. Took me two years to earn mine — you did it in one storm.", "Race you down the pole later. Loser polishes the engine." },
		{ "Kettle's on, crew's home, and the watch has its keeper again.", "Rest those flippers, hero. Tomorrow we train the NEXT junior firefighter." },
	}
	DEFS["Firefighter" .. i] = {
		display = names[i],
		hiddenUntil = "FirehouseRestored",
		build = function(cf, parent) return buildHuman(cf, parent, { name = "Firefighter" .. i, shirt = shirts[i], pants = Color3.fromRGB(60, 62, 70), helmet = Color3.fromRGB(220, 60, 50) }) end,
		prompt = { action = "Talk", hold = 0.4 },
		onTrigger = function(self, player)
			if registry.QuestService:IsCompleted(player) then
				say(player, self.display, gradLines[i], "happy")
			else
				say(player, self.display, lines[i], "happy")
			end
		end,
	}
end

-- ============ the graduation ceremony (story finale) ============
-- Called by QuestService the moment the final stage completes. The crew
-- gathers around Pip, the training is revealed, and the junior firefighter
-- becomes a full-fledged one — helmet and all.
function NPCService:RunGraduation(player)
	task.spawn(function()
		local Celebration = RS.Remotes.Celebration
		local Credits = RS.Remotes.Credits
		Celebration:FireClient(player, { kind = "story", title = "You made it home!", detail = "The firehouse glows warm again." })
		Notify:FireAllClients({ text = "\u{2B50} " .. player.Name .. " reunited with the firehouse family!", kind = "story" })
		task.wait(3.5)
		-- the crew gathers around Pip
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local offsets = { CFrame.new(-4, 0, -2), CFrame.new(4, 0, -2), CFrame.new(0, 0, -5) }
			for i = 1, 3 do
				local npc = npcs["Firefighter" .. i]
				if npc and npc.model and npc.model.Parent then
					local targetPos = (CFrame.new(root.Position) * offsets[i]).Position
					npc.model:PivotTo(groundedPivot(npc.model, targetPos.X, targetPos.Z, CFrame.lookAt(targetPos, root.Position).Rotation))
					happyBurst(npc.model:FindFirstChild("Head"))
				end
			end
		end
		task.wait(1)
		say(player, "Captain Rosa", {
			"\"Crew! Fall in! Our smallest firefighter has come the longest way home.\"",
			"\"Pip — did you think we hadn't noticed? Every drill on the training tower. Every knot, every ladder, every bucket brigade.\"",
			"\"You've been training to be one of us your whole little life. And tonight you crossed a whole city of fire and fear to prove it.\"",
			"\"You doused the flames. You freed the spirits. You saved this city, junior firefighter. So… no more 'junior'.\"",
			"Captain Rosa kneels and settles a bright red helmet over your head. It fits perfectly.",
			"\"By the warmth of the watch and the whole firehouse family — welcome, FIREFIGHTER Pip!\"",
		}, "happy")
		-- the helmet is real: earned, owned, equipped
		local data = registry.DataService:Get(player)
		if data then
			data.cosmetics.owned["FirefighterHat"] = true
			data.cosmetics.equippedHat = "FirefighterHat"
			registry.DataService:MarkDirty(player)
			registry.InventoryService:ApplyCosmetics(player)
		end
		registry.PlayerStateService:AwardBadge(player, "Full-Fledged Firefighter")
		-- confetti from the whole crew
		if root then
			for i = 1, 3 do
				local npc = npcs["Firefighter" .. i]
				local head = npc and npc.model and npc.model:FindFirstChild("Head")
				if head then happyBurst(head, Color3.fromRGB(255, 210, 120)) end
			end
		end
		task.wait(16)
		if player.Parent then
			RS.Remotes.Credits:FireClient(player, {})
		end
	end)
end

-- prompts relax for any completion, however the credit arrived (prompt, co-op
-- assist, TestHook) — QuestService calls this after recording each signal
function NPCService:RefreshPromptsFor(player)
	for _, npc in pairs(npcs) do
		if npc.refreshPromptFor then
			pcall(function() npc:refreshPromptFor(player) end)
		end
	end
end

-- ============ treat (med kit) support ============
function NPCService:TryTreatNearby(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	for id, npc in pairs(npcs) do
		local def = npc.def
		-- anyone with a treat signal can be treated once, whenever you find them hurt
		if def.treatSignal and not registry.QuestService:HasSignalled(player, def.treatSignal) then
			local ref = npc.model and npc.model:FindFirstChild("Head")
			if ref and (ref.Position - root.Position).Magnitude <= 10 then
				registry.QuestService:Signal(def.treatSignal, player, ref.Position)
				if def.onTreated then def.onTreated(npc, player) end
				if npc.refreshPromptFor then npc:refreshPromptFor(player) end
				return true
			end
		end
	end
	return false
end

-- ============ setup ============
local function setupNpc(spot)
	local id = spot:GetAttribute("NpcId")
	local def = DEFS[id]
	if not def then
		warn("[NPCService] no definition for NpcId " .. tostring(id))
		return
	end
	local npc = { def = def, spot = spot, calmed = false, display = def.display }
	-- ground the character precisely: raycast down from above the marker so NPCs
	-- stand on the real surface (terrain height varies between regions)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace.NPCs, spot }
	params.RespectCanCollide = true -- don't spawn anyone on a tree canopy
	local hit = workspace:Raycast(spot.Position + Vector3.new(0, 12, 0), Vector3.new(0, -60, 0), params)
	local groundY = hit and hit.Position.Y or (spot.Position.Y - 1)
	local yaw = spot:GetAttribute("FaceYaw") or 0
	local cf = CFrame.new(spot.Position.X, groundY, spot.Position.Z) * CFrame.Angles(0, math.rad(yaw), 0)
	npc.model = def.build(cf, workspace.NPCs)
	ensurePrimary(npc.model)
	nameTag(npc.model, def.display)

	-- once a character's story moment is over, their prompt verb relaxes
	-- ("Rescue" → "Pet", "Check on" → "Talk") so nobody looks stuck in trouble
	function npc:refreshPromptFor(player)
		if not (def.doneKey and self.promptInstance) then return end
		if registry.QuestService:HasSignalled(player, def.doneKey) then
			self.promptInstance.ActionText = def.doneAction or "Talk"
			self.promptInstance.HoldDuration = 0.4
		end
	end

	function npc:attachPrompt()
		local target = self.model:FindFirstChild("Body") or self.model:FindFirstChild("Torso") or self.model:FindFirstChildWhichIsA("BasePart")
		if not target then return end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = def.prompt.action
		prompt.ObjectText = def.display
		prompt.HoldDuration = def.prompt.hold
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = target
		self.promptInstance = prompt
		prompt.Triggered:Connect(function(player)
			local ok, err = pcall(def.onTrigger, npc, player)
			if not ok then warn("[NPCService] " .. id .. " trigger error: " .. tostring(err)) end
			npc:refreshPromptFor(player)
		end)
	end

	-- copy def methods onto instance for self-calls
	for k, v in pairs(def) do
		if type(v) == "function" and k ~= "build" and k ~= "onTrigger" and k ~= "onTreated" then
			npc[k] = v
		end
	end

	npc:attachPrompt()
	npcs[id] = npc

	-- hidden-until NPCs (the firefighter family)
	if def.hiddenUntil then
		for _, d in ipairs(npc.model:GetDescendants()) do
			if d:IsA("BasePart") then
				d:SetAttribute("OrigT", d.Transparency)
				d.Transparency = 1
			elseif d:IsA("ProximityPrompt") then
				d.Enabled = false
			elseif d:IsA("BillboardGui") then
				d.Enabled = false
			end
		end
		task.spawn(function()
			while npc.model.Parent do
				if registry.WorldService:IsUnlocked(def.hiddenUntil) then
					for _, d in ipairs(npc.model:GetDescendants()) do
						if d:IsA("BasePart") then
							d.Transparency = d:GetAttribute("OrigT") or 0
						elseif d:IsA("ProximityPrompt") then
							d.Enabled = true
						elseif d:IsA("BillboardGui") then
							d.Enabled = true
						end
					end
					happyBurst(npc.model:FindFirstChild("Head") or npc.model:FindFirstChildWhichIsA("BasePart"))
					break
				end
				task.wait(4)
			end
		end)
	end
end

-- ============ patrols (gentle server-side wandering) ============
-- Anchored models are pivoted along waypoints with a little walk-bob.
-- The "Patrolling" attribute tells the client ambience script to hold off.
local PATROLS = {
	-- keep every point clear of the bandstand footprint (x -111..-89, z -16..6):
	-- the patrol ground-raycast would otherwise walk him onto the roof
	WardenBram = { speed = 3.5, points = { Vector3.new(-100, 2, -23), Vector3.new(-92, 2, -26), Vector3.new(-108, 2, -27) } },
	Firefighter2 = { speed = 5, points = { Vector3.new(706, 0, 2), Vector3.new(690, 0, 22), Vector3.new(672, 0, 36), Vector3.new(692, 0, 10) } },
	Firefighter3 = { speed = 4, points = { Vector3.new(697, 0, 8), Vector3.new(716, 0, -28), Vector3.new(738, 0, -6) } },
	AshCat = { speed = 6, gated = true, points = { Vector3.new(-632, 0, -470), Vector3.new(-616, 0, -434), Vector3.new(-602, 0, -444), Vector3.new(-622, 0, -462) } },
}

local function runPatrol(npc, def)
	task.spawn(function()
		local i = 1
		while true do
			if not (npc.model and npc.model.Parent) then break end
			if def.gated and not npc.patrolEnabled then
				task.wait(2)
			else
				local pivot = npc.model:GetPivot()
				local from = pivot.Position
				local target = def.points[i]
				local flat = Vector3.new(target.X, from.Y, target.Z)
				local dist = (flat - from).Magnitude
				if dist > 1 then
					npc.model:SetAttribute("Patrolling", true)
					local look = CFrame.lookAt(from, flat)
					local dur = dist / def.speed
					local t0 = os.clock()
					-- how high the pivot rides above the model's feet (computed once per hop)
					local bboxCF, bboxSize = npc.model:GetBoundingBox()
					local pivotAboveBottom = from.Y - (bboxCF.Position.Y - bboxSize.Y / 2)
					while os.clock() - t0 < dur do
						if not npc.model.Parent then return end
						local a = math.clamp((os.clock() - t0) / dur, 0, 1)
						local bob = math.abs(math.sin(a * dist * 1.8)) * 0.14
						local p = from:Lerp(flat, a)
						-- follow the real surface so nobody ever wades through the ground
						local g = surfaceYAt(p.X, p.Z)
						local y = g and (g + pivotAboveBottom) or p.Y
						npc.model:PivotTo(CFrame.new(p.X, y + bob, p.Z) * look.Rotation)
						task.wait(0.06)
					end
					npc.model:SetAttribute("Patrolling", false)
				end
				i = (i % #def.points) + 1
				task.wait(2.5 + math.random() * 4)
			end
		end
	end)
end

function NPCService:Init(reg)
	registry = reg
	Dialogue = RS.Remotes.Dialogue
	Notify = RS.Remotes.Notify
	GuardianScene = RS.Remotes.GuardianScene
end

function NPCService:Start()
	for _, spot in ipairs(CS:GetTagged("NPCSpot")) do
		local ok, err = pcall(setupNpc, spot)
		if not ok then warn("[NPCService] setup failed: " .. tostring(err)) end
	end
	for npcId, def in pairs(PATROLS) do
		local npc = npcs[npcId]
		if npc then runPatrol(npc, def) end
	end
	-- returning players: relax prompts for arcs they've already finished
	registry.DataService.PlayerLoaded.Event:Connect(function(player)
		for _, npc in pairs(npcs) do
			if npc.refreshPromptFor then
				pcall(function() npc:refreshPromptFor(player) end)
			end
		end
		-- Ash was already rescued in a past session: wander from the tent
		local ash = npcs.AshCat
		if ash and not ash.patrolEnabled and registry.QuestService:HasSignalled(player, "Rescue:AshCat") then
			ash.model:PivotTo(groundedPivot(ash.model, ash.spot.Position.X + 6, ash.spot.Position.Z + 8))
			ash.patrolEnabled = true
		end
	end)
end

return NPCService

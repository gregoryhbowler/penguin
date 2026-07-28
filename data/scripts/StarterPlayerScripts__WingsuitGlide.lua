-- WingsuitGlide: while the Wingsuit tool is equipped and Pip is falling, he
-- glides: steer with movement input (~10 s per flight), drift straight down
-- when idle. The charge refills the moment he lands or hits water. Client-side
-- like the belly-slide (cosmetic-scale advantage; all valuable state is server-
-- authoritative).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local GLIDE_SECONDS = 10
local GLIDE_SPEED = 34
local FALL_STEER = -7   -- gentle sink while steering
local FALL_IDLE = -13   -- faster drift straight down with no input

local function bind(char)
	local hum = char:WaitForChild("Humanoid", 10)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not (hum and root) then return end

	local gliding = false
	local charge = GLIDE_SECONDS
	local conn

	local function equippedWingsuit()
		local t = char:FindFirstChild("Wingsuit")
		return t ~= nil and t:IsA("Tool")
	end

	local trail
	local function setTrail(on)
		if on and not trail then
			trail = Instance.new("ParticleEmitter")
			trail.Name = "GlideTrail"
			trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			trail.Rate = 14
			trail.Lifetime = NumberRange.new(0.3, 0.6)
			trail.Speed = NumberRange.new(0.5)
			trail.Size = NumberSequence.new(0.35)
			trail.Color = ColorSequence.new(Color3.fromRGB(190, 220, 245))
			trail.Parent = root
		elseif not on and trail then
			trail:Destroy()
			trail = nil
		end
	end

	local function stopGlide()
		if not gliding then return end
		gliding = false
		char:SetAttribute("Gliding", false)
		setTrail(false)
		if conn then conn:Disconnect() conn = nil end
	end

	local function startGlide()
		if gliding or charge <= 0 then return end
		gliding = true
		char:SetAttribute("Gliding", true)
		setTrail(true)
		conn = RunService.Heartbeat:Connect(function(dt)
			if not (char.Parent and equippedWingsuit()) then stopGlide() return end
			local state = hum:GetState()
			if state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.Running
				or state == Enum.HumanoidStateType.Swimming or state == Enum.HumanoidStateType.Seated
				or state == Enum.HumanoidStateType.Climbing then
				charge = GLIDE_SECONDS -- landed: refill for the next leap
				stopGlide()
				return
			end
			charge -= dt
			if charge <= 0 then stopGlide() return end -- wings tire: normal fall
			local move = hum.MoveDirection
			if move.Magnitude > 0.1 then
				local flat = Vector3.new(move.X, 0, move.Z).Unit
				root.AssemblyLinearVelocity = flat * GLIDE_SPEED + Vector3.new(0, FALL_STEER, 0)
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
			else
				local v = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(v.X * 0.92, FALL_IDLE, v.Z * 0.92)
			end
		end)
	end

	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Freefall and equippedWingsuit() then
			startGlide()
		elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running
			or new == Enum.HumanoidStateType.Swimming or new == Enum.HumanoidStateType.Climbing then
			charge = GLIDE_SECONDS
			stopGlide()
		end
	end)
	char.ChildRemoved:Connect(function(c)
		if c.Name == "Wingsuit" then stopGlide() end
	end)
end

player.CharacterAdded:Connect(bind)
if player.Character then bind(player.Character) end
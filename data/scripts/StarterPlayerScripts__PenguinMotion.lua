-- PenguinMotion: procedural waddle/flap/bob for every penguin character in the server,
-- plus the local player's belly slide. Runs entirely on each client (zero network cost);
-- every client animates every penguin from its velocity, so all players see the waddle.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local CS = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.GameConfig)

local localPlayer = Players.LocalPlayer

-- rig cache: [Model] = {motors, baseC0s, phase}
local rigs = {}

local MOTOR_NAMES = { "RootJoint", "Neck", "LeftShoulder", "RightShoulder", "LeftHip", "RightHip" }

local function tryRegister(character)
	if rigs[character] then return end
	local hum = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (hum and root) then return end
	local motors = {}
	local baseC0 = {}
	for _, name in ipairs(MOTOR_NAMES) do
		local m = nil
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("Motor6D") and d.Name == name then m = d break end
		end
		if not m then return end -- not a penguin rig (or not loaded yet)
		motors[name] = m
		baseC0[name] = m.C0
	end
	rigs[character] = { motors = motors, base = baseC0, phase = 0, hum = hum, root = root }
end

local function unregister(character)
	rigs[character] = nil
end

local function watchPlayer(player)
	player.CharacterAdded:Connect(function(char)
		-- motors may stream in a beat later
		task.delay(0.2, function() tryRegister(char) end)
		char.AncestryChanged:Connect(function(_, parent)
			if not parent then unregister(char) end
		end)
	end)
	if player.Character then task.defer(tryRegister, player.Character) end
end

Players.PlayerAdded:Connect(watchPlayer)
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end

-- ---------------- diving tricks (from the bridge diving board) ----------------
-- Jumping off a tagged DivingBoard starts a dive (default: swan). While airborne,
-- W = front flip, A/D = barrel roll, S = cannonball. The server stamps the trick
-- as a character attribute so every client animates it.
local diveActive = false

local function nearDivingBoard(root)
	for _, board in ipairs(CS:GetTagged("DivingBoard")) do
		if board.Parent and (board.Position - root.Position).Magnitude < 12 then
			return true
		end
	end
	return false
end

-- ---- trick coach card: teaches the moves the moment you step onto the board ----
local trickGui = Instance.new("ScreenGui")
trickGui.Name = "TrickCoach"
trickGui.ResetOnSpawn = false
trickGui.Parent = localPlayer:WaitForChild("PlayerGui")
local trickCard = Instance.new("Frame")
trickCard.AnchorPoint = Vector2.new(0.5, 0)
trickCard.Position = UDim2.new(0.5, 0, 0, 132)
trickCard.Size = UDim2.new(0, 380, 0, 58)
trickCard.BackgroundColor3 = Color3.fromRGB(52, 62, 82)
trickCard.BackgroundTransparency = 0.12
trickCard.Visible = false
trickCard.Parent = trickGui
local tcCorner = Instance.new("UICorner") tcCorner.CornerRadius = UDim.new(0, 12) tcCorner.Parent = trickCard
local tcStroke = Instance.new("UIStroke") tcStroke.Color = Color3.fromRGB(110, 140, 190) tcStroke.Thickness = 2 tcStroke.Parent = trickCard
local trickLabel = Instance.new("TextLabel")
trickLabel.BackgroundTransparency = 1
trickLabel.Size = UDim2.fromScale(1, 1)
trickLabel.Font = Enum.Font.GothamMedium
trickLabel.TextSize = 14
trickLabel.TextWrapped = true
trickLabel.TextColor3 = Color3.fromRGB(235, 240, 250)
trickLabel.Text = UserInputService.TouchEnabled
	and "\u{1F93F} Dive time! Jump off the end of the board — tap Slide in the air to flip!"
	or "\u{1F93F} Dive time! Jump off the board, then in the air: W flip • A/D barrel roll • S cannonball"
trickLabel.Parent = trickCard
local trickCardUntil = 0
local function showTrickCard(seconds)
	trickCardUntil = os.clock() + seconds
	trickCard.Visible = true
end
task.spawn(function()
	while true do
		task.wait(0.5)
		if trickCard.Visible and os.clock() > trickCardUntil then trickCard.Visible = false end
		-- surface the coach card whenever Pip is standing near a diving board
		local char = localPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and not diveActive and nearDivingBoard(root) then
			showTrickCard(4)
		end
	end
end)

local function sendTrick(trick)
	RS.Remotes.ToolAction:FireServer("Trick", trick)
end

local function watchDives(char)
	local hum = char:WaitForChild("Humanoid", 10)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not (hum and root) then return end
	hum.StateChanged:Connect(function(_, new)
		if (new == Enum.HumanoidStateType.Jumping or new == Enum.HumanoidStateType.Freefall)
			and not diveActive and nearDivingBoard(root) then
			diveActive = true
			sendTrick("swan")
			showTrickCard(2.5) -- remind the moves while airborne
		elseif new == Enum.HumanoidStateType.Swimming or new == Enum.HumanoidStateType.Landed
			or new == Enum.HumanoidStateType.Running or new == Enum.HumanoidStateType.Seated then
			diveActive = false
		end
	end)
end
localPlayer.CharacterAdded:Connect(watchDives)
if localPlayer.Character then watchDives(localPlayer.Character) end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not diveActive then return end
	if input.KeyCode == Enum.KeyCode.W then sendTrick("flip")
	elseif input.KeyCode == Enum.KeyCode.S then sendTrick("cannonball")
	elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.D then sendTrick("roll")
	end
end)

-- ---------------- belly slide (local player only) ----------------
local sliding = false
local lastSlide = 0

local function baseSpeed(hum)
	return hum:GetAttribute("BaseWalkSpeed") or Config.WALK_SPEED
end

local function doSlide()
	local char = localPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	-- mid-dive, the Slide button performs a flip instead (touch-friendly tricks)
	if diveActive then
		sendTrick("flip")
		return
	end
	if sliding then return end
	if os.clock() - lastSlide < Config.SLIDE_COOLDOWN then return end
	if hum.MoveDirection.Magnitude < 0.1 then return end
	if hum:GetState() == Enum.HumanoidStateType.Swimming then return end
	sliding = true
	lastSlide = os.clock()
	hum.WalkSpeed = Config.SLIDE_SPEED
	task.delay(Config.SLIDE_DURATION, function()
		sliding = false
		if hum and hum.Parent then
			hum.WalkSpeed = baseSpeed(hum)
		end
	end)
end

ContextActionService:BindAction("BellySlide", function(_, state)
	if state == Enum.UserInputState.Begin then doSlide() end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("BellySlide", "Slide")
pcall(function()
	ContextActionService:SetPosition("BellySlide", UDim2.new(1, -170, 1, -140))
end)

-- ---------------- animation loop ----------------
local function lerpC0(motor, target, alpha)
	motor.C0 = motor.C0:Lerp(target, alpha)
end

RunService.Heartbeat:Connect(function(dt)
	for char, rig in pairs(rigs) do
		if not char.Parent then rigs[char] = nil continue end
		local hum, root = rig.hum, rig.root
		if not (hum.Parent and root.Parent) then rigs[char] = nil continue end

		local vel = root.AssemblyLinearVelocity
		local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local state = hum:GetState()
		local swimming = state == Enum.HumanoidStateType.Swimming
		local airborne = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
		-- skimming across ice fast enough reads as a belly slide for everyone
		local onIce = hum.FloorMaterial == Enum.Material.Ice or hum.FloorMaterial == Enum.Material.Glacier
		local isLocalSliding = (char == localPlayer.Character) and (sliding or (onIce and speed > 16))
		local trick = char:GetAttribute("Trick")

		-- belt-and-braces dive detection (StateChanged can be missed on scripted jumps):
		if char == localPlayer.Character then
			if airborne and not diveActive and nearDivingBoard(root) then
				diveActive = true
				sendTrick("swan")
			elseif diveActive and (swimming or (not airborne and speed < 0.5)) then
				diveActive = false
			end
		end

		rig.phase += dt * math.clamp(speed, 0, 40) * 0.55
		local s = math.sin(rig.phase * math.pi)
		local moving = speed > 0.5
		local alpha = math.clamp(dt * 10, 0, 1)

		local m, b = rig.motors, rig.base

		if trick and not swimming then
			-- diving trick animations (replicated to every client via the attribute)
			rig.trickPhase = (rig.trickPhase or 0) + dt
			local tp = rig.trickPhase
			if trick == "flip" then
				lerpC0(m.RootJoint, b.RootJoint * CFrame.Angles(-tp * math.rad(560), 0, 0), 1)
				lerpC0(m.LeftShoulder, b.LeftShoulder * CFrame.Angles(0, 0, math.rad(-70)), alpha)
				lerpC0(m.RightShoulder, b.RightShoulder * CFrame.Angles(0, 0, math.rad(70)), alpha)
			elseif trick == "roll" then
				lerpC0(m.RootJoint, b.RootJoint * CFrame.Angles(math.rad(-30), 0, tp * math.rad(480)), 1)
				lerpC0(m.LeftShoulder, b.LeftShoulder * CFrame.Angles(0, 0, math.rad(-25)), alpha)
				lerpC0(m.RightShoulder, b.RightShoulder * CFrame.Angles(0, 0, math.rad(25)), alpha)
			elseif trick == "cannonball" then
				lerpC0(m.RootJoint, b.RootJoint * CFrame.Angles(-tp * math.rad(420), 0, 0), 1)
				lerpC0(m.LeftShoulder, b.LeftShoulder * CFrame.Angles(math.rad(50), 0, math.rad(-60)), alpha)
				lerpC0(m.RightShoulder, b.RightShoulder * CFrame.Angles(math.rad(50), 0, math.rad(60)), alpha)
				lerpC0(m.LeftHip, b.LeftHip * CFrame.new(0, 0.5, -0.5) * CFrame.Angles(math.rad(-60), 0, 0), alpha)
				lerpC0(m.RightHip, b.RightHip * CFrame.new(0, 0.5, -0.5) * CFrame.Angles(math.rad(-60), 0, 0), alpha)
			else -- swan: slow, graceful arc, flippers wide
				local lean = math.min(tp * 90, 110)
				lerpC0(m.RootJoint, b.RootJoint * CFrame.Angles(math.rad(-lean), 0, 0), alpha)
				lerpC0(m.LeftShoulder, b.LeftShoulder * CFrame.Angles(0, 0, math.rad(-85)), alpha)
				lerpC0(m.RightShoulder, b.RightShoulder * CFrame.Angles(0, 0, math.rad(85)), alpha)
				lerpC0(m.Neck, b.Neck * CFrame.Angles(math.rad(30), 0, 0), alpha)
			end
		elseif swimming or isLocalSliding then
			rig.trickPhase = nil
			-- belly-down glide
			lerpC0(m.RootJoint, b.RootJoint * CFrame.Angles(math.rad(-72), 0, 0) * CFrame.new(0, -0.4, 0), alpha)
			lerpC0(m.Neck, b.Neck * CFrame.Angles(math.rad(55), 0, 0), alpha)
			lerpC0(m.LeftShoulder, b.LeftShoulder * CFrame.Angles(0, 0, math.rad(-35 + s * 12)), alpha)
			lerpC0(m.RightShoulder, b.RightShoulder * CFrame.Angles(0, 0, math.rad(35 - s * 12)), alpha)
			lerpC0(m.LeftHip, b.LeftHip * CFrame.Angles(math.rad(15), 0, 0), alpha)
			lerpC0(m.RightHip, b.RightHip * CFrame.Angles(math.rad(15), 0, 0), alpha)
		elseif airborne then
			lerpC0(m.RootJoint, b.RootJoint * CFrame.Angles(math.rad(8), 0, 0), alpha)
			lerpC0(m.LeftShoulder, b.LeftShoulder * CFrame.Angles(0, 0, math.rad(-55)), alpha)
			lerpC0(m.RightShoulder, b.RightShoulder * CFrame.Angles(0, 0, math.rad(55)), alpha)
			lerpC0(m.Neck, b.Neck, alpha)
		elseif moving then
			-- the waddle
			lerpC0(m.RootJoint, b.RootJoint * CFrame.Angles(math.rad(4), 0, s * 0.14), alpha)
			lerpC0(m.Neck, b.Neck * CFrame.Angles(math.rad(math.abs(s) * 4 - 2), 0, -s * 0.08), alpha)
			lerpC0(m.LeftShoulder, b.LeftShoulder * CFrame.Angles(0, 0, math.rad(-12 + s * 10)), alpha)
			lerpC0(m.RightShoulder, b.RightShoulder * CFrame.Angles(0, 0, math.rad(12 + s * 10)), alpha)
			lerpC0(m.LeftHip, b.LeftHip * CFrame.new(0, 0.06 * math.max(0, s), -0.15 * s), alpha)
			lerpC0(m.RightHip, b.RightHip * CFrame.new(0, 0.06 * math.max(0, -s), 0.15 * s), alpha)
		else
			-- idle: gentle breathing
			rig.trickPhase = nil
			local breathe = math.sin(os.clock() * 1.6) * 0.015
			lerpC0(m.RootJoint, b.RootJoint * CFrame.new(0, breathe, 0), alpha * 0.5)
			lerpC0(m.Neck, b.Neck, alpha * 0.5)
			lerpC0(m.LeftShoulder, b.LeftShoulder * CFrame.Angles(0, 0, math.rad(-2)), alpha * 0.5)
			lerpC0(m.RightShoulder, b.RightShoulder * CFrame.Angles(0, 0, math.rad(2)), alpha * 0.5)
			lerpC0(m.LeftHip, b.LeftHip, alpha * 0.5)
			lerpC0(m.RightHip, b.RightHip, alpha * 0.5)
		end
	end
end)

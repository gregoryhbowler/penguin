-- NPCAmbience: idle life for every character and spirit, computed per-client.
-- Reads each model's AmbientStyle attribute (set by NPCService builders):
--   breathe  - humans: subtle bob + occasional glances around
--   cat      - small animals: quicker bob, bigger curious glances
--   bird     - head-bob pecking rhythm
--   spirit   - slow hover with gentle drift and sway
--   guardian - heavy, slow smolder-breathing
-- Server patrols set a "Patrolling" attribute; we hold off while they move and
-- re-base whenever the server has repositioned a model.

local RunService = game:GetService("RunService")

local npcFolder = workspace:WaitForChild("NPCs", 30)
if not npcFolder then return end

local entries = {}   -- [model] = {base, phase, yaw, yawTarget, nextGlance, lastApplied}

local function track(model)
	if entries[model] then return end
	if not model:IsA("Model") or not model:GetAttribute("AmbientStyle") then return end
	entries[model] = {
		base = model:GetPivot(),
		phase = math.random() * 6.28,
		yaw = 0,
		yawTarget = 0,
		nextGlance = os.clock() + 2 + math.random() * 5,
		lastApplied = nil,
	}
end

npcFolder.ChildAdded:Connect(function(c) task.delay(0.1, track, c) end)
for _, c in ipairs(npcFolder:GetChildren()) do track(c) end

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 1 / 30 then return end -- 30 Hz is plenty for idle motion
	local step = accumulator
	accumulator = 0
	local now = os.clock()

	for model, e in pairs(entries) do
		if not model.Parent then
			entries[model] = nil
		elseif model:GetAttribute("Patrolling") then
			e.lastApplied = nil -- server is driving; re-base when it stops
		else
			local cur = model:GetPivot()
			-- re-base only on real server moves (teleports/patrol stops), never on our
			-- own sub-stud idle offsets — otherwise tiny errors compound into drift
			if e.lastApplied == nil or (cur.Position - e.lastApplied.Position).Magnitude > 1.5 then
				e.base = cur
			end

			local style = model:GetAttribute("AmbientStyle")
			local dy, sway, glanceRange = 0, 0, 25
			if style == "breathe" then
				dy = math.sin(now * 1.4 + e.phase) * 0.05
			elseif style == "cat" then
				dy = math.sin(now * 2.2 + e.phase) * 0.05
				glanceRange = 55
			elseif style == "bird" then
				dy = math.max(0, math.sin(now * 3.2 + e.phase)) * 0.12
				glanceRange = 70
			elseif style == "spirit" then
				dy = math.sin(now * 0.9 + e.phase) * 0.4 + 0.25
				sway = math.sin(now * 0.45 + e.phase) * 3
				glanceRange = 12
			elseif style == "guardian" then
				dy = math.sin(now * 0.55 + e.phase) * 0.18
				sway = math.sin(now * 0.3 + e.phase) * 1.2
				glanceRange = 8
			end

			-- occasional glances: pick a new yaw target now and then, ease toward it
			if now >= e.nextGlance then
				e.yawTarget = (math.random() - 0.5) * 2 * glanceRange
				e.nextGlance = now + 3 + math.random() * 6
			end
			e.yaw += (e.yawTarget - e.yaw) * math.min(step * 2.5, 1)

			local offset = CFrame.new(0, dy, 0) * CFrame.Angles(0, math.rad(e.yaw), math.rad(sway))
			local applied = e.base * offset
			model:PivotTo(applied)
			e.lastApplied = applied
		end
	end
end)

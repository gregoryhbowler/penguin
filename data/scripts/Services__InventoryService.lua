-- InventoryService: builds the game's Tool instances procedurally, grants them to
-- players (persisted in their profile), re-equips them on respawn, and routes
-- server-side Tool.Activated events to the owning gameplay service.
-- Also applies scarf cosmetics to spawned penguins.
-- Tools are never droppable and are restored on death, so quest tools can't be lost.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local Config = require(RS.Shared.GameConfig)
local ItemDefs = require(RS.Shared.ItemDefs)

local InventoryService = {}
local registry
local toolTemplates = {}
local selfHealCooldown = {}   -- [player] = os.clock()
local blanketCooldown = {}

-- ---------- tool geometry builders ----------
local function basePart(name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function weldTo(handle, part, offset)
	local w = Instance.new("Weld")
	w.Part0 = handle
	w.Part1 = part
	w.C0 = offset
	w.Parent = handle
end

-- Tools are handle-less (RequiresHandle=false): the penguin is a custom rig, so we
-- manage the visual ourselves — a "Visual" model of anchored parts that gets
-- welded to the "Right Arm" grip part while equipped. Nothing can ever fall out.
local function buildTool(name)
	local def = ItemDefs.Tools[name]
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.ToolTip = def and def.tip or ""
	tool.CanBeDropped = false
	tool.RequiresHandle = false

	local handle
	if name == "Bucket" then
		handle = basePart("Grip", Vector3.new(1.3, 1.2, 1.3), Color3.fromRGB(160, 90, 60), Enum.Material.Metal)
		local water = basePart("Water", Vector3.new(1.05, 0.25, 1.05), Color3.fromRGB(90, 160, 210), Enum.Material.Glass)
		water.Transparency = 1
		water.Parent = tool
		weldTo(handle, water, CFrame.new(0, 0.45, 0))
	elseif name == "MedKit" then
		handle = basePart("Grip", Vector3.new(1.6, 1, 1.2), Color3.fromRGB(235, 235, 235))
		local crossV = basePart("CrossV", Vector3.new(0.28, 0.7, 0.1), Color3.fromRGB(200, 60, 60))
		crossV.Parent = tool
		weldTo(handle, crossV, CFrame.new(0, 0, -0.62))
		local crossH = basePart("CrossH", Vector3.new(0.7, 0.28, 0.1), Color3.fromRGB(200, 60, 60))
		crossH.Parent = tool
		weldTo(handle, crossH, CFrame.new(0, 0, -0.62))
	elseif name == "FireBlanket" then
		handle = basePart("Grip", Vector3.new(1.7, 0.9, 1.1), Color3.fromRGB(180, 60, 50), Enum.Material.Fabric)
		local strap = basePart("Strap", Vector3.new(1.8, 0.25, 1.2), Color3.fromRGB(240, 220, 190), Enum.Material.Fabric)
		strap.Parent = tool
		weldTo(handle, strap, CFrame.new(0, 0, 0))
	elseif name == "Axe" then
		handle = basePart("Grip", Vector3.new(0.35, 2.6, 0.35), Color3.fromRGB(130, 100, 70), Enum.Material.Wood)
		local head = basePart("Head", Vector3.new(1.2, 0.8, 0.25), Color3.fromRGB(150, 150, 158), Enum.Material.Metal)
		head.Parent = tool
		weldTo(handle, head, CFrame.new(0.55, 1, 0))
	elseif name == "Hose" then
		handle = basePart("Grip", Vector3.new(0.5, 0.5, 1.7), Color3.fromRGB(200, 170, 60), Enum.Material.Metal)
		local grip = basePart("GripRing", Vector3.new(0.7, 0.7, 0.4), Color3.fromRGB(120, 60, 50), Enum.Material.Rubber)
		grip.Parent = tool
		weldTo(handle, grip, CFrame.new(0, 0, 0.5))
	elseif name == "Wingsuit" then
		-- a little sky-blue wing pack; the glide itself is handled by WingsuitGlide
		handle = basePart("Grip", Vector3.new(0.9, 1.1, 0.5), Color3.fromRGB(96, 148, 208), Enum.Material.Fabric)
		for _, side in ipairs({ -1, 1 }) do
			local wing = basePart("Wing", Vector3.new(1.7, 0.14, 0.8), Color3.fromRGB(150, 190, 230), Enum.Material.Fabric)
			wing.Parent = tool
			weldTo(handle, wing, CFrame.new(side * 1.2, 0.25, 0) * CFrame.Angles(0, 0, side * math.rad(-18)))
		end
		local strap = basePart("Strap", Vector3.new(1.0, 0.2, 0.6), Color3.fromRGB(220, 200, 140), Enum.Material.Fabric)
		strap.Parent = tool
		weldTo(handle, strap, CFrame.new(0, 0.6, 0))
	end
	-- gather the loose parts we created into an anchored Visual model
	local visual = Instance.new("Model")
	visual.Name = "Visual"
	handle.Parent = visual
	for _, part in ipairs(tool:GetChildren()) do
		if part:IsA("BasePart") then part.Parent = visual end
	end
	for _, part in ipairs(visual:GetChildren()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end
	visual.PrimaryPart = handle
	visual.Parent = tool
	return tool
end

-- ---------- activation routing ----------
local function onActivated(player, tool)
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local FireService = registry.FireService
	local InteractionService = registry.InteractionService
	local NPCService = registry.NPCService
	local notify = RS.Remotes.Notify

	if tool.Name == "Bucket" then
		if tool:GetAttribute("Filled") then
			local fire = FireService:FindBurningFireNear(root.Position, Config.DOUSE_RANGE, { Water = true, Hose = true })
			if fire then
				InventoryService:SetBucketFilled(tool, false)
				FireService:Douse(fire, player, 1)
			else
				-- is there a fire here that needs a different tool? say so instead of
				-- the misleading "no flames in reach"
				local blanketFire = FireService:FindBurningFireNear(root.Position, Config.DOUSE_RANGE, { Blanket = true })
				if blanketFire then
					if InventoryService:HasTool(player, "FireBlanket") then
						notify:FireClient(player, { text = "Water just spreads this greasy little fire — smother it with your Fire Blanket!", kind = "hint" })
					else
						notify:FireClient(player, { text = "Water won't work on this greasy fire — it needs a Fire Blanket. Warden Bram by the park bandstand lends them out.", kind = "hint" })
					end
				else
					notify:FireClient(player, { text = "No flames in reach. Get closer to the fire!", kind = "hint" })
				end
			end
		else
			-- try to fill from a nearby source as a convenience (prompt also works)
			if InteractionService:TryFillBucket(player) then return end
			notify:FireClient(player, { text = "The bucket is empty. Fill it at the river, a pond, the fountain, or a live hydrant.", kind = "hint" })
		end
	elseif tool.Name == "FireBlanket" then
		local last = blanketCooldown[player]
		if last and os.clock() - last < 1.5 then return end
		blanketCooldown[player] = os.clock()
		local fire = FireService:FindSmotherableFireNear(root.Position, Config.BLANKET_RANGE)
		if fire then
			FireService:Douse(fire, player, 99) -- blankets smother small/weakened fires completely
		else
			notify:FireClient(player, { text = "The blanket smothers small fires — or big ones once water has beaten them down. Stand right beside the flames.", kind = "hint" })
		end
	elseif tool.Name == "Axe" then
		InteractionService:TryChop(player)
	elseif tool.Name == "MedKit" then
		if NPCService:TryTreatNearby(player) then return end
		local last = selfHealCooldown[player]
		if last and os.clock() - last < 8 then
			notify:FireClient(player, { text = "Catch your breath — the med kit needs a moment.", kind = "hint" })
			return
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health < hum.MaxHealth then
			selfHealCooldown[player] = os.clock()
			hum.Health = math.min(hum.MaxHealth, hum.Health + 30)
			notify:FireClient(player, { text = "Patched up! (+30 health)", kind = "good" })
		end
	elseif tool.Name == "Hose" then
		FireService:ToggleHose(player, tool)
	end
end

-- ---------- granting ----------
function InventoryService:SetBucketFilled(tool, filled)
	tool:SetAttribute("Filled", filled)
	local water = tool:FindFirstChild("Water", true)
	if water then water.Transparency = filled and 0.2 or 1 end
end

-- weld the tool's Visual model to the penguin's grip part while equipped
local function attachVisual(player, tool)
	local char = player.Character
	local arm = char and char:FindFirstChild("Right Arm")
	local visual = tool:FindFirstChild("Visual")
	local grip = visual and visual.PrimaryPart
	if not (arm and grip) then return end
	local old = arm:FindFirstChild("RightGrip")
	if old then old:Destroy() end
	visual:PivotTo(arm.CFrame * CFrame.new(0.1, -0.6, -0.55))
	for _, part in ipairs(visual:GetChildren()) do
		if part:IsA("BasePart") then part.Anchored = false end
	end
	local w = Instance.new("Motor6D")
	w.Name = "RightGrip"
	w.Part0 = arm
	w.Part1 = grip
	w.C0 = CFrame.new(0.1, -0.6, -0.55)
	w.Parent = arm
end

local function detachVisual(player, tool)
	local char = player.Character
	local arm = char and char:FindFirstChild("Right Arm")
	local grip = arm and arm:FindFirstChild("RightGrip")
	if grip then grip:Destroy() end
	local visual = tool and tool:FindFirstChild("Visual")
	if visual then
		for _, part in ipairs(visual:GetChildren()) do
			if part:IsA("BasePart") then part.Anchored = true end
		end
	end
end

local function giveToolInstance(player, name)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	if backpack:FindFirstChild(name) then return end
	local char = player.Character
	if char and char:FindFirstChild(name) then return end
	local clone = toolTemplates[name]:Clone()
	clone.Activated:Connect(function()
		onActivated(player, clone)
	end)
	clone.Equipped:Connect(function()
		attachVisual(player, clone)
	end)
	clone.Unequipped:Connect(function()
		detachVisual(player, clone)
		if clone.Name == "Hose" then
			registry.FireService:StopHose(player)
		end
	end)
	clone.Parent = backpack
end

function InventoryService:GrantTool(player, name, silent)
	if not toolTemplates[name] then
		warn("[InventoryService] unknown tool " .. tostring(name))
		return
	end
	local data = registry.DataService:Get(player)
	if not data then return end
	if not data.tools[name] then
		data.tools[name] = true
		registry.DataService:MarkDirty(player)
	end
	giveToolInstance(player, name)
end

function InventoryService:HasTool(player, name)
	local data = registry.DataService:GetIfLoaded(player)
	return data ~= nil and data.tools[name] == true
end

-- ---------- cosmetics ----------
local function hatPart(name, size, color, mat, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildHat(hatId, head)
	local m = Instance.new("Model")
	m.Name = "HatCosmetic"
	local parts = {}
	if hatId == "TopHat" then
		local brim = hatPart("Brim", Vector3.new(1.5, 0.12, 1.5), Color3.fromRGB(38, 36, 40), Enum.Material.Fabric, m)
		brim.Shape = Enum.PartType.Cylinder
		local tube = hatPart("Tube", Vector3.new(1.0, 1.1, 1.0), Color3.fromRGB(38, 36, 40), Enum.Material.Fabric, m)
		local band = hatPart("Band", Vector3.new(1.05, 0.22, 1.05), Color3.fromRGB(190, 60, 50), Enum.Material.Fabric, m)
		parts = { { brim, CFrame.new(0, 0.45, 0) * CFrame.Angles(0, 0, math.rad(90)) }, { tube, CFrame.new(0, 1.05, 0) }, { band, CFrame.new(0, 0.62, 0) } }
	elseif hatId == "FlowerCrown" then
		local ring = hatPart("Ring", Vector3.new(1.25, 0.18, 1.25), Color3.fromRGB(96, 128, 78), Enum.Material.Grass, m)
		parts = { { ring, CFrame.new(0, 0.5, 0) } }
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			local fl = hatPart("Flower" .. i, Vector3.new(0.22, 0.14, 0.22), Color3.fromRGB(235, 215, 150), Enum.Material.Neon, m)
			table.insert(parts, { fl, CFrame.new(math.cos(a) * 0.6, 0.58, math.sin(a) * 0.6) })
		end
	elseif hatId == "FirefighterHat" then
		local dome = hatPart("Dome", Vector3.new(1.35, 0.7, 1.4), Color3.fromRGB(200, 55, 45), Enum.Material.SmoothPlastic, m)
		local mesh = Instance.new("SpecialMesh") mesh.MeshType = Enum.MeshType.Sphere mesh.Parent = dome
		local brim = hatPart("Brim", Vector3.new(1.55, 0.12, 1.8), Color3.fromRGB(180, 48, 40), Enum.Material.SmoothPlastic, m)
		local badge = hatPart("Badge", Vector3.new(0.32, 0.36, 0.1), Color3.fromRGB(235, 205, 120), Enum.Material.Metal, m)
		parts = { { dome, CFrame.new(0, 0.62, 0) }, { brim, CFrame.new(0, 0.34, 0.12) }, { badge, CFrame.new(0, 0.66, -0.68) } }
	else
		m:Destroy()
		return nil
	end
	for _, entry in ipairs(parts) do
		local part, offset = entry[1], entry[2]
		part.CFrame = head.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = part
		weld.Parent = part
	end
	return m
end

function InventoryService:ApplyCosmetics(player)
	local char = player.Character
	local data = registry.DataService:GetIfLoaded(player)
	if not (char and data) then return end
	-- scarf (a built-in rig part, recolored or hidden)
	local scarf = char:FindFirstChild("Scarf")
	if scarf then
		local equipped = data.cosmetics.equipped
		local found = false
		if equipped and equipped ~= "" then
			for _, c in ipairs(Config.SCARF_COLORS) do
				if c.id == equipped then
					scarf.Color = c.color
					scarf.Transparency = 0
					found = true
					break
				end
			end
		end
		if not found then scarf.Transparency = 1 end
	end
	-- hat (built fresh and welded to the head)
	local oldHat = char:FindFirstChild("HatCosmetic")
	if oldHat then oldHat:Destroy() end
	local hatId = data.cosmetics.equippedHat
	if hatId and hatId ~= "" then
		local head = char:FindFirstChild("Head")
		if head then
			local hat = buildHat(hatId, head)
			if hat then hat.Parent = char end
		end
	end
end

function InventoryService:Init(reg)
	registry = reg
	local toolsFolder = SS:FindFirstChild("Tools") or Instance.new("Folder")
	toolsFolder.Name = "Tools"
	toolsFolder.Parent = SS
	toolsFolder:ClearAllChildren()
	for name in pairs(ItemDefs.Tools) do
		local tool = buildTool(name)
		tool.Parent = toolsFolder
		toolTemplates[name] = tool
	end
end

function InventoryService:Start()
	local function onCharacter(player, char)
		-- restore owned tools + cosmetics after data is ready
		task.spawn(function()
			local data = registry.DataService:Get(player)
			if not data then return end
			for name in pairs(data.tools) do
				giveToolInstance(player, name)
			end
			InventoryService:ApplyCosmetics(player)
		end)
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
		if player.Character then onCharacter(player, player.Character) end
	end
	Players.PlayerRemoving:Connect(function(player)
		selfHealCooldown[player] = nil
		blanketCooldown[player] = nil
	end)
end

return InventoryService

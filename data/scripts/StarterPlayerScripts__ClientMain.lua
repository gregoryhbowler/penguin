-- ClientMain: all UI and client feedback for Ember Grove.
-- Warm illustrated field-journal style: parchment cards, ink text, ember accents.
-- Sections: theme kit / audio / HUD / region banner / toasts / objective card /
-- dialogue / journal / shop / settings / tutorial tips / celebrations / credits /
-- guardian scene / pickup hiding / state sync / title card.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local CS = game:GetService("CollectionService")

local Config = require(RS.Shared.GameConfig)
local QuestDefs = require(RS.Shared.QuestDefs)
local SpecimenDefs = require(RS.Shared.SpecimenDefs)
local Remotes = RS.Remotes

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============ THEME ============
local PARCHMENT = Color3.fromRGB(243, 233, 210)
local PARCHMENT_DARK = Color3.fromRGB(226, 213, 186)
local INK = Color3.fromRGB(59, 50, 40)
local INK_SOFT = Color3.fromRGB(110, 96, 78)
local EMBER = Color3.fromRGB(217, 118, 61)
local WOOD = Color3.fromRGB(138, 103, 72)
local HEALTH_C = Color3.fromRGB(194, 91, 78)
local ENERGY_C = Color3.fromRGB(224, 169, 62)
local GOOD_C = Color3.fromRGB(110, 160, 90)
local WARN_C = Color3.fromRGB(212, 150, 60)
local HINT_C = Color3.fromRGB(110, 140, 190)
local HEADER_FONT = Enum.Font.FredokaOne
local BODY_FONT = Enum.Font.GothamMedium
local ITALIC_FONT = Enum.Font.Gotham

local function mk(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do inst[k] = v end
	inst.Parent = parent
	return inst
end
local function corner(inst, r) mk("UICorner", { CornerRadius = UDim.new(0, r or 10) }, inst) end
local function stroke(inst, color, thickness, tr) mk("UIStroke", { Color = color or WOOD, Thickness = thickness or 2, Transparency = tr or 0 }, inst) end
local function pad(inst, p) mk("UIPadding", { PaddingTop = UDim.new(0, p), PaddingBottom = UDim.new(0, p), PaddingLeft = UDim.new(0, p), PaddingRight = UDim.new(0, p) }, inst) end

local gui = mk("ScreenGui", { Name = "EmberGroveUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
local uiScale = mk("UIScale", { Scale = 1 }, gui)
local function fitScale()
	local cam = workspace.CurrentCamera
	if cam then uiScale.Scale = cam.ViewportSize.Y < 600 and 0.82 or (cam.ViewportSize.Y < 800 and 0.92 or 1) end
end
task.defer(fitScale)
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale) end

-- ============ AUDIO ============
local musicGroup = mk("SoundGroup", { Name = "Music", Volume = 0.5 }, SoundService)
local sfxGroup = mk("SoundGroup", { Name = "SFX", Volume = 0.8 }, SoundService)
-- PLACEHOLDER music/ambience: SoundIds are empty on purpose. Replace with licensed
-- or original loops before publishing (see README "Audio").
mk("Sound", { Name = "PLACEHOLDER_WarmFirehouseTheme", SoundId = "", Looped = true, Volume = 0.35, SoundGroup = musicGroup }, SoundService)
mk("Sound", { Name = "PLACEHOLDER_ForestAmbience", SoundId = "", Looped = true, Volume = 0.3, SoundGroup = musicGroup }, SoundService)
local function sfx(name, id, vol)
	return mk("Sound", { Name = name, SoundId = id, Volume = vol or 0.5, SoundGroup = sfxGroup }, SoundService)
end
local sndPing = sfx("UIPing", "rbxasset://sounds/electronicpingshort.wav", 0.35)
local sndSplash = sfx("Splash", "rbxasset://sounds/impact_water.mp3", 0.55)
local sndPop = sfx("Pop", "rbxasset://sounds/snap.mp3", 0.5)
local function play(s) pcall(function() s:Play() end) end

-- ============ HUD ============
local hud = mk("Frame", { Name = "HUD", BackgroundColor3 = PARCHMENT, BackgroundTransparency = 0.08, Position = UDim2.new(0, 14, 0, 14), Size = UDim2.new(0, 240, 0, 84) }, gui)
corner(hud, 14)
stroke(hud, WOOD, 2.5)
pad(hud, 10)
mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Font = HEADER_FONT, Text = Config.PENGUIN_NAME, TextColor3 = INK, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left }, hud)
local function bar(y, fillColor, label)
	local back = mk("Frame", { BackgroundColor3 = PARCHMENT_DARK, Position = UDim2.new(0, 0, 0, y), Size = UDim2.new(1, 0, 0, 17) }, hud)
	corner(back, 8)
	stroke(back, WOOD, 1.5, 0.4)
	local fill = mk("Frame", { BackgroundColor3 = fillColor, Size = UDim2.fromScale(1, 1) }, back)
	corner(fill, 8)
	mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = BODY_FONT, Text = label, TextColor3 = INK, TextSize = 11, ZIndex = 3 }, back)
	return fill
end
local healthFill = bar(24, HEALTH_C, "Health")
local energyFill = bar(46, ENERGY_C, "Energy")

local chip = mk("Frame", { BackgroundColor3 = PARCHMENT, BackgroundTransparency = 0.08, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.new(0, 170, 0, 40) }, gui)
corner(chip, 12)
stroke(chip, WOOD, 2.5)
local sparksLabel = mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.58, 0, 1, 0), Font = HEADER_FONT, Text = "\u{2728} 0", TextColor3 = EMBER, TextSize = 19 }, chip)
local badgeLabel = mk("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.58, 0), Size = UDim2.new(0.42, 0, 1, 0), Font = HEADER_FONT, Text = "\u{1F396} 0", TextColor3 = INK, TextSize = 17 }, chip)

-- fish satchel: appears after the first catch; tap it to eat a fish (+energy)
local fishChip = mk("TextButton", { BackgroundColor3 = PARCHMENT, BackgroundTransparency = 0.08, AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 14, 0, 106), Size = UDim2.new(0, 110, 0, 34), Font = HEADER_FONT, Text = "\u{1F41F} 0", TextColor3 = HINT_C, TextSize = 17, Visible = false }, gui)
corner(fishChip, 10)
stroke(fishChip, WOOD, 2)
local fishTip = mk("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(1, 8, 0, 0), Size = UDim2.new(0, 150, 1, 0), Font = ITALIC_FONT, Text = "saving for someone hungry…", TextColor3 = INK_SOFT, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Visible = false }, fishChip)
local function refreshFishTip()
	fishTip.Text = player:GetAttribute("FishEdible") and "tap to eat one" or "saving for someone hungry…"
end
player:GetAttributeChangedSignal("FishEdible"):Connect(refreshFishTip)
refreshFishTip()
fishChip.MouseEnter:Connect(function() fishTip.Visible = true end)
fishChip.MouseLeave:Connect(function() fishTip.Visible = false end)
fishChip.Activated:Connect(function()
	Remotes.EatFish:FireServer()
	play(sndPop)
end)

-- seed pouch: appears after the first seed; the community garden wants them
local seedChip = mk("TextButton", { BackgroundColor3 = PARCHMENT, BackgroundTransparency = 0.08, AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 130, 0, 106), Size = UDim2.new(0, 96, 0, 34), Font = HEADER_FONT, Text = "\u{1F331} 0", TextColor3 = GOOD_C, TextSize = 17, Visible = false, AutoButtonColor = false }, gui)
corner(seedChip, 10)
stroke(seedChip, WOOD, 2)
local seedTip = mk("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(1, 8, 0, 0), Size = UDim2.new(0, 170, 1, 0), Font = ITALIC_FONT, Text = "plant these at the community garden", TextColor3 = INK_SOFT, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Visible = false }, seedChip)
seedChip.MouseEnter:Connect(function() seedTip.Visible = true end)
seedChip.MouseLeave:Connect(function() seedTip.Visible = false end)

-- health binding
local function bindCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	local function upd()
		local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
		TweenService:Create(healthFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(frac, 1) }):Play()
	end
	hum.HealthChanged:Connect(upd)
	upd()
end
player.CharacterAdded:Connect(bindCharacter)
if player.Character then bindCharacter(player.Character) end

-- ============ REGION BANNER ============
local regionBanner = mk("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.new(0, 520, 0, 44), Font = HEADER_FONT, Text = "", TextColor3 = PARCHMENT, TextSize = 32, TextStrokeColor3 = INK, TextStrokeTransparency = 0.35, TextTransparency = 1 }, gui)
player:GetAttributeChangedSignal("CurrentZone"):Connect(function()
	local z = player:GetAttribute("CurrentZone")
	if not z then return end
	regionBanner.Text = "\u{2014}  " .. z .. "  \u{2014}"
	regionBanner.TextTransparency = 1
	TweenService:Create(regionBanner, TweenInfo.new(0.7), { TextTransparency = 0 }):Play()
	task.delay(2.6, function()
		TweenService:Create(regionBanner, TweenInfo.new(1.2), { TextTransparency = 1 }):Play()
	end)
end)

-- ============ TOASTS ============
local toastHolder = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 72), Size = UDim2.new(0, 430, 0, 240) }, gui)
mk("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }, toastHolder)
local KIND_COLORS = { good = GOOD_C, warn = WARN_C, hint = HINT_C, sparks = EMBER, story = EMBER }
local function toast(text, kind)
	local card = mk("Frame", { BackgroundColor3 = PARCHMENT, BackgroundTransparency = 0.05, Size = UDim2.new(1, -20, 0, 10), AutomaticSize = Enum.AutomaticSize.Y }, toastHolder)
	corner(card, 10)
	stroke(card, KIND_COLORS[kind] or WOOD, 2.5)
	pad(card, 8)
	mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = BODY_FONT, Text = text, TextColor3 = INK, TextSize = 15, TextWrapped = true }, card)
	play(sndPing)
	task.delay(kind == "story" and 6 or 4, function()
		if card.Parent then card:Destroy() end
	end)
end
Remotes.Notify.OnClientEvent:Connect(function(p)
	if p and p.text then toast(p.text, p.kind) end
end)

-- ============ OBJECTIVE CARD ============
local objCard = mk("Frame", { BackgroundColor3 = PARCHMENT, BackgroundTransparency = 0.08, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 64), Size = UDim2.new(0, 300, 0, 10), AutomaticSize = Enum.AutomaticSize.Y }, gui)
corner(objCard, 14)
stroke(objCard, EMBER, 2.5)
pad(objCard, 12)
mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, objCard)
local objKicker = mk("TextLabel", { LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), Font = BODY_FONT, Text = "CURRENT TASK", TextColor3 = INK_SOFT, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left }, objCard)
-- minimize toggle lives inside the kicker row so the list layout ignores it
local objToggle = mk("TextButton", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 22, 0, 22), Font = HEADER_FONT, Text = "\u{2013}", TextColor3 = INK_SOFT, TextSize = 18 }, objKicker)
local objTitle = mk("TextLabel", { LayoutOrder = 2, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = HEADER_FONT, Text = "Waking up…", TextColor3 = INK, TextSize = 19, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left }, objCard)
local objText = mk("TextLabel", { LayoutOrder = 3, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = BODY_FONT, Text = "", TextColor3 = INK, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left }, objCard)
local objProgress = mk("TextLabel", { LayoutOrder = 4, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = HEADER_FONT, Text = "", TextColor3 = EMBER, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Visible = false }, objCard)
local objHint = mk("TextLabel", { LayoutOrder = 5, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = ITALIC_FONT, Text = "", TextColor3 = INK_SOFT, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Visible = false }, objCard)

-- collapse/expand: the player can minimize the task card, and it also tucks
-- itself away while dialogue is on screen so it never covers the words
local objUserCollapsed = false
local objDialogueOpen = false
local objHasProgress = false
local objHasHint = false
local function applyObjCollapse()
	local collapsed = objUserCollapsed or objDialogueOpen
	objTitle.Visible = not collapsed
	objText.Visible = not collapsed
	objProgress.Visible = not collapsed and objHasProgress
	objHint.Visible = not collapsed and objHasHint
	objToggle.Text = objUserCollapsed and "\u{25B8}" or "\u{2013}"
	objCard.BackgroundTransparency = collapsed and 0.35 or 0.08
end
objToggle.Activated:Connect(function()
	objUserCollapsed = not objUserCollapsed
	applyObjCollapse()
end)

-- ============ TUTORIAL TIPS ============
local TIPS = {
	wake = UserInputService.TouchEnabled
		and "Drag the left side of the screen to waddle. Tap the Slide button to belly-slide!"
		or "WASD to waddle • Space to jump • Left Ctrl to belly-slide!",
	fill = "Walk to the pond's edge and press the prompt to fill your bucket.",
	firstfire = UserInputService.TouchEnabled
		and "Tap the Bucket in your toolbar to equip it, then tap near the flames to douse them."
		or "Press 1 to equip the Bucket, then click near the flames to douse them.",
	catrescue = "Hold the Rescue prompt to help characters in trouble.",
	grovefire = "Bigger fires need more water — there's a forest pool nearby for refills.",
	cookfire = "Equip the Fire Blanket and use it right beside the small fire.",
	branch = "Equip the Axe and swing it next to the cracked branch. Three good chops!",
	streetfire = "Stand near the hydrant with the Hose equipped, then click/tap to spray. Tap again to stop. Playing with a friend? They can hold the hydrant's Pump prompt to supercharge your spray!",
	valves = "Each valve wheel has a painted number. Open them in order: 1, 2, 3.",
	memoryfires = "The yard hydrants are live now — hose down all four memory fires. A friend on the hydrant pump makes the hose roar!",
}
-- sits above the touch joystick zone on tablets/phones
local tipCard = mk("Frame", { BackgroundColor3 = Color3.fromRGB(52, 62, 82), BackgroundTransparency = 0.12, Position = UDim2.new(0, 14, 1, UserInputService.TouchEnabled and -230 or -120), AnchorPoint = Vector2.new(0, 1), Size = UDim2.new(0, 300, 0, 10), AutomaticSize = Enum.AutomaticSize.Y, Visible = false }, gui)
corner(tipCard, 12)
stroke(tipCard, HINT_C, 2)
pad(tipCard, 10)
local tipText = mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = BODY_FONT, Text = "", TextColor3 = Color3.fromRGB(235, 240, 250), TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left }, tipCard)
local tipShownFor = {}
local function showTip(stageId)
	local tip = TIPS[stageId]
	if not tip or tipShownFor[stageId] then return end
	tipShownFor[stageId] = true
	tipText.Text = "\u{1F4A1} " .. tip
	tipCard.Visible = true
	task.delay(12, function()
		if tipText.Text == "\u{1F4A1} " .. tip then tipCard.Visible = false end
	end)
end

Remotes.ObjectiveUpdate.OnClientEvent:Connect(function(p)
	objTitle.Text = p.title or ""
	objText.Text = p.objective or ""
	objHasProgress = p.progress ~= nil
	if p.progress then
		objProgress.Text = p.progress.n .. " / " .. p.progress.total .. " found"
	end
	objHasHint = p.hint ~= nil
	objHint.Text = p.hint and ("Hint: " .. p.hint) or ""
	objKicker.Text = p.completed and "FREE EXPLORATION" or ("CURRENT TASK  \u{2022}  " .. (p.stageIndex or 1) .. " of " .. (p.totalStages or "?"))
	applyObjCollapse()
	local stage = QuestDefs.Stages[p.stageIndex or 0]
	if stage then showTip(stage.id) end
end)

-- ============ DIALOGUE ============
local dlg = mk("Frame", { BackgroundColor3 = PARCHMENT, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.new(0, 520, 0, 130), Visible = false }, gui)
corner(dlg, 16)
stroke(dlg, WOOD, 3)
local dlgName = mk("TextLabel", { BackgroundColor3 = EMBER, Position = UDim2.new(0, 16, 0, -14), Size = UDim2.new(0, 180, 0, 28), Font = HEADER_FONT, Text = "", TextColor3 = Color3.new(1, 1, 1), TextSize = 16 }, dlg)
corner(dlgName, 8)
local dlgText = mk("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 20), Size = UDim2.new(1, -32, 1, -50), Font = BODY_FONT, Text = "", TextColor3 = INK, TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, dlg)
local dlgNext = mk("TextButton", { BackgroundColor3 = PARCHMENT_DARK, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -10), Size = UDim2.new(0, 140, 0, 30), Font = HEADER_FONT, Text = "Continue \u{25B8}", TextColor3 = INK, TextSize = 15 }, dlg)
corner(dlgNext, 8)
stroke(dlgNext, WOOD, 1.5)
local dlgLines, dlgIndex = nil, 0
local function advanceDialogue()
	if not dlgLines then return end
	dlgIndex += 1
	if dlgIndex > #dlgLines then
		dlg.Visible = false
		dlgLines = nil
		objDialogueOpen = false
		applyObjCollapse()
		return
	end
	dlgText.Text = dlgLines[dlgIndex]
	dlgNext.Text = dlgIndex == #dlgLines and "Done \u{2714}" or "Continue \u{25B8}"
	play(sndPop)
end
dlgNext.Activated:Connect(advanceDialogue)
Remotes.Dialogue.OnClientEvent:Connect(function(p)
	if not (p and p.lines and #p.lines > 0) then return end
	dlgName.Text = p.name or "???"
	dlgLines = p.lines
	dlgIndex = 0
	dlg.Visible = true
	objDialogueOpen = true
	applyObjCollapse()
	advanceDialogue()
end)

-- ============ BOTTOM-RIGHT BUTTON CLUSTER ============
local cluster = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.new(0, 56, 0, 130) }, gui)
mk("UIListLayout", { Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom }, cluster)
local function clusterButton(emoji, tooltip)
	local b = mk("TextButton", { BackgroundColor3 = PARCHMENT, Size = UDim2.new(0, 52, 0, 52), Font = HEADER_FONT, Text = emoji, TextSize = 24, TextColor3 = INK }, cluster)
	corner(b, 14)
	stroke(b, WOOD, 2.5)
	return b
end
local journalBtn = clusterButton("\u{1F4D6}")
local settingsBtn = clusterButton("\u{2699}")

-- ============ PANELS (journal / shop / settings share a modal holder) ============
local function makePanel(titleText, height)
	local overlay = mk("TextButton", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Text = "", AutoButtonColor = false, Visible = false, ZIndex = 10 }, gui)
	local panel = mk("Frame", { BackgroundColor3 = PARCHMENT, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 460, 0, height), ZIndex = 11 }, overlay)
	corner(panel, 18)
	stroke(panel, WOOD, 3)
	mk("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 20, 0, 10), Size = UDim2.new(1, -40, 0, 34), Font = HEADER_FONT, Text = titleText, TextColor3 = INK, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 }, panel)
	local closeBtn = mk("TextButton", { BackgroundColor3 = HEALTH_C, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.new(0, 34, 0, 34), Font = HEADER_FONT, Text = "\u{2715}", TextColor3 = Color3.new(1, 1, 1), TextSize = 18, ZIndex = 12 }, panel)
	corner(closeBtn, 10)
	closeBtn.Activated:Connect(function() overlay.Visible = false end)
	overlay.Activated:Connect(function() overlay.Visible = false end)
	local content = mk("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 52), Size = UDim2.new(1, -32, 1, -68), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ZIndex = 12 }, panel)
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	return overlay, content
end

-- ---------- journal ----------
local journalOverlay, journalContent = makePanel("\u{1F4D6} Pip's Field Journal", 420)
local latestState = { badges = {}, stageIndex = 1, completed = false, collected = {} }
local function rebuildJournal()
	journalContent:ClearAllChildren()
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, journalContent)
	local order = 0
	local function row(text, color, font)
		order += 1
		local r = mk("TextLabel", { LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = font or BODY_FONT, Text = text, TextColor3 = color or INK, TextSize = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 }, journalContent)
		return r
	end
	row("THE ROAD HOME", INK_SOFT)
	for i, stage in ipairs(QuestDefs.Stages) do
		if i < latestState.stageIndex then
			row("\u{2714} " .. stage.title, INK_SOFT)
		elseif i == latestState.stageIndex and not latestState.completed then
			row("\u{25B8} " .. stage.title .. " — " .. stage.objective, EMBER, HEADER_FONT)
		elseif i == latestState.stageIndex + 1 then
			row("\u{2022} …and " .. (#QuestDefs.Stages - latestState.stageIndex) .. " more chapters to go…", INK_SOFT)
			break
		end
	end
	if latestState.completed then
		row("\u{2B50} Story complete! The city is yours to explore.", EMBER, HEADER_FONT)
	end
	row(" ", INK)
	row("FIREHOUSE BADGES (" .. #latestState.badges .. ")", INK_SOFT)
	if #latestState.badges == 0 then
		row("None yet — help someone in trouble!", INK_SOFT)
	else
		for _, b in ipairs(latestState.badges) do row("\u{1F396} " .. b, INK) end
	end
	row(" ", INK)
	-- the Collection: specimens found in hidden caches (mineral-plate energy)
	local specTotal, specFound = 0, 0
	for _ in pairs(SpecimenDefs) do specTotal += 1 end
	local foundList = {}
	for id, def in pairs(SpecimenDefs) do
		if latestState.collected and latestState.collected[id] then
			specFound += 1
			table.insert(foundList, def)
		end
	end
	table.sort(foundList, function(a, b) return a.name < b.name end)
	row("THE COLLECTION (" .. specFound .. " of " .. specTotal .. ")", INK_SOFT)
	if specFound == 0 then
		row("Curious things hide in quiet corners. Bring them here.", INK_SOFT)
	else
		for _, def in ipairs(foundList) do
			row("\u{25C8} " .. def.name, INK, HEADER_FONT)
			row("    " .. def.text, INK_SOFT)
		end
	end
	row(" ", INK)
	row("HOW TO PLAY", INK_SOFT)
	row(TIPS.wake, INK)
	row("Fires: buckets for flames, blankets for small fires, the hose for big ones.", INK)
	row("Feeling tired? Eat snacks to restore energy. Spirits reward kindness, not fighting.", INK)
end
journalBtn.Activated:Connect(function()
	rebuildJournal()
	journalOverlay.Visible = true
end)

-- ---------- shop ----------
local shopOverlay, shopContent = makePanel("\u{1F36A} Marla's Snack Kiosk", 420)
Remotes.ShopOpen.OnClientEvent:Connect(function(payload)
	shopContent:ClearAllChildren()
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, shopContent)
	for order, item in ipairs(payload.items or {}) do
		local rowBtn = mk("TextButton", { LayoutOrder = order, BackgroundColor3 = PARCHMENT_DARK, Size = UDim2.new(1, -8, 0, 44), Text = "", ZIndex = 12 }, shopContent)
		corner(rowBtn, 10)
		stroke(rowBtn, WOOD, 1.5, 0.3)
		local desc = item.kind == "food" and ("+" .. item.energy .. " energy") or "scarf cosmetic"
		mk("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.62, 0, 1, 0), Font = BODY_FONT, Text = item.name .. "  (" .. desc .. ")", TextColor3 = INK, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13 }, rowBtn)
		mk("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.new(0.3, 0, 1, 0), Font = HEADER_FONT, Text = "\u{2728} " .. item.price, TextColor3 = EMBER, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 13 }, rowBtn)
		if item.color then
			local sw = mk("Frame", { BackgroundColor3 = Color3.fromRGB(item.color[1], item.color[2], item.color[3]), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.68, 0, 0.5, 0), Size = UDim2.new(0, 22, 0, 22), ZIndex = 13 }, rowBtn)
			corner(sw, 11)
		end
		rowBtn.Activated:Connect(function()
			local result = Remotes.Purchase:InvokeServer(item.id)
			if result and not result.ok and result.msg then toast(result.msg, "warn") end
		end)
	end
	shopOverlay.Visible = true
end)

-- ---------- settings ----------
local settingsOverlay, settingsContent = makePanel("\u{2699} Settings", 300)
local function slider(labelText, initial, onChange)
	local holder = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 58), ZIndex = 12 }, settingsContent)
	mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Font = BODY_FONT, Text = labelText, TextColor3 = INK, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13 }, holder)
	local track = mk("TextButton", { BackgroundColor3 = PARCHMENT_DARK, Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 0, 18), Text = "", AutoButtonColor = false, ZIndex = 13 }, holder)
	corner(track, 9)
	stroke(track, WOOD, 1.5, 0.4)
	local fill = mk("Frame", { BackgroundColor3 = EMBER, Size = UDim2.fromScale(initial, 1), ZIndex = 13 }, track)
	corner(fill, 9)
	local dragging = false
	local function setFromX(x)
		local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		fill.Size = UDim2.fromScale(rel, 1)
		onChange(rel)
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	track.InputEnded:Connect(function() dragging = false end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
end
local saveSettingsDebounce = false
local currentSettings = { music = 0.5, sfx = 0.8 }
local function pushSettings()
	if saveSettingsDebounce then return end
	saveSettingsDebounce = true
	task.delay(1, function()
		saveSettingsDebounce = false
		Remotes.SettingsSave:FireServer(currentSettings)
	end)
end
slider("Music & Ambience Volume", 0.5, function(v)
	musicGroup.Volume = v
	currentSettings.music = v
	pushSettings()
end)
slider("Sound Effects Volume", 0.8, function(v)
	sfxGroup.Volume = v
	currentSettings.sfx = v
	pushSettings()
end)
mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 40), Font = ITALIC_FONT, Text = "Ember Grove: A Penguin's Way Home — a cozy rescue adventure.", TextColor3 = INK_SOFT, TextSize = 13, TextWrapped = true, ZIndex = 12 }, settingsContent)
settingsBtn.Activated:Connect(function() settingsOverlay.Visible = true end)

-- ============ CELEBRATIONS ============
Remotes.Celebration.OnClientEvent:Connect(function(p)
	local big = mk("Frame", { BackgroundColor3 = PARCHMENT, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.new(0, 380, 0, 110), ZIndex = 20 }, gui)
	corner(big, 16)
	stroke(big, EMBER, 4)
	mk("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 14), Size = UDim2.new(1, 0, 0, 40), Font = HEADER_FONT, Text = (p.kind == "badge" and "\u{1F396} " or "\u{2B50} ") .. (p.title or ""), TextColor3 = EMBER, TextSize = 26, ZIndex = 21 }, big)
	mk("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 56), Size = UDim2.new(1, 0, 0, 30), Font = BODY_FONT, Text = p.detail or "", TextColor3 = INK, TextSize = 16, ZIndex = 21 }, big)
	big.Size = UDim2.new(0, 30, 0, 20)
	TweenService:Create(big, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Size = UDim2.new(0, 380, 0, 110) }):Play()
	play(sndSplash)
	-- confetti on the penguin
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Rate = 0
		pe.Lifetime = NumberRange.new(1, 1.6)
		pe.Speed = NumberRange.new(8, 14)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new(0.6)
		pe.Color = ColorSequence.new(Color3.fromRGB(255, 220, 130), Color3.fromRGB(240, 130, 80))
		pe.Parent = root
		pe:Emit(40)
		task.delay(2, function() pe:Destroy() end)
	end
	task.delay(3.4, function()
		TweenService:Create(big, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		task.delay(0.5, function() big:Destroy() end)
	end)
end)

-- ============ GUARDIAN SCENE (finale flash) ============
Remotes.GuardianScene.OnClientEvent:Connect(function()
	local flash = mk("Frame", { BackgroundColor3 = Color3.fromRGB(255, 226, 160), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30 }, gui)
	local tIn = TweenService:Create(flash, TweenInfo.new(1.2), { BackgroundTransparency = 0.25 })
	tIn:Play()
	tIn.Completed:Wait()
	TweenService:Create(flash, TweenInfo.new(2.4), { BackgroundTransparency = 1 }):Play()
	task.delay(2.5, function() flash:Destroy() end)
end)

-- ============ CREDITS ============
Remotes.Credits.OnClientEvent:Connect(function()
	local overlay = mk("Frame", { BackgroundColor3 = Color3.fromRGB(28, 24, 22), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40 }, gui)
	TweenService:Create(overlay, TweenInfo.new(1.5), { BackgroundTransparency = 0.12 }):Play()
	local lines = {
		{ Config.GAME_TITLE, 34, EMBER },
		{ " ", 10 },
		{ "Pip crossed the woods, the park, the bricks, the bridge, and the dark below —", 18 },
		{ "and every spirit along the way remembered who they were.", 18 },
		{ " ", 10 },
		{ "The firehouse lights are on. The kettle is warm. The watch is kept.", 18 },
		{ " ", 10 },
		{ "\u{1F427} Thank you for playing \u{1F427}", 22, EMBER },
		{ "The city is yours to explore — ember incidents, hidden caches, and friends await.", 16 },
	}
	local holder = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 640, 0, 420), ZIndex = 41 }, overlay)
	mk("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center }, holder)
	for order, line in ipairs(lines) do
		local l = mk("TextLabel", { LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, line[2] + 8), Font = order == 1 and HEADER_FONT or BODY_FONT, Text = line[1], TextColor3 = line[3] or PARCHMENT, TextSize = line[2], TextWrapped = true, TextTransparency = 1, ZIndex = 42 }, holder)
		task.delay(0.8 + order * 0.55, function()
			TweenService:Create(l, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
		end)
	end
	task.delay(14, function()
		TweenService:Create(overlay, TweenInfo.new(2), { BackgroundTransparency = 1 }):Play()
		for _, d in ipairs(overlay:GetDescendants()) do
			if d:IsA("TextLabel") then TweenService:Create(d, TweenInfo.new(2), { TextTransparency = 1 }):Play() end
		end
		task.delay(2.1, function() overlay:Destroy() end)
	end)
end)

-- ============ PICKUP HIDING (per-player collected items) ============
local function pickupId(part)
	return (part.Parent and part.Parent.Name or "World") .. "/" .. part.Name
end
local function applyCollected(collected)
	if type(collected) ~= "table" then return end
	for _, part in ipairs(CS:GetTagged("Pickup")) do
		if part:GetAttribute("Kind") == "Lore" then continue end -- inscriptions stay readable
		if collected[pickupId(part)] then
			part.LocalTransparencyModifier = 1
			local prompt = part:FindFirstChildOfClass("ProximityPrompt")
			if prompt then prompt.Enabled = false end
			local pe = part:FindFirstChildOfClass("ParticleEmitter")
			if pe then pe.Enabled = false end
		end
	end
end

-- ============ STATE SYNC ============
Remotes.StateSync.OnClientEvent:Connect(function(s)
	if s.energy then
		TweenService:Create(energyFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(math.clamp(s.energy / (s.maxEnergy or 100), 0, 1), 1) }):Play()
	end
	if s.sparks ~= nil then sparksLabel.Text = "\u{2728} " .. s.sparks end
	if s.badges then
		badgeLabel.Text = "\u{1F396} " .. #s.badges
		latestState.badges = s.badges
	end
	if s.stageIndex then latestState.stageIndex = s.stageIndex end
	if s.completed ~= nil then latestState.completed = s.completed end
	if s.collected then
		latestState.collected = s.collected
		applyCollected(s.collected)
	end
	if s.settings then
		currentSettings = { music = s.settings.music or 0.5, sfx = s.settings.sfx or 0.8 }
		musicGroup.Volume = currentSettings.music
		sfxGroup.Volume = currentSettings.sfx
	end
end)
Remotes.QuestSync.OnClientEvent:Connect(function(q)
	if q.stageIndex then latestState.stageIndex = q.stageIndex end
	if q.completed ~= nil then latestState.completed = q.completed end
	if q.collected then
		latestState.collected = q.collected
		applyCollected(q.collected)
	end
	if q.questItems then
		local fish = q.questItems.Fish or 0
		fishChip.Text = "\u{1F41F} " .. fish
		if fish > 0 then fishChip.Visible = true end
		local seeds = q.questItems.Seed or 0
		seedChip.Text = "\u{1F331} " .. seeds
		seedChip.Visible = seeds > 0
	end
end)

-- ============ TITLE CARD ============
local title = mk("Frame", { BackgroundColor3 = Color3.fromRGB(28, 24, 22), Size = UDim2.fromScale(1, 1), ZIndex = 50 }, gui)
local tt = mk("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.new(0, 700, 0, 60), Font = HEADER_FONT, Text = Config.GAME_TITLE, TextColor3 = EMBER, TextSize = 40, TextTransparency = 1, TextWrapped = true, ZIndex = 51 }, title)
local ts = mk("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.new(0, 600, 0, 30), Font = BODY_FONT, Text = "A little penguin, a long way home.", TextColor3 = PARCHMENT, TextSize = 18, TextTransparency = 1, ZIndex = 51 }, title)
TweenService:Create(tt, TweenInfo.new(1), { TextTransparency = 0 }):Play()
TweenService:Create(ts, TweenInfo.new(1.4), { TextTransparency = 0 }):Play()

-- storm prologue: three beats, then the world fades in
local PROLOGUE = {
	"The night the storm came, the river burned with strange embers.",
	"The spirits who kept this city began to forget who they were.",
	"And far from home, one small penguin woke to the smell of smoke…",
}
task.delay(2.6, function()
	TweenService:Create(tt, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
	TweenService:Create(ts, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
	local line = mk("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 700, 0, 80), Font = ITALIC_FONT, Text = "", TextColor3 = PARCHMENT, TextSize = 22, TextWrapped = true, TextTransparency = 1, ZIndex = 51 }, title)
	for _, beat in ipairs(PROLOGUE) do
		line.Text = beat
		TweenService:Create(line, TweenInfo.new(0.9), { TextTransparency = 0 }):Play()
		task.wait(3.4)
		TweenService:Create(line, TweenInfo.new(0.7), { TextTransparency = 1 }):Play()
		task.wait(0.8)
	end
	TweenService:Create(title, TweenInfo.new(1.4), { BackgroundTransparency = 1 }):Play()
	task.delay(1.5, function() title:Destroy() end)
end)

-- ============ INITIAL DATA FETCH ============
task.spawn(function()
	local ok, initial = pcall(function() return Remotes.GetData:InvokeServer() end)
	if ok and initial then
		sparksLabel.Text = "\u{2728} " .. (initial.sparks or 0)
		badgeLabel.Text = "\u{1F396} " .. #(initial.badges or {})
		latestState.badges = initial.badges or {}
		latestState.stageIndex = initial.stageIndex or 1
		latestState.completed = initial.completed or false
		if initial.collected then
			latestState.collected = initial.collected
			applyCollected(initial.collected)
		end
		if initial.settings then
			currentSettings = { music = initial.settings.music or 0.5, sfx = initial.settings.sfx or 0.8 }
			musicGroup.Volume = currentSettings.music
			sfxGroup.Volume = currentSettings.sfx
		end
	end
end)

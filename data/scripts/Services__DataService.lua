-- DataService: server-authoritative persistence via DataStoreService.
-- * Schema-versioned player profiles with defaults merged on load.
-- * pcall + retry with backoff on every store call.
-- * Studio safety: unless workspace attribute EnableStudioSaves == true, Studio
--   sessions run on an in-memory mock store and NEVER touch production data.
-- * The game stays fully playable if loading/saving fails (session-only profile,
--   player is notified gently, and we refuse to overwrite good data with defaults).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.GameConfig)

local DataService = {}
DataService.PlayerLoaded = Instance.new("BindableEvent") -- fired (player) after profile ready

local profiles = {}   -- [player] = { data = table, dirty = bool, loadedFromStore = bool, saveFailed = bool }
local store = nil     -- nil => mock mode
local notifyRemote = nil

local function defaultData()
	return {
		v = Config.DATASTORE_SCHEMA_VERSION,
		stageIndex = 1,
		sparks = 0,
		badges = {},
		tools = {},
		questItems = {},   -- e.g. { Mitten = 2 }
		collected = {},    -- pickup unique ids already taken by this player
		unlocks = {},      -- world unlock ids earned
		cosmetics = { owned = {}, equipped = "", equippedHat = "" },
		completed = false,
		settings = { music = 0.5, sfx = 0.8 },
	}
end

-- merge defaults for any missing keys (schema migration for v1; bump logic here later)
local function migrate(data)
	local def = defaultData()
	for k, v in pairs(def) do
		if data[k] == nil then data[k] = v end
	end
	if type(data.cosmetics) ~= "table" then data.cosmetics = def.cosmetics end
	if data.cosmetics.owned == nil then data.cosmetics.owned = {} end
	if data.cosmetics.equippedHat == nil then data.cosmetics.equippedHat = "" end
	data.v = Config.DATASTORE_SCHEMA_VERSION
	return data
end

local function keyFor(player)
	return "p_" .. player.UserId
end

local function withRetries(fn, label)
	local lastErr
	for attempt = 1, Config.SAVE_RETRIES do
		local ok, resultOrErr = pcall(fn)
		if ok then return true, resultOrErr end
		lastErr = resultOrErr
		task.wait(0.5 * attempt * attempt)
	end
	warn("[DataService] " .. label .. " failed: " .. tostring(lastErr))
	return false, lastErr
end

function DataService:Init(registry)
	notifyRemote = RS.Remotes.Notify
	local studioSavesEnabled = workspace:GetAttribute(Config.STUDIO_SAVE_ATTRIBUTE) == true
	if RunService:IsStudio() and not studioSavesEnabled then
		store = nil -- mock mode: session-only data
		print("[DataService] Studio session: using in-memory data (set workspace attribute "
			.. Config.STUDIO_SAVE_ATTRIBUTE .. "=true to write real saves)")
	else
		local ok, s = pcall(function()
			return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
		end)
		if ok then store = s else
			warn("[DataService] DataStore unavailable, running session-only: " .. tostring(s))
			store = nil
		end
	end
end

local function loadProfile(player)
	local profile = { data = defaultData(), dirty = false, loadedFromStore = false, saveFailed = false }
	profiles[player] = profile
	if store then
		local ok, stored = withRetries(function()
			return store:GetAsync(keyFor(player))
		end, "load " .. player.Name)
		if ok and type(stored) == "table" then
			profile.data = migrate(stored)
			profile.loadedFromStore = true
		elseif ok then
			profile.loadedFromStore = true -- new player, defaults are correct
		else
			profile.saveFailed = true -- do NOT overwrite store with defaults later
			task.defer(function()
				if notifyRemote and player.Parent then
					notifyRemote:FireClient(player, { text = "Cloud saves are napping. Your adventure still works, but progress may not stick this visit.", kind = "warn" })
				end
			end)
		end
	else
		profile.loadedFromStore = true -- mock mode behaves like a fresh/valid profile
	end
	if player.Parent then
		DataService.PlayerLoaded:Fire(player)
	end
end

local function saveProfile(player, isFinal)
	local profile = profiles[player]
	if not profile then return end
	if not store then return end
	-- never clobber real data with a profile we failed to load
	if not profile.loadedFromStore then return end
	if not (profile.dirty or isFinal) then return end
	local snapshot = profile.data
	local ok = withRetries(function()
		store:SetAsync(keyFor(player), snapshot)
		return true
	end, "save " .. player.Name)
	if ok then profile.dirty = false end
end

function DataService:Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadProfile, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(loadProfile, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		saveProfile(player, true)
		profiles[player] = nil
	end)

	-- autosave
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(saveProfile, player, false)
			end
		end
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			saveProfile(player, true)
		end
	end)
end

-- Returns the profile data table, yielding briefly if the profile is still loading.
function DataService:Get(player)
	local deadline = os.clock() + 10
	while not profiles[player] and os.clock() < deadline and player.Parent do
		task.wait(0.1)
	end
	local profile = profiles[player]
	return profile and profile.data or nil
end

function DataService:GetIfLoaded(player)
	local profile = profiles[player]
	return profile and profile.data or nil
end

function DataService:MarkDirty(player)
	local profile = profiles[player]
	if profile then profile.dirty = true end
end

return DataService

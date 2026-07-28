--!strict
-- Main bootstrap for Ember Grove.
-- Requires every service module, wires them together through a shared registry,
-- then starts them in dependency order. Add new services to the ORDER list.

local Services = game:GetService("ServerScriptService"):WaitForChild("Services")

local ORDER = {
	"DataService",
	"WorldService",
	"InventoryService",
	"PlayerStateService",
	"FireService",
	"QuestService",
	"InteractionService",
	"NPCService",
	"ShopService",
	"FishService",
	"SideQuestService",
}

local registry: { [string]: any } = {}

for _, name in ipairs(ORDER) do
	local mod = Services:WaitForChild(name)
	local ok, service = pcall(require, mod)
	if ok then
		registry[name] = service
	else
		warn("[Main] failed to require " .. name .. ": " .. tostring(service))
	end
end

for _, name in ipairs(ORDER) do
	local service = registry[name]
	if service and service.Init then
		local ok, err = pcall(service.Init, service, registry)
		if not ok then warn("[Main] " .. name .. ".Init failed: " .. tostring(err)) end
	end
end

for _, name in ipairs(ORDER) do
	local service = registry[name]
	if service and service.Start then
		local ok, err = pcall(service.Start, service)
		if not ok then warn("[Main] " .. name .. ".Start failed: " .. tostring(err)) end
	end
end

print("[EmberGrove] server booted")

-- QA test hook: lets Studio tooling drive quest signals and inspect state.
-- Server-side BindableFunction only — clients can never reach this.
local hook = Instance.new("BindableFunction")
hook.Name = "TestHook"
hook.OnInvoke = function(action, ...)
	local args = { ... }
	if action == "signal" then
		registry.QuestService:Signal(args[1], args[2], args[3])
		return true
	elseif action == "getdata" then
		return registry.DataService:GetIfLoaded(args[1])
	elseif action == "addquestitem" then
		registry.QuestService:AddQuestItem(args[1], args[2], args[3])
		return true
	elseif action == "unlocked" then
		return registry.WorldService:IsUnlocked(args[1])
	elseif action == "granttool" then
		registry.InventoryService:GrantTool(args[1], args[2])
		return true
	elseif action == "stageid" then
		return registry.QuestService:GetStageId(args[1])
	end
	return nil
end
hook.Parent = game:GetService("ServerScriptService")


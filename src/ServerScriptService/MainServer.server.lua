local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAMES = {
	"CoinCollectedEffect",
	"BuyUpgrade",
	"UpgradeResult",
	"SyncPlayerData",
	"CollectZoneState",
	"AdminRequest",
	"AdminResult",
	"InventoryAction",
	"SyncInventory",
}

local function getOrCreateRemotes()
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")

	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
	end

	local remotes = {}

	for _, remoteName in ipairs(REMOTE_NAMES) do
		local remote = remotesFolder:FindFirstChild(remoteName)

		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = remoteName
			remote.Parent = remotesFolder
		end

		remotes[remoteName] = remote
	end

	return remotes
end

local function safeRequire(name)
	local moduleScript = script.Parent:FindFirstChild(name)

	if not moduleScript then
		warn(name .. " module not found")
		return nil
	end

	local ok, result = pcall(function()
		return require(moduleScript)
	end)

	if not ok then
		warn(name .. " failed to require:", result)
		return nil
	end

	return result
end

local function safeInit(name, callback)
	local ok, err = pcall(callback)

	if not ok then
		warn(name .. " failed to init:", err)
	end
end

local remotes = getOrCreateRemotes()

local DataService = safeRequire("DataService")
local UpgradeService = safeRequire("UpgradeService")
local LeaderboardService = safeRequire("LeaderboardService")
local BillboardStatsService = safeRequire("BillboardStatsService")
local ItemService = safeRequire("ItemService")
local CoinService = safeRequire("CoinService")
local AdminService = safeRequire("AdminService")

if DataService then
	safeInit("DataService", function()
		DataService.Init()
	end)
end

if UpgradeService then
	safeInit("UpgradeService", function()
		UpgradeService.Init(remotes)
	end)
end

if LeaderboardService then
	safeInit("LeaderboardService", function()
		LeaderboardService.Init()
	end)
end

if BillboardStatsService then
	safeInit("BillboardStatsService", function()
		BillboardStatsService.Init()
	end)
end

if ItemService then
	safeInit("ItemService", function()
		ItemService.Init(remotes)
	end)
end

if CoinService then
	safeInit("CoinService", function()
		CoinService.Init(remotes)
	end)
end

if AdminService then
	safeInit("AdminService", function()
		AdminService.Init(remotes)
	end)
end

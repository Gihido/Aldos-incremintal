local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local UpgradeService = require(script.Parent.UpgradeService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local BillboardStatsService = require(script.Parent.BillboardStatsService)
local CoinService = require(script.Parent.CoinService)

local REMOTE_NAMES = {
	"CoinCollectedEffect",
	"BuyUpgrade",
	"UpgradeResult",
	"SyncPlayerData",
	"CollectZoneState",
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

local remotes = getOrCreateRemotes()

DataService.Init()
UpgradeService.Init(remotes)
LeaderboardService.Init()
BillboardStatsService.Init()
CoinService.Init(remotes)

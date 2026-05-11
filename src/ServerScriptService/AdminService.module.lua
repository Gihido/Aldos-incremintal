local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local ItemService = require(script.Parent.ItemService)
local UpgradeService = require(script.Parent.UpgradeService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local ItemConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemConfig"))

local ADMIN_NAME = "Doter24_7"
local MAX_ADD_COINS = 1e15
local MAX_ADD_ITEMS = 999

local AdminService = {}

local adminRequestRemote
local adminResultRemote

local function isAdmin(player)
	return player and player.Name == ADMIN_NAME
end

local function sendResult(player, success, message)
	if adminResultRemote and player then
		adminResultRemote:FireClient(player, {
			Success = success == true,
			Message = message or (success and "Done" or "Error"),
		})
	end
end

local function getTargetPlayer(targetUserId)
	local userId = tonumber(targetUserId)

	if not userId then
		return nil
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId then
			return player
		end
	end

	return nil
end

local function updateLeaderstats(player)
	local data = DataService.Get(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")

	if coins then
		coins.Value = data.Coins
	end
end

local function refreshPlayerSystems(player, refreshAllPlayers)
	updateLeaderstats(player)

	if type(UpgradeService.SyncPlayer) == "function" then
		UpgradeService.SyncPlayer(player)
	end

	if refreshAllPlayers and type(UpgradeService.NotifyMaxCoinsChanged) == "function" then
		UpgradeService.NotifyMaxCoinsChanged()
	end

	if refreshAllPlayers and type(UpgradeService.SyncAllPlayers) == "function" then
		UpgradeService.SyncAllPlayers()
	end

	if type(LeaderboardService.Refresh) == "function" then
		LeaderboardService.Refresh()
	end

	if type(ItemService.SyncPlayer) == "function" then
		ItemService.SyncPlayer(player)
	end
end

local function savePlayer(player)
	if type(DataService.SavePlayer) == "function" then
		DataService.SavePlayer(player)
	elseif type(DataService.Save) == "function" then
		DataService.Save(player, true)
	end
end

local function handleAddCoins(adminPlayer, payload)
	local targetPlayer = getTargetPlayer(payload.TargetUserId)

	if not targetPlayer then
		sendResult(adminPlayer, false, "Player not found")
		return
	end

	local amount = tonumber(payload.Amount)

	if not amount or amount ~= amount or amount == math.huge or amount == -math.huge then
		sendResult(adminPlayer, false, "Invalid amount")
		return
	end

	amount = math.floor(amount)

	if amount <= 0 then
		sendResult(adminPlayer, false, "Amount must be positive")
		return
	end

	amount = math.min(amount, MAX_ADD_COINS)
	local newCoins = DataService.AddCoins(targetPlayer, amount)
	refreshPlayerSystems(targetPlayer, false)
	savePlayer(targetPlayer)
	sendResult(adminPlayer, true, `Added {amount} Coins to {targetPlayer.Name}. New balance: {newCoins}`)
end


local function handleAddItem(adminPlayer, payload)
	local targetPlayer = getTargetPlayer(payload.TargetUserId)

	if not targetPlayer then
		sendResult(adminPlayer, false, "Player not found")
		return
	end

	local itemId = tostring(payload.ItemId or "")

	if not ItemConfig[itemId] then
		sendResult(adminPlayer, false, "Unknown item")
		return
	end

	local amount = tonumber(payload.Amount)

	if not amount or amount ~= amount or amount == math.huge or amount == -math.huge then
		sendResult(adminPlayer, false, "Invalid amount")
		return
	end

	amount = math.floor(amount)

	if amount <= 0 then
		sendResult(adminPlayer, false, "Amount must be positive")
		return
	end

	amount = math.min(amount, MAX_ADD_ITEMS)
	local success, message, newCount = ItemService.AddItem(targetPlayer, itemId, amount)

	if success then
		refreshPlayerSystems(targetPlayer, false)
		savePlayer(targetPlayer)
		sendResult(adminPlayer, true, `{message}. {targetPlayer.Name} now has {newCount or DataService.GetItemCount(targetPlayer, itemId)}`)
	else
		sendResult(adminPlayer, false, message or "Failed to add item")
	end
end

local function handleResetProgress(adminPlayer, payload)
	local targetPlayer = getTargetPlayer(payload.TargetUserId)

	if not targetPlayer then
		sendResult(adminPlayer, false, "Player not found")
		return
	end

	DataService.ResetProgress(targetPlayer)
	refreshPlayerSystems(targetPlayer, true)
	savePlayer(targetPlayer)
	sendResult(adminPlayer, true, `Progress reset for {targetPlayer.Name}`)
end

local function handleRequest(player, payload)
	if not isAdmin(player) then
		warn("[AdminService] Unauthorized admin request from", player and player.Name or "unknown")
		sendResult(player, false, "Not enough permissions")
		return
	end

	if type(payload) ~= "table" then
		sendResult(player, false, "Invalid request")
		return
	end

	if payload.Action == "AddCoins" then
		handleAddCoins(player, payload)
	elseif payload.Action == "AddItem" then
		handleAddItem(player, payload)
	elseif payload.Action == "ResetProgress" then
		handleResetProgress(player, payload)
	else
		sendResult(player, false, "Unknown action")
	end
end

function AdminService.Init(remotes)
	adminRequestRemote = remotes.AdminRequest
	adminResultRemote = remotes.AdminResult

	if not adminRequestRemote or not adminResultRemote then
		warn("[AdminService] Admin remotes are missing")
		return
	end

	adminRequestRemote.OnServerEvent:Connect(handleRequest)
end

return AdminService

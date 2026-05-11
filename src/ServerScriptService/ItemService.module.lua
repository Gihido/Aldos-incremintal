local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local ItemConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemConfig"))

local CLEANUP_SECONDS = 5

local ItemService = {}

local inventoryActionRemote
local syncInventoryRemote
local cleanupLoopStarted = false

local function getItemDefinition(itemId)
	return ItemConfig[itemId]
end

local function buildItemsPayload(player)
	local inventory = DataService.GetInventory(player)
	local items = {}

	for _, itemId in ipairs(ItemConfig.Order) do
		items[itemId] = inventory.Items[itemId] or 0
	end

	return items
end

local function buildBuffsPayload(player)
	DataService.RemoveExpiredBuffs(player)

	local now = os.time()
	local payload = {}

	for _, buff in ipairs(DataService.GetActiveBuffs(player)) do
		local itemDefinition = getItemDefinition(buff.ItemId)

		if itemDefinition then
			table.insert(payload, {
				Uid = buff.Uid,
				ItemId = buff.ItemId,
				EndTime = buff.EndTime,
				Remaining = math.max(0, buff.EndTime - now),
				CoinMultiplier = buff.CoinMultiplier or itemDefinition.CoinMultiplier or 1,
			})
		end
	end

	return payload
end

local function buildPayload(player, resultType, message)
	return {
		Items = buildItemsPayload(player),
		ActiveBuffs = buildBuffsPayload(player),
		TotalCoinMultiplier = ItemService.GetCoinBuffMultiplier(player),
		ResultType = resultType,
		Message = message,
	}
end

function ItemService.SyncPlayer(player, resultType, message)
	if syncInventoryRemote and player then
		syncInventoryRemote:FireClient(player, buildPayload(player, resultType, message))
	end
end

function ItemService.CleanupExpiredBuffs(player)
	local removedAny = DataService.RemoveExpiredBuffs(player)

	if removedAny then
		ItemService.SyncPlayer(player)
	end

	return removedAny
end

function ItemService.GetCoinBuffMultiplier(player)
	if not player then
		return 1
	end

	DataService.RemoveExpiredBuffs(player)

	local multiplier = 1

	for _, buff in ipairs(DataService.GetActiveBuffs(player)) do
		local value = tonumber(buff.CoinMultiplier) or 1
		multiplier *= math.max(1, value)
	end

	return math.max(1, multiplier)
end

function ItemService.ActivateItem(player, itemId)
	local itemDefinition = getItemDefinition(itemId)

	if not itemDefinition then
		ItemService.SyncPlayer(player, "Error", "Unknown item")
		return false, "Unknown item"
	end

	if DataService.GetItemCount(player, itemId) <= 0 then
		ItemService.SyncPlayer(player, "NotEnough", "No items left")
		return false, "No items left"
	end

	DataService.RemoveItem(player, itemId, 1)
	DataService.AddActiveBuff(player, {
		Uid = HttpService:GenerateGUID(false),
		ItemId = itemId,
		EndTime = os.time() + itemDefinition.Duration,
		CoinMultiplier = itemDefinition.CoinMultiplier,
	})

	ItemService.SyncPlayer(player, "Success", `{itemDefinition.DisplayName} activated`)

	if type(DataService.SavePlayer) == "function" then
		task.defer(function()
			DataService.SavePlayer(player)
		end)
	end

	return true, "Activated"
end


function ItemService.AddItem(player, itemId, amount)
	local itemDefinition = getItemDefinition(itemId)

	if not player then
		return false, "Player not found"
	end

	if not itemDefinition then
		if player then
			ItemService.SyncPlayer(player, "Error", "Unknown item")
		end
		return false, "Unknown item"
	end

	local safeAmount = math.floor(tonumber(amount) or 0)

	if safeAmount <= 0 then
		ItemService.SyncPlayer(player, "Error", "Amount must be positive")
		return false, "Amount must be positive"
	end

	safeAmount = math.min(safeAmount, 999)
	local newCount = DataService.AddItem(player, itemId, safeAmount)
	ItemService.SyncPlayer(player, "Success", `Added {safeAmount} {itemDefinition.DisplayName}`)

	if type(DataService.SavePlayer) == "function" then
		task.defer(function()
			DataService.SavePlayer(player)
		end)
	end

	return true, `Added {safeAmount} {itemDefinition.DisplayName}`, newCount
end

function ItemService.DeleteItem(player, itemId, amount)
	local itemDefinition = getItemDefinition(itemId)

	if not itemDefinition then
		ItemService.SyncPlayer(player, "Error", "Unknown item")
		return false, "Unknown item"
	end

	local removed = DataService.RemoveItem(player, itemId, amount or 1)

	if removed <= 0 then
		ItemService.SyncPlayer(player, "NotEnough", "No items left")
		return false, "No items left"
	end

	ItemService.SyncPlayer(player, "Success", `{itemDefinition.DisplayName} deleted`)

	if type(DataService.SavePlayer) == "function" then
		task.defer(function()
			DataService.SavePlayer(player)
		end)
	end

	return true, "Deleted"
end

local function handleInventoryAction(player, payload)
	if type(payload) ~= "table" then
		ItemService.SyncPlayer(player, "Error", "Invalid inventory request")
		return
	end

	if payload.Action == "ActivateItem" then
		ItemService.ActivateItem(player, payload.ItemId)
	elseif payload.Action == "DeleteItem" then
		ItemService.DeleteItem(player, payload.ItemId, payload.Amount)
	elseif payload.Action == "RequestSync" then
		ItemService.SyncPlayer(player)
	else
		ItemService.SyncPlayer(player, "Error", "Unknown inventory action")
	end
end

local function startCleanupLoop()
	if cleanupLoopStarted then
		return
	end

	cleanupLoopStarted = true
	task.spawn(function()
		while true do
			task.wait(CLEANUP_SECONDS)

			for _, player in ipairs(Players:GetPlayers()) do
				ItemService.CleanupExpiredBuffs(player)
			end
		end
	end)
end

function ItemService.Init(remotes)
	inventoryActionRemote = remotes.InventoryAction
	syncInventoryRemote = remotes.SyncInventory

	if not inventoryActionRemote or not syncInventoryRemote then
		warn("[ItemService] Inventory remotes are missing")
		return
	end

	inventoryActionRemote.OnServerEvent:Connect(handleInventoryAction)

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			DataService.Get(player)
			ItemService.SyncPlayer(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		DataService.RemoveExpiredBuffs(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.defer(function()
			ItemService.SyncPlayer(player)
		end)
	end

	startCleanupLoop()
end

return ItemService

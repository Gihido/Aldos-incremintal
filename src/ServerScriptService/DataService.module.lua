local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE_NAME = "AldosIncrementalPlayerData_v1"
local AUTOSAVE_SECONDS = 60
local DEFAULT_DATA = {
	Coins = 0,
	Position = {
		X = 0,
		Y = 5,
		Z = 0,
	},
	Upgrades = {
		CoinGain = 0,
		MultiCoins = 0,
		MaxSpawnCoins = 0,
	},
	Inventory = {
		Items = {
			Carrot = 3,
			Cucumber = 2,
			Tomato = 1,
			Corn = 1,
		},
		ActiveBuffs = {},
	},
}

local DataService = {}

local dataStore = DataStoreService:GetDataStore(STORE_NAME)
local sessionData = {}
local autosaveStarted = false

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}

	for key, childValue in pairs(value) do
		copy[key] = deepCopy(childValue)
	end

	return copy
end

local function sanitizeNumber(value, fallback)
	local number = tonumber(value)

	if number == nil or number ~= number or number == math.huge or number == -math.huge then
		return fallback
	end

	return number
end

local function mergeWithDefaults(savedData)
	local data = deepCopy(DEFAULT_DATA)

	if type(savedData) ~= "table" then
		return data
	end

	data.Coins = math.max(0, sanitizeNumber(savedData.Coins, data.Coins))

	if type(savedData.Position) == "table" then
		data.Position.X = sanitizeNumber(savedData.Position.X, data.Position.X)
		data.Position.Y = sanitizeNumber(savedData.Position.Y, data.Position.Y)
		data.Position.Z = sanitizeNumber(savedData.Position.Z, data.Position.Z)
	end

	if type(savedData.Upgrades) == "table" then
		for upgradeId, defaultLevel in pairs(DEFAULT_DATA.Upgrades) do
			data.Upgrades[upgradeId] = math.max(0, math.floor(sanitizeNumber(savedData.Upgrades[upgradeId], defaultLevel)))
		end
	end

	if type(savedData.Inventory) == "table" then
		if type(savedData.Inventory.Items) == "table" then
			for itemId, defaultCount in pairs(DEFAULT_DATA.Inventory.Items) do
				data.Inventory.Items[itemId] = math.max(0, math.floor(sanitizeNumber(savedData.Inventory.Items[itemId], defaultCount)))
			end
		end

		if type(savedData.Inventory.ActiveBuffs) == "table" then
			local now = os.time()

			for _, buff in ipairs(savedData.Inventory.ActiveBuffs) do
				if type(buff) == "table" then
					local endTime = math.floor(sanitizeNumber(buff.EndTime, 0))

					if endTime > now then
						table.insert(data.Inventory.ActiveBuffs, {
							Uid = tostring(buff.Uid or buff.Id or ""),
							ItemId = tostring(buff.ItemId or ""),
							EndTime = endTime,
							CoinMultiplier = math.max(1, sanitizeNumber(buff.CoinMultiplier or buff.Multiplier, 1)),
						})
					end
				end
			end
		end
	end

	return data
end

local function getKey(player)
	return `player_{player.UserId}`
end

local function getHumanoidRootPart(player)
	local character = player.Character

	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

function DataService.Load(player)
	if sessionData[player] then
		return sessionData[player]
	end

	local savedData

	local success, result = pcall(function()
		return dataStore:GetAsync(getKey(player))
	end)

	if success then
		savedData = result
	else
		warn(`Failed to load data for {player.Name}: {result}`)
	end

	local data = mergeWithDefaults(savedData)
	sessionData[player] = data

	return data
end

function DataService.Get(player)
	return sessionData[player] or DataService.Load(player)
end

function DataService.UpdatePosition(player)
	local data = DataService.Get(player)
	local rootPart = getHumanoidRootPart(player)

	if not rootPart then
		return
	end

	local position = rootPart.Position
	data.Position.X = position.X
	data.Position.Y = position.Y
	data.Position.Z = position.Z
end

function DataService.RestorePosition(player)
	local data = DataService.Get(player)
	local character = player.Character or player.CharacterAdded:Wait()
	local rootPart = character:WaitForChild("HumanoidRootPart", 8)

	if not rootPart then
		return
	end

	local position = data.Position
	rootPart.CFrame = CFrame.new(position.X, position.Y, position.Z)
end

local function updateLeaderstatsCoins(player)
	local data = DataService.Get(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")

	if coins then
		coins.Value = data.Coins
	end
end

function DataService.GetPlayerData(player)
	return DataService.Get(player)
end

function DataService.SetCoins(player, value)
	local data = DataService.Get(player)
	data.Coins = math.max(0, sanitizeNumber(value, 0))
	updateLeaderstatsCoins(player)

	return data.Coins
end

function DataService.AddCoins(player, amount)
	local data = DataService.Get(player)
	local safeAmount = sanitizeNumber(amount, 0)
	data.Coins = math.max(0, data.Coins + safeAmount)
	updateLeaderstatsCoins(player)

	return data.Coins
end

function DataService.SpendCoins(player, amount)
	local data = DataService.Get(player)

	if data.Coins < amount then
		return false
	end

	data.Coins -= amount
	return true
end

function DataService.SetUpgradeLevel(player, upgradeId, level)
	local data = DataService.Get(player)
	data.Upgrades[upgradeId] = math.max(0, math.floor(level))
end

function DataService.GetUpgradeLevel(player, upgradeId)
	local data = DataService.Get(player)
	return data.Upgrades[upgradeId] or 0
end

local function ensureInventory(data)
	if type(data.Inventory) ~= "table" then
		data.Inventory = deepCopy(DEFAULT_DATA.Inventory)
	end

	if type(data.Inventory.Items) ~= "table" then
		data.Inventory.Items = deepCopy(DEFAULT_DATA.Inventory.Items)
	end

	for itemId, defaultCount in pairs(DEFAULT_DATA.Inventory.Items) do
		data.Inventory.Items[itemId] = math.max(0, math.floor(sanitizeNumber(data.Inventory.Items[itemId], defaultCount)))
	end

	if type(data.Inventory.ActiveBuffs) ~= "table" then
		data.Inventory.ActiveBuffs = {}
	end

	return data.Inventory
end

function DataService.GetInventory(player)
	local data = DataService.Get(player)
	return ensureInventory(data)
end

function DataService.GetItemCount(player, itemId)
	local inventory = DataService.GetInventory(player)
	return inventory.Items[itemId] or 0
end

function DataService.AddItem(player, itemId, amount)
	local inventory = DataService.GetInventory(player)
	local safeAmount = math.floor(sanitizeNumber(amount, 0))
	inventory.Items[itemId] = math.min(999, math.max(0, (inventory.Items[itemId] or 0) + safeAmount))

	return inventory.Items[itemId]
end

function DataService.RemoveItem(player, itemId, amount)
	local inventory = DataService.GetInventory(player)
	local safeAmount = math.max(0, math.floor(sanitizeNumber(amount, 1)))
	local currentCount = inventory.Items[itemId] or 0
	local removed = math.min(currentCount, safeAmount)
	inventory.Items[itemId] = currentCount - removed

	return removed, inventory.Items[itemId]
end

function DataService.GetActiveBuffs(player)
	local inventory = DataService.GetInventory(player)
	return inventory.ActiveBuffs
end

function DataService.AddActiveBuff(player, buffData)
	local inventory = DataService.GetInventory(player)
	table.insert(inventory.ActiveBuffs, buffData)

	return buffData
end

function DataService.RemoveExpiredBuffs(player)
	local inventory = DataService.GetInventory(player)
	local now = os.time()
	local activeBuffs = {}
	local removedAny = false

	for _, buff in ipairs(inventory.ActiveBuffs) do
		if type(buff) == "table" and math.floor(sanitizeNumber(buff.EndTime, 0)) > now then
			table.insert(activeBuffs, buff)
		else
			removedAny = true
		end
	end

	inventory.ActiveBuffs = activeBuffs
	return removedAny
end

function DataService.ResetInventory(player)
	local data = DataService.Get(player)
	data.Inventory = deepCopy(DEFAULT_DATA.Inventory)
	return data.Inventory
end

function DataService.ResetProgress(player)
	local currentData = DataService.Get(player)
	local currentPosition = type(currentData.Position) == "table" and deepCopy(currentData.Position) or deepCopy(DEFAULT_DATA.Position)
	local resetData = deepCopy(DEFAULT_DATA)
	resetData.Position = currentPosition
	sessionData[player] = resetData
	updateLeaderstatsCoins(player)

	return resetData
end

function DataService.Save(player, keepSession)
	local data = sessionData[player]

	if not data then
		return true
	end

	DataService.UpdatePosition(player)

	local payload = deepCopy(data)
	local success, errorMessage = pcall(function()
		dataStore:SetAsync(getKey(player), payload)
	end)

	if not success then
		warn(`Failed to save data for {player.Name}: {errorMessage}`)
		return false
	end

	if not keepSession then
		sessionData[player] = nil
	end

	return true
end

function DataService.SavePlayer(player)
	return DataService.Save(player, true)
end

function DataService.Init()
	Players.PlayerAdded:Connect(function(player)
		DataService.Load(player)

		player.CharacterAdded:Connect(function()
			task.defer(function()
				DataService.RestorePosition(player)
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player, false)
	end)

	if autosaveStarted then
		return
	end

	autosaveStarted = true
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)

			for _, player in ipairs(Players:GetPlayers()) do
				DataService.Save(player, true)
			end
		end
	end)
end

return DataService

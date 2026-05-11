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

function DataService.AddCoins(player, amount)
	local data = DataService.Get(player)
	data.Coins = math.max(0, data.Coins + amount)

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

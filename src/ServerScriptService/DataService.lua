local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local STORE_NAME = "AldosIncrementalPlayerData_v1"
local DEFAULT_DATA = {
	Coins = 0,
}

local DataService = {}

local dataStore = DataStoreService:GetDataStore(STORE_NAME)
local sessionData = {}

local function copyDefaultData()
	local data = {}

	for key, value in DEFAULT_DATA do
		data[key] = value
	end

	return data
end

local function getKey(player)
	return `player_{player.UserId}`
end

function DataService.Load(player)
	if sessionData[player] then
		return sessionData[player]
	end

	local data = copyDefaultData()

	if not RunService:IsStudio() then
		local success, savedData = pcall(function()
			return dataStore:GetAsync(getKey(player))
		end)

		if success and type(savedData) == "table" then
			for key, defaultValue in DEFAULT_DATA do
				local savedValue = savedData[key]

				if typeof(savedValue) == typeof(defaultValue) then
					data[key] = savedValue
				end
			end
		elseif not success then
			warn(`Failed to load data for {player.Name}: {savedData}`)
		end
	end

	sessionData[player] = data

	return data
end

function DataService.Get(player)
	return sessionData[player] or DataService.Load(player)
end

function DataService.AddCoins(player, amount)
	local data = DataService.Get(player)
	data.Coins += amount

	return data.Coins
end

function DataService.Save(player)
	local data = sessionData[player]

	if not data then
		return true
	end

	if RunService:IsStudio() then
		sessionData[player] = nil
		return true
	end

	local success, errorMessage = pcall(function()
		dataStore:SetAsync(getKey(player), data)
	end)

	if not success then
		warn(`Failed to save data for {player.Name}: {errorMessage}`)
		return false
	end

	sessionData[player] = nil
	return true
end

return DataService

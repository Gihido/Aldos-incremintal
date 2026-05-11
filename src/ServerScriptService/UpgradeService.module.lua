local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local FormatNumber = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FormatNumber"))

local BASE_MAX_ACTIVE_COINS = 10
local BUY_DEBOUNCE_SECONDS = 0.2

local UPGRADE_DEFINITIONS = {
	CoinGain = {
		Name = "Coin Gain",
		BasePrice = 2,
		PriceMultiplier = 1.25,
		MaxLevel = 15,
		Order = 1,
	},
	MultiCoins = {
		Name = "Multi Coins",
		BasePrice = 5,
		PriceMultiplier = 1.3,
		MaxLevel = 20,
		Order = 2,
	},
	MaxSpawnCoins = {
		Name = "Max Spawn Coins",
		BasePrice = 2.5,
		PriceMultiplier = 1.5,
		MaxLevel = 15,
		Order = 3,
	},
}

local UpgradeService = {}

local buyUpgradeRemote
local upgradeResultRemote
local syncPlayerDataRemote
local lastBuyRequestAt = {}
local maxCoinsChangedCallbacks = {}

local function getDefinition(upgradeId)
	return UPGRADE_DEFINITIONS[upgradeId]
end

local function getPriceForLevel(definition, level)
	return definition.BasePrice * (definition.PriceMultiplier ^ level)
end

local function getLevel(player, upgradeId)
	return DataService.GetUpgradeLevel(player, upgradeId)
end

local function getCoinGainBonus(level)
	return 1 + level
end

local function getMultiCoinsMultiplier(level)
	return 1 + (level * 0.1)
end

local function getMaxSpawnCoins(level)
	return BASE_MAX_ACTIVE_COINS + level
end

local function getEffectText(upgradeId, level)
	if upgradeId == "CoinGain" then
		return `+{FormatNumber(getCoinGainBonus(level))}`
	elseif upgradeId == "MultiCoins" then
		return `x{FormatNumber(getMultiCoinsMultiplier(level))}`
	elseif upgradeId == "MaxSpawnCoins" then
		return `{FormatNumber(getMaxSpawnCoins(level))} max`
	end

	return "-"
end

local function getSingleBonusText(upgradeId)
	if upgradeId == "CoinGain" then
		return "+1"
	elseif upgradeId == "MultiCoins" then
		return "+0.1x"
	elseif upgradeId == "MaxSpawnCoins" then
		return "+1 max"
	end

	return "-"
end

local function getBulkBonusText(upgradeId, levels)
	if levels <= 0 then
		return "0"
	end

	if upgradeId == "CoinGain" then
		return `+{FormatNumber(levels)}`
	elseif upgradeId == "MultiCoins" then
		return `+{FormatNumber(levels * 0.1)}x`
	elseif upgradeId == "MaxSpawnCoins" then
		return `+{FormatNumber(levels)} max`
	end

	return "-"
end

local function calculateBuyMax(player, upgradeId)
	local definition = getDefinition(upgradeId)

	if not definition then
		return 0, 0
	end

	local data = DataService.Get(player)
	local coins = data.Coins
	local currentLevel = getLevel(player, upgradeId)
	local levelsToBuy = 0
	local totalCost = 0

	while currentLevel + levelsToBuy < definition.MaxLevel do
		local price = getPriceForLevel(definition, currentLevel + levelsToBuy)

		if totalCost + price > coins then
			break
		end

		totalCost += price
		levelsToBuy += 1
	end

	return levelsToBuy, totalCost
end

local function updateLeaderstats(player)
	local data = DataService.Get(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")

	if coins then
		coins.Value = data.Coins
	end
end

local function notifyMaxCoinsChanged()
	for _, callback in ipairs(maxCoinsChangedCallbacks) do
		task.spawn(callback)
	end
end

function UpgradeService.GetDefinitions()
	return UPGRADE_DEFINITIONS
end

function UpgradeService.GetCoinsPerPickup(player)
	local coinGainLevel = getLevel(player, "CoinGain")
	local multiCoinsLevel = getLevel(player, "MultiCoins")
	local amount = getCoinGainBonus(coinGainLevel) * getMultiCoinsMultiplier(multiCoinsLevel)

	return math.max(1, amount)
end

function UpgradeService.GetServerMaxActiveCoins()
	local maxCoins = BASE_MAX_ACTIVE_COINS

	for _, player in ipairs(Players:GetPlayers()) do
		local level = getLevel(player, "MaxSpawnCoins")
		maxCoins = math.max(maxCoins, getMaxSpawnCoins(level))
	end

	return maxCoins
end

function UpgradeService.OnMaxCoinsChanged(callback)
	table.insert(maxCoinsChangedCallbacks, callback)
end

function UpgradeService.BuildPlayerPayload(player)
	local data = DataService.Get(player)
	local upgrades = {}

	for upgradeId, definition in pairs(UPGRADE_DEFINITIONS) do
		local level = getLevel(player, upgradeId)
		local isMaxed = level >= definition.MaxLevel
		local buyMaxLevels, buyMaxCost = calculateBuyMax(player, upgradeId)

		upgrades[upgradeId] = {
			Name = definition.Name,
			Level = level,
			MaxLevel = definition.MaxLevel,
			Price = isMaxed and 0 or getPriceForLevel(definition, level),
			PriceFormatted = isMaxed and "MAX" or FormatNumber(getPriceForLevel(definition, level)),
			EffectText = getEffectText(upgradeId, level),
			NextEffectText = isMaxed and getEffectText(upgradeId, level) or getEffectText(upgradeId, level + 1),
			BuyBonusText = getSingleBonusText(upgradeId),
			BuyMaxLevels = buyMaxLevels,
			BuyMaxCost = buyMaxCost,
			BuyMaxCostFormatted = FormatNumber(buyMaxCost),
			BuyMaxBonusText = getBulkBonusText(upgradeId, buyMaxLevels),
			Order = definition.Order,
			IsMaxed = isMaxed,
		}
	end

	return {
		Coins = data.Coins,
		CoinsFormatted = FormatNumber(data.Coins),
		CoinsPerPickup = UpgradeService.GetCoinsPerPickup(player),
		CoinsPerPickupFormatted = FormatNumber(UpgradeService.GetCoinsPerPickup(player)),
		MaxActiveCoins = UpgradeService.GetServerMaxActiveCoins(),
		Upgrades = upgrades,
	}
end

function UpgradeService.SyncPlayer(player)
	if syncPlayerDataRemote then
		syncPlayerDataRemote:FireClient(player, UpgradeService.BuildPlayerPayload(player))
	end
end

function UpgradeService.SyncAllPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		UpgradeService.SyncPlayer(player)
	end
end

function UpgradeService.BuyUpgrade(player, upgradeId, mode)
	local now = os.clock()

	if lastBuyRequestAt[player] and now - lastBuyRequestAt[player] < BUY_DEBOUNCE_SECONDS then
		return "Error", "Слишком много запросов, попробуйте чуть позже"
	end

	lastBuyRequestAt[player] = now

	local definition = getDefinition(upgradeId)

	if not definition then
		return "Error", "Такого улучшения не существует"
	end

	if mode ~= "Buy" and mode ~= "BuyMax" then
		return "Error", "Некорректный режим покупки"
	end

	local level = getLevel(player, upgradeId)

	if level >= definition.MaxLevel then
		return "Limit", "Максимальный уровень уже куплен"
	end

	local levelsToBuy = 1
	local totalCost = getPriceForLevel(definition, level)

	if mode == "BuyMax" then
		levelsToBuy, totalCost = calculateBuyMax(player, upgradeId)

		if levelsToBuy <= 0 then
			return "NotEnough", "Недостаточно монет"
		end
	elseif DataService.Get(player).Coins < totalCost then
		return "NotEnough", "Недостаточно монет"
	end

	if not DataService.SpendCoins(player, totalCost) then
		return "NotEnough", "Недостаточно монет"
	end

	DataService.SetUpgradeLevel(player, upgradeId, level + levelsToBuy)
	updateLeaderstats(player)

	if upgradeId == "MaxSpawnCoins" then
		notifyMaxCoinsChanged()
		UpgradeService.SyncAllPlayers()
	else
		UpgradeService.SyncPlayer(player)
	end
	return "Success", levelsToBuy == 1 and "Улучшение куплено!" or `Куплено уровней: {levelsToBuy}`
end

function UpgradeService.Init(remotes)
	buyUpgradeRemote = remotes.BuyUpgrade
	upgradeResultRemote = remotes.UpgradeResult
	syncPlayerDataRemote = remotes.SyncPlayerData

	buyUpgradeRemote.OnServerEvent:Connect(function(player, upgradeId, mode)
		local resultType, message = UpgradeService.BuyUpgrade(player, upgradeId, mode)

		upgradeResultRemote:FireClient(player, {
			Type = resultType,
			Message = message,
			Data = UpgradeService.BuildPlayerPayload(player),
		})
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			UpgradeService.SyncPlayer(player)
			notifyMaxCoinsChanged()
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastBuyRequestAt[player] = nil
		task.defer(notifyMaxCoinsChanged)
	end)
end

return UpgradeService

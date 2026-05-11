local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)
local ItemService = require(script.Parent.ItemService)
local UpgradeService = require(script.Parent.UpgradeService)
local ItemConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ItemConfig"))

local OFFER_SECONDS = 60
local TOTAL_AMOUNT_OPTIONS = { 3, 6, 9, 12 }
local PRICE_MULTIPLIERS = {
	[3] = 7.5,
	[6] = 10,
	[9] = 12.5,
	[12] = 15,
}
local RANDOM_FACTOR_MIN = 0.85
local RANDOM_FACTOR_MAX = 1.25

local PackTraderService = {}

local packTraderActionRemote
local syncPackTraderRemote
local offersByPlayer = {}
local refreshLoopStarted = false
local random = Random.new()

local function getItemIds()
	local ids = {}

	for _, itemId in ipairs(ItemConfig.Order or {}) do
		if ItemConfig[itemId] then
			table.insert(ids, itemId)
		end
	end

	return ids
end

local function shuffle(list)
	local shuffled = table.clone(list)

	for index = #shuffled, 2, -1 do
		local swapIndex = random:NextInteger(1, index)
		shuffled[index], shuffled[swapIndex] = shuffled[swapIndex], shuffled[index]
	end

	return shuffled
end

local function getBaseCoinsPerPickup(player)
	if type(UpgradeService.GetCoinsPerPickup) ~= "function" then
		return 1
	end

	local value = tonumber(UpgradeService.GetCoinsPerPickup(player)) or 1
	return math.max(1, value)
end

local function chooseTotalAmount()
	return TOTAL_AMOUNT_OPTIONS[random:NextInteger(1, #TOTAL_AMOUNT_OPTIONS)]
end

local function chooseItemTypes()
	local itemIds = shuffle(getItemIds())
	local typeCount = random:NextInteger(1, math.min(4, #itemIds))
	local selected = {}

	for index = 1, typeCount do
		table.insert(selected, itemIds[index])
	end

	return selected
end

local function distributeAmount(totalAmount, selectedItems)
	local remaining = totalAmount
	local offerItems = {}

	for index, itemId in ipairs(selectedItems) do
		local slotsLeft = #selectedItems - index + 1
		local amount

		if slotsLeft <= 1 then
			amount = remaining
		else
			local maxForThisSlot = math.max(1, remaining - (slotsLeft - 1))
			amount = random:NextInteger(1, maxForThisSlot)
		end

		remaining = remaining - amount
		table.insert(offerItems, {
			ItemId = itemId,
			Amount = amount,
		})
	end

	return offerItems
end

local function calculatePrice(player, totalAmount)
	local baseCoinsPerPickup = getBaseCoinsPerPickup(player)
	local multiplier = PRICE_MULTIPLIERS[totalAmount] or 10
	local randomFactor = random:NextNumber(RANDOM_FACTOR_MIN, RANDOM_FACTOR_MAX)

	return math.max(1, math.floor(baseCoinsPerPickup * multiplier * totalAmount * randomFactor))
end

local function copyOffer(offer)
	if type(offer) ~= "table" then
		return nil
	end

	local items = {}

	for _, item in ipairs(offer.Items or {}) do
		table.insert(items, {
			ItemId = item.ItemId,
			Amount = item.Amount,
		})
	end

	return {
		OfferId = offer.OfferId,
		ExpiresAt = offer.ExpiresAt,
		Remaining = math.max(0, (offer.ExpiresAt or os.time()) - os.time()),
		Items = items,
		TotalItemAmount = offer.TotalItemAmount,
		Price = offer.Price,
	}
end

local function generateOffer(player)
	local totalAmount = chooseTotalAmount()
	local selectedItems = chooseItemTypes()
	local offer = {
		OfferId = HttpService:GenerateGUID(false),
		ExpiresAt = os.time() + OFFER_SECONDS,
		Items = distributeAmount(totalAmount, selectedItems),
		TotalItemAmount = totalAmount,
		Price = calculatePrice(player, totalAmount),
	}

	offersByPlayer[player] = offer
	return offer
end

local function getOffer(player)
	local offer = offersByPlayer[player]

	if not offer or (offer.ExpiresAt or 0) <= os.time() then
		offer = generateOffer(player)
	end

	return offer
end

function PackTraderService.SyncPlayer(player, resultType, message)
	if not player or not syncPackTraderRemote then
		return
	end

	local offer = getOffer(player)
	syncPackTraderRemote:FireClient(player, {
		Offer = copyOffer(offer),
		ResultType = resultType,
		Message = message,
	})
end

function PackTraderService.RefreshOffer(player, resultType, message)
	generateOffer(player)
	PackTraderService.SyncPlayer(player, resultType, message)
end

function PackTraderService.BuyOffer(player)
	local offer = getOffer(player)

	if not offer then
		PackTraderService.SyncPlayer(player, "Error", "No offer")
		return false, "No offer"
	end

	if (offer.ExpiresAt or 0) <= os.time() then
		PackTraderService.RefreshOffer(player, "Error", "Offer expired")
		return false, "Offer expired"
	end

	local data = DataService.Get(player)
	local price = tonumber(offer.Price) or 0

	if (data.Coins or 0) < price then
		PackTraderService.SyncPlayer(player, "NotEnough", "Not enough Coins")
		return false, "Not enough Coins"
	end

	if not DataService.SpendCoins(player, price) then
		PackTraderService.SyncPlayer(player, "NotEnough", "Not enough Coins")
		return false, "Not enough Coins"
	end

	for _, item in ipairs(offer.Items or {}) do
		ItemService.AddItem(player, item.ItemId, item.Amount)
	end

	PackTraderService.RefreshOffer(player, "Success", "Offer purchased")

	if type(DataService.SavePlayer) == "function" then
		task.defer(function()
			DataService.SavePlayer(player)
		end)
	end

	return true, "Offer purchased"
end

local function handleAction(player, payload)
	if type(payload) ~= "table" then
		PackTraderService.SyncPlayer(player, "Error", "Invalid request")
		return
	end

	if payload.Action == "BuyOffer" then
		PackTraderService.BuyOffer(player)
	elseif payload.Action == "RequestSync" then
		PackTraderService.SyncPlayer(player)
	else
		PackTraderService.SyncPlayer(player, "Error", "Unknown action")
	end
end

local function startRefreshLoop()
	if refreshLoopStarted then
		return
	end

	refreshLoopStarted = true
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()

			for _, player in ipairs(Players:GetPlayers()) do
				local offer = offersByPlayer[player]

				if not offer or (offer.ExpiresAt or 0) <= now then
					PackTraderService.RefreshOffer(player)
				else
					PackTraderService.SyncPlayer(player)
				end
			end
		end
	end)
end

function PackTraderService.Init(remotes)
	packTraderActionRemote = remotes.PackTraderAction
	syncPackTraderRemote = remotes.SyncPackTrader

	if not packTraderActionRemote or not syncPackTraderRemote then
		warn("[PackTraderService] Pack trader remotes are missing")
		return
	end

	packTraderActionRemote.OnServerEvent:Connect(handleAction)

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			DataService.Get(player)
			generateOffer(player)
			PackTraderService.SyncPlayer(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		offersByPlayer[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.defer(function()
			generateOffer(player)
			PackTraderService.SyncPlayer(player)
		end)
	end

	startRefreshLoop()
end

return PackTraderService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent.DataService)
local UpgradeService = require(script.Parent.UpgradeService)

local RESPAWN_SECONDS = 1
local FILL_CHECK_SECONDS = 1
local COIN_COLOR = Color3.fromRGB(135, 135, 135)
local COIN_HIGHLIGHT_FILL = Color3.fromRGB(170, 170, 170)
local COIN_HIGHLIGHT_OUTLINE = Color3.fromRGB(255, 255, 255)

local CoinService = {}

local coinTemplate
local zonePart
local coinCollectedEffect
local activeCoins = {}
local fillLoopStarted = false
local random = Random.new()

local function getPlayerFromHit(hit)
	local character = hit:FindFirstAncestorOfClass("Model")

	if not character then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function getCoinParts(coin)
	if coin:IsA("BasePart") then
		return { coin }
	end

	local parts = {}

	if coin:IsA("Model") then
		for _, descendant in coin:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
	end

	return parts
end

local function getCoinRootPart(coin)
	if coin:IsA("BasePart") then
		return coin
	end

	if not coin:IsA("Model") then
		return nil
	end

	if coin.PrimaryPart then
		return coin.PrimaryPart
	end

	return coin:FindFirstChildWhichIsA("BasePart", true)
end

local function setCoinCFrame(coin, cframe)
	if coin:IsA("BasePart") then
		coin.CFrame = cframe
	elseif coin:IsA("Model") then
		coin:PivotTo(cframe)
	end
end

local function removeCoinGridDecor(coin)
	for _, child in coin:GetDescendants() do
		if string.find(child.Name, "GridLine") then
			child:Destroy()
		end
	end
end

local function getRandomCoinCFrame()
	local halfSize = zonePart.Size * 0.5
	local x = random:NextNumber(-halfSize.X, halfSize.X)
	local z = random:NextNumber(-halfSize.Z, halfSize.Z)
	local y = halfSize.Y + 1.5

	return zonePart.CFrame * CFrame.new(x, y, z)
end

local function styleCoin(coin)
	coin:SetAttribute("IsCoin", true)
	coin:SetAttribute("Collected", false)

	for _, part in getCoinParts(coin) do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = true
		part.Material = Enum.Material.Neon
		part.Color = COIN_COLOR
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "CoinHighlight"
	highlight.FillTransparency = 0.65
	highlight.OutlineTransparency = 0
	highlight.FillColor = COIN_HIGHLIGHT_FILL
	highlight.OutlineColor = COIN_HIGHLIGHT_OUTLINE
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = coin
end

local function removeActiveCoin(coin)
	activeCoins[coin] = nil
end

local function getActiveCoinCount()
	local activeCount = 0

	for coin in activeCoins do
		if coin.Parent then
			activeCount += 1
		else
			removeActiveCoin(coin)
		end
	end

	return activeCount
end

local function spawnCoin()
	if not coinTemplate or not zonePart then
		return false
	end

	if getActiveCoinCount() >= UpgradeService.GetServerMaxActiveCoins() then
		return false
	end

	local coin = coinTemplate:Clone()
	coin.Name = "Coin"
	removeCoinGridDecor(coin)
	styleCoin(coin)
	setCoinCFrame(coin, getRandomCoinCFrame())
	coin.Parent = Workspace
	activeCoins[coin] = true

	local coinParts = getCoinParts(coin)

	if #coinParts == 0 or not getCoinRootPart(coin) then
		warn("Spawned coin has no BasePart to touch or animate")
		coin:Destroy()
		removeActiveCoin(coin)
		return false
	end

	local function collect(player)
		if coin:GetAttribute("Collected") then
			return
		end

		coin:SetAttribute("Collected", true)

		local amount = UpgradeService.GetCoinsPerPickup(player)
		local newCoinBalance = DataService.AddCoins(player, amount)
		local leaderstats = player:FindFirstChild("leaderstats")
		local coins = leaderstats and leaderstats:FindFirstChild("Coins")

		if coins then
			coins.Value = newCoinBalance
		end

		coinCollectedEffect:FireClient(player, amount)
		UpgradeService.SyncPlayer(player)

		removeActiveCoin(coin)
		coin:Destroy()

		task.delay(RESPAWN_SECONDS, function()
			CoinService.FillCoinsToLimit()
		end)
	end

	for _, part in coinParts do
		part.Touched:Connect(function(hit)
			local player = getPlayerFromHit(hit)

			if player then
				collect(player)
			end
		end)
	end

	return true
end

function CoinService.FillCoinsToLimit()
	local maxActiveCoins = UpgradeService.GetServerMaxActiveCoins()

	while getActiveCoinCount() < maxActiveCoins do
		if not spawnCoin() then
			break
		end
	end
end

local function startFillLoop()
	if fillLoopStarted then
		return
	end

	fillLoopStarted = true
	task.spawn(function()
		while true do
			CoinService.FillCoinsToLimit()
			task.wait(FILL_CHECK_SECONDS)
		end
	end)
end

function CoinService.Init(remotes)
	coinTemplate = ServerStorage:WaitForChild("CoinPart")
	zonePart = Workspace:WaitForChild("ZonePart")
	coinCollectedEffect = remotes.CoinCollectedEffect or ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CoinCollectedEffect")

	UpgradeService.OnMaxCoinsChanged(function()
		CoinService.FillCoinsToLimit()
	end)

	CoinService.FillCoinsToLimit()
	startFillLoop()
end

return CoinService

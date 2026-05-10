local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent.DataService)
local LeaderboardService = require(script.Parent.LeaderboardService)

local COIN_REWARD = 1
local MAX_ACTIVE_COINS = 10
local RESPAWN_SECONDS = 1
local COIN_COLOR = Color3.fromRGB(255, 235, 40)
local COIN_HIGHLIGHT_FILL = Color3.fromRGB(255, 255, 180)
local COIN_HIGHLIGHT_OUTLINE = Color3.fromRGB(255, 255, 255)

local CoinService = {}

local coinTemplate
local zonePart
local coinCollectedEffect
local activeCoins = {}

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

local function getRandomCoinCFrame()
	local halfSize = zonePart.Size * 0.5
	local x = Random.new():NextNumber(-halfSize.X, halfSize.X)
	local z = Random.new():NextNumber(-halfSize.Z, halfSize.Z)
	local y = halfSize.Y + 1.5

	return zonePart.CFrame * CFrame.new(x, y, z)
end

local function styleCoin(coin)
	coin:SetAttribute("IsCoin", true)
	coin:SetAttribute("Collected", false)

	local coinParts = getCoinParts(coin)

	for _, part in coinParts do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = true
		part.Material = Enum.Material.Neon
		part.Color = COIN_COLOR
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "CoinHighlight"
	highlight.FillTransparency = 0.45
	highlight.OutlineTransparency = 0
	highlight.FillColor = COIN_HIGHLIGHT_FILL
	highlight.OutlineColor = COIN_HIGHLIGHT_OUTLINE
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = coin
end

local function removeActiveCoin(coin)
	activeCoins[coin] = nil
end

local function spawnCoin()
	if not coinTemplate or not zonePart then
		return
	end

	local activeCount = 0

	for coin in activeCoins do
		if coin.Parent then
			activeCount += 1
		else
			removeActiveCoin(coin)
		end
	end

	if activeCount >= MAX_ACTIVE_COINS then
		return
	end

	local coin = coinTemplate:Clone()
	coin.Name = "Coin"
	styleCoin(coin)
	setCoinCFrame(coin, getRandomCoinCFrame())
	coin.Parent = Workspace
	activeCoins[coin] = true

	local coinParts = getCoinParts(coin)

	if #coinParts == 0 or not getCoinRootPart(coin) then
		warn("Spawned coin has no BasePart to touch or animate")
		coin:Destroy()
		removeActiveCoin(coin)
		return
	end

	local function collect(player)
		if coin:GetAttribute("Collected") then
			return
		end

		coin:SetAttribute("Collected", true)

		local rootPart = getCoinRootPart(coin)
		local effectPosition = rootPart and rootPart.Position or zonePart.Position
		local totalCoins = DataService.AddCoins(player, COIN_REWARD)

		LeaderboardService.SetCoins(player, totalCoins)
		coinCollectedEffect:FireClient(player, effectPosition, COIN_REWARD, totalCoins)

		removeActiveCoin(coin)
		coin:Destroy()

		task.delay(RESPAWN_SECONDS, spawnCoin)
	end

	for _, part in coinParts do
		part.Touched:Connect(function(hit)
			local player = getPlayerFromHit(hit)

			if player then
				collect(player)
			end
		end)
	end
end

local function fillCoinZone()
	for _ = 1, MAX_ACTIVE_COINS do
		spawnCoin()
	end
end

function CoinService.Init()
	coinTemplate = ServerStorage:WaitForChild("CoinPart")
	zonePart = Workspace:WaitForChild("ZonePart")
	coinCollectedEffect = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CoinCollectedEffect")

	fillCoinZone()
end

return CoinService

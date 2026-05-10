local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent.DataService)
local LeaderboardService = require(script.Parent.LeaderboardService)

local COIN_REWARD = 1
local RESPAWN_SECONDS = 2
local SPIN_TIME = 1.2

local CoinService = {}

local coinPart
local coinCollectedEffect
local touchDebounce = {}

local function getPlayerFromHit(hit)
	local character = hit:FindFirstAncestorOfClass("Model")

	if not character then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function setCoinVisible(isVisible)
	coinPart.Transparency = isVisible and 0 or 1
	coinPart.CanTouch = isVisible
end

local function playIdleSpin()
	local spinTween = TweenService:Create(
		coinPart,
		TweenInfo.new(SPIN_TIME, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Orientation = coinPart.Orientation + Vector3.new(0, 360, 0) }
	)

	spinTween:Play()
end

local function collect(player)
	if touchDebounce[player] then
		return
	end

	touchDebounce[player] = true

	local totalCoins = DataService.AddCoins(player, COIN_REWARD)
	LeaderboardService.SetCoins(player, totalCoins)
	coinCollectedEffect:FireClient(player, coinPart.Position, COIN_REWARD, totalCoins)

	setCoinVisible(false)
	task.delay(RESPAWN_SECONDS, function()
		setCoinVisible(true)
		touchDebounce[player] = nil
	end)
end

function CoinService.Init()
	coinPart = Workspace:WaitForChild("CoinPart")
	coinCollectedEffect = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CoinCollectedEffect")

	coinPart.Touched:Connect(function(hit)
		local player = getPlayerFromHit(hit)

		if player then
			collect(player)
		end
	end)

	playIdleSpin()
end

return CoinService

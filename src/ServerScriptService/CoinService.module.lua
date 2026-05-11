local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent.DataService)
local UpgradeService = require(script.Parent.UpgradeService)

local RESPAWN_SECONDS = 1
local FILL_CHECK_SECONDS = 1
local COLLECT_CHECK_SECONDS = 0.12
local COLLECT_SQUARE_SIZE = 3
local ZONE_EXIT_HYSTERESIS = 1
local COIN_LAUNCH_SECONDS = 0.3
local COIN_BACK_OFF_SECONDS = 0.2
local START_CHASE_SPEED = 12
local CHASE_ACCELERATION = 55
local MAX_CHASE_SPEED = 90
local HIT_DISTANCE = 1.8
local CHASE_TIMEOUT_SECONDS = 5
local COIN_COLOR = Color3.fromRGB(135, 135, 135)
local COIN_HIGHLIGHT_FILL = Color3.fromRGB(170, 170, 170)
local COIN_HIGHLIGHT_OUTLINE = Color3.fromRGB(255, 255, 255)

local CoinService = {}

local coinTemplate
local zonePart
local coinCollectedEffect
local collectZoneStateRemote
local activeCoins = {}
local fillLoopStarted = false
local collectLoopStarted = false
local playersInsideZone = {}
local random = Random.new()

local function getCoinParts(coin)
	if coin:IsA("BasePart") then
		return { coin }
	end

	local parts = {}

	if coin:IsA("Model") then
		for _, descendant in ipairs(coin:GetDescendants()) do
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

local function getCoinCFrame(coin)
	if coin:IsA("BasePart") then
		return coin.CFrame
	end

	local rootPart = getCoinRootPart(coin)

	return rootPart and rootPart.CFrame or CFrame.new()
end

local function getCoinPosition(coin)
	return getCoinCFrame(coin).Position
end

local function setCoinCFrame(coin, cframe)
	if coin:IsA("BasePart") then
		coin.CFrame = cframe
		return
	end

	if not coin:IsA("Model") then
		return
	end

	local rootPart = getCoinRootPart(coin)

	if not rootPart then
		return
	end

	local rootCFrame = rootPart.CFrame

	for _, part in ipairs(getCoinParts(coin)) do
		local partOffset = rootCFrame:ToObjectSpace(part.CFrame)
		part.CFrame = cframe * partOffset
	end
end

local function removeCoinGridDecor(coin)
	for _, child in ipairs(coin:GetDescendants()) do
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

	for _, part in ipairs(getCoinParts(coin)) do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
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

	for coin in pairs(activeCoins) do
		if coin.Parent then
			activeCount = activeCount + 1
		else
			removeActiveCoin(coin)
		end
	end

	return activeCount
end

local function getServerMaxActiveCoins()
	if type(UpgradeService.GetServerMaxActiveCoins) ~= "function" then
		warn("UpgradeService.GetServerMaxActiveCoins is not available; using fallback max coins")
		return 0
	end

	return UpgradeService.GetServerMaxActiveCoins()
end

local function getCoinsPerPickup(player)
	if type(UpgradeService.GetCoinsPerPickup) ~= "function" then
		warn("UpgradeService.GetCoinsPerPickup is not available; using fallback pickup amount")
		return 1
	end

	return UpgradeService.GetCoinsPerPickup(player)
end

local function awardCoins(player, amount)
	if type(DataService.AddCoins) ~= "function" then
		warn("DataService.AddCoins is not available; coin award skipped")
		return nil
	end

	return DataService.AddCoins(player, amount)
end

local function syncPlayer(player)
	if type(UpgradeService.SyncPlayer) == "function" then
		UpgradeService.SyncPlayer(player)
	end
end

local function getPlayerRoot(player)
	local character = player.Character

	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function isPlayerInsideZone(player)
	if not zonePart then
		return false
	end

	local root = getPlayerRoot(player)

	if not root then
		return false
	end

	local previousState = playersInsideZone[player] == true
	local margin = previousState and ZONE_EXIT_HYSTERESIS or 0
	local localPosition = zonePart.CFrame:PointToObjectSpace(root.Position)
	local halfSize = zonePart.Size * 0.5

	return math.abs(localPosition.X) <= halfSize.X + margin
		and math.abs(localPosition.Y) <= halfSize.Y + 5
		and math.abs(localPosition.Z) <= halfSize.Z + margin
end

local function updateCollectZoneState(player, isInside)
	if playersInsideZone[player] == isInside then
		return
	end

	playersInsideZone[player] = isInside == true

	if collectZoneStateRemote then
		collectZoneStateRemote:FireClient(player, isInside, COLLECT_SQUARE_SIZE)
	end
end

local function isCoinInsideCollectSquare(player, coin)
	local root = getPlayerRoot(player)

	if not root then
		return false
	end

	local coinPosition = getCoinPosition(coin)
	local halfSize = COLLECT_SQUARE_SIZE * 0.5

	return math.abs(coinPosition.X - root.Position.X) <= halfSize
		and math.abs(coinPosition.Z - root.Position.Z) <= halfSize
		and math.abs(coinPosition.Y - root.Position.Y) <= 12
end

local function createParticleBurst(parent, name, color, emitCount, lifetimeMin, lifetimeMax, speedMin, speedMax)
	if not parent then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = parent

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name .. "Emitter"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.75
	emitter.Lifetime = NumberRange.new(lifetimeMin, lifetimeMax)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(speedMin, speedMax)
	emitter.SpreadAngle = Vector2.new(360, 360)
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = attachment
	emitter:Emit(emitCount)

	Debris:AddItem(attachment, lifetimeMax + 0.4)
end

local function createCoinLaunchEffect(coin)
	createParticleBurst(getCoinRootPart(coin), "CoinLaunchEffect", Color3.fromRGB(235, 235, 235), 10, 0.18, 0.35, 3, 8)
end

local function createWhiteCoinImpact(player)
	createParticleBurst(getPlayerRoot(player), "CoinImpactEffect", Color3.fromRGB(255, 255, 255), 22, 0.22, 0.45, 6, 12)
end

local function cleanupCollectedCoin(coin)
	removeActiveCoin(coin)

	if coin.Parent then
		coin:Destroy()
	end

	task.delay(RESPAWN_SECONDS, function()
		CoinService.FillCoinsToLimit()
	end)
end

local function finishCoinCollection(player, coin, amount)
	if not coin.Parent then
		return
	end

	local newCoinBalance = awardCoins(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")

	if coins and newCoinBalance then
		coins.Value = newCoinBalance
	end

	createWhiteCoinImpact(player)
	coinCollectedEffect:FireClient(player, amount)
	syncPlayer(player)
	cleanupCollectedCoin(coin)
end

local function moveCoinToward(coin, targetCFrame, duration, easingStyle, easingDirection)
	local startCFrame = getCoinCFrame(coin)
	local elapsed = 0

	while coin.Parent and elapsed < duration do
		local deltaTime = RunService.Heartbeat:Wait()
		elapsed = elapsed + deltaTime

		local alpha = math.clamp(elapsed / duration, 0, 1)

		if easingStyle == Enum.EasingStyle.Back then
			alpha = 1 - ((1 - alpha) * (1 - alpha))
		elseif easingStyle == Enum.EasingStyle.Quad and easingDirection == Enum.EasingDirection.Out then
			alpha = 1 - ((1 - alpha) * (1 - alpha))
		end

		setCoinCFrame(coin, startCFrame:Lerp(targetCFrame, alpha))
	end

	if coin.Parent then
		setCoinCFrame(coin, targetCFrame)
	end
end

local function chaseCoinToPlayer(player, coin, amount)
	local speed = START_CHASE_SPEED
	local startedAt = os.clock()
	local rotation = 0

	while coin.Parent do
		local root = getPlayerRoot(player)

		if not root then
			cleanupCollectedCoin(coin)
			return
		end

		local currentPosition = getCoinPosition(coin)
		local targetPosition = root.Position + Vector3.new(0, 1.2, 0)
		local direction = targetPosition - currentPosition
		local distance = direction.Magnitude

		if distance <= HIT_DISTANCE then
			finishCoinCollection(player, coin, amount)
			return
		end

		local deltaTime = RunService.Heartbeat:Wait()
		speed = math.min(MAX_CHASE_SPEED, speed + (CHASE_ACCELERATION * deltaTime))

		if os.clock() - startedAt > CHASE_TIMEOUT_SECONDS and speed >= MAX_CHASE_SPEED then
			setCoinCFrame(coin, CFrame.new(targetPosition))
			finishCoinCollection(player, coin, amount)
			return
		end
	end)

		if distance > 0.001 then
			local step = math.min(distance, speed * deltaTime)
			local newPosition = currentPosition + (direction.Unit * step)
			rotation = rotation + (deltaTime * speed * 0.2)
			local chaseCFrame = CFrame.new(newPosition) * CFrame.Angles(0, rotation, 0)
			setCoinCFrame(coin, chaseCFrame)
		end
	end
end

local function startCoinChasePlayer(player, coin, amount)
	task.spawn(function()
		if not coin.Parent then
			return
		end

		local root = getPlayerRoot(player)

		if not root then
			cleanupCollectedCoin(coin)
			return
		end

		createCoinLaunchEffect(coin)

		local startCFrame = getCoinCFrame(coin)
		local launchPosition = startCFrame.Position + Vector3.new(0, random:NextNumber(2, 4), 0)
		moveCoinToward(coin, CFrame.new(launchPosition), COIN_LAUNCH_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		if not coin.Parent then
			return
		end

		root = getPlayerRoot(player)

		if not root then
			cleanupCollectedCoin(coin)
			return
		end

		local awayDirection = launchPosition - root.Position
		awayDirection = Vector3.new(awayDirection.X, 0, awayDirection.Z)

		if awayDirection.Magnitude < 0.1 then
			awayDirection = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1))
		end

		if awayDirection.Magnitude < 0.1 then
			awayDirection = Vector3.new(1, 0, 0)
		end

		local sideDirection = Vector3.new(-awayDirection.Z, 0, awayDirection.X).Unit * random:NextNumber(-1.4, 1.4)
		local backOffPosition = launchPosition + awayDirection.Unit * 2 + sideDirection
		moveCoinToward(coin, CFrame.new(backOffPosition), COIN_BACK_OFF_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		chaseCoinToPlayer(player, coin, amount)
	end)
end

local function collectCoin(player, coin)
	if coin:GetAttribute("Collected") then
		return
	end

	local root = getPlayerRoot(player)

	if not root or not isPlayerInsideZone(player) then
		return
	end

	coin:SetAttribute("Collected", true)
	coin:SetAttribute("IsCoin", false)

	for _, part in ipairs(getCoinParts(coin)) do
		part.CanTouch = false
		part.CanQuery = false
	end

	local amount = getCoinsPerPickup(player)
	startCoinChasePlayer(player, coin, amount)
end


local function spawnCoin()
	if not coinTemplate or not zonePart then
		return false
	end

	if getActiveCoinCount() >= getServerMaxActiveCoins() then
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

	return true
end

function CoinService.FillCoinsToLimit()
	local maxActiveCoins = getServerMaxActiveCoins()

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

local function startCollectLoop()
	if collectLoopStarted then
		return
	end

	collectLoopStarted = true
	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				local isInside = isPlayerInsideZone(player)
				updateCollectZoneState(player, isInside)

				if isInside then
					for coin in pairs(activeCoins) do
						if coin.Parent and not coin:GetAttribute("Collected") and isCoinInsideCollectSquare(player, coin) then
							collectCoin(player, coin)
						end
					end
				end
			end

			task.wait(COLLECT_CHECK_SECONDS)
		end
	end)
end

function CoinService.Init(remotes)
	coinTemplate = ServerStorage:WaitForChild("CoinPart")
	zonePart = Workspace:WaitForChild("ZonePart")
	coinCollectedEffect = remotes.CoinCollectedEffect or ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CoinCollectedEffect")
	collectZoneStateRemote = remotes.CollectZoneState or ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CollectZoneState")

	UpgradeService.OnMaxCoinsChanged(function()
		CoinService.FillCoinsToLimit()
	end)

	CoinService.FillCoinsToLimit()
	Players.PlayerRemoving:Connect(function(player)
		playersInsideZone[player] = nil
	end)

	startFillLoop()
	startCollectLoop()
end

return CoinService

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
local START_CHASE_SPEED = 12
local CHASE_ACCELERATION = 55
local MAX_CHASE_SPEED = 90
local HIT_DISTANCE = 1.8
local CHASE_TIMEOUT_SECONDS = 5
local COIN_COLOR = Color3.fromRGB(210, 210, 210)
local COIN_HIGHLIGHT_FILL = Color3.fromRGB(235, 235, 235)
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
local spawnCoin

local function getPlayerRoot(player)
	local character = player and player.Character

	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function getCoinParts(coin)
	if not coin then
		return {}
	end

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
	if not coin then
		return nil
	end

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
	if not coin then
		return CFrame.new()
	end

	if coin:IsA("Model") then
		local ok, pivot = pcall(function()
			return coin:GetPivot()
		end)

		if ok and pivot then
			return pivot
		end
	elseif coin:IsA("BasePart") then
		return coin.CFrame
	end

	local rootPart = getCoinRootPart(coin)

	return rootPart and rootPart.CFrame or CFrame.new()
end

local function getCoinPosition(coin)
	return getCoinCFrame(coin).Position
end

local function setCoinCFrame(coin, cframe)
	if not coin then
		return
	end

	if coin:IsA("Model") then
		local ok = pcall(function()
			coin:PivotTo(cframe)
		end)

		if ok then
			return
		end
	elseif coin:IsA("BasePart") then
		coin.CFrame = cframe
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

local function cleanupOldCoinDecor(coin)
	if not coin then
		return
	end

	for _, child in ipairs(coin:GetDescendants()) do
		if string.find(child.Name, "GridLine") or string.find(child.Name, "BaseplateLine") then
			child:Destroy()
		end
	end
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

local function createCoinLaunchBurstEffect(coin)
	local coinPosition = getCoinPosition(coin)
	local burst = Instance.new("Part")
	burst.Name = "CoinLaunchWhiteBurst"
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.CanTouch = false
	burst.CastShadow = false
	burst.Color = Color3.fromRGB(255, 255, 255)
	burst.Material = Enum.Material.Neon
	burst.Shape = Enum.PartType.Ball
	burst.Size = Vector3.new(0.35, 0.35, 0.35)
	burst.Transparency = 0.25
	burst.CFrame = CFrame.new(coinPosition)
	burst.Parent = Workspace

	local tween = TweenService:Create(burst, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(1.45, 1.45, 1.45),
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(burst, 0.3)
end

local function createWhiteCoinImpact(player)
	local root = getPlayerRoot(player)

	if not root then
		return
	end

	local impactPosition = root.Position + Vector3.new(0, 1.25, 0)
	local orb = Instance.new("Part")
	orb.Name = "CoinImpactWhiteOrb"
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CanTouch = false
	orb.CastShadow = false
	orb.Color = Color3.fromRGB(255, 255, 255)
	orb.Material = Enum.Material.Neon
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(1.05, 1.05, 1.05)
	orb.Transparency = 0.22
	orb.CFrame = CFrame.new(impactPosition)
	orb.Parent = Workspace

	TweenService:Create(orb, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(3, 3, 3),
		Transparency = 1,
	}):Play()
	Debris:AddItem(orb, 0.35)

	local ring = Instance.new("Part")
	ring.Name = "CoinImpactSilverRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Color = Color3.fromRGB(235, 235, 235)
	ring.Material = Enum.Material.Neon
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.08, 1.1, 1.1)
	ring.Transparency = 0.28
	ring.CFrame = CFrame.new(impactPosition) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = Workspace

	TweenService:Create(ring, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.08, 4.2, 4.2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.4)

	for index = 1, 8 do
		local angle = (math.pi * 2 * index) / 8
		local direction = Vector3.new(math.cos(angle), 0.18, math.sin(angle)).Unit
		local spark = Instance.new("Part")
		spark.Name = "CoinImpactLightSpark"
		spark.Anchored = true
		spark.CanCollide = false
		spark.CanQuery = false
		spark.CanTouch = false
		spark.CastShadow = false
		spark.Color = Color3.fromRGB(245, 245, 245)
		spark.Material = Enum.Material.Neon
		spark.Shape = Enum.PartType.Ball
		spark.Size = Vector3.new(0.14, 0.14, 0.14)
		spark.Transparency = 0.15
		spark.CFrame = CFrame.new(impactPosition)
		spark.Parent = Workspace

		TweenService:Create(spark, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(impactPosition + (direction * 1.45)),
			Size = Vector3.new(0.05, 0.05, 0.05),
			Transparency = 1,
		}):Play()
		Debris:AddItem(spark, 0.3)
	end
end

local function getServerMaxActiveCoins()
	if type(UpgradeService.GetServerMaxActiveCoins) ~= "function" then
		warn("[CoinService] UpgradeService.GetServerMaxActiveCoins is not available; using fallback max coins")
		return 10
	end

	local value = tonumber(UpgradeService.GetServerMaxActiveCoins()) or 10

	if value <= 0 then
		warn("[CoinService] UpgradeService.GetServerMaxActiveCoins returned", value, "; using minimum max coins")
	end

	return math.max(1, value)
end

local function getCoinsPerPickup(player)
	if type(UpgradeService.GetCoinsPerPickup) ~= "function" then
		warn("UpgradeService.GetCoinsPerPickup is not available; using fallback pickup amount")
		return 1
	end

	return UpgradeService.GetCoinsPerPickup(player)
end

local function awardCoinsToPlayer(player, amount)
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

local function scheduleCoinRespawn()
	task.delay(RESPAWN_SECONDS, function()
		if spawnCoin then
			spawnCoin()
		end
	end)
end

local function cancelCollectedCoin(coin)
	if coin then
		removeActiveCoin(coin)

		if coin.Parent then
			coin:Destroy()
		end
	end

	scheduleCoinRespawn()
end

local function finishCoinCollection(player, coin, amount)
	if not coin or not coin.Parent then
		return
	end

	print("[CoinService] Finish collect:", player.Name, amount)

	local newCoinBalance = awardCoinsToPlayer(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")

	if coins and newCoinBalance then
		coins.Value = newCoinBalance
	end

	createWhiteCoinImpact(player)

	if coinCollectedEffect then
		coinCollectedEffect:FireClient(player, amount)
	end

	syncPlayer(player)
	removeActiveCoin(coin)
	coin:Destroy()
	scheduleCoinRespawn()
end

local function animateCoinToPosition(coin, targetPosition, duration)
	local startedAt = os.clock()
	local startCFrame = getCoinCFrame(coin)
	local startPosition = startCFrame.Position

	while coin and coin.Parent and os.clock() - startedAt < duration do
		local alpha = math.clamp((os.clock() - startedAt) / duration, 0, 1)
		local eased = 1 - ((1 - alpha) * (1 - alpha))
		local position = startPosition:Lerp(targetPosition, eased)
		setCoinCFrame(coin, CFrame.new(position))
		RunService.Heartbeat:Wait()
	end

	if coin and coin.Parent then
		setCoinCFrame(coin, CFrame.new(targetPosition))
	end
end

local function runCoinChase(player, coin, amount)
	local root = getPlayerRoot(player)

	if not root then
		cancelCollectedCoin(coin)
		return
	end

	local startedAt = os.clock()
	local speed = START_CHASE_SPEED
	local rotation = 0
	local startPosition = getCoinPosition(coin)
	local awayDirection = startPosition - root.Position

	if awayDirection.Magnitude < 0.1 then
		awayDirection = Vector3.new(random:NextNumber() - 0.5, 0, random:NextNumber() - 0.5)
	end

	awayDirection = Vector3.new(awayDirection.X, 0, awayDirection.Z)

	if awayDirection.Magnitude < 0.1 then
		awayDirection = Vector3.new(1, 0, 0)
	end

	createCoinLaunchBurstEffect(coin)
	local liftPosition = startPosition + Vector3.new(0, 3, 0) + (awayDirection.Unit * 2)
	animateCoinToPosition(coin, liftPosition, COIN_LAUNCH_SECONDS)

	while coin and coin.Parent do
		root = getPlayerRoot(player)

		if not root then
			cancelCollectedCoin(coin)
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

		if os.clock() - startedAt > CHASE_TIMEOUT_SECONDS then
			speed = MAX_CHASE_SPEED
		end

		if direction.Magnitude > 0.001 then
			local step = math.min(distance, speed * deltaTime)
			local newPosition = currentPosition + (direction.Unit * step)
			rotation = rotation + (deltaTime * 12)
			local newCFrame = CFrame.new(newPosition) * CFrame.Angles(rotation, rotation * 0.7, rotation * 0.35)
			setCoinCFrame(coin, newCFrame)
		end
	end
end

local function startCoinChasePlayer(player, coin, amount)
	task.spawn(function()
		local ok, err = pcall(function()
			runCoinChase(player, coin, amount)
		end)

		if not ok then
			warn("Coin chase failed:", err)
			cancelCollectedCoin(coin)
		end
	end)
end

local function tryCollectCoinForPlayer(player, coin)
	if not coin or not coin.Parent or coin:GetAttribute("Collected") then
		return
	end

	print("[CoinService] Try collect:", player.Name, coin.Name)

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
		part.CanQuery = true
		part.Material = Enum.Material.Neon
		part.Color = COIN_COLOR
	end

	local oldHighlight = coin:FindFirstChild("CoinHighlight")

	if oldHighlight then
		oldHighlight:Destroy()
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

spawnCoin = function()
	if not coinTemplate then
		warn("[CoinService] CoinPart template not found in ServerStorage")
		return false
	end

	if not zonePart then
		warn("[CoinService] ZonePart not found in Workspace")
		return false
	end

	local maxCoins = getServerMaxActiveCoins()
	local activeCount = getActiveCoinCount()
	print("[CoinService] spawn check active:", activeCount, "max:", maxCoins)

	if activeCount >= maxCoins then
		return false
	end

	local coin = coinTemplate:Clone()
	coin.Name = "Coin"

	cleanupOldCoinDecor(coin)
	styleCoin(coin)

	local coinParts = getCoinParts(coin)

	if #coinParts == 0 or not getCoinRootPart(coin) then
		warn("[CoinService] Spawned coin has no BasePart")
		coin:Destroy()
		return false
	end

	coin.Parent = Workspace
	setCoinCFrame(coin, getRandomCoinCFrame())
	activeCoins[coin] = true

	print("[CoinService] Coin spawned:", coin:GetFullName())

	return true
end

function CoinService.FillCoinsToLimit()
	print("[CoinService] FillCoinsToLimit called")

	local maxActiveCoins = getServerMaxActiveCoins()
	print("[CoinService] active:", getActiveCoinCount(), "max:", maxActiveCoins)

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
							tryCollectCoinForPlayer(player, coin)
						end
					end
				end
			end

			task.wait(COLLECT_CHECK_SECONDS)
		end
	end)
end

function CoinService.Init(remotes)
	print("[CoinService] Init started")

	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	coinTemplate = ServerStorage:FindFirstChild("CoinPart")
	zonePart = Workspace:FindFirstChild("ZonePart")
	coinCollectedEffect = remotes and remotes.CoinCollectedEffect or remotesFolder and remotesFolder:FindFirstChild("CoinCollectedEffect")
	collectZoneStateRemote = remotes and remotes.CollectZoneState or remotesFolder and remotesFolder:FindFirstChild("CollectZoneState")

	print("[CoinService] coinTemplate:", coinTemplate)
	print("[CoinService] zonePart:", zonePart)

	if not coinTemplate then
		warn("[CoinService] CoinPart template not found in ServerStorage")
	elseif #getCoinParts(coinTemplate) == 0 then
		warn("[CoinService] CoinPart has no BasePart")
	end

	if not zonePart then
		warn("[CoinService] ZonePart not found in Workspace")
	end

	if not coinCollectedEffect then
		warn("[CoinService] CoinCollectedEffect RemoteEvent not found in ReplicatedStorage.Remotes")
	end

	if not collectZoneStateRemote then
		warn("[CoinService] CollectZoneState RemoteEvent not found in ReplicatedStorage.Remotes")
	end

	if type(UpgradeService.OnMaxCoinsChanged) ~= "function" then
		warn("[CoinService] UpgradeService.OnMaxCoinsChanged is not available")
	else
		UpgradeService.OnMaxCoinsChanged(function()
			CoinService.FillCoinsToLimit()
		end)
	end

	CoinService.FillCoinsToLimit()
	Players.PlayerRemoving:Connect(function(player)
		playersInsideZone[player] = nil
	end)

	startFillLoop()
	startCollectLoop()
end

return CoinService

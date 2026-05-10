local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local coinCollectedEffect = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CoinCollectedEffect")

local ROTATION_SPEED_DEGREES = 45
local BOB_HEIGHT = 0.45
local BOB_SPEED = 2.2

local animatedCoins = {}

local function getPlayerGui()
	return player:WaitForChild("PlayerGui")
end

local function getCoinCFrame(coin)
	if coin:IsA("BasePart") then
		return coin.CFrame
	end

	if coin:IsA("Model") then
		return coin:GetPivot()
	end

	return nil
end

local function setCoinCFrame(coin, cframe)
	if coin:IsA("BasePart") then
		coin.CFrame = cframe
	elseif coin:IsA("Model") then
		coin:PivotTo(cframe)
	end
end

local function isAnimatableCoin(instance)
	return (instance:IsA("BasePart") or instance:IsA("Model")) and instance:GetAttribute("IsCoin") == true
end

local function stopAnimatingCoin(coin)
	animatedCoins[coin] = nil
end

local function startAnimatingCoin(coin)
	if animatedCoins[coin] or not isAnimatableCoin(coin) then
		return
	end

	local baseCFrame = getCoinCFrame(coin)

	if not baseCFrame then
		return
	end

	animatedCoins[coin] = {
		BaseCFrame = baseCFrame,
		Phase = math.random() * math.pi * 2,
	}

	coin.AncestryChanged:Connect(function(_, parent)
		if not parent then
			stopAnimatingCoin(coin)
		end
	end)
end

local function scanForCoins(container)
	for _, descendant in container:GetDescendants() do
		if isAnimatableCoin(descendant) then
			startAnimatingCoin(descendant)
		end
	end
end

local function showFloatingText(reward, totalCoins)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CoinCollectedEffectGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = getPlayerGui()

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Position = UDim2.fromScale(0.5, 0.45)
	label.Size = UDim2.fromOffset(360, 80)
	label.Text = `+{reward} Coin  •  Total: {totalCoins}`
	label.TextColor3 = Color3.fromRGB(255, 221, 64)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.2
	label.Parent = screenGui

	local tween = TweenService:Create(
		label,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = UDim2.fromScale(0.5, 0.35),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)

	tween.Completed:Connect(function()
		screenGui:Destroy()
	end)

	tween:Play()
end

local function showWorldBurst(position)
	local burst = Instance.new("Part")
	burst.Name = "CoinBurst"
	burst.Anchored = true
	burst.CanCollide = false
	burst.Material = Enum.Material.Neon
	burst.Shape = Enum.PartType.Ball
	burst.Color = Color3.fromRGB(255, 221, 64)
	burst.Position = position
	burst.Size = Vector3.new(0.25, 0.25, 0.25)
	burst.Transparency = 0.1
	burst.Parent = workspace

	local tween = TweenService:Create(
		burst,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(4, 4, 4),
			Transparency = 1,
		}
	)

	tween.Completed:Connect(function()
		burst:Destroy()
	end)

	tween:Play()
end

workspace.DescendantAdded:Connect(function(descendant)
	if isAnimatableCoin(descendant) then
		startAnimatingCoin(descendant)
		return
	end

	descendant:GetAttributeChangedSignal("IsCoin"):Connect(function()
		if isAnimatableCoin(descendant) then
			startAnimatingCoin(descendant)
		end
	end)
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()

	for coin, animation in animatedCoins do
		if not coin.Parent or coin:GetAttribute("IsCoin") ~= true then
			stopAnimatingCoin(coin)
		else
			local bobOffset = math.sin((now * BOB_SPEED) + animation.Phase) * BOB_HEIGHT
			local rotation = math.rad((now * ROTATION_SPEED_DEGREES) % 360)
			local animatedCFrame = animation.BaseCFrame * CFrame.new(0, bobOffset, 0) * CFrame.Angles(0, rotation, 0)
			local success = pcall(setCoinCFrame, coin, animatedCFrame)

			if not success then
				stopAnimatingCoin(coin)
			end
		end
	end
end)

coinCollectedEffect.OnClientEvent:Connect(function(position, reward, totalCoins)
	showFloatingText(reward, totalCoins)
	showWorldBurst(position)
end)

scanForCoins(workspace)

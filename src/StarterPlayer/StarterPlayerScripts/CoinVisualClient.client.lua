local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FLOAT_HEIGHT = 0.45
local FLOAT_SPEED = 2.2
local ROTATION_SPEED = math.rad(30)

local animatedCoins = {}

local function isAnimatableCoin(instance)
	return (instance:IsA("BasePart") or instance:IsA("Model")) and instance:GetAttribute("IsCoin") == true
end

local function getBaseCFrame(coin)
	if coin:IsA("Model") then
		return coin:GetPivot()
	elseif coin:IsA("BasePart") then
		return coin.CFrame
	end

	return nil
end

local function applyCoinCFrame(coin, baseCFrame, floatOffset, rotation)
	local animatedCFrame = baseCFrame * CFrame.new(0, floatOffset, 0) * CFrame.Angles(0, rotation, 0)

	if coin:IsA("Model") then
		coin:PivotTo(animatedCFrame)
	elseif coin:IsA("BasePart") then
		coin.CFrame = animatedCFrame
	end
end

local function stopAnimatingCoin(coin)
	animatedCoins[coin] = nil
end

local function startAnimatingCoin(coin)
	if animatedCoins[coin] or not isAnimatableCoin(coin) then
		return
	end

	local baseCFrame = getBaseCFrame(coin)

	if not baseCFrame then
		return
	end

	animatedCoins[coin] = {
		BaseCFrame = baseCFrame,
		StartTime = os.clock(),
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

Workspace.DescendantAdded:Connect(function(descendant)
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
			local elapsed = now - animation.StartTime
			local floatOffset = math.sin(elapsed * FLOAT_SPEED) * FLOAT_HEIGHT
			local rotation = elapsed * ROTATION_SPEED
			local success = pcall(applyCoinCFrame, coin, animation.BaseCFrame, floatOffset, rotation)

			if not success then
				stopAnimatingCoin(coin)
			end
		end
	end
end)

scanForCoins(Workspace)

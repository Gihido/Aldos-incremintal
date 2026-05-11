local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ROTATION_SPEED = math.rad(30)
local FLOAT_HEIGHT = 0.45
local FLOAT_SPEED = 2.2
local SHIMMER_SPEED = 1.35
local SHIMMER_COLORS = {
	Color3.fromRGB(180, 180, 180),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(210, 210, 210),
}

local animatedCoins = {}
local attributeConnections = {}

local function isAnimatableCoin(instance)
	return (instance:IsA("BasePart") or instance:IsA("Model")) and instance:GetAttribute("IsCoin") == true
end

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

local function getShimmerColor(t)
	local segment = (t * SHIMMER_SPEED) % #SHIMMER_COLORS
	local index = math.floor(segment) + 1
	local nextIndex = (index % #SHIMMER_COLORS) + 1
	local alpha = segment - math.floor(segment)
	local easedAlpha = 0.5 - (math.cos(alpha * math.pi) * 0.5)

	return SHIMMER_COLORS[index]:Lerp(SHIMMER_COLORS[nextIndex], easedAlpha)
end

local function applyShimmerColor(coin, color)
	for _, part in ipairs(getCoinParts(coin)) do
		if part.Parent then
			part.Color = color
		end
	end
end

local function animateCoin(coin)
	if animatedCoins[coin] then
		return
	end

	if not coin:GetAttribute("IsCoin") then
		return
	end

	animatedCoins[coin] = true

	local isModel = coin:IsA("Model")
	local isPart = coin:IsA("BasePart")

	if not isModel and not isPart then
		animatedCoins[coin] = nil
		return
	end

	local baseCFrame

	if isModel then
		baseCFrame = coin:GetPivot()
	else
		baseCFrame = coin.CFrame
	end

	task.spawn(function()
		local startTime = os.clock()

		while coin and coin.Parent and coin:GetAttribute("IsCoin") do
			local t = os.clock() - startTime
			local floatOffset = math.sin(t * FLOAT_SPEED) * FLOAT_HEIGHT
			local rotation = t * ROTATION_SPEED
			local shimmerColor = getShimmerColor(t)
			local success = true

			applyShimmerColor(coin, shimmerColor)

			if isModel then
				success = pcall(function()
					if coin.Parent then
						coin:PivotTo(
							baseCFrame
							* CFrame.new(0, floatOffset, 0)
							* CFrame.Angles(0, rotation, 0)
						)
					end
				end)
			elseif isPart then
				success = pcall(function()
					if coin.Parent then
						local basePosition = baseCFrame.Position
						coin.CFrame =
							CFrame.new(basePosition + Vector3.new(0, floatOffset, 0))
							* CFrame.Angles(0, rotation, 0)
					end
				end)
			end

			if not success then
				break
			end

			RunService.RenderStepped:Wait()
		end

		animatedCoins[coin] = nil
	end)
end

local function watchCoinCandidate(instance)
	if attributeConnections[instance] then
		return
	end

	attributeConnections[instance] = instance:GetAttributeChangedSignal("IsCoin"):Connect(function()
		if isAnimatableCoin(instance) then
			animateCoin(instance)
		end
	end)

	instance.Destroying:Connect(function()
		if attributeConnections[instance] then
			attributeConnections[instance]:Disconnect()
			attributeConnections[instance] = nil
		end
	end)
end

local function scanForCoins(container)
	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("BasePart") or descendant:IsA("Model") then
			watchCoinCandidate(descendant)
		end

		if isAnimatableCoin(descendant) then
			animateCoin(descendant)
		end
	end
end

Workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("BasePart") or descendant:IsA("Model") then
		watchCoinCandidate(descendant)
	end

	if isAnimatableCoin(descendant) then
		animateCoin(descendant)
	end
end)

scanForCoins(Workspace)

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ROTATION_SPEED = math.rad(30)
local FLOAT_HEIGHT = 0.45
local FLOAT_SPEED = 2.2

local animatedCoins = {}

local function isAnimatableCoin(instance)
	return (instance:IsA("BasePart") or instance:IsA("Model")) and instance:GetAttribute("IsCoin") == true
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
			local success = true

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

local function scanForCoins(container)
	for _, descendant in container:GetDescendants() do
		if isAnimatableCoin(descendant) then
			animateCoin(descendant)
		end
	end
end

Workspace.DescendantAdded:Connect(function(descendant)
	if isAnimatableCoin(descendant) then
		animateCoin(descendant)
		return
	end

	descendant:GetAttributeChangedSignal("IsCoin"):Connect(function()
		if isAnimatableCoin(descendant) then
			animateCoin(descendant)
		end
	end)
end)

scanForCoins(Workspace)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local coinCollectedEffect = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CoinCollectedEffect")

local function getPlayerGui()
	return player:WaitForChild("PlayerGui")
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

coinCollectedEffect.OnClientEvent:Connect(function(position, reward, totalCoins)
	showFloatingText(reward, totalCoins)
	showWorldBurst(position)
end)

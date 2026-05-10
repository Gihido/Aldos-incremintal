local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FormatNumber = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FormatNumber"))

local COIN_POPUP_ICON_ID = "rbxassetid://0"
local UPGRADE_ICONS = {
	CoinGain = "rbxassetid://0",
	MultiCoins = "rbxassetid://0",
	MaxSpawnCoins = "rbxassetid://0",
}
local NOTIFICATION_CONFIG = {
	Success = {
		Color = Color3.fromRGB(90, 255, 130),
		Icon = "rbxassetid://0",
	},
	Limit = {
		Color = Color3.fromRGB(255, 200, 80),
		Icon = "rbxassetid://0",
	},
	NotEnough = {
		Color = Color3.fromRGB(255, 120, 70),
		Icon = "rbxassetid://0",
	},
	Error = {
		Color = Color3.fromRGB(255, 70, 70),
		Icon = "rbxassetid://0",
	},
}

local ROTATION_SPEED_DEGREES = 30
local BOB_HEIGHT = 0.45
local BOB_SPEED = 2.2
local UPGRADE_ORDER = { "CoinGain", "MultiCoins", "MaxSpawnCoins" }

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local coinCollectedEffect = remotes:WaitForChild("CoinCollectedEffect")
local buyUpgradeRemote = remotes:WaitForChild("BuyUpgrade")
local upgradeResultRemote = remotes:WaitForChild("UpgradeResult")
local syncPlayerDataRemote = remotes:WaitForChild("SyncPlayerData")

local animatedCoins = {}
local latestPlayerData
local upgradeCards = {}
local notificationCount = 0

local function getPlayerGui()
	return player:WaitForChild("PlayerGui")
end

local function getOrCreateScreenGui()
	local playerGui = getPlayerGui()
	local screenGui = playerGui:FindFirstChild("ClientEffectsGui")

	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "ClientEffectsGui"
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.Parent = playerGui
	end

	return screenGui
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent

	return corner
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.Parent = parent

	return stroke
end

local function addGradient(parent, colorA, colorB, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(colorA, colorB)
	gradient.Rotation = rotation or 0
	gradient.Parent = parent

	return gradient
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

local function showCoinPopup(amount)
	local screenGui = getOrCreateScreenGui()
	local popup = Instance.new("Frame")
	popup.Name = "CoinPickupPopup"
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundColor3 = Color3.fromRGB(22, 22, 24)
	popup.BackgroundTransparency = 0.1
	popup.BorderSizePixel = 0
	popup.Position = UDim2.fromScale(0.5 + math.random(-8, 8) / 100, 0.55)
	popup.Size = UDim2.fromOffset(116, 38)
	popup.Parent = screenGui

	addCorner(popup, UDim.new(0, 12))
	addStroke(popup, Color3.fromRGB(225, 225, 205), 1.5, 0.25)
	addGradient(popup, Color3.fromRGB(50, 50, 54), Color3.fromRGB(16, 16, 18), 90)

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = COIN_POPUP_ICON_ID
	icon.Position = UDim2.fromOffset(8, 7)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromOffset(24, 24)
	icon.Parent = popup

	local text = Instance.new("TextLabel")
	text.Name = "Amount"
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.Position = UDim2.fromOffset(38, 0)
	text.Size = UDim2.new(1, -44, 1, 0)
	text.Text = `+{FormatNumber(amount)}`
	text.TextColor3 = Color3.fromRGB(245, 240, 205)
	text.TextScaled = true
	text.TextStrokeTransparency = 0.72
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Parent = popup

	local moveTween = TweenService:Create(popup, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = popup.Position - UDim2.fromScale(0, 0.085),
		BackgroundTransparency = 1,
	})
	local textTween = TweenService:Create(text, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	local iconTween = TweenService:Create(icon, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		ImageTransparency = 1,
	})

	moveTween.Completed:Connect(function()
		popup:Destroy()
	end)

	moveTween:Play()
	textTween:Play()
	iconTween:Play()
end

local function showNotification(notificationType, message)
	local config = NOTIFICATION_CONFIG[notificationType] or NOTIFICATION_CONFIG.Error
	local screenGui = getOrCreateScreenGui()
	notificationCount += 1

	local frame = Instance.new("Frame")
	frame.Name = `Notification{notificationCount}`
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	frame.BackgroundTransparency = 0.06
	frame.BorderSizePixel = 0
	frame.Position = UDim2.fromScale(1.32, 0.43)
	frame.Size = UDim2.fromOffset(300, 58)
	frame.Parent = screenGui

	addCorner(frame, UDim.new(0, 14))
	addStroke(frame, config.Color, 2, 0.12)
	addGradient(frame, Color3.fromRGB(44, 44, 50), Color3.fromRGB(14, 14, 18), 0)

	local iconBackground = Instance.new("Frame")
	iconBackground.Name = "IconBackground"
	iconBackground.BackgroundColor3 = config.Color
	iconBackground.BackgroundTransparency = 0.72
	iconBackground.BorderSizePixel = 0
	iconBackground.Position = UDim2.fromOffset(10, 10)
	iconBackground.Size = UDim2.fromOffset(38, 38)
	iconBackground.Parent = frame
	addCorner(iconBackground, UDim.new(0, 10))

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = config.Icon
	icon.Position = UDim2.fromOffset(6, 6)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromOffset(26, 26)
	icon.Parent = iconBackground

	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Position = UDim2.fromOffset(58, 6)
	label.Size = UDim2.new(1, -68, 1, -12)
	label.Text = message
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.82
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local targetY = 0.43 + math.min(notificationCount % 4, 3) * 0.075
	TweenService:Create(frame, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.985, targetY),
	}):Play()

	task.delay(3, function()
		if not frame.Parent then
			return
		end

		local outTween = TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(1.32, targetY),
			BackgroundTransparency = 1,
		})

		outTween.Completed:Connect(function()
			frame:Destroy()
		end)
		outTween:Play()
	end)
end

local function createText(parent, name, textValue, position, size, font, color)
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Font = font or Enum.Font.GothamBold
	text.Position = position
	text.Size = size
	text.Text = textValue
	text.TextColor3 = color or Color3.fromRGB(245, 245, 245)
	text.TextScaled = true
	text.TextStrokeTransparency = 0.8
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Parent = parent

	return text
end

local function showTooltip(button, tooltip, text)
	tooltip.Text = text
	tooltip.Visible = true
	tooltip.Position = button.Position - UDim2.fromOffset(0, 34)
end

local function hideTooltip(tooltip)
	tooltip.Visible = false
end

local function createUpgradeCard(parent, upgradeId, index)
	local card = Instance.new("Frame")
	card.Name = upgradeId
	card.BackgroundColor3 = Color3.fromRGB(18, 20, 18)
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.LayoutOrder = index
	card.Size = UDim2.new(0.32, 0, 0.92, 0)
	card.Parent = parent

	addCorner(card, UDim.new(0, 18))
	addStroke(card, Color3.fromRGB(190, 230, 140), 2, 0.28)
	addGradient(card, Color3.fromRGB(38, 42, 34), Color3.fromRGB(10, 12, 10), 90)

	local iconBox = Instance.new("Frame")
	iconBox.Name = "IconBox"
	iconBox.BackgroundColor3 = Color3.fromRGB(210, 230, 170)
	iconBox.BackgroundTransparency = 0.7
	iconBox.BorderSizePixel = 0
	iconBox.Position = UDim2.fromScale(0.06, 0.07)
	iconBox.Size = UDim2.fromScale(0.2, 0.18)
	iconBox.Parent = card
	addCorner(iconBox, UDim.new(0, 12))
	addStroke(iconBox, Color3.fromRGB(240, 245, 210), 1, 0.35)

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = UPGRADE_ICONS[upgradeId] or "rbxassetid://0"
	icon.Position = UDim2.fromScale(0.12, 0.12)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromScale(0.76, 0.76)
	icon.Parent = iconBox

	local title = createText(card, "Title", upgradeId, UDim2.fromScale(0.3, 0.065), UDim2.fromScale(0.64, 0.08), Enum.Font.GothamBlack, Color3.fromRGB(245, 245, 225))
	local level = createText(card, "Level", "Level 0/0", UDim2.fromScale(0.3, 0.15), UDim2.fromScale(0.64, 0.065), Enum.Font.GothamBold, Color3.fromRGB(205, 215, 195))

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.BackgroundColor3 = Color3.fromRGB(160, 210, 120)
	badge.BorderSizePixel = 0
	badge.Position = UDim2.fromScale(0.16, 0.34)
	badge.Size = UDim2.fromScale(0.68, 0.14)
	badge.Parent = card
	addCorner(badge, UDim.new(0, 14))
	addStroke(badge, Color3.fromRGB(255, 255, 230), 1, 0.25)
	addGradient(badge, Color3.fromRGB(220, 255, 160), Color3.fromRGB(90, 150, 80), 0)

	local effect = createText(badge, "Effect", "+1", UDim2.fromScale(0.08, 0), UDim2.fromScale(0.84, 1), Enum.Font.GothamBlack, Color3.fromRGB(12, 18, 10))
	effect.TextXAlignment = Enum.TextXAlignment.Center

	local price = createText(card, "Price", "Price: 0 coins", UDim2.fromScale(0.12, 0.57), UDim2.fromScale(0.76, 0.075), Enum.Font.GothamBold, Color3.fromRGB(230, 230, 215))
	price.TextXAlignment = Enum.TextXAlignment.Center

	local tooltip = createText(card, "Tooltip", "+1", UDim2.fromScale(0.18, 0.66), UDim2.fromScale(0.64, 0.075), Enum.Font.GothamBlack, Color3.fromRGB(255, 250, 210))
	tooltip.BackgroundColor3 = Color3.fromRGB(8, 9, 8)
	tooltip.BackgroundTransparency = 0.04
	tooltip.BorderSizePixel = 0
	tooltip.TextXAlignment = Enum.TextXAlignment.Center
	tooltip.Visible = false
	addCorner(tooltip, UDim.new(0, 10))
	addStroke(tooltip, Color3.fromRGB(225, 235, 180), 1, 0.2)

	local buyButton = Instance.new("TextButton")
	buyButton.Name = "Buy"
	buyButton.BackgroundColor3 = Color3.fromRGB(90, 180, 85)
	buyButton.BorderSizePixel = 0
	buyButton.Font = Enum.Font.GothamBlack
	buyButton.Position = UDim2.fromScale(0.08, 0.78)
	buyButton.Size = UDim2.fromScale(0.38, 0.13)
	buyButton.Text = "Buy"
	buyButton.TextColor3 = Color3.fromRGB(10, 20, 10)
	buyButton.TextScaled = true
	buyButton.Parent = card
	addCorner(buyButton, UDim.new(0, 12))
	addStroke(buyButton, Color3.fromRGB(235, 255, 210), 1, 0.25)
	addGradient(buyButton, Color3.fromRGB(160, 255, 125), Color3.fromRGB(70, 155, 65), 90)

	local buyMaxButton = buyButton:Clone()
	buyMaxButton.Name = "BuyMax"
	buyMaxButton.Position = UDim2.fromScale(0.54, 0.78)
	buyMaxButton.Text = "Buy Max"
	buyMaxButton.Parent = card

	local cardData = {
		Frame = card,
		Title = title,
		Level = level,
		Effect = effect,
		Price = price,
		Tooltip = tooltip,
		Buy = buyButton,
		BuyMax = buyMaxButton,
	}

	local function hookButton(button, mode)
		button.Activated:Connect(function()
			buyUpgradeRemote:FireServer(upgradeId, mode)
		end)

		button.MouseEnter:Connect(function()
			local data = latestPlayerData and latestPlayerData.Upgrades and latestPlayerData.Upgrades[upgradeId]
			local text = data and (mode == "Buy" and data.BuyBonusText or data.BuyMaxBonusText) or "-"
			showTooltip(button, tooltip, text)
		end)

		button.MouseLeave:Connect(function()
			hideTooltip(tooltip)
		end)

		button.MouseButton1Down:Connect(function()
			local data = latestPlayerData and latestPlayerData.Upgrades and latestPlayerData.Upgrades[upgradeId]
			local text = data and (mode == "Buy" and data.BuyBonusText or data.BuyMaxBonusText) or "-"
			showTooltip(button, tooltip, text)
		end)

		button.MouseButton1Up:Connect(function()
			hideTooltip(tooltip)
		end)
	end

	hookButton(buyButton, "Buy")
	hookButton(buyMaxButton, "BuyMax")

	upgradeCards[upgradeId] = cardData
end

local function setupUpgradeBoard()
	local boardPart = Workspace:FindFirstChild("UpgCoin")

	if not boardPart then
		warn("UpgCoin was not found in Workspace; upgrade board will be skipped")
		return
	end

	local surfaceGui = boardPart:FindFirstChild("CoinUpgradeSurfaceGui")

	if not surfaceGui then
		surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "CoinUpgradeSurfaceGui"
		surfaceGui.Face = Enum.NormalId.Front
		surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surfaceGui.PixelsPerStud = 70
		surfaceGui.LightInfluence = 0
		surfaceGui.Parent = boardPart
	else
		surfaceGui:ClearAllChildren()
	end

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.BackgroundColor3 = Color3.fromRGB(6, 8, 6)
	background.BackgroundTransparency = 0.08
	background.BorderSizePixel = 0
	background.Size = UDim2.fromScale(1, 1)
	background.Parent = surfaceGui
	addGradient(background, Color3.fromRGB(24, 30, 20), Color3.fromRGB(5, 6, 5), 90)

	local title = createText(background, "Title", "УЛУЧШЕНИЯ МОНЕТ", UDim2.fromScale(0.03, 0.025), UDim2.fromScale(0.94, 0.11), Enum.Font.GothamBlack, Color3.fromRGB(225, 245, 190))
	title.TextXAlignment = Enum.TextXAlignment.Center

	local cardsFrame = Instance.new("Frame")
	cardsFrame.Name = "Cards"
	cardsFrame.BackgroundTransparency = 1
	cardsFrame.Position = UDim2.fromScale(0.035, 0.18)
	cardsFrame.Size = UDim2.fromScale(0.93, 0.76)
	cardsFrame.Parent = background

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0.02, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = cardsFrame

	for index, upgradeId in UPGRADE_ORDER do
		createUpgradeCard(cardsFrame, upgradeId, index)
	end
end

local function updateUpgradeBoard(data)
	latestPlayerData = data

	if not data or not data.Upgrades then
		return
	end

	for upgradeId, card in upgradeCards do
		local upgradeData = data.Upgrades[upgradeId]

		if upgradeData then
			card.Title.Text = upgradeData.Name
			card.Level.Text = `Level {upgradeData.Level}/{upgradeData.MaxLevel}`
			card.Effect.Text = upgradeData.EffectText

			if upgradeData.IsMaxed then
				card.Price.Text = "Price: MAX"
				card.Buy.AutoButtonColor = false
				card.BuyMax.AutoButtonColor = false
				card.Buy.BackgroundTransparency = 0.45
				card.BuyMax.BackgroundTransparency = 0.45
			else
				card.Price.Text = `Price: {upgradeData.PriceFormatted} coins`
				card.Buy.AutoButtonColor = true
				card.BuyMax.AutoButtonColor = true
				card.Buy.BackgroundTransparency = 0
				card.BuyMax.BackgroundTransparency = 0
			end
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

coinCollectedEffect.OnClientEvent:Connect(function(amount)
	showCoinPopup(amount)
end)

upgradeResultRemote.OnClientEvent:Connect(function(result)
	if typeof(result) ~= "table" then
		showNotification("Error", "Ошибка покупки, попробуйте позже")
		return
	end

	if result.Data then
		updateUpgradeBoard(result.Data)
	end

	showNotification(result.Type or "Error", result.Message or "Ошибка покупки, попробуйте позже")
end)

syncPlayerDataRemote.OnClientEvent:Connect(function(data)
	updateUpgradeBoard(data)
end)

getOrCreateScreenGui()
setupUpgradeBoard()
scanForCoins(Workspace)

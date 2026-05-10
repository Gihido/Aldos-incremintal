local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FormatNumber = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FormatNumber"))

local COIN_POPUP_ICON_ID = "rbxassetid://0"
local COIN_POPUP_BACKGROUND_IMAGE_ID = "rbxassetid://0"
local UPGRADE_CARD_BACKGROUND_IMAGE_ID = "rbxassetid://0"
local UPGRADE_BONUS_BADGE_BACKGROUND_IMAGE_ID = "rbxassetid://0"
local UPGRADE_TOOLTIP_BACKGROUND_IMAGE_ID = "rbxassetid://0"
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


local function hasCustomAssetId(assetId)
	return type(assetId) == "string" and assetId ~= "" and assetId ~= "rbxassetid://0"
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

local function showCoinPickupPopup(amount)
	local screenGui = getOrCreateScreenGui()
	local popup = Instance.new("Frame")
	popup.Name = "CoinPickupPopup"
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundColor3 = Color3.fromRGB(74, 74, 78)
	popup.BackgroundTransparency = 0.12
	popup.BorderSizePixel = 0
	popup.ClipsDescendants = true
	popup.Position = UDim2.fromScale(0.5 + math.random(-4, 4) / 100, 0.58)
	popup.Size = UDim2.fromOffset(145, 48)
	popup.ZIndex = 80
	popup.Parent = screenGui

	addCorner(popup, UDim.new(0, 13))
	addStroke(popup, Color3.fromRGB(218, 218, 218), 1.5, 0.22)
	addGradient(popup, Color3.fromRGB(96, 96, 102), Color3.fromRGB(42, 42, 46), 90)

	local scale = Instance.new("UIScale")
	scale.Scale = 0.88
	scale.Parent = popup

	local backgroundImage
	local darkOverlay

	if hasCustomAssetId(COIN_POPUP_BACKGROUND_IMAGE_ID) then
		backgroundImage = Instance.new("ImageLabel")
		backgroundImage.Name = "PopupBackgroundImage"
		backgroundImage.BackgroundTransparency = 1
		backgroundImage.Image = COIN_POPUP_BACKGROUND_IMAGE_ID
		backgroundImage.ImageTransparency = 0.32
		backgroundImage.Position = UDim2.fromScale(0, 0)
		backgroundImage.ScaleType = Enum.ScaleType.Stretch
		backgroundImage.Size = UDim2.fromScale(1, 1)
		backgroundImage.ZIndex = 80
		backgroundImage.Parent = popup

		darkOverlay = Instance.new("Frame")
		darkOverlay.Name = "PopupDarkOverlay"
		darkOverlay.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
		darkOverlay.BackgroundTransparency = 0.38
		darkOverlay.BorderSizePixel = 0
		darkOverlay.Size = UDim2.fromScale(1, 1)
		darkOverlay.ZIndex = 81
		darkOverlay.Parent = popup
	end

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = COIN_POPUP_ICON_ID
	icon.Position = UDim2.fromOffset(10, 9)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromOffset(28, 28)
	icon.ZIndex = 82
	icon.Parent = popup

	local text = Instance.new("TextLabel")
	text.Name = "Amount"
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.Position = UDim2.fromOffset(45, 0)
	text.Size = UDim2.new(1, -54, 1, 0)
	text.Text = `+{FormatNumber(amount)}`
	text.TextColor3 = Color3.fromRGB(248, 248, 236)
	text.TextScaled = true
	text.TextStrokeTransparency = 0.62
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.ZIndex = 82
	text.Parent = popup

	TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	local moveTween = TweenService:Create(popup, TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = popup.Position - UDim2.fromOffset(0, 58),
		BackgroundTransparency = 1,
	})
	local textTween = TweenService:Create(text, TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	local iconTween = TweenService:Create(icon, TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		ImageTransparency = 1,
	})

	if backgroundImage then
		TweenService:Create(backgroundImage, TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			ImageTransparency = 1,
		}):Play()
	end

	if darkOverlay then
		TweenService:Create(darkOverlay, TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
	end

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
	local offsetY = ((notificationCount - 1) % 3) * 4

	local frame = Instance.new("Frame")
	frame.Name = `Notification{notificationCount}`
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	frame.BackgroundTransparency = 0.06
	frame.BorderSizePixel = 0
	frame.Position = UDim2.new(1.32, 0, 0.4, offsetY)
	frame.Size = UDim2.fromOffset(300, 58)
	frame.ZIndex = 100 + notificationCount
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

	local targetPosition = UDim2.new(0.97, 0, 0.4, offsetY)
	TweenService:Create(frame, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = targetPosition,
	}):Play()

	task.delay(3, function()
		if not frame.Parent then
			return
		end

		local outTween = TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(1.32, 0, 0.4, offsetY),
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
	text.TextStrokeTransparency = 0.62
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.ZIndex = 8
	text.Parent = parent

	return text
end

local function addImageBackground(parent, imageId, imageTransparency)
	if not hasCustomAssetId(imageId) then
		return nil
	end

	local image = Instance.new("ImageLabel")
	image.Name = "CustomBackgroundImage"
	image.BackgroundTransparency = 1
	image.Image = imageId
	image.ImageTransparency = imageTransparency or 0.35
	image.Position = UDim2.fromScale(0, 0)
	image.ScaleType = Enum.ScaleType.Stretch
	image.Size = UDim2.fromScale(1, 1)
	image.ZIndex = 1
	image.Parent = parent

	local overlay = Instance.new("Frame")
	overlay.Name = "ReadabilityOverlay"
	overlay.BackgroundColor3 = Color3.fromRGB(5, 7, 6)
	overlay.BackgroundTransparency = 0.28
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 2
	overlay.Parent = parent

	return image
end

local function showTooltip(button, tooltip, text)
	tooltip.Text = text
	tooltip.Visible = true
	tooltip.Position = UDim2.new(button.Position.X.Scale, button.Position.X.Offset, button.Position.Y.Scale - 0.16, button.Position.Y.Offset)
	tooltip.Size = UDim2.fromScale(0.42, 0.09)
end

local function hideTooltip(tooltip)
	tooltip.Visible = false
end

local function styleButton(button, colorA, colorB, strokeColor, textColor)
	button.AutoButtonColor = false
	button.BackgroundColor3 = colorB
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBlack
	button.TextColor3 = textColor
	button.TextScaled = true
	button.TextStrokeTransparency = 0.7
	button.ZIndex = 9
	addCorner(button, UDim.new(0, 11))
	addStroke(button, strokeColor, 1.4, 0.18)
	addGradient(button, colorA, colorB, 90)

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	local function tweenScale(value)
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = value,
		}):Play()
	end

	button.MouseEnter:Connect(function()
		tweenScale(1.045)
	end)

	button.MouseLeave:Connect(function()
		tweenScale(1)
	end)

	button.MouseButton1Down:Connect(function()
		tweenScale(0.95)
	end)

	button.MouseButton1Up:Connect(function()
		tweenScale(1.035)
	end)
end

local function startUpgradeIconPulse(icon)
	task.spawn(function()
		while icon.Parent do
			task.wait(3)

			if not icon.Parent then
				break
			end

			local grow = TweenService:Create(icon, TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(0.88, 0.88),
				Position = UDim2.fromScale(0.06, 0.06),
			})
			local shrink = TweenService:Create(icon, TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
				Size = UDim2.fromScale(0.76, 0.76),
				Position = UDim2.fromScale(0.12, 0.12),
			})

			grow:Play()
			grow.Completed:Wait()

			if not icon.Parent then
				break
			end

			shrink:Play()
		end
	end)
end

local function createUpgradeCard(parent, upgradeId, index)
	local card = Instance.new("Frame")
	card.Name = upgradeId
	card.BackgroundColor3 = Color3.fromRGB(14, 17, 14)
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.LayoutOrder = index
	card.Size = UDim2.fromOffset(220, 245)
	card.ZIndex = 5
	card.Parent = parent

	addCorner(card, UDim.new(0, 16))
	addStroke(card, Color3.fromRGB(190, 235, 135), 1.7, 0.25)
	addGradient(card, Color3.fromRGB(36, 44, 32), Color3.fromRGB(8, 10, 8), 90)
	addImageBackground(card, UPGRADE_CARD_BACKGROUND_IMAGE_ID, 0.36)

	local shine = Instance.new("Frame")
	shine.Name = "TopShine"
	shine.BackgroundColor3 = Color3.fromRGB(220, 255, 170)
	shine.BackgroundTransparency = 0.76
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromScale(0.07, 0.04)
	shine.Size = UDim2.fromScale(0.86, 0.018)
	shine.ZIndex = 7
	shine.Parent = card
	addCorner(shine, UDim.new(1, 0))

	local iconBox = Instance.new("Frame")
	iconBox.Name = "IconBox"
	iconBox.BackgroundColor3 = Color3.fromRGB(170, 215, 120)
	iconBox.BackgroundTransparency = 0.66
	iconBox.BorderSizePixel = 0
	iconBox.Position = UDim2.fromScale(0.07, 0.075)
	iconBox.Size = UDim2.fromOffset(54, 54)
	iconBox.ZIndex = 7
	iconBox.Parent = card
	addCorner(iconBox, UDim.new(0, 13))
	addStroke(iconBox, Color3.fromRGB(235, 255, 205), 1, 0.32)

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = UPGRADE_ICONS[upgradeId] or "rbxassetid://0"
	icon.Position = UDim2.fromScale(0.12, 0.12)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromScale(0.76, 0.76)
	icon.ZIndex = 8
	icon.Parent = iconBox
	startUpgradeIconPulse(icon)

	local title = createText(card, "Title", upgradeId, UDim2.fromScale(0.34, 0.065), UDim2.fromScale(0.6, 0.1), Enum.Font.GothamBlack, Color3.fromRGB(248, 250, 226))
	local level = createText(card, "Level", "Level 0/0", UDim2.fromScale(0.34, 0.165), UDim2.fromScale(0.58, 0.07), Enum.Font.GothamBold, Color3.fromRGB(205, 220, 195))
	level.TextStrokeTransparency = 0.7

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.BackgroundColor3 = Color3.fromRGB(125, 190, 75)
	badge.BorderSizePixel = 0
	badge.ClipsDescendants = true
	badge.Position = UDim2.fromScale(0.2, 0.315)
	badge.Size = UDim2.fromScale(0.6, 0.135)
	badge.ZIndex = 7
	badge.Parent = card
	addCorner(badge, UDim.new(0, 13))
	addStroke(badge, Color3.fromRGB(255, 255, 215), 1.2, 0.18)
	addGradient(badge, Color3.fromRGB(230, 255, 155), Color3.fromRGB(85, 155, 70), 0)
	addImageBackground(badge, UPGRADE_BONUS_BADGE_BACKGROUND_IMAGE_ID, 0.4)

	local effect = createText(badge, "Effect", "+1", UDim2.fromScale(0.08, 0.05), UDim2.fromScale(0.84, 0.9), Enum.Font.GothamBlack, Color3.fromRGB(250, 255, 232))
	effect.TextXAlignment = Enum.TextXAlignment.Center
	effect.TextStrokeTransparency = 0.48
	effect.ZIndex = 10

	local price = createText(card, "Price", "Price: 0 coins", UDim2.fromScale(0.08, 0.515), UDim2.fromScale(0.84, 0.075), Enum.Font.GothamBlack, Color3.fromRGB(255, 235, 145))
	price.TextXAlignment = Enum.TextXAlignment.Center
	price.TextStrokeTransparency = 0.56

	local tooltip = createText(card, "Tooltip", "+1", UDim2.fromScale(0.08, 0.665), UDim2.fromScale(0.42, 0.09), Enum.Font.GothamBlack, Color3.fromRGB(255, 252, 210))
	tooltip.BackgroundColor3 = Color3.fromRGB(10, 12, 10)
	tooltip.BackgroundTransparency = 0.05
	tooltip.BorderSizePixel = 0
	tooltip.TextXAlignment = Enum.TextXAlignment.Center
	tooltip.Visible = false
	tooltip.ClipsDescendants = true
	tooltip.ZIndex = 20
	addCorner(tooltip, UDim.new(0, 10))
	addStroke(tooltip, Color3.fromRGB(225, 240, 180), 1, 0.18)
	addGradient(tooltip, Color3.fromRGB(42, 48, 34), Color3.fromRGB(10, 12, 9), 90)
	addImageBackground(tooltip, UPGRADE_TOOLTIP_BACKGROUND_IMAGE_ID, 0.38)

	local buyButton = Instance.new("TextButton")
	buyButton.Name = "Buy"
	buyButton.Position = UDim2.fromScale(0.08, 0.78)
	buyButton.Size = UDim2.fromScale(0.39, 0.13)
	buyButton.Text = "Buy"
	buyButton.Parent = card
	styleButton(buyButton, Color3.fromRGB(180, 255, 115), Color3.fromRGB(72, 170, 66), Color3.fromRGB(235, 255, 205), Color3.fromRGB(12, 28, 10))

	local buyMaxButton = Instance.new("TextButton")
	buyMaxButton.Name = "BuyMax"
	buyMaxButton.Position = UDim2.fromScale(0.53, 0.78)
	buyMaxButton.Size = UDim2.fromScale(0.39, 0.13)
	buyMaxButton.Text = "Buy Max"
	buyMaxButton.Parent = card
	styleButton(buyMaxButton, Color3.fromRGB(165, 185, 255), Color3.fromRGB(92, 72, 185), Color3.fromRGB(230, 220, 255), Color3.fromRGB(246, 245, 255))

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

		local function showCurrentTooltip()
			local data = latestPlayerData and latestPlayerData.Upgrades and latestPlayerData.Upgrades[upgradeId]
			local tooltipText = data and (mode == "Buy" and data.BuyBonusText or data.BuyMaxBonusText) or "-"
			showTooltip(button, tooltip, tooltipText)
		end

		button.MouseEnter:Connect(showCurrentTooltip)
		button.MouseLeave:Connect(function()
			hideTooltip(tooltip)
		end)
		button.MouseButton1Down:Connect(showCurrentTooltip)
		button.MouseButton1Up:Connect(function()
			hideTooltip(tooltip)
		end)
	end

	hookButton(buyButton, "Buy")
	hookButton(buyMaxButton, "BuyMax")

	upgradeCards[upgradeId] = cardData
end

local function findUpgradeBoardPart()
	local upgCoin = Workspace:WaitForChild("UpgCoin", 10)

	if upgCoin then
		return upgCoin
	end

	upgCoin = Workspace:FindFirstChild("UpgCoin")
		or Workspace:FindFirstChild("UPGCoin")
		or Workspace:FindFirstChild("UpgradeCoin")

	if not upgCoin then
		warn("UpgCoin was not found in Workspace after 10 seconds; upgrade board will be skipped")
	end

	return upgCoin
end

local function setupUpgradeBoard()
	local boardPart = findUpgradeBoardPart()

	if not boardPart then
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
	background.BackgroundColor3 = Color3.fromRGB(5, 8, 7)
	background.BackgroundTransparency = 0.04
	background.BorderSizePixel = 0
	background.Size = UDim2.fromScale(1, 1)
	background.Parent = surfaceGui
	addCorner(background, UDim.new(0, 12))
	addStroke(background, Color3.fromRGB(190, 235, 135), 2, 0.2)
	addGradient(background, Color3.fromRGB(26, 34, 25), Color3.fromRGB(4, 6, 5), 90)

	local title = createText(background, "Title", "УЛУЧШЕНИЯ МОНЕТ", UDim2.fromScale(0.03, 0.025), UDim2.fromScale(0.94, 0.095), Enum.Font.GothamBlack, Color3.fromRGB(225, 245, 190))
	title.TextXAlignment = Enum.TextXAlignment.Center

	local cardsFrame = Instance.new("Frame")
	cardsFrame.Name = "Cards"
	cardsFrame.BackgroundTransparency = 1
	cardsFrame.Position = UDim2.fromScale(0.045, 0.18)
	cardsFrame.Size = UDim2.fromScale(0.91, 0.74)
	cardsFrame.Parent = background

	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.CellSize = UDim2.fromOffset(220, 245)
	layout.FillDirectionMaxCells = 3
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
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
				card.Buy.AutoButtonColor = false
				card.BuyMax.AutoButtonColor = false
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
	showCoinPickupPopup(amount)
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

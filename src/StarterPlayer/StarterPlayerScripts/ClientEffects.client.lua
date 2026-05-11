local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local FormatNumber = require(shared:WaitForChild("FormatNumber"))
local ResponsiveUI = require(shared:WaitForChild("ResponsiveUI"))
local UIAssetConfig = require(shared:WaitForChild("UIAssetConfig"))

local NOTIFICATION_CONFIG = {
	Success = {
		Color = Color3.fromRGB(90, 255, 130),
	},
	Limit = {
		Color = Color3.fromRGB(255, 200, 80),
	},
	NotEnough = {
		Color = Color3.fromRGB(255, 120, 70),
	},
	Error = {
		Color = Color3.fromRGB(255, 70, 70),
	},
}

local UPGRADE_ORDER = { "CoinGain", "MultiCoins", "MaxSpawnCoins" }
local CARD_WIDTH = 420
local CARD_HEIGHT = 245
local CARD_PADDING = 18

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local coinCollectedEffect = remotes:WaitForChild("CoinCollectedEffect")
local buyUpgradeRemote = remotes:WaitForChild("BuyUpgrade")
local upgradeResultRemote = remotes:WaitForChild("UpgradeResult")
local syncPlayerDataRemote = remotes:WaitForChild("SyncPlayerData")

local latestPlayerData
local upgradeCards = {}
local notificationCount = 0
local responsiveScaleConnections = {}
local pendingPurchaseEffectUpgradeId
local pendingPurchaseEffectButton

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

local function getOrCreateGuiLayer(name, displayOrder)
	local screenGui = getOrCreateScreenGui()
	local layer = screenGui:FindFirstChild(name)

	if not layer then
		layer = Instance.new("Frame")
		layer.Name = name
		layer.BackgroundTransparency = 1
		layer.BorderSizePixel = 0
		layer.Position = UDim2.fromScale(0, 0)
		layer.Size = UDim2.fromScale(1, 1)
		layer.ZIndex = displayOrder or 1
		layer.Parent = screenGui
	end

	return layer
end

local function applyResponsiveScale(parent, baseScale)
	local scale = ResponsiveUI.ApplyScale(parent, baseScale)
	local connection = responsiveScaleConnections[scale]

	if connection then
		connection:Disconnect()
	end

	local function updateScale()
		if scale.Parent then
			scale.Scale = (baseScale or 1) * ResponsiveUI.GetScreenScale()
		end
	end

	local camera = Workspace.CurrentCamera
	if camera then
		responsiveScaleConnections[scale] = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	scale.Destroying:Connect(function()
		local currentConnection = responsiveScaleConnections[scale]
		if currentConnection then
			currentConnection:Disconnect()
			responsiveScaleConnections[scale] = nil
		end
	end)

	return scale
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

local function getUpgradeAssetConfig(upgradeId)
	return (UIAssetConfig.UpgradeCards and UIAssetConfig.UpgradeCards[upgradeId]) or {}
end

local function getNotificationAssetConfig(notificationType)
	return (UIAssetConfig.Notifications and UIAssetConfig.Notifications[notificationType]) or {}
end

local function addGradient(parent, colorA, colorB, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(colorA, colorB)
	gradient.Rotation = rotation or 0
	gradient.Parent = parent

	return gradient
end

local function destroyLegacyGuiObject(instance, playerGui)
	local current = instance
	local candidate = instance

	while current and current.Parent and current.Parent ~= playerGui do
		if current:IsA("GuiObject") then
			candidate = current
		end

		current = current.Parent
	end

	if current and current:IsA("ScreenGui") and current.Name ~= "ClientEffectsGui" then
		current:Destroy()
	elseif candidate and candidate.Name ~= "CoinPickupPopup" then
		candidate:Destroy()
	end
end

local function cleanupLegacyCoinPickupEffects()
	local playerGui = getPlayerGui()

	for _, child in playerGui:GetChildren() do
		local lowerName = string.lower(child.Name)
		local looksLikeLegacyCoinEffect = string.find(lowerName, "coin")
			and (
				string.find(lowerName, "collected")
				or string.find(lowerName, "effect")
				or string.find(lowerName, "pickup")
				or string.find(lowerName, "popup")
				or string.find(lowerName, "poput")
				or string.find(lowerName, "floating")
				or string.find(lowerName, "notification")
			)

		if child:IsA("ScreenGui") and child.Name ~= "ClientEffectsGui" and looksLikeLegacyCoinEffect then
			child:Destroy()
		end
	end

	for _, descendant in playerGui:GetDescendants() do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
			local text = string.lower(tostring(descendant.Text))
			local lowerName = string.lower(descendant.Name)
			local hasLegacyTotalText = string.find(text, "coins") and string.find(text, "total")
			local hasLegacyNilText = string.find(text, "nil") and (string.find(text, "coin") or string.find(lowerName, "coin"))

			if hasLegacyTotalText or hasLegacyNilText then
				destroyLegacyGuiObject(descendant, playerGui)
			end
		end
	end
end

local function showCoinPickupPopup(amount)
	cleanupLegacyCoinPickupEffects()
	local popupLayer = getOrCreateGuiLayer("CoinPickupGui", 20)
	local isMobileLike = ResponsiveUI.IsMobileLike()
	local minX = isMobileLike and 0.25 or 0.2
	local maxX = isMobileLike and 0.75 or 0.8
	local randomX = minX + (math.random() * (maxX - minX))
	local randomY = 0.72 + (math.random() * 0.12)
	local startPosition = UDim2.fromScale(randomX, randomY)
	local endPosition = UDim2.new(
		startPosition.X.Scale,
		startPosition.X.Offset,
		startPosition.Y.Scale,
		startPosition.Y.Offset - math.random(40, 80)
	)
	local targetScale = ResponsiveUI.GetScreenScale()

	local popup = Instance.new("Frame")
	popup.Name = "CoinPickupPopup"
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundColor3 = Color3.fromRGB(74, 74, 78)
	popup.BackgroundTransparency = 0.12
	popup.BorderSizePixel = 0
	popup.ClipsDescendants = true
	popup.Position = startPosition
	popup.Size = UDim2.fromOffset(145, 48)
	popup.ZIndex = 20
	popup.Parent = popupLayer

	addCorner(popup, UDim.new(0, 13))
	addStroke(popup, Color3.fromRGB(218, 218, 218), 1.5, 0.22)
	addGradient(popup, Color3.fromRGB(96, 96, 102), Color3.fromRGB(42, 42, 46), 90)

	local scale = Instance.new("UIScale")
	scale.Scale = targetScale * 0.88
	scale.Parent = popup

	local backgroundImage
	local darkOverlay

	local coinPopupConfig = UIAssetConfig.CoinPickupPopup or {}

	if hasCustomAssetId(coinPopupConfig.BackgroundImage) then
		backgroundImage = Instance.new("ImageLabel")
		backgroundImage.Name = "PopupBackgroundImage"
		backgroundImage.BackgroundTransparency = 1
		backgroundImage.Image = coinPopupConfig.BackgroundImage
		backgroundImage.ImageTransparency = 0.2
		backgroundImage.Position = UDim2.fromScale(0, 0)
		backgroundImage.ScaleType = Enum.ScaleType.Stretch
		backgroundImage.Size = UDim2.fromScale(1, 1)
		backgroundImage.ZIndex = 80
		backgroundImage.Parent = popup

		darkOverlay = Instance.new("Frame")
		darkOverlay.Name = "PopupDarkOverlay"
		darkOverlay.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
		darkOverlay.BackgroundTransparency = 0.72
		darkOverlay.BorderSizePixel = 0
		darkOverlay.Size = UDim2.fromScale(1, 1)
		darkOverlay.ZIndex = 81
		darkOverlay.Parent = popup
	end

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = coinPopupConfig.IconImage or "rbxassetid://0"
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
		Scale = targetScale,
	}):Play()

	local tweenInfo = TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local moveTween = TweenService:Create(popup, tweenInfo, {
		Position = endPosition,
		BackgroundTransparency = 1,
	})
	local textTween = TweenService:Create(text, tweenInfo, {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	local iconTween = TweenService:Create(icon, tweenInfo, {
		ImageTransparency = 1,
	})

	if backgroundImage then
		TweenService:Create(backgroundImage, tweenInfo, {
			ImageTransparency = 1,
		}):Play()
	end

	if darkOverlay then
		TweenService:Create(darkOverlay, tweenInfo, {
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

local addImageBackground

local function showNotification(notificationType, message)
	local config = NOTIFICATION_CONFIG[notificationType] or NOTIFICATION_CONFIG.Error
	local assetConfig = getNotificationAssetConfig(notificationType)
	local notificationLayer = getOrCreateGuiLayer("NotificationsGui", 100)
	local isMobileLike = ResponsiveUI.IsMobileLike()
	notificationCount += 1

	local frame = Instance.new("Frame")
	frame.Name = `Notification{notificationCount}`
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.BackgroundColor3 = config.Color
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Position = UDim2.fromScale(0.025, 0.08)
	frame.Size = UDim2.fromOffset(isMobileLike and 280 or 300, isMobileLike and 60 or 66)
	frame.ZIndex = 100 + (notificationCount * 10)
	frame.Parent = notificationLayer
	applyResponsiveScale(frame, 1)

	addCorner(frame, UDim.new(0, 10))
	addStroke(frame, Color3.fromRGB(245, 245, 235), 2, 0.12)
	addGradient(frame, config.Color, Color3.fromRGB(38, 40, 42), 0)
	addImageBackground(frame, assetConfig.BackgroundImage, 0.14, 0.86)

	local iconBackground = Instance.new("Frame")
	iconBackground.Name = "IconBackground"
	iconBackground.BackgroundColor3 = Color3.fromRGB(18, 20, 18)
	iconBackground.BackgroundTransparency = 0.1
	iconBackground.BorderSizePixel = 0
	iconBackground.Position = UDim2.fromOffset(9, 9)
	iconBackground.Size = UDim2.fromOffset(42, 42)
	iconBackground.ZIndex = frame.ZIndex + 4
	iconBackground.Parent = frame
	addCorner(iconBackground, UDim.new(0, 8))
	addStroke(iconBackground, Color3.fromRGB(255, 255, 245), 1.5, 0.25)

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = assetConfig.IconImage or "rbxassetid://0"
	icon.Position = UDim2.fromOffset(7, 7)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromOffset(28, 28)
	icon.ZIndex = frame.ZIndex + 5
	icon.Parent = iconBackground

	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.BackgroundColor3 = Color3.fromRGB(12, 14, 13)
	label.BackgroundTransparency = 0.22
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Position = UDim2.fromOffset(60, 7)
	label.Size = UDim2.new(1, -70, 1, -14)
	label.Text = message
	label.TextColor3 = Color3.fromRGB(248, 248, 238)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.55
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = frame.ZIndex + 5
	label.Parent = frame
	addCorner(label, UDim.new(0, 6))

	frame.BackgroundTransparency = 0.32
	TweenService:Create(frame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.08,
	}):Play()

	task.delay(3, function()
		if not frame.Parent then
			return
		end

		local outTween = TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		})

		TweenService:Create(label, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(icon, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			ImageTransparency = 1,
		}):Play()

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

function addImageBackground(parent, imageId, imageTransparency, overlayTransparency)
	if not hasCustomAssetId(imageId) then
		return nil
	end

	local image = Instance.new("ImageLabel")
	image.Name = "CustomBackgroundImage"
	image.BackgroundTransparency = 1
	image.Image = imageId
	image.ImageTransparency = imageTransparency or 0.18
	image.Position = UDim2.fromScale(0, 0)
	image.ScaleType = Enum.ScaleType.Stretch
	image.Size = UDim2.fromScale(1, 1)
	image.ZIndex = parent.ZIndex + 1
	image.Parent = parent

	local overlay = Instance.new("Frame")
	overlay.Name = "ReadabilityOverlay"
	overlay.BackgroundColor3 = Color3.fromRGB(8, 10, 9)
	overlay.BackgroundTransparency = overlayTransparency or 0.82
	overlay.BorderSizePixel = 0
	overlay.Position = UDim2.fromScale(0, 0)
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = parent.ZIndex + 2
	overlay.Parent = parent

	return image
end

local function showTooltip(button, tooltip, text)
	local label = tooltip:FindFirstChild("TooltipText")

	if label then
		label.Text = text
	end

	tooltip.Visible = true
	tooltip.Position = UDim2.new(
		button.Position.X.Scale,
		button.Position.X.Offset,
		button.Position.Y.Scale - 0.17,
		button.Position.Y.Offset
	)
	tooltip.Size = UDim2.fromOffset(176, 42)
	tooltip.ZIndex = 80
end

local function hideTooltip(tooltip)
	tooltip.Visible = false
end

local function styleButton(button, colorA, colorB, strokeColor, textColor)
	button.AutoButtonColor = false
	button.BackgroundColor3 = colorB
	button.BackgroundTransparency = 0.03
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = textColor
	button.TextScaled = true
	button.TextStrokeTransparency = 0.72
	button.ZIndex = 30
	addCorner(button, UDim.new(0, 8))
	local stroke = addStroke(button, strokeColor, 2, 0.12)
	addGradient(button, colorA, colorB, 90)

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	local function tweenScale(value)
		TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = value,
		}):Play()
	end

	button.MouseEnter:Connect(function()
		stroke.Transparency = 0
		tweenScale(1.035)
	end)

	button.MouseLeave:Connect(function()
		stroke.Transparency = 0.12
		tweenScale(1)
	end)

	button.MouseButton1Down:Connect(function()
		stroke.Transparency = 0
		tweenScale(0.95)
	end)

	button.MouseButton1Up:Connect(function()
		tweenScale(1.025)
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

local function playPurchaseEffect(button, upgradeId)
	if not button or not button.Parent then
		return
	end

	local assetConfig = getUpgradeAssetConfig(upgradeId)
	local effectImage = assetConfig.PurchaseEffectImage

	if not hasCustomAssetId(effectImage) then
		effectImage = assetConfig.IconImage
	end

	if not hasCustomAssetId(effectImage) then
		return
	end

	local parent = button.Parent
	local centerXScale = button.Position.X.Scale + (button.Size.X.Scale / 2)
	local centerXOffset = button.Position.X.Offset + (button.Size.X.Offset / 2)
	local centerYScale = button.Position.Y.Scale + (button.Size.Y.Scale / 2)
	local centerYOffset = button.Position.Y.Offset + (button.Size.Y.Offset / 2)
	local directions = {
		Vector2.new(-70, -58),
		Vector2.new(0, -76),
		Vector2.new(70, -58),
		Vector2.new(82, 0),
		Vector2.new(70, 58),
		Vector2.new(0, 76),
		Vector2.new(-70, 58),
		Vector2.new(-82, 0),
	}

	for index, offset in directions do
		local particle = Instance.new("ImageLabel")
		particle.Name = `PurchaseBurst{index}`
		particle.AnchorPoint = Vector2.new(0.5, 0.5)
		particle.BackgroundTransparency = 1
		particle.Image = effectImage
		particle.ImageTransparency = 0
		particle.Position = UDim2.new(centerXScale, centerXOffset, centerYScale, centerYOffset)
		particle.Rotation = index * 18
		particle.ScaleType = Enum.ScaleType.Fit
		particle.Size = UDim2.fromOffset(20, 20)
		particle.ZIndex = 95
		particle.Parent = parent

		local tween = TweenService:Create(particle, TweenInfo.new(0.62, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(centerXScale, centerXOffset + offset.X, centerYScale, centerYOffset + offset.Y),
			Rotation = particle.Rotation + 140,
			Size = UDim2.fromOffset(10, 10),
			ImageTransparency = 1,
		})

		tween.Completed:Connect(function()
			particle:Destroy()
		end)

		tween:Play()
	end
end

local function createTooltip(parent)
	local tooltip = Instance.new("Frame")
	tooltip.Name = "Tooltip"
	tooltip.BackgroundColor3 = Color3.fromRGB(48, 54, 48)
	tooltip.BackgroundTransparency = 0.08
	tooltip.BorderSizePixel = 0
	tooltip.ClipsDescendants = true
	tooltip.Size = UDim2.fromOffset(176, 42)
	tooltip.Visible = false
	tooltip.ZIndex = 80
	tooltip.Parent = parent
	addCorner(tooltip, UDim.new(0, 8))
	addStroke(tooltip, Color3.fromRGB(224, 242, 186), 1.5, 0.08)
	addGradient(tooltip, Color3.fromRGB(72, 84, 66), Color3.fromRGB(25, 28, 24), 90)
	addImageBackground(tooltip, (UIAssetConfig.Tooltip or {}).BackgroundImage, 0.16, 0.88)

	local label = Instance.new("TextLabel")
	label.Name = "TooltipText"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Position = UDim2.fromOffset(8, 4)
	label.Size = UDim2.new(1, -16, 1, -8)
	label.Text = "+1"
	label.TextColor3 = Color3.fromRGB(255, 252, 220)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.62
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.ZIndex = 84
	label.Parent = tooltip

	return tooltip
end

local function createUpgradeCard(parent, upgradeId, index)
	local cardScale
	local card = Instance.new("Frame")
	card.Name = upgradeId
	card.BackgroundColor3 = Color3.fromRGB(24, 26, 25)
	card.BackgroundTransparency = 0.04
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.LayoutOrder = index
	card.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	card.ZIndex = 10
	card.Parent = parent

	addCorner(card, UDim.new(0, 10))
	local cardStroke = addStroke(card, Color3.fromRGB(196, 220, 176), 2, 0.1)
	addGradient(card, Color3.fromRGB(42, 46, 43), Color3.fromRGB(14, 16, 15), 90)
	local assetConfig = getUpgradeAssetConfig(upgradeId)
	addImageBackground(card, assetConfig.BackgroundImage, 0.16, 0.86)

	cardScale = Instance.new("UIScale")
	cardScale.Scale = 1
	cardScale.Parent = card

	card.MouseEnter:Connect(function()
		cardStroke.Transparency = 0.02
		TweenService:Create(cardScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.012,
		}):Play()
	end)

	card.MouseLeave:Connect(function()
		cardStroke.Transparency = 0.1
		TweenService:Create(cardScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end)

	local shine = Instance.new("Frame")
	shine.Name = "TopAccent"
	shine.BackgroundColor3 = Color3.fromRGB(205, 235, 170)
	shine.BackgroundTransparency = 0.18
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromOffset(16, 10)
	shine.Size = UDim2.new(1, -32, 0, 3)
	shine.ZIndex = 14
	shine.Parent = card

	local innerFrame = Instance.new("Frame")
	innerFrame.Name = "InnerFrame"
	innerFrame.BackgroundTransparency = 1
	innerFrame.Position = UDim2.fromOffset(11, 11)
	innerFrame.Size = UDim2.new(1, -22, 1, -22)
	innerFrame.ZIndex = 15
	innerFrame.Parent = card
	addCorner(innerFrame, UDim.new(0, 8))
	addStroke(innerFrame, Color3.fromRGB(240, 245, 220), 1, 0.72)

	local iconBox = Instance.new("Frame")
	iconBox.Name = "IconBox"
	iconBox.BackgroundColor3 = Color3.fromRGB(104, 132, 92)
	iconBox.BackgroundTransparency = 0.34
	iconBox.BorderSizePixel = 0
	iconBox.Position = UDim2.fromOffset(20, 28)
	iconBox.Size = UDim2.fromOffset(64, 64)
	iconBox.ZIndex = 18
	iconBox.Parent = card
	addCorner(iconBox, UDim.new(0, 8))
	addStroke(iconBox, Color3.fromRGB(232, 248, 205), 1.5, 0.18)

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = assetConfig.IconImage or "rbxassetid://0"
	icon.Position = UDim2.fromScale(0.12, 0.12)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromScale(0.76, 0.76)
	icon.ZIndex = 21
	icon.Parent = iconBox
	startUpgradeIconPulse(icon)

	local title = createText(card, "Title", upgradeId, UDim2.fromOffset(98, 26), UDim2.new(1, -118, 0, 34), Enum.Font.GothamBold, Color3.fromRGB(245, 248, 230))
	title.TextStrokeTransparency = 0.7
	title.ZIndex = 22
	local level = createText(card, "Level", "Level 0/0", UDim2.fromOffset(98, 61), UDim2.new(1, -118, 0, 26), Enum.Font.GothamBold, Color3.fromRGB(196, 212, 190))
	level.TextStrokeTransparency = 0.78
	level.ZIndex = 22

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.BackgroundColor3 = Color3.fromRGB(111, 174, 78)
	badge.BorderSizePixel = 0
	badge.ClipsDescendants = true
	badge.Position = UDim2.fromOffset(24, 108)
	badge.Size = UDim2.new(1, -48, 0, 36)
	badge.ZIndex = 18
	badge.Parent = card
	addCorner(badge, UDim.new(0, 8))
	addStroke(badge, Color3.fromRGB(244, 255, 210), 1.5, 0.14)
	addGradient(badge, Color3.fromRGB(212, 245, 145), Color3.fromRGB(74, 136, 66), 0)
	addImageBackground(badge, (UIAssetConfig.BonusBadge or {}).BackgroundImage, 0.18, 0.88)

	local effect = createText(badge, "Effect", "+1", UDim2.fromOffset(8, 2), UDim2.new(1, -16, 1, -4), Enum.Font.GothamBold, Color3.fromRGB(250, 255, 232))
	effect.TextXAlignment = Enum.TextXAlignment.Center
	effect.TextStrokeTransparency = 0.48
	effect.ZIndex = 24

	local price = createText(card, "Price", "Price: 0 coins", UDim2.fromOffset(24, 153), UDim2.new(1, -48, 0, 28), Enum.Font.GothamBold, Color3.fromRGB(255, 235, 150))
	price.TextXAlignment = Enum.TextXAlignment.Center
	price.TextStrokeTransparency = 0.62
	price.ZIndex = 22

	local tooltip = createTooltip(card)

	local buyButton = Instance.new("TextButton")
	buyButton.Name = "Buy"
	buyButton.Position = UDim2.fromOffset(28, 192)
	buyButton.Size = UDim2.fromOffset(168, 38)
	buyButton.Text = "Buy"
	buyButton.Parent = card
	styleButton(buyButton, Color3.fromRGB(176, 226, 118), Color3.fromRGB(62, 142, 62), Color3.fromRGB(232, 255, 198), Color3.fromRGB(12, 28, 10))

	local buyMaxButton = Instance.new("TextButton")
	buyMaxButton.Name = "BuyMax"
	buyMaxButton.Position = UDim2.fromOffset(224, 192)
	buyMaxButton.Size = UDim2.fromOffset(168, 38)
	buyMaxButton.Text = "Buy Max"
	buyMaxButton.Parent = card
	styleButton(buyMaxButton, Color3.fromRGB(242, 210, 132), Color3.fromRGB(128, 112, 82), Color3.fromRGB(255, 244, 205), Color3.fromRGB(255, 255, 245))

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
			pendingPurchaseEffectUpgradeId = upgradeId
			pendingPurchaseEffectButton = button
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
		button.TouchLongPress:Connect(function(_, state)
			if state == Enum.UserInputState.Begin then
				showCurrentTooltip()
			else
				hideTooltip(tooltip)
			end
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
		surfaceGui.Parent = boardPart
	else
		surfaceGui:ClearAllChildren()
		surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		surfaceGui.CanvasSize = Vector2.new(1600, 900)
		surfaceGui.PixelsPerStud = 80
		surfaceGui.LightInfluence = 0
	end

	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surfaceGui.CanvasSize = Vector2.new(1400, 650)
	surfaceGui.PixelsPerStud = 85
	surfaceGui.LightInfluence = 0

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.BackgroundColor3 = Color3.fromRGB(6, 8, 7)
	background.BackgroundTransparency = 0.04
	background.BorderSizePixel = 0
	background.Size = UDim2.fromScale(1, 1)
	background.Parent = surfaceGui
	addCorner(background, UDim.new(0, 10))
	addStroke(background, Color3.fromRGB(190, 235, 135), 2, 0.2)
	addGradient(background, Color3.fromRGB(28, 32, 30), Color3.fromRGB(5, 6, 6), 90)

	local title = createText(background, "Title", "Coin Upgrades", UDim2.fromScale(0.03, 0.025), UDim2.fromScale(0.94, 0.105), Enum.Font.GothamBold, Color3.fromRGB(225, 245, 190))
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextStrokeTransparency = 0.55

	local cardsScroll = Instance.new("ScrollingFrame")
	cardsScroll.Name = "CardsScroll"
	cardsScroll.Active = true
	cardsScroll.BackgroundColor3 = Color3.fromRGB(12, 14, 13)
	cardsScroll.BackgroundTransparency = 0.28
	cardsScroll.BorderSizePixel = 0
	cardsScroll.CanvasSize = UDim2.fromOffset((#UPGRADE_ORDER * CARD_WIDTH) + ((#UPGRADE_ORDER - 1) * CARD_PADDING) + 24, 0)
	cardsScroll.ClipsDescendants = true
	cardsScroll.Position = UDim2.fromScale(0.03, 0.19)
	cardsScroll.ScrollingDirection = Enum.ScrollingDirection.X
	cardsScroll.ScrollBarImageColor3 = Color3.fromRGB(210, 240, 170)
	cardsScroll.ScrollBarImageTransparency = 0.15
	cardsScroll.ScrollBarThickness = 10
	cardsScroll.Size = UDim2.fromScale(0.94, 0.70)
	cardsScroll.VerticalScrollBarInset = Enum.ScrollBarInset.None
	cardsScroll.ZIndex = 5
	cardsScroll.Parent = background
	addCorner(cardsScroll, UDim.new(0, 8))
	addStroke(cardsScroll, Color3.fromRGB(170, 200, 150), 1, 0.55)

	local cardsContainer = Instance.new("Frame")
	cardsContainer.Name = "CardsContainer"
	cardsContainer.BackgroundTransparency = 1
	cardsContainer.Position = UDim2.fromOffset(12, 16)
	cardsContainer.Size = UDim2.new(0, (#UPGRADE_ORDER * CARD_WIDTH) + ((#UPGRADE_ORDER - 1) * CARD_PADDING), 1, -36)
	cardsContainer.ZIndex = 6
	cardsContainer.Parent = cardsScroll

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, CARD_PADDING)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = cardsContainer

	for index, upgradeId in UPGRADE_ORDER do
		createUpgradeCard(cardsContainer, upgradeId, index)
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
				card.Price.Text = "Price: Max"
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


coinCollectedEffect.OnClientEvent:Connect(function(amount)
	print("[CoinCollectedEffect handler] ClientEffects")
	cleanupLegacyCoinPickupEffects()
	showCoinPickupPopup(amount)
	task.defer(cleanupLegacyCoinPickupEffects)
	task.delay(0.15, cleanupLegacyCoinPickupEffects)
end)

upgradeResultRemote.OnClientEvent:Connect(function(result)
	if typeof(result) ~= "table" then
		showNotification("Error", "Ошибка покупки, попробуйте позже")
		return
	end

	if result.Data then
		updateUpgradeBoard(result.Data)
	end

	if result.Type == "Success" and pendingPurchaseEffectUpgradeId then
		local card = upgradeCards[pendingPurchaseEffectUpgradeId]

		if card then
			playPurchaseEffect(pendingPurchaseEffectButton or card.Buy, pendingPurchaseEffectUpgradeId)
		end
	end

	pendingPurchaseEffectUpgradeId = nil
	pendingPurchaseEffectButton = nil
	showNotification(result.Type or "Error", result.Message or "Ошибка покупки, попробуйте позже")
end)

syncPlayerDataRemote.OnClientEvent:Connect(function(data)
	updateUpgradeBoard(data)
end)

getOrCreateScreenGui()
setupUpgradeBoard()

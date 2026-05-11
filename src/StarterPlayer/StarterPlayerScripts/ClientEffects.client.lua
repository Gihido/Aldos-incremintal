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
local CARD_WIDTH = 390
local CARD_HEIGHT = 610
local CARD_PADDING = 22
local CARD_SIDE_PADDING = 20
local CARD_EXTRA_SCROLL_SPACE = 180

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
local upgradeGuiReady = false
local updateUpgradeBoard


local function getGameFont()
	return (UIAssetConfig.Fonts and UIAssetConfig.Fonts.Main) or Enum.Font.Arcade
end

local function applyGameFont(textObject)
	if textObject and (textObject:IsA("TextLabel") or textObject:IsA("TextButton") or textObject:IsA("TextBox")) then
		textObject.Font = getGameFont()
	end
end

local function applyAnimatedTextGradient(textObject)
	if not textObject or not (textObject:IsA("TextLabel") or textObject:IsA("TextButton") or textObject:IsA("TextBox")) then
		return nil
	end

	local gradient = textObject:FindFirstChild("AnimatedTextGradient")

	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Name = "AnimatedTextGradient"
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.48, Color3.fromRGB(95, 95, 95)),
			ColorSequenceKeypoint.new(0.72, Color3.fromRGB(18, 18, 18)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		})
		gradient.Offset = Vector2.new(-1, 0)
		gradient.Parent = textObject
	end

	task.spawn(function()
		while gradient.Parent == textObject do
			gradient.Offset = Vector2.new(-1, 0)
			local tween = TweenService:Create(gradient, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Offset = Vector2.new(1, 0),
			})
			tween:Play()
			tween.Completed:Wait()
		end
	end)

	return gradient
end

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
	corner.CornerRadius = UDim.new(0, 0)
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

local function getButtonImage(assetConfig, mode)
	if mode == "BuyMax" then
		return assetConfig.BuyMaxButtonImage or assetConfig.BuyMaxButtonBackground
	end

	return assetConfig.BuyButtonImage or assetConfig.BuyButtonBackground
end

local function setTextSafe(obj, value, labelName, upgradeId)
	if obj and (obj:IsA("TextLabel") or obj:IsA("TextButton")) then
		obj.Text = value
		return true
	end

	warn(`{labelName or "TextLabel"} missing for {upgradeId or "upgrade card"}`)
	return false
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

local function tweenPopupTransparency(popup, value, tweenInfo)
	for _, descendant in popup:GetDescendants() do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
			TweenService:Create(descendant, tweenInfo, {
				TextTransparency = value,
				TextStrokeTransparency = value,
			}):Play()
		elseif descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
			TweenService:Create(descendant, tweenInfo, {
				ImageTransparency = value,
			}):Play()
		elseif descendant:IsA("Frame") then
			local targetTransparency = value
			if descendant.Name == "PopupBackgroundFallback" then
				targetTransparency = value == 1 and 1 or 0.08
			end

			TweenService:Create(descendant, tweenInfo, {
				BackgroundTransparency = targetTransparency,
			}):Play()
		end
	end
end

local function showCoinPickupPopup(amount)
	cleanupLegacyCoinPickupEffects()

	local popupLayer = getOrCreateGuiLayer("CoinPickupGui", 20)
	local viewport = ResponsiveUI.GetViewportSize()
	local isMobileLike = math.min(viewport.X, viewport.Y) <= 700
	local popupSize = isMobileLike and 54 or 70
	local minX = isMobileLike and 0.18 or 0.12
	local maxX = isMobileLike and 0.82 or 0.88
	local randomX = minX + (math.random() * (maxX - minX))
	local startY = isMobileLike and (0.955 + (math.random() * 0.01)) or (0.98 + (math.random() * 0.005))
	local peakY = isMobileLike and (0.82 + (math.random() * 0.015)) or (0.84 + (math.random() * 0.012))
	local startRotation = math.random(-8, 8)
	local fallRotation = startRotation + math.random(360, 540)

	local popup = Instance.new("Frame")
	popup.Name = "CoinPickupPopup"
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundColor3 = Color3.fromRGB(52, 56, 50)
	popup.BackgroundTransparency = 0.08
	popup.BorderSizePixel = 0
	popup.ClipsDescendants = true
	popup.Position = UDim2.fromScale(randomX, startY)
	popup.Rotation = startRotation
	popup.Size = UDim2.fromOffset(popupSize, popupSize)
	popup.ZIndex = 20
	popup.Parent = popupLayer

	addCorner(popup, UDim.new(0, 0))
	addStroke(popup, Color3.fromRGB(245, 245, 220), 1.5, 0.18)

	local coinPopupConfig = UIAssetConfig.CoinPickupPopup or {}

	if hasCustomAssetId(coinPopupConfig.BackgroundImage) then
		local backgroundImage = Instance.new("ImageLabel")
		backgroundImage.Name = "PopupBackgroundImage"
		backgroundImage.BackgroundTransparency = 1
		backgroundImage.BorderSizePixel = 0
		backgroundImage.Image = coinPopupConfig.BackgroundImage
		backgroundImage.ImageTransparency = 0.08
		backgroundImage.Position = UDim2.fromScale(0, 0)
		backgroundImage.ScaleType = Enum.ScaleType.Stretch
		backgroundImage.Size = UDim2.fromScale(1, 1)
		backgroundImage.ZIndex = popup.ZIndex + 1
		backgroundImage.Parent = popup
	else
		local fallback = Instance.new("Frame")
		fallback.Name = "PopupBackgroundFallback"
		fallback.BackgroundColor3 = Color3.fromRGB(74, 82, 66)
		fallback.BackgroundTransparency = 0.08
		fallback.BorderSizePixel = 0
		fallback.Position = UDim2.fromScale(0, 0)
		fallback.Size = UDim2.fromScale(1, 1)
		fallback.ZIndex = popup.ZIndex + 1
		fallback.Parent = popup
		addGradient(fallback, Color3.fromRGB(98, 112, 82), Color3.fromRGB(40, 45, 38), 90)
	end

	local text = Instance.new("TextLabel")
	text.Name = "Amount"
	text.BackgroundTransparency = 1
	text.Font = getGameFont()
	text.Position = UDim2.fromScale(0.05, 0.05)
	text.Size = UDim2.fromScale(0.9, 0.9)
	text.Text = `+{FormatNumber(amount)}`
	text.TextColor3 = Color3.fromRGB(255, 252, 220)
	text.TextScaled = true
	text.TextStrokeColor3 = Color3.fromRGB(20, 24, 20)
	text.TextStrokeTransparency = 0.45
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextYAlignment = Enum.TextYAlignment.Center
	text.ZIndex = popup.ZIndex + 2
	text.Parent = popup
	applyAnimatedTextGradient(text)

	local textSizeConstraint = Instance.new("UITextSizeConstraint")
	textSizeConstraint.MaxTextSize = isMobileLike and 22 or 28
	textSizeConstraint.MinTextSize = 10
	textSizeConstraint.Parent = text

	local tossTween = TweenService:Create(popup, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(randomX, peakY),
		Rotation = startRotation + math.random(-6, 6),
	})

	tossTween.Completed:Connect(function()
		task.delay(0.9, function()
			if not popup.Parent then
				return
			end

			local fallTweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local fallTween = TweenService:Create(popup, fallTweenInfo, {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(randomX, 1.08),
				Rotation = fallRotation,
			})

			tweenPopupTransparency(popup, 1, fallTweenInfo)
			fallTween.Completed:Connect(function()
				popup:Destroy()
			end)
			fallTween:Play()
		end)
	end)

	tossTween:Play()
end

local addImageBackground

local function showNotification(notificationType, message)
	local config = NOTIFICATION_CONFIG[notificationType] or NOTIFICATION_CONFIG.Error
	local assetConfig = getNotificationAssetConfig(notificationType)
	local notificationLayer = getOrCreateGuiLayer("NotificationsGui", 100)
	local isMobileLike = ResponsiveUI.IsMobileLike()
	notificationCount += 1

	local targetPosition = UDim2.fromScale(0.98, 0.08)
	local frame = Instance.new("Frame")
	frame.Name = `Notification{notificationCount}`
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.BackgroundColor3 = config.Color
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Position = UDim2.fromScale(1.2, 0.08)
	frame.Size = UDim2.fromOffset(isMobileLike and 240 or 300, isMobileLike and 52 or 66)
	frame.ZIndex = 100 + (notificationCount * 10)
	frame.Parent = notificationLayer
	applyResponsiveScale(frame, isMobileLike and 0.92 or 1)

	addStroke(frame, Color3.fromRGB(245, 245, 235), 2, 0.1)
	addGradient(frame, config.Color, Color3.fromRGB(38, 40, 42), 0)
	addImageBackground(frame, assetConfig.BackgroundImage, 0.05, 0.94)

	local iconBackground = Instance.new("Frame")
	iconBackground.Name = "IconBackground"
	iconBackground.BackgroundColor3 = Color3.fromRGB(18, 20, 18)
	iconBackground.BackgroundTransparency = 0.05
	iconBackground.BorderSizePixel = 0
	iconBackground.Position = UDim2.fromOffset(9, 9)
	iconBackground.Size = UDim2.fromOffset(42, 42)
	iconBackground.ZIndex = frame.ZIndex + 4
	iconBackground.Parent = frame
	addStroke(iconBackground, Color3.fromRGB(255, 255, 245), 1.5, 0.25)

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Image = assetConfig.IconImage or "rbxassetid://0"
	icon.Position = UDim2.fromOffset(7, 7)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromOffset(28, 28)
	icon.ZIndex = frame.ZIndex + 5
	icon.Parent = iconBackground

	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = getGameFont()
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
	applyAnimatedTextGradient(label)

	TweenService:Create(frame, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = targetPosition,
	}):Play()

	task.delay(3, function()
		if not frame.Parent then
			return
		end

		local outTween = TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(1.2, 0.08),
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
	text.Font = font or getGameFont()
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
	applyGameFont(text)
	applyAnimatedTextGradient(text)

	return text
end

function addImageBackground(parent, imageId, imageTransparency, overlayTransparency)
	if not hasCustomAssetId(imageId) then
		return nil
	end

	local fillColor = parent.BackgroundColor3
	parent.BackgroundTransparency = 1
	parent.BorderSizePixel = 0
	parent.ClipsDescendants = true

	local fill = Instance.new("Frame")
	fill.Name = "BackgroundFill"
	fill.BackgroundColor3 = fillColor
	fill.BackgroundTransparency = 0.03
	fill.BorderSizePixel = 0
	fill.Position = UDim2.fromScale(0, 0)
	fill.Size = UDim2.fromScale(1, 1)
	fill.ZIndex = parent.ZIndex
	fill.Parent = parent

	local image = Instance.new("ImageLabel")
	image.Name = "CustomBackgroundImage"
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Image = imageId
	image.ImageTransparency = imageTransparency or 0.05
	image.Position = UDim2.fromScale(0, 0)
	image.ScaleType = Enum.ScaleType.Stretch
	image.Size = UDim2.fromScale(1, 1)
	image.ZIndex = parent.ZIndex + 1
	image.Parent = parent

	local overlay = Instance.new("Frame")
	overlay.Name = "ReadabilityOverlay"
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = overlayTransparency or 0.92
	overlay.BorderSizePixel = 0
	overlay.Position = UDim2.fromScale(0, 0)
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = parent.ZIndex + 2
	overlay.Parent = parent

	return image
end

local function getCardBackground(assetConfig)
	return assetConfig.CardBackground or assetConfig.BackgroundImage
end

local function showTooltip(button, tooltip, text)
	local label = tooltip:FindFirstChild("TooltipText")

	if label then
		label.Text = text
	end

	local tooltipX = button.Name == "BuyMax" and 220 or 36

	tooltip.Visible = true
	tooltip.Position = UDim2.fromOffset(tooltipX, 445)
	tooltip.Size = UDim2.fromOffset(130, 38)
	tooltip.ZIndex = 80
end

local function hideTooltip(tooltip)
	tooltip.Visible = false
end

local function styleButton(button, colorA, colorB, strokeColor, textColor, buttonImage, fallbackText)
	local hasButtonImage = hasCustomAssetId(buttonImage)

	button.AutoButtonColor = false
	button.BackgroundColor3 = colorB
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Image = hasButtonImage and buttonImage or ""
	button.ImageColor3 = Color3.fromRGB(255, 255, 255)
	button.ImageTransparency = hasButtonImage and 0 or 1
	button.ScaleType = Enum.ScaleType.Stretch
	button.ZIndex = 30
	button.ClipsDescendants = true
	button:SetAttribute("UsesImageBackground", hasButtonImage)
	local stroke = addStroke(button, strokeColor, 2, 0.1)

	if not hasButtonImage then
		button.BackgroundTransparency = 0.03
		addGradient(button, colorA, colorB, 90)
	end

	local label = Instance.new("TextLabel")
	label.Name = "ButtonText"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = getGameFont()
	label.Position = UDim2.fromScale(0, 0)
	label.Size = UDim2.fromScale(1, 1)
	label.Text = fallbackText
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = false
	label.TextSize = fallbackText == "Buy Max" and 25 or 28
	label.TextStrokeTransparency = 0.72
	label.Visible = true
	label.ZIndex = button.ZIndex + 5
	label.Parent = button
	applyAnimatedTextGradient(label)

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
		button.ImageColor3 = Color3.fromRGB(255, 255, 255)
		tweenScale(1.035)
	end)

	button.MouseLeave:Connect(function()
		stroke.Transparency = 0.1
		button.ImageColor3 = Color3.fromRGB(255, 255, 255)
		tweenScale(1)
	end)

	button.MouseButton1Down:Connect(function()
		stroke.Transparency = 0
		button.ImageColor3 = Color3.fromRGB(230, 230, 230)
		tweenScale(0.95)
	end)

	button.MouseButton1Up:Connect(function()
		button.ImageColor3 = Color3.fromRGB(255, 255, 255)
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

	for index, offset in ipairs(directions) do
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

local function createTextBox(parent, name, position, size, color, backgroundImage, zIndex)
	local box = Instance.new("Frame")
	box.Name = name
	box.BackgroundColor3 = color
	box.BackgroundTransparency = hasCustomAssetId(backgroundImage) and 1 or 0.06
	box.BorderSizePixel = 0
	box.ClipsDescendants = true
	box.Position = position
	box.Size = size
	box.ZIndex = zIndex
	box.Parent = parent
	addStroke(box, Color3.fromRGB(235, 235, 220), 2, 0.18)
	addImageBackground(box, backgroundImage, 0.03, 0.95)

	return box
end

local function createBoxLabel(parent, name, textValue, font, color, options)
	options = options or {}

	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font or getGameFont()
	label.Position = options.Position or UDim2.fromOffset(8, 6)
	label.Size = options.Size or UDim2.new(1, -16, 1, -12)
	label.Text = textValue
	label.TextColor3 = color or Color3.fromRGB(248, 248, 236)
	label.TextScaled = options.TextScaled ~= false
	label.TextSize = options.TextSize or 32
	label.TextStrokeTransparency = options.TextStrokeTransparency or 0.58
	label.TextWrapped = options.TextWrapped ~= false
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = parent.ZIndex + 5
	label.Parent = parent
	applyGameFont(label)
	applyAnimatedTextGradient(label)

	if options.MinTextSize or options.MaxTextSize then
		local sizeConstraint = Instance.new("UITextSizeConstraint")
		sizeConstraint.MinTextSize = options.MinTextSize or 12
		sizeConstraint.MaxTextSize = options.MaxTextSize or label.TextSize
		sizeConstraint.Parent = label
	end

	return label
end

local function createTooltip(parent, assetConfig)
	local tooltip = createTextBox(
		parent,
		"Tooltip",
		UDim2.fromOffset(220, 445),
		UDim2.fromOffset(130, 38),
		Color3.fromRGB(48, 54, 48),
		(assetConfig and assetConfig.TooltipBackground) or (UIAssetConfig.Tooltip or {}).BackgroundImage,
		80
	)
	tooltip.Visible = false

	local label = createBoxLabel(tooltip, "TooltipText", "+1", getGameFont(), Color3.fromRGB(255, 252, 220), {
		TextScaled = false,
		TextSize = 26,
		TextStrokeTransparency = 0.62,
	})

	return tooltip
end

local function createUpgradeCard(parent, upgradeId, index)
	local cardScale
	local assetConfig = getUpgradeAssetConfig(upgradeId)
	local card = Instance.new("Frame")
	card.Name = `{upgradeId}Card`
	card.BackgroundColor3 = Color3.fromRGB(24, 26, 25)
	card.BackgroundTransparency = hasCustomAssetId(getCardBackground(assetConfig)) and 1 or 0.04
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.LayoutOrder = index
	card.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	card.ZIndex = 10
	card.Parent = parent

	local cardStroke = addStroke(card, Color3.fromRGB(196, 220, 176), 2, 0.1)
	addGradient(card, Color3.fromRGB(42, 46, 43), Color3.fromRGB(14, 16, 15), 90)
	addImageBackground(card, getCardBackground(assetConfig), 0.02, 0.96)

	cardScale = Instance.new("UIScale")
	cardScale.Scale = 1
	cardScale.Parent = card

	card.MouseEnter:Connect(function()
		cardStroke.Transparency = 0.02
		TweenService:Create(cardScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.006,
		}):Play()
	end)

	card.MouseLeave:Connect(function()
		cardStroke.Transparency = 0.1
		TweenService:Create(cardScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end)

	local iconBox = Instance.new("Frame")
	iconBox.Name = "IconBox"
	iconBox.BackgroundColor3 = Color3.fromRGB(104, 132, 92)
	iconBox.BackgroundTransparency = 0.08
	iconBox.BorderSizePixel = 0
	iconBox.ClipsDescendants = true
	iconBox.Position = UDim2.fromOffset(30, 54)
	iconBox.Size = UDim2.fromOffset(105, 105)
	iconBox.ZIndex = 18
	iconBox.Parent = card
	addStroke(iconBox, Color3.fromRGB(232, 248, 205), 2, 0.12)

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Image = assetConfig.IconImage or "rbxassetid://0"
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromOffset(76, 76)
	icon.ZIndex = 24
	icon.Parent = iconBox

	local title = createText(card, "Title", upgradeId, UDim2.fromOffset(150, 62), UDim2.fromOffset(205, 40), getGameFont(), Color3.fromRGB(245, 248, 230))
	title.TextStrokeTransparency = 0.7
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.ZIndex = 26

	local level = createText(card, "Level", "0/0", UDim2.fromOffset(150, 108), UDim2.fromOffset(150, 36), getGameFont(), Color3.fromRGB(196, 212, 190))
	level.TextStrokeTransparency = 0.78
	level.TextYAlignment = Enum.TextYAlignment.Center
	level.ZIndex = 26

	local valueBox = createTextBox(card, "ValueBox", UDim2.fromOffset(34, 180), UDim2.fromOffset(322, 110), Color3.fromRGB(38, 43, 39), assetConfig.ValueBoxBackground, 18)
	local effect = createBoxLabel(valueBox, "Effect", "+1", getGameFont(), Color3.fromRGB(250, 255, 232), {
		Position = UDim2.fromOffset(12, 14),
		Size = UDim2.new(1, -24, 1, -28),
		TextScaled = false,
		TextSize = 46,
		TextStrokeTransparency = 0.46,
		TextWrapped = false,
	})

	local priceBox = createTextBox(card, "PriceBox", UDim2.fromOffset(34, 318), UDim2.fromOffset(322, 64), Color3.fromRGB(44, 39, 31), assetConfig.PriceBoxBackground, 18)
	local price = createBoxLabel(priceBox, "Price", "Price : 0 Coins", getGameFont(), Color3.fromRGB(255, 235, 150), {
		TextSize = 30,
		MinTextSize = 16,
		MaxTextSize = 32,
		TextStrokeTransparency = 0.58,
	})

	local tooltip = createTooltip(card, assetConfig)

	local buyButton = Instance.new("ImageButton")
	buyButton.Name = "Buy"
	buyButton.Position = UDim2.fromOffset(34, 500)
	buyButton.Size = UDim2.fromOffset(130, 82)
	buyButton.Parent = card
	styleButton(buyButton, Color3.fromRGB(176, 226, 118), Color3.fromRGB(62, 142, 62), Color3.fromRGB(232, 255, 198), Color3.fromRGB(12, 28, 10), getButtonImage(assetConfig, "Buy"), "Buy")

	local buyMaxButton = Instance.new("ImageButton")
	buyMaxButton.Name = "BuyMax"
	buyMaxButton.Position = UDim2.fromOffset(206, 500)
	buyMaxButton.Size = UDim2.fromOffset(150, 82)
	buyMaxButton.Parent = card
	styleButton(buyMaxButton, Color3.fromRGB(242, 210, 132), Color3.fromRGB(128, 112, 82), Color3.fromRGB(255, 244, 205), Color3.fromRGB(255, 255, 245), getButtonImage(assetConfig, "BuyMax"), "Buy Max")

	local cardData = {
		Frame = card,
		Title = title,
		Level = level,
		Effect = effect,
		Price = price,
		BonusMini = bonusMini,
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
	surfaceGui.CanvasSize = Vector2.new(1400, 760)
	surfaceGui.PixelsPerStud = 90
	surfaceGui.LightInfluence = 0

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.BackgroundColor3 = Color3.fromRGB(6, 8, 7)
	background.BackgroundTransparency = 0.04
	background.BorderSizePixel = 0
	background.ClipsDescendants = true
	background.Size = UDim2.fromScale(1, 1)
	background.Parent = surfaceGui
	addStroke(background, Color3.fromRGB(190, 235, 135), 2, 0.2)
	addGradient(background, Color3.fromRGB(28, 32, 30), Color3.fromRGB(5, 6, 6), 90)

	local title = createText(background, "Title", "Coin Upgrades", UDim2.fromOffset(36, 24), UDim2.new(1, -72, 0, 70), getGameFont(), Color3.fromRGB(225, 245, 190))
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextStrokeTransparency = 0.55

	local cardsScroll = Instance.new("ScrollingFrame")
	cardsScroll.Name = "CardsScroll"
	cardsScroll.Active = true
	cardsScroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	cardsScroll.BackgroundColor3 = Color3.fromRGB(12, 14, 13)
	cardsScroll.BackgroundTransparency = 1
	cardsScroll.BorderSizePixel = 0
	cardsScroll.CanvasSize = UDim2.fromOffset(0, 0)
	cardsScroll.ClipsDescendants = true
	cardsScroll.HorizontalScrollBarInset = Enum.ScrollBarInset.Always
	cardsScroll.Position = UDim2.fromOffset(30, 90)
	cardsScroll.ScrollingDirection = Enum.ScrollingDirection.X
	cardsScroll.ScrollingEnabled = true
	cardsScroll.ScrollBarImageColor3 = Color3.fromRGB(230, 230, 230)
	cardsScroll.ScrollBarImageTransparency = 0
	cardsScroll.ScrollBarThickness = 12
	cardsScroll.Size = UDim2.new(1, -60, 0, CARD_HEIGHT + 48)
	cardsScroll.VerticalScrollBarInset = Enum.ScrollBarInset.None
	cardsScroll.ZIndex = 5
	cardsScroll.Parent = background
	addStroke(cardsScroll, Color3.fromRGB(170, 200, 150), 1, 0.55)

	local cardsContainer = Instance.new("Frame")
	cardsContainer.Name = "CardsContainer"
	cardsContainer.BackgroundTransparency = 1
	cardsContainer.BorderSizePixel = 0
	cardsContainer.Position = UDim2.fromOffset(CARD_SIDE_PADDING, 0)
	cardsContainer.Size = UDim2.fromOffset(0, CARD_HEIGHT)
	cardsContainer.ZIndex = 6
	cardsContainer.Parent = cardsScroll

	local function updateScrollCanvas()
		local totalCardsWidth = (#UPGRADE_ORDER * CARD_WIDTH) + ((#UPGRADE_ORDER - 1) * CARD_PADDING)
		local canvasWidth = totalCardsWidth + (CARD_SIDE_PADDING * 2) + CARD_EXTRA_SCROLL_SPACE
		cardsContainer.Size = UDim2.fromOffset(totalCardsWidth, CARD_HEIGHT)
		cardsScroll.CanvasSize = UDim2.fromOffset(canvasWidth, 0)
	end

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Padding = UDim.new(0, CARD_PADDING)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Parent = cardsContainer

	for index, upgradeId in ipairs(UPGRADE_ORDER) do
		createUpgradeCard(cardsContainer, upgradeId, index)
	end

	updateScrollCanvas()
	upgradeGuiReady = true

	if latestPlayerData then
		updateUpgradeBoard(latestPlayerData)
	end
end

function updateUpgradeBoard(data)
	latestPlayerData = data

	if not upgradeGuiReady or not data or not data.Upgrades then
		return
	end

	for upgradeId, card in pairs(upgradeCards) do
		local upgradeData = data.Upgrades[upgradeId]

		if upgradeData then
			setTextSafe(card.Title, upgradeData.Name, "Title", upgradeId)
			setTextSafe(card.Level, `{upgradeData.Level}/{upgradeData.MaxLevel}`, "Level", upgradeId)
			setTextSafe(card.Effect, upgradeData.EffectText, "Effect", upgradeId)

			if upgradeData.IsMaxed then
				setTextSafe(card.Price, "Price : Max", "Price", upgradeId)
				if card.Buy then
					card.Buy.AutoButtonColor = false
					card.Buy.BackgroundTransparency = card.Buy:GetAttribute("UsesImageBackground") and 1 or 0.45
				end
				if card.BuyMax then
					card.BuyMax.AutoButtonColor = false
					card.BuyMax.BackgroundTransparency = card.BuyMax:GetAttribute("UsesImageBackground") and 1 or 0.45
				end
			else
				setTextSafe(card.Price, `Price : {upgradeData.PriceFormatted} Coins`, "Price", upgradeId)
				if card.Buy then
					card.Buy.AutoButtonColor = false
					card.Buy.BackgroundTransparency = card.Buy:GetAttribute("UsesImageBackground") and 1 or 0
				end
				if card.BuyMax then
					card.BuyMax.AutoButtonColor = false
					card.BuyMax.BackgroundTransparency = card.BuyMax:GetAttribute("UsesImageBackground") and 1 or 0
				end
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

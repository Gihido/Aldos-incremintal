local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local ItemConfig = require(shared:WaitForChild("ItemConfig"))
local ResponsiveUI = require(shared:WaitForChild("ResponsiveUI"))
local UIAssetConfig = require(shared:WaitForChild("UIAssetConfig"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local inventoryActionRemote = remotes:WaitForChild("InventoryAction")
local syncInventoryRemote = remotes:WaitForChild("SyncInventory")

local INVENTORY_ITEMS = ItemConfig.Order
local FALLBACK_BACKGROUND = Color3.fromRGB(22, 28, 36)
local FALLBACK_STROKE = Color3.fromRGB(210, 220, 235)
local SELECTED_STROKE = Color3.fromRGB(255, 245, 120)
local HOVER_STROKE = Color3.fromRGB(140, 230, 255)
local PRESS_STROKE = Color3.fromRGB(255, 255, 180)
local TWEEN_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_PANEL_OPEN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_PANEL_CLOSE = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FORCE_MOBILE_IN_STUDIO = false
local UI_PROFILES = {
	Desktop = {
		InventoryScale = 1,
		ToggleScale = 1,
		TooltipScale = 1,
		BuffsScale = 1,
	},

	Mobile = {
		InventoryScale = 0.50,
		ToggleScale = 0.64,
		TooltipScale = 0.64,
		BuffsScale = 0.58,
	},

	SmallMobile = {
		InventoryScale = 0.42,
		ToggleScale = 0.56,
		TooltipScale = 0.56,
		BuffsScale = 0.50,
	},
}

local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("InventoryGui", 10)

if not gui then
	warn("[InventoryClient] PlayerGui.InventoryGui was not found. Run InventoryGuiBuilder in Studio first.")
	return
end

local latestInventoryData = {
	Items = {},
	ItemOrder = {},
	ActiveBuffs = {},
	TotalCoinMultiplier = 1,
}
local selectedItemId
local selectedSlot
local currentTab = "Items"
local buffRows = {}
local slotHoverStates = {}
local baseLayout = {}
local ui = {}

local function hasCustomAssetId(assetId)
	return type(assetId) == "string" and assetId ~= "" and assetId ~= "rbxassetid://0"
end

local function getInventoryAssetConfig()
	return UIAssetConfig.Inventory or {}
end

local function getMainAssets()
	return getInventoryAssetConfig().Main or {}
end

local function getItemAssets(itemId)
	return (getInventoryAssetConfig().Items and getInventoryAssetConfig().Items[itemId]) or {}
end

local function warnMissing(name)
	warn("[InventoryClient] Missing GUI element:", name)
end

local function findChild(parent, name)
	if not parent then
		warnMissing(name)
		return nil
	end

	local child = parent:FindFirstChild(name)

	if not child then
		warnMissing(name)
	end

	return child
end

local function getNested(parent, path)
	local current = parent

	for _, name in ipairs(path) do
		current = findChild(current, name)

		if not current then
			return nil
		end
	end

	return current
end

local function ensureStroke(guiObject, name, color, thickness, transparency)
	if not guiObject or not guiObject:IsA("GuiObject") then
		return nil
	end

	local stroke = guiObject:FindFirstChild(name)

	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = name
		stroke.Parent = guiObject
	end

	stroke.Color = color or FALLBACK_STROKE
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0.25

	return stroke
end

local function setImageOrFallback(imageObject, assetId, fallbackColor)
	if not imageObject or not (imageObject:IsA("ImageLabel") or imageObject:IsA("ImageButton")) then
		return
	end

	local fallbackStroke = imageObject:FindFirstChild("FallbackStroke")

	if hasCustomAssetId(assetId) then
		imageObject.Image = assetId
		imageObject.ImageTransparency = 0
		imageObject.BackgroundTransparency = 1

		if fallbackStroke then
			fallbackStroke.Enabled = false
		end
	else
		imageObject.Image = ""
		imageObject.ImageTransparency = 1
		imageObject.BackgroundColor3 = fallbackColor or FALLBACK_BACKGROUND
		imageObject.BackgroundTransparency = 0.12
		ensureStroke(imageObject, "FallbackStroke", FALLBACK_STROKE, 2, 0.35).Enabled = true
	end
end

local function setText(label, text)
	if label and (label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox")) then
		label.Text = text
	end
end

local function getGameFont()
	return (UIAssetConfig.Fonts and UIAssetConfig.Fonts.Main) or Enum.Font.Arcade
end

local function applyTextConstraint(textObject, minSize, maxSize)
	if not textObject or not (textObject:IsA("TextLabel") or textObject:IsA("TextButton") or textObject:IsA("TextBox")) then
		return
	end

	textObject.Font = getGameFont()
	textObject.TextScaled = true
	textObject.TextStrokeTransparency = math.min(textObject.TextStrokeTransparency, 0.22)
	textObject.TextWrapped = true

	local constraint = textObject:FindFirstChildOfClass("UITextSizeConstraint")

	if not constraint then
		constraint = Instance.new("UITextSizeConstraint")
		constraint.Parent = textObject
	end

	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
end

local TEXT_SIZE_RULES = {
	InventoryTitle = { Min = 22, Desktop = 48, Mobile = 34, SmallMobile = 28 },
	ItemName = { Min = 12, Desktop = 28, Mobile = 18, SmallMobile = 15 },
	ItemCount = { Min = 12, Desktop = 24, Mobile = 16, SmallMobile = 14 },
	InfoName = { Min = 14, Desktop = 34, Mobile = 22, SmallMobile = 18 },
	InfoCount = { Min = 12, Desktop = 28, Mobile = 18, SmallMobile = 15 },
	InfoBoost = { Min = 12, Desktop = 28, Mobile = 18, SmallMobile = 15 },
	InfoDescription = { Min = 11, Desktop = 26, Mobile = 16, SmallMobile = 14 },
	ButtonText = { Min = 11, Desktop = 26, Mobile = 18, SmallMobile = 15 },
	TooltipName = { Min = 12, Desktop = 30, Mobile = 18, SmallMobile = 15 },
	TooltipBoost = { Min = 11, Desktop = 26, Mobile = 16, SmallMobile = 14 },
	BuffTime = { Min = 10, Desktop = 22, Mobile = 14, SmallMobile = 12 },
	ItemsEmptyLabel = { Min = 18, Desktop = 42, Mobile = 28, SmallMobile = 22 },
	PassivesComingSoonLabel = { Min = 18, Desktop = 42, Mobile = 28, SmallMobile = 22 },
}


local getUIProfileName

local function applyResponsiveTextConstraint(textObject, rule)
	if not textObject or not (textObject:IsA("TextLabel") or textObject:IsA("TextButton") or textObject:IsA("TextBox")) then
		return
	end

	local profileName = getUIProfileName and getUIProfileName() or "Desktop"
	local maxTextSize = rule.Desktop

	if profileName == "SmallMobile" then
		maxTextSize = rule.SmallMobile or rule.Mobile or rule.Desktop
	elseif profileName == "Mobile" then
		maxTextSize = rule.Mobile or rule.Desktop
	end

	applyTextConstraint(textObject, rule.Min or 10, maxTextSize or rule.Desktop or 24)
end

local function applyResponsiveTextConstraints(root)
	if not root then
		return
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		local rule = TEXT_SIZE_RULES[descendant.Name]

		if rule then
			applyResponsiveTextConstraint(descendant, rule)
		elseif ui.ActiveBuffsPanel and descendant:IsDescendantOf(ui.ActiveBuffsPanel) and (descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox")) then
			applyResponsiveTextConstraint(descendant, { Min = 10, Desktop = 22, Mobile = 14, SmallMobile = 12 })
		end
	end
end

local function applyInventoryTextStyles(root)
	if not root then
		return
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		local rule = TEXT_SIZE_RULES[descendant.Name]

		if rule then
			applyResponsiveTextConstraint(descendant, rule)
		elseif ui.ActiveBuffsPanel and descendant:IsDescendantOf(ui.ActiveBuffsPanel) and (descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox")) then
			applyResponsiveTextConstraint(descendant, { Min = 10, Desktop = 22, Mobile = 14, SmallMobile = 12 })
		end
	end
end

local function ensureScale(guiObject, name)
	if not guiObject or not guiObject:IsA("GuiObject") then
		return nil
	end

	local scale = guiObject:FindFirstChild(name or "HoverScale")

	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = name or "HoverScale"
		scale.Scale = 1
		scale.Parent = guiObject
	end

	return scale
end

local function tweenScale(guiObject, scaleValue)
	local scale = ensureScale(guiObject)

	if scale then
		TweenService:Create(scale, TWEEN_FAST, {
			Scale = scaleValue,
		}):Play()
	end
end

local function getOrCreateScale(parent, name)
	if not parent or not parent:IsA("GuiObject") then
		warnMissing(name)
		return nil
	end

	local scale = parent:FindFirstChild(name)

	if scale and not scale:IsA("UIScale") then
		warn(`[InventoryClient] {name} exists but is not a UIScale`)
		return nil
	end

	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = name
		scale.Scale = 1
		scale.Parent = parent
	end

	return scale
end

local function getViewport()
	local camera = Workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1920, 1080)
end

local function isMobileDevice()
	if FORCE_MOBILE_IN_STUDIO then
		return true
	end

	local viewport = getViewport()
	local minSide = math.min(viewport.X, viewport.Y)
	local maxSide = math.max(viewport.X, viewport.Y)
	local aspect = maxSide / math.max(minSide, 1)
	local touch = UserInputService.TouchEnabled
	local keyboard = UserInputService.KeyboardEnabled
	local tenFoot = GuiService:IsTenFootInterface()

	if tenFoot then
		return false
	end

	if minSide <= 800 then
		return true
	end

	if touch and not keyboard then
		return true
	end

	if touch and aspect >= 1.6 and minSide <= 900 then
		return true
	end

	return false
end

getUIProfileName = function()
	local viewport = getViewport()
	local minSide = math.min(viewport.X, viewport.Y)

	if isMobileDevice() then
		if minSide <= 500 then
			return "SmallMobile"
		end

		return "Mobile"
	end

	return "Desktop"
end

local function getCurrentResponsiveScales()
	local profileName = getUIProfileName()
	return UI_PROFILES[profileName] or UI_PROFILES.Desktop
end

local function getItemCount(itemId)
	return (latestInventoryData.Items and latestInventoryData.Items[itemId]) or 0
end

local function getOrderedVisibleItemIds()
	local ordered = {}
	local seen = {}

	if type(latestInventoryData.ItemOrder) == "table" then
		for _, itemId in ipairs(latestInventoryData.ItemOrder) do
			if ItemConfig[itemId] and not seen[itemId] and getItemCount(itemId) > 0 then
				seen[itemId] = true
				table.insert(ordered, itemId)
			end
		end
	end

	for _, itemId in ipairs(INVENTORY_ITEMS) do
		if ItemConfig[itemId] and not seen[itemId] and getItemCount(itemId) > 0 then
			seen[itemId] = true
			table.insert(ordered, itemId)
		end
	end

	return ordered
end

local function getItemIcon(itemId, forBuff)
	local itemAssets = getItemAssets(itemId)

	if forBuff and hasCustomAssetId(itemAssets.BuffIcon) then
		return itemAssets.BuffIcon
	end

	return itemAssets.Icon or "rbxassetid://0"
end

local function getSlotBackground(itemId)
	local itemAssets = getItemAssets(itemId)
	return itemAssets.SlotBackground or getMainAssets().ItemSlotBackground
end

local function getTooltipBackground(itemId)
	local itemAssets = getItemAssets(itemId)
	if hasCustomAssetId(itemAssets.TooltipBackground) then
		return itemAssets.TooltipBackground
	end

	return getMainAssets().TooltipBackground
end

local function getBuffTooltipBackground(itemId)
	local itemAssets = getItemAssets(itemId)
	return itemAssets.BuffTooltipBackground or getMainAssets().BuffTooltipBackground or getTooltipBackground(itemId)
end

local function getInfoBackground(itemId)
	local itemAssets = getItemAssets(itemId)
	return itemAssets.InfoBackground or getMainAssets().ItemInfoBackground
end

local function getActivateButtonBackground(itemId)
	local itemAssets = getItemAssets(itemId)
	return itemAssets.ActivateButtonBackground or getMainAssets().ActivateButtonBackground
end

local function getDeleteButtonBackground(itemId)
	local itemAssets = getItemAssets(itemId)
	return itemAssets.DeleteButtonBackground or getMainAssets().DeleteButtonBackground
end

local function setIconFallbackLetter(icon, itemId, forBuff)
	if not icon then
		return
	end

	local letter = icon:FindFirstChild("FallbackLetter")
	local hasIcon = hasCustomAssetId(icon.Image) or hasCustomAssetId(getItemIcon(itemId, forBuff == true))

	if hasIcon then
		if letter then
			letter.Visible = false
		end
		return
	end

	if not letter then
		letter = Instance.new("TextLabel")
		letter.Name = "FallbackLetter"
		letter.BackgroundTransparency = 1
		letter.Font = Enum.Font.Arcade
		letter.Size = UDim2.fromScale(1, 1)
		letter.TextColor3 = Color3.fromRGB(240, 240, 240)
		letter.TextScaled = true
		letter.TextStrokeTransparency = 0.25
		letter.ZIndex = icon.ZIndex + 1
		letter.Parent = icon
	end

	letter.Visible = true
	letter.Text = string.sub(itemId, 1, 1)
end

local function cacheGui()
	ui.ToggleButton = findChild(gui, "InventoryToggleButton")
	ui.InventoryMain = findChild(gui, "InventoryMain")
	ui.ItemTooltip = findChild(gui, "ItemTooltip")
	ui.ActiveBuffsPanel = findChild(gui, "ActiveBuffsPanel")

	ui.ButtonScale = getOrCreateScale(ui.ToggleButton, "ButtonScale")
	ui.InventoryScale = getOrCreateScale(ui.InventoryMain, "InventoryScale")
	ui.InventoryBackground = findChild(ui.InventoryMain, "InventoryBackground")
	ui.CloseInventoryButton = findChild(ui.InventoryMain, "CloseInventoryButton")
	ui.InventoryTitle = findChild(ui.InventoryMain, "InventoryTitle")
	ui.InventoryContent = findChild(ui.InventoryMain, "InventoryContent")
	ui.ItemsTabButton = getNested(ui.InventoryMain, { "CategoryPanel", "ItemsTabButton" })
	ui.PassivesTabButton = getNested(ui.InventoryMain, { "CategoryPanel", "PassivesTabButton" })
	ui.PackTraderTabButton = getNested(ui.InventoryMain, { "CategoryPanel", "PackTraderTabButton" })
	ui.ItemsScroll = getNested(ui.InventoryContent, { "ItemsScroll" })
	ui.PassivesScroll = getNested(ui.InventoryContent, { "PassivesScroll" })
	ui.ItemInfoPanel = findChild(ui.InventoryMain, "ItemInfoPanel")
	ui.CloseInfoButton = findChild(ui.ItemInfoPanel, "CloseInfoButton")
	ui.InfoBackground = findChild(ui.ItemInfoPanel, "InfoBackground")
	ui.InfoIcon = findChild(ui.ItemInfoPanel, "InfoIcon")
	ui.InfoName = findChild(ui.ItemInfoPanel, "InfoName")
	ui.InfoCount = findChild(ui.ItemInfoPanel, "InfoCount")
	ui.InfoBoost = findChild(ui.ItemInfoPanel, "InfoBoost")
	ui.InfoDescription = findChild(ui.ItemInfoPanel, "InfoDescription")
	ui.ActivateButton = findChild(ui.ItemInfoPanel, "ActivateButton")
	ui.DeleteButton = findChild(ui.ItemInfoPanel, "DeleteButton")
	ui.TooltipScale = getOrCreateScale(ui.ItemTooltip, "TooltipScale")
	ui.TooltipBackground = findChild(ui.ItemTooltip, "TooltipBackground")
	ui.TooltipName = findChild(ui.ItemTooltip, "TooltipName")
	ui.TooltipBoost = findChild(ui.ItemTooltip, "TooltipBoost")
	ui.BuffsScale = getOrCreateScale(ui.ActiveBuffsPanel, "BuffsScale")
	ui.BuffsBackground = findChild(ui.ActiveBuffsPanel, "BuffsBackground")
	ui.BuffsScroll = findChild(ui.ActiveBuffsPanel, "BuffsScroll")
	ui.BuffTemplate = findChild(ui.BuffsScroll, "BuffTemplate")
end

local function applyInventoryAssets()
	local mainAssets = getMainAssets()
	setImageOrFallback(ui.ToggleButton, mainAssets.ToggleButton, Color3.fromRGB(30, 45, 65))
	setImageOrFallback(ui.InventoryBackground, mainAssets.Background, Color3.fromRGB(18, 25, 34))
	setImageOrFallback(ui.CloseInventoryButton, mainAssets.CloseButton, Color3.fromRGB(100, 35, 35))
	setImageOrFallback(ui.ItemsTabButton, mainAssets.ItemsTabButton, Color3.fromRGB(45, 70, 95))
	setImageOrFallback(ui.PassivesTabButton, mainAssets.PassivesTabButton, Color3.fromRGB(45, 70, 95))
	setImageOrFallback(ui.InfoBackground, mainAssets.ItemInfoBackground, Color3.fromRGB(24, 32, 42))
	setImageOrFallback(ui.TooltipBackground, mainAssets.TooltipBackground, Color3.fromRGB(24, 32, 42))
	setImageOrFallback(ui.BuffsBackground, mainAssets.ActiveBuffsBackground, Color3.fromRGB(18, 25, 34))
	setImageOrFallback(ui.ActivateButton, mainAssets.ActivateButtonBackground, Color3.fromRGB(55, 110, 55))
	setImageOrFallback(ui.DeleteButton, mainAssets.DeleteButtonBackground, Color3.fromRGB(120, 50, 45))
end

local function applyResponsiveMode()
	local profileName = getUIProfileName()
	local profile = UI_PROFILES[profileName] or UI_PROFILES.Desktop
	local viewport = getViewport()

	if ui.InventoryScale then
		ui.InventoryScale.Scale = profile.InventoryScale
	end

	if ui.ButtonScale then
		ui.ButtonScale.Scale = profile.ToggleScale
	end

	if ui.TooltipScale then
		ui.TooltipScale.Scale = profile.TooltipScale
	end

	if ui.BuffsScale then
		ui.BuffsScale.Scale = profile.BuffsScale
	end

	print("[InventoryClient] Responsive applied:", profileName, viewport)
	print("[InventoryClient] Viewport:", viewport.X, viewport.Y)
	print("[InventoryClient] Touch:", UserInputService.TouchEnabled, "Keyboard:", UserInputService.KeyboardEnabled, "TenFoot:", GuiService:IsTenFootInterface())
	applyResponsiveTextConstraints(gui)
	print("[InventoryClient] Scales:", ui.InventoryScale and ui.InventoryScale.Scale or "missing", ui.ButtonScale and ui.ButtonScale.Scale or "missing", ui.TooltipScale and ui.TooltipScale.Scale or "missing", ui.BuffsScale and ui.BuffsScale.Scale or "missing")
end

local function ensureCloseInfoButtonVisible()
	if not ui.CloseInfoButton or not ui.CloseInfoButton:IsA("GuiObject") then
		return
	end

	ui.CloseInfoButton.Visible = true
	ui.CloseInfoButton.ZIndex = math.max(ui.CloseInfoButton.ZIndex, (ui.ItemInfoPanel and ui.ItemInfoPanel.ZIndex or 0) + 30)
	ui.CloseInfoButton.BackgroundTransparency = 1

	if ui.CloseInfoButton:IsA("ImageButton") or ui.CloseInfoButton:IsA("ImageLabel") then
		ui.CloseInfoButton.ImageTransparency = 0
	end

	if ui.CloseInfoButton.AbsoluteSize.X < 38 or ui.CloseInfoButton.AbsoluteSize.Y < 38 then
		ui.CloseInfoButton.Size = UDim2.fromOffset(math.max(38, ui.CloseInfoButton.AbsoluteSize.X), math.max(38, ui.CloseInfoButton.AbsoluteSize.Y))
	end

	local fallbackLabel = ui.CloseInfoButton:FindFirstChild("FallbackX")
	if not fallbackLabel then
		fallbackLabel = Instance.new("TextLabel")
		fallbackLabel.Name = "FallbackX"
		fallbackLabel.BackgroundTransparency = 1
		fallbackLabel.Size = UDim2.fromScale(1, 1)
		fallbackLabel.Font = getGameFont()
		fallbackLabel.Text = "X"
		fallbackLabel.TextColor3 = Color3.fromRGB(255, 245, 245)
		fallbackLabel.TextScaled = true
		fallbackLabel.TextStrokeColor3 = Color3.fromRGB(130, 20, 20)
		fallbackLabel.TextStrokeTransparency = 0.15
		fallbackLabel.ZIndex = ui.CloseInfoButton.ZIndex + 1
		fallbackLabel.Parent = ui.CloseInfoButton
	end

	fallbackLabel.Visible = true
	fallbackLabel.ZIndex = ui.CloseInfoButton.ZIndex + 1
	applyTextConstraint(fallbackLabel, 18, 34)
	ensureStroke(ui.CloseInfoButton, "CloseButtonFallbackStroke", Color3.fromRGB(255, 235, 235), 2, 0.15).Enabled = true
end

local getInfoHiddenPosition

local function captureBaseLayout()
	if ui.ItemInfoPanel and not baseLayout.InfoOpenPosition then
		baseLayout.InfoOpenPosition = ui.ItemInfoPanel.Position
		baseLayout.InfoOpenSize = ui.ItemInfoPanel.Size
		ui.ItemInfoPanel.Position = getInfoHiddenPosition()
		ui.ItemInfoPanel.Visible = false
	end

	if ui.InventoryContent and not baseLayout.ContentDefaultPosition then
		baseLayout.ContentDefaultPosition = ui.InventoryContent.Position
		baseLayout.ContentDefaultSize = ui.InventoryContent.Size
		baseLayout.ContentDefaultAbsoluteSize = ui.InventoryContent.AbsoluteSize
	end
end

getInfoHiddenPosition = function()
	local openPosition = baseLayout.InfoOpenPosition or (ui.ItemInfoPanel and ui.ItemInfoPanel.Position) or UDim2.fromScale(1, 0)
	local panelWidth = ui.ItemInfoPanel and ui.ItemInfoPanel.AbsoluteSize.X or 0

	return UDim2.new(
		openPosition.X.Scale,
		openPosition.X.Offset + panelWidth + 40,
		openPosition.Y.Scale,
		openPosition.Y.Offset
	)
end

local function getCompressedContentLayout()
	if not ui.InventoryContent or currentTab ~= "Items" then
		return nil, nil
	end

	local defaultPosition = baseLayout.ContentDefaultPosition or ui.InventoryContent.Position
	local defaultSize = baseLayout.ContentDefaultSize or ui.InventoryContent.Size
	local panelWidth = ui.ItemInfoPanel and ui.ItemInfoPanel.AbsoluteSize.X or 0
	local gap = ResponsiveUI.IsMobileLike() and 12 or 20
	local compression = ResponsiveUI.IsMobileLike() and ((panelWidth * 0.85) + gap) or (panelWidth + gap)
	local profileName = getUIProfileName()
	local minWidth = profileName == "SmallMobile" and 180 or (profileName == "Mobile" and 200 or 300)
	local defaultAbsoluteSize = ui.InventoryContent.AbsoluteSize
	if baseLayout.ContentDefaultAbsoluteSize and not ResponsiveUI.IsMobileLike() then
		defaultAbsoluteSize = baseLayout.ContentDefaultAbsoluteSize
	end
	local allowedCompression = math.max(0, math.min(compression, math.max(0, defaultAbsoluteSize.X - minWidth)))
	local shift = ResponsiveUI.IsMobileLike() and math.min(28, allowedCompression * 0.35) or math.min(20, allowedCompression * 0.25)

	return UDim2.new(
		defaultPosition.X.Scale,
		defaultPosition.X.Offset - shift,
		defaultPosition.Y.Scale,
		defaultPosition.Y.Offset
	), UDim2.new(
		defaultSize.X.Scale,
		defaultSize.X.Offset - allowedCompression,
		defaultSize.Y.Scale,
		defaultSize.Y.Offset
	)
end

local function tweenInventoryContent(compressed)
	if not ui.InventoryContent then
		return
	end

	local targetPosition
	local targetSize

	if compressed and currentTab == "Items" then
		targetPosition, targetSize = getCompressedContentLayout()
	else
		targetPosition = baseLayout.ContentDefaultPosition or ui.InventoryContent.Position
		targetSize = baseLayout.ContentDefaultSize or ui.InventoryContent.Size
	end

	if targetPosition and targetSize then
		TweenService:Create(ui.InventoryContent, TWEEN_PANEL_OPEN, {
			Position = targetPosition,
			Size = targetSize,
		}):Play()
	end
end

local function createEmptyStateLabel(parent, name, text)
	if not parent then
		return nil
	end

	local label = parent:FindFirstChild(name)

	if not label then
		label = Instance.new("TextLabel")
		label.Name = name
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.new(1, -40, 0, 90)
		label.ZIndex = (parent:IsA("GuiObject") and parent.ZIndex or 1) + 2
		label.Parent = parent
	end

	label.Font = getGameFont()
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeColor3 = Color3.fromRGB(24, 24, 30)
	label.TextStrokeTransparency = 0.2
	label.TextWrapped = true
	applyResponsiveTextConstraint(label, TEXT_SIZE_RULES[name] or { Min = 18, Desktop = 42, Mobile = 28, SmallMobile = 22 })

	return label
end

local function setupEmptyStateLabels()
	ui.ItemsEmptyLabel = createEmptyStateLabel(ui.ItemsScroll or ui.InventoryContent, "ItemsEmptyLabel", "Инвентарь пуст")
	ui.PassivesComingSoonLabel = createEmptyStateLabel(ui.PassivesScroll or ui.InventoryContent, "PassivesComingSoonLabel", "Пассивы скоро будут")

	if ui.ItemsEmptyLabel then
		ui.ItemsEmptyLabel.Visible = false
	end

	if ui.PassivesComingSoonLabel then
		ui.PassivesComingSoonLabel.Visible = false
	end
end

local function countVisibleInventoryItems()
	local count = 0

	for _, itemId in ipairs(INVENTORY_ITEMS) do
		if getItemCount(itemId) > 0 then
			count += 1
		end
	end

	return count
end

local function updateEmptyStateLabels(visibleItemCount)
	local hasItems = (visibleItemCount or countVisibleInventoryItems()) > 0

	if ui.ItemsEmptyLabel then
		ui.ItemsEmptyLabel.Visible = currentTab == "Items" and not hasItems
	end

	if ui.PassivesComingSoonLabel then
		ui.PassivesComingSoonLabel.Visible = currentTab == "Passives"
	end
end

local function setSlotSelected(slot, selected)
	local hovered = slot and slotHoverStates[slot]
	local color = selected and SELECTED_STROKE or (hovered and HOVER_STROKE or FALLBACK_STROKE)
	local thickness = selected and 3 or (hovered and 2 or 1)
	local transparency = selected and 0 or (hovered and 0.08 or 0.8)
	local stroke = ensureStroke(slot, "SelectedStroke", color, thickness, transparency)

	if stroke then
		stroke.Enabled = true
	end
end

local closeItemInfo

local function updateSlot(itemId, visibleIndex)
	local slot = ui.ItemsScroll and ui.ItemsScroll:FindFirstChild(`Item_{itemId}`)
	local definition = ItemConfig[itemId]

	if not slot or not definition then
		return visibleIndex
	end

	local count = getItemCount(itemId)

	if count <= 0 then
		slot.Visible = false
		slotHoverStates[slot] = nil
		if selectedItemId == itemId then
			closeItemInfo()
		end
		return visibleIndex
	end

	local slotBackground = slot:FindFirstChild("SlotBackground")
	local itemIcon = slot:FindFirstChild("ItemIcon")
	local itemName = slot:FindFirstChild("ItemName")
	local itemCount = slot:FindFirstChild("ItemCount")

	slot.Visible = true
	slot.LayoutOrder = visibleIndex
	setImageOrFallback(slotBackground, getSlotBackground(itemId), Color3.fromRGB(28, 36, 48))
	setImageOrFallback(itemIcon, getItemIcon(itemId, false), Color3.fromRGB(40, 48, 56))
	setIconFallbackLetter(itemIcon, itemId)
	setText(itemName, definition.DisplayName)
	setText(itemCount, `x{count}`)
	slot.ImageTransparency = 1
	slot.BackgroundTransparency = 1
	setSlotSelected(slot, selectedItemId == itemId)

	return visibleIndex + 1
end

local function updateAllSlots()
	local visibleIndex = 1
	local orderedItemIds = getOrderedVisibleItemIds()
	local visibleSet = {}

	for _, itemId in ipairs(orderedItemIds) do
		visibleSet[itemId] = true
		visibleIndex = updateSlot(itemId, visibleIndex)
	end

	for _, itemId in ipairs(INVENTORY_ITEMS) do
		if not visibleSet[itemId] then
			local slot = ui.ItemsScroll and ui.ItemsScroll:FindFirstChild(`Item_{itemId}`)
			if slot then
				slot.Visible = false
				slotHoverStates[slot] = nil
			end
		end
	end

	local visibleItemCount = visibleIndex - 1
	updateEmptyStateLabels(visibleItemCount)

	return visibleItemCount
end

closeItemInfo = function()
	selectedItemId = nil

	if selectedSlot then
		setSlotSelected(selectedSlot, false)
		selectedSlot = nil
	end

	if ui.ItemInfoPanel then
		TweenService:Create(ui.ItemInfoPanel, TWEEN_PANEL_CLOSE, {
			Position = getInfoHiddenPosition(),
		}):Play()
		tweenInventoryContent(false)
		task.delay(0.17, function()
			if not selectedItemId and ui.ItemInfoPanel then
				ui.ItemInfoPanel.Visible = false
			end
		end)
	end
end

local function refreshItemInfo()
	if not selectedItemId or not ui.ItemInfoPanel then
		return
	end

	local definition = ItemConfig[selectedItemId]

	if not definition then
		return
	end

	setImageOrFallback(ui.InfoBackground, getInfoBackground(selectedItemId), Color3.fromRGB(24, 32, 42))
	setImageOrFallback(ui.InfoIcon, getItemIcon(selectedItemId, false), Color3.fromRGB(40, 48, 56))
	setIconFallbackLetter(ui.InfoIcon, selectedItemId)
	setText(ui.InfoName, definition.DisplayName)
	setText(ui.InfoCount, `Count: {getItemCount(selectedItemId)}`)
	setText(ui.InfoBoost, definition.BoostText)
	setText(ui.InfoDescription, definition.Description)
	setImageOrFallback(ui.ActivateButton, getActivateButtonBackground(selectedItemId), Color3.fromRGB(55, 110, 55))
	setImageOrFallback(ui.DeleteButton, getDeleteButtonBackground(selectedItemId), Color3.fromRGB(120, 50, 45))

	for _, button in ipairs({ ui.ActivateButton, ui.DeleteButton }) do
		local buttonText = button and button:FindFirstChild("ButtonText")
		if buttonText and (buttonText:IsA("TextLabel") or buttonText:IsA("TextButton")) then
			buttonText.Visible = false
		end
	end

	if ui.ActivateButton then
		ui.ActivateButton.AutoButtonColor = getItemCount(selectedItemId) > 0
		ui.ActivateButton.ImageTransparency = getItemCount(selectedItemId) > 0 and 0 or 0.45
	end
end

local function openItemInfo(itemId)
	local definition = ItemConfig[itemId]

	if not definition then
		return
	end

	if selectedSlot then
		setSlotSelected(selectedSlot, false)
	end

	selectedItemId = itemId
	selectedSlot = ui.ItemsScroll and ui.ItemsScroll:FindFirstChild(`Item_{itemId}`)

	if selectedSlot then
		setSlotSelected(selectedSlot, true)
	end

	if ui.ItemInfoPanel then
		ui.ItemInfoPanel.Visible = true
		ui.ItemInfoPanel.Position = getInfoHiddenPosition()
		refreshItemInfo()
		tweenInventoryContent(true)
		TweenService:Create(ui.ItemInfoPanel, TWEEN_PANEL_OPEN, {
			Position = baseLayout.InfoOpenPosition or ui.ItemInfoPanel.Position,
		}):Play()
	end

	updateAllSlots()
end

local function formatTooltipRemaining(seconds)
	seconds = math.max(0, math.floor(seconds or 0))

	if seconds >= 60 then
		local minutes = math.floor(seconds / 60)
		local remainder = seconds % 60

		if remainder > 0 then
			return `{minutes}m {remainder}s`
		end

		return `{minutes}m`
	end

	return `{seconds}s`
end

local function getScreenPosition(position)
	if typeof(position) == "Vector2" then
		return position
	elseif typeof(position) == "UDim2" then
		return Vector2.new(position.X.Offset, position.Y.Offset)
	end

	return UserInputService:GetMouseLocation()
end

local function setTooltipZIndex(root, zIndex)
	if not root then
		return
	end

	if root:IsA("GuiObject") then
		root.ZIndex = zIndex
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = math.max(descendant.ZIndex, zIndex + 1)
		end
	end
end

local function getClampedTooltipPosition(position)
	if not ui.ItemTooltip then
		return UDim2.fromOffset(0, 0)
	end

	local viewport = ResponsiveUI.GetViewportSize()
	local screenPosition = getScreenPosition(position)
	local width = ui.ItemTooltip.AbsoluteSize.X * (ui.TooltipScale and ui.TooltipScale.Scale or 1)
	local height = ui.ItemTooltip.AbsoluteSize.Y * (ui.TooltipScale and ui.TooltipScale.Scale or 1)
	local padding = 12
	local x = screenPosition.X + 18
	local y = screenPosition.Y + 18

	if x + width + padding > viewport.X then
		x = screenPosition.X - width - 18
	end

	if y + height + padding > viewport.Y then
		y = screenPosition.Y - height - 18
	end

	x = math.clamp(x, padding, math.max(padding, viewport.X - width - padding))
	y = math.clamp(y, padding, math.max(padding, viewport.Y - height - padding))

	return UDim2.fromOffset(x, y)
end

local function showTooltip(itemId, position)
	if not ui.ItemTooltip or not ItemConfig[itemId] then
		return
	end

	local definition = ItemConfig[itemId]
	if ui.ItemTooltip.Parent ~= gui then
		ui.ItemTooltip.Parent = gui
	end
	setTooltipZIndex(ui.ItemTooltip, 1000)
	setImageOrFallback(ui.TooltipBackground, getTooltipBackground(itemId), Color3.fromRGB(24, 32, 42))
	setText(ui.TooltipName, definition.DisplayName)
	setText(ui.TooltipBoost, `{definition.BoostText} / {definition.Duration}s`)
	ui.ItemTooltip.Position = getClampedTooltipPosition(position or UDim2.fromOffset(0, 0))
	ui.ItemTooltip.Visible = true
end

local function showBuffTooltip(buff, position)
	if not ui.ItemTooltip or type(buff) ~= "table" or not ItemConfig[buff.ItemId] then
		return
	end

	local definition = ItemConfig[buff.ItemId]
	if ui.ItemTooltip.Parent ~= gui then
		ui.ItemTooltip.Parent = gui
	end
	setTooltipZIndex(ui.ItemTooltip, 1000)
	local remaining = (buff.EndTime or os.time()) - os.time()
	setImageOrFallback(ui.TooltipBackground, getBuffTooltipBackground(buff.ItemId), Color3.fromRGB(24, 32, 42))
	setText(ui.TooltipName, definition.DisplayName)
	setText(ui.TooltipBoost, `{definition.BoostText}\nОсталось: {formatTooltipRemaining(remaining)}`)
	ui.ItemTooltip.Position = getClampedTooltipPosition(position or UDim2.fromOffset(0, 0))
	ui.ItemTooltip.Visible = true
end

local function hideTooltip()
	if ui.ItemTooltip then
		ui.ItemTooltip.Visible = false
	end
end

local function showTab(tabName)
	currentTab = tabName

	local function applyTab()
		if ui.ItemsScroll then
			ui.ItemsScroll.Visible = tabName == "Items"
		end

		if ui.PassivesScroll then
			ui.PassivesScroll.Visible = tabName == "Passives"
		end

		setSlotSelected(ui.ItemsTabButton, tabName == "Items")
		setSlotSelected(ui.PassivesTabButton, tabName == "Passives")
		updateEmptyStateLabels()
	end

	if tabName ~= "Items" and ui.ItemInfoPanel and ui.ItemInfoPanel.Visible then
		closeItemInfo()
		task.delay(0.2, applyTab)
	else
		applyTab()
	end
end

local function openInventory()
	if not ui.InventoryMain then
		return
	end

	ui.InventoryMain.Visible = true
	showTab(currentTab)

	if ui.InventoryScale then
		local targetScale = getCurrentResponsiveScales().InventoryScale
		ui.InventoryScale.Scale = targetScale * 0.92
		TweenService:Create(ui.InventoryScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = targetScale,
		}):Play()
	end
end

local function closeInventory()
	if not ui.InventoryMain then
		return
	end

	closeItemInfo()

	if ui.InventoryScale then
		local targetScale = getCurrentResponsiveScales().InventoryScale
		TweenService:Create(ui.InventoryScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = targetScale * 0.92,
		}):Play()
		task.delay(0.13, function()
			if ui.InventoryMain then
				ui.InventoryMain.Visible = false
				ui.InventoryScale.Scale = targetScale
			end
		end)
	else
		ui.InventoryMain.Visible = false
	end
end

local function toggleInventory()
	if ui.InventoryMain and ui.InventoryMain.Visible then
		closeInventory()
	else
		openInventory()
	end
end

local function activateSelectedItem()
	if selectedItemId then
		inventoryActionRemote:FireServer({
			Action = "ActivateItem",
			ItemId = selectedItemId,
		})
	end
end

local function deleteSelectedItem()
	if selectedItemId then
		inventoryActionRemote:FireServer({
			Action = "DeleteItem",
			ItemId = selectedItemId,
			Amount = 1,
		})
	end
end

local function clearBuffRows()
	for uid, row in pairs(buffRows) do
		if row and row.Parent then
			row:Destroy()
		end

		buffRows[uid] = nil
	end
end

local function formatRemaining(seconds)
	seconds = math.max(0, math.floor(seconds))

	if seconds >= 60 then
		return `{math.floor(seconds / 60)}m`
	end

	return `{seconds}s`
end

local function updateBuffTimeLabels()
	local now = os.time()

	for uid, row in pairs(buffRows) do
		local endTime = row:GetAttribute("EndTime") or now
		local remaining = endTime - now
		local timeLabel = row:FindFirstChild("BuffTime", true)

		if remaining <= 0 then
			row.Visible = false
		elseif timeLabel and timeLabel:IsA("TextLabel") then
			timeLabel.Text = formatRemaining(remaining)
		end
	end
end

local function updateActiveBuffs(data)
	if not ui.BuffsScroll or not ui.BuffTemplate then
		return
	end

	clearBuffRows()

	for _, buff in ipairs(data.ActiveBuffs or {}) do
		local definition = ItemConfig[buff.ItemId]

		if definition then
			local row = ui.BuffTemplate:Clone()
			row.Name = `Buff_{buff.Uid}`
			row:SetAttribute("EndTime", buff.EndTime)
			row.Active = true
			row.Visible = true
			row.Parent = ui.BuffsScroll

			local background = row:FindFirstChild("BuffSlotBackground")
			local icon = row:FindFirstChild("BuffIcon")
			local timeLabel = row:FindFirstChild("BuffTime")

			setImageOrFallback(background, getMainAssets().BuffSlotBackground, Color3.fromRGB(28, 36, 48))
			setImageOrFallback(icon, getItemIcon(buff.ItemId, true), Color3.fromRGB(40, 48, 56))
			setIconFallbackLetter(icon, buff.ItemId, true)

			if icon and icon:IsA("GuiObject") then
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.BackgroundTransparency = 1
				icon.Position = UDim2.fromScale(0.5, 0.5)
				icon.Size = UDim2.fromScale(1, 1)
				if icon:IsA("ImageLabel") or icon:IsA("ImageButton") then
					icon.ScaleType = Enum.ScaleType.Stretch
				end
			end

			for _, textName in ipairs({ "BuffMultiplier", "BuffName", "BuffBoostText" }) do
				local extraText = row:FindFirstChild(textName, true)
				if extraText and (extraText:IsA("TextLabel") or extraText:IsA("TextButton")) then
					extraText.Visible = false
				end
			end

			if timeLabel and timeLabel:IsA("TextLabel") then
				timeLabel.AnchorPoint = Vector2.new(0.5, 1)
				timeLabel.BackgroundTransparency = 1
				if getUIProfileName() == "Desktop" then
					timeLabel.Position = UDim2.new(0.5, 0, 1, 4)
				else
					timeLabel.Position = UDim2.new(0.5, 0, 1, -2)
				end
				timeLabel.Size = UDim2.new(1, 0, 0, 22)
				timeLabel.Text = formatRemaining(buff.Remaining or ((buff.EndTime or os.time()) - os.time()))
				timeLabel.TextStrokeTransparency = 0.15
				timeLabel.ZIndex = row.ZIndex + 4
				applyResponsiveTextConstraint(timeLabel, TEXT_SIZE_RULES.BuffTime)
			end

			row.MouseEnter:Connect(function()
				local mousePosition = UserInputService:GetMouseLocation()
				showBuffTooltip(buff, UDim2.fromOffset(mousePosition.X + 14, mousePosition.Y + 12))
			end)
			row.MouseLeave:Connect(hideTooltip)
			row.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					showBuffTooltip(buff, UDim2.fromOffset(input.Position.X + 12, input.Position.Y + 12))
				end
			end)
			row.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					hideTooltip()
				end
			end)

			buffRows[buff.Uid] = row
		end
	end
end

local function updateInventory(data)
	if type(data) ~= "table" then
		return
	end

	latestInventoryData = data
	latestInventoryData.Items = latestInventoryData.Items or {}
	latestInventoryData.ItemOrder = latestInventoryData.ItemOrder or {}
	latestInventoryData.ActiveBuffs = latestInventoryData.ActiveBuffs or {}
	updateAllSlots()
	refreshItemInfo()
	updateActiveBuffs(latestInventoryData)
end

local function hookItemSlots()
	if not ui.ItemsScroll then
		return
	end

	for _, itemId in ipairs(INVENTORY_ITEMS) do
		local slot = ui.ItemsScroll:FindFirstChild(`Item_{itemId}`)

		if slot and slot:IsA("GuiButton") then
			ensureScale(slot)
			slot.MouseButton1Click:Connect(function()
				if getItemCount(itemId) > 0 then
					openItemInfo(itemId)
				end
			end)

			slot.MouseEnter:Connect(function()
				if getItemCount(itemId) <= 0 then
					return
				end
				slotHoverStates[slot] = true
				setSlotSelected(slot, selectedItemId == itemId)
				tweenScale(slot, 1.06)
				local mousePosition = UserInputService:GetMouseLocation()
				showTooltip(itemId, UDim2.fromOffset(mousePosition.X + 16, mousePosition.Y + 12))
			end)

			slot.MouseLeave:Connect(function()
				slotHoverStates[slot] = false
				setSlotSelected(slot, selectedItemId == itemId)
				tweenScale(slot, 1)
				hideTooltip()
			end)
			slot.MouseButton1Down:Connect(function(x, y)
				if getItemCount(itemId) <= 0 then
					return
				end
				tweenScale(slot, 0.96)
				local stroke = ensureStroke(slot, "SelectedStroke", PRESS_STROKE, 3, 0.02)
				if stroke then
					stroke.Enabled = true
				end
				if ResponsiveUI.IsMobileLike() then
					showTooltip(itemId, UDim2.fromOffset(x + 12, y + 12))
				end
			end)
			slot.MouseButton1Up:Connect(function()
				tweenScale(slot, slotHoverStates[slot] and 1.06 or 1)
				setSlotSelected(slot, selectedItemId == itemId)
				if ResponsiveUI.IsMobileLike() then
					hideTooltip()
				end
			end)
		else
			warnMissing(`ItemsScroll.Item_{itemId}`)
		end
	end
end

local function hookButtonEffects(button, hoverScale, pressScale)
	if not button or not button:IsA("GuiButton") then
		return
	end

	ensureScale(button)
	button.MouseEnter:Connect(function()
		tweenScale(button, hoverScale or 1.05)
		local stroke = ensureStroke(button, "HoverStroke", HOVER_STROKE, 2, 0.12)
		if stroke then
			stroke.Enabled = true
		end
	end)
	button.MouseLeave:Connect(function()
		tweenScale(button, 1)
		local stroke = button:FindFirstChild("HoverStroke")
		if stroke then
			stroke.Enabled = false
		end
	end)
	button.MouseButton1Down:Connect(function()
		tweenScale(button, pressScale or 0.96)
	end)
	button.MouseButton1Up:Connect(function()
		tweenScale(button, hoverScale or 1.05)
	end)
end

local function hookButtons()
	hookButtonEffects(ui.ToggleButton, 1.06, 0.94)
	hookButtonEffects(ui.CloseInventoryButton, 1.06, 0.94)
	hookButtonEffects(ui.ItemsTabButton, 1.04, 0.96)
	hookButtonEffects(ui.PassivesTabButton, 1.04, 0.96)
	hookButtonEffects(ui.PackTraderTabButton, 1.04, 0.96)
	hookButtonEffects(ui.CloseInfoButton, 1.06, 0.94)
	hookButtonEffects(ui.ActivateButton, 1.05, 0.95)
	hookButtonEffects(ui.DeleteButton, 1.05, 0.95)

	if ui.ToggleButton and ui.ToggleButton:IsA("GuiButton") then
		ui.ToggleButton.MouseButton1Click:Connect(toggleInventory)
	end

	if ui.CloseInventoryButton and ui.CloseInventoryButton:IsA("GuiButton") then
		ui.CloseInventoryButton.MouseButton1Click:Connect(closeInventory)
	end

	if ui.ItemsTabButton and ui.ItemsTabButton:IsA("GuiButton") then
		ui.ItemsTabButton.MouseButton1Click:Connect(function()
			showTab("Items")
		end)
	end

	if ui.PassivesTabButton and ui.PassivesTabButton:IsA("GuiButton") then
		ui.PassivesTabButton.MouseButton1Click:Connect(function()
			showTab("Passives")
		end)
	end

	if ui.PackTraderTabButton and ui.PackTraderTabButton:IsA("GuiButton") then
		ui.PackTraderTabButton.MouseButton1Click:Connect(function()
			showTab("PackTrader")
		end)
	end

	if ui.CloseInfoButton and ui.CloseInfoButton:IsA("GuiButton") then
		ui.CloseInfoButton.MouseButton1Click:Connect(closeItemInfo)
	end

	if ui.ActivateButton and ui.ActivateButton:IsA("GuiButton") then
		ui.ActivateButton.MouseButton1Click:Connect(activateSelectedItem)
	end

	if ui.DeleteButton and ui.DeleteButton:IsA("GuiButton") then
		ui.DeleteButton.MouseButton1Click:Connect(deleteSelectedItem)
	end
end

local function setupPassivesPlaceholder()
	setupEmptyStateLabels()
	updateEmptyStateLabels()
end

cacheGui()
task.wait()
captureBaseLayout()
applyInventoryTextStyles(gui)
applyInventoryAssets()
ensureCloseInfoButtonVisible()
applyResponsiveMode()
task.defer(applyResponsiveMode)
task.delay(0.25, applyResponsiveMode)
task.delay(1, applyResponsiveMode)
hookButtons()
hookItemSlots()
setupPassivesPlaceholder()
showTab("Items")
updateAllSlots()
updateActiveBuffs(latestInventoryData)

local camera = Workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		task.defer(applyResponsiveMode)
	end)
end

syncInventoryRemote.OnClientEvent:Connect(updateInventory)
inventoryActionRemote:FireServer({
	Action = "RequestSync",
})

task.spawn(function()
	while true do
		updateBuffTimeLabels()
		task.wait(1)
	end
end)

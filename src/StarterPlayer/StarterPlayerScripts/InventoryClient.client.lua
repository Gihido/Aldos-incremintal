local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
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

local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("InventoryGui", 10)

if not gui then
	warn("[InventoryClient] PlayerGui.InventoryGui was not found. Run InventoryGuiBuilder in Studio first.")
	return
end

local latestInventoryData = {
	Items = {},
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
	InventoryTitle = { 22, 48 },
	ItemName = { 14, 30 },
	ItemCount = { 14, 30 },
	InfoName = { 22, 44 },
	InfoCount = { 16, 34 },
	InfoBoost = { 16, 34 },
	InfoDescription = { 14, 30 },
	ButtonText = { 16, 34 },
	TooltipName = { 18, 36 },
	TooltipBoost = { 15, 30 },
	BuffTime = { 14, 28 },
}

local function applyInventoryTextStyles(root)
	if not root then
		return
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		local rule = TEXT_SIZE_RULES[descendant.Name]

		if rule then
			applyTextConstraint(descendant, rule[1], rule[2])
		elseif ui.ActiveBuffsPanel and descendant:IsDescendantOf(ui.ActiveBuffsPanel) and (descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox")) then
			applyTextConstraint(descendant, 14, 28)
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

local function getItemCount(itemId)
	return (latestInventoryData.Items and latestInventoryData.Items[itemId]) or 0
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
	return itemAssets.TooltipBackground or getMainAssets().TooltipBackground
end

local function getInfoBackground(itemId)
	local itemAssets = getItemAssets(itemId)
	return itemAssets.InfoBackground or getMainAssets().ItemInfoBackground
end

local function setIconFallbackLetter(icon, itemId)
	if not icon then
		return
	end

	local letter = icon:FindFirstChild("FallbackLetter")
	local hasIcon = hasCustomAssetId(getItemIcon(itemId, false))

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

	ui.ButtonScale = findChild(ui.ToggleButton, "ButtonScale")
	ui.InventoryScale = findChild(ui.InventoryMain, "InventoryScale")
	ui.InventoryBackground = findChild(ui.InventoryMain, "InventoryBackground")
	ui.CloseInventoryButton = findChild(ui.InventoryMain, "CloseInventoryButton")
	ui.InventoryTitle = findChild(ui.InventoryMain, "InventoryTitle")
	ui.InventoryContent = findChild(ui.InventoryMain, "InventoryContent")
	ui.ItemsTabButton = getNested(ui.InventoryMain, { "CategoryPanel", "ItemsTabButton" })
	ui.PassivesTabButton = getNested(ui.InventoryMain, { "CategoryPanel", "PassivesTabButton" })
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
	ui.TooltipScale = findChild(ui.ItemTooltip, "TooltipScale")
	ui.TooltipBackground = findChild(ui.ItemTooltip, "TooltipBackground")
	ui.TooltipName = findChild(ui.ItemTooltip, "TooltipName")
	ui.TooltipBoost = findChild(ui.ItemTooltip, "TooltipBoost")
	ui.BuffsScale = findChild(ui.ActiveBuffsPanel, "BuffsScale")
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

local function updateResponsiveScale()
	local isMobile = ResponsiveUI.IsMobileLike()

	if ui.InventoryScale then
		ui.InventoryScale.Scale = isMobile and 0.74 or 1
	end

	if ui.TooltipScale then
		ui.TooltipScale.Scale = isMobile and 0.8 or 1
	end

	if ui.BuffsScale then
		ui.BuffsScale.Scale = isMobile and 0.78 or 1
	end

	if ui.ButtonScale then
		ui.ButtonScale.Scale = isMobile and 0.85 or 1
	end
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
	if not ui.InventoryContent then
		return nil, nil
	end

	local defaultPosition = baseLayout.ContentDefaultPosition or ui.InventoryContent.Position
	local defaultSize = baseLayout.ContentDefaultSize or ui.InventoryContent.Size
	local panelWidth = ui.ItemInfoPanel and ui.ItemInfoPanel.AbsoluteSize.X or 0
	local gap = 20
	local compression = panelWidth + gap
	local minWidth = 280
	local currentWidth = ui.InventoryContent.AbsoluteSize.X
	if baseLayout.ContentDefaultSize then
		currentWidth += (baseLayout.ContentDefaultSize.X.Offset - ui.InventoryContent.Size.X.Offset)
	end
	local allowedCompression = math.max(0, math.min(compression, math.max(0, currentWidth - minWidth)))
	local shift = math.min(20, allowedCompression * 0.25)

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

	if compressed then
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

	for _, itemId in ipairs(INVENTORY_ITEMS) do
		visibleIndex = updateSlot(itemId, visibleIndex)
	end
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

local function showTooltip(itemId, position)
	if not ui.ItemTooltip or not ItemConfig[itemId] then
		return
	end

	local definition = ItemConfig[itemId]
	setImageOrFallback(ui.TooltipBackground, getTooltipBackground(itemId), Color3.fromRGB(24, 32, 42))
	setText(ui.TooltipName, definition.DisplayName)
	setText(ui.TooltipBoost, `{definition.BoostText} / {definition.Duration}s`)
	ui.ItemTooltip.Position = position or UDim2.fromOffset(0, 0)
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
	end

	if tabName == "Passives" and ui.ItemInfoPanel and ui.ItemInfoPanel.Visible then
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
		local targetScale = ResponsiveUI.IsMobileLike() and 0.74 or 1
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
		local targetScale = ResponsiveUI.IsMobileLike() and 0.74 or 1
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
			row.Visible = true
			row.Parent = ui.BuffsScroll

			local background = row:FindFirstChild("BuffSlotBackground")
			local icon = row:FindFirstChild("BuffIcon")
			local timeLabel = row:FindFirstChild("BuffTime")

			setImageOrFallback(background, getMainAssets().BuffSlotBackground, Color3.fromRGB(28, 36, 48))
			setImageOrFallback(icon, getItemIcon(buff.ItemId, true), Color3.fromRGB(40, 48, 56))
			setIconFallbackLetter(icon, buff.ItemId)

			if timeLabel and timeLabel:IsA("TextLabel") then
				timeLabel.Text = formatRemaining(buff.Remaining or ((buff.EndTime or os.time()) - os.time()))
				applyTextConstraint(timeLabel, 14, 28)
			end

			local multiplierLabel = row:FindFirstChild("BuffMultiplier")
			if not multiplierLabel then
				multiplierLabel = Instance.new("TextLabel")
				multiplierLabel.Name = "BuffMultiplier"
				multiplierLabel.BackgroundTransparency = 1
				multiplierLabel.Position = UDim2.new(0, 0, 0, 0)
				multiplierLabel.Size = UDim2.new(1, 0, 0, 20)
				multiplierLabel.ZIndex = row.ZIndex + 2
				multiplierLabel.Parent = row
			end

			multiplierLabel.Text = `x{string.format("%.2f", buff.CoinMultiplier or definition.CoinMultiplier or 1)}`
			multiplierLabel.TextColor3 = Color3.fromRGB(255, 245, 170)
			applyTextConstraint(multiplierLabel, 12, 24)

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
	if not ui.PassivesScroll then
		return
	end

	local placeholder = ui.PassivesScroll:FindFirstChild("PassivesSoon")

	if not placeholder then
		placeholder = Instance.new("TextLabel")
		placeholder.Name = "PassivesSoon"
		placeholder.BackgroundTransparency = 1
		placeholder.Font = Enum.Font.Arcade
		placeholder.Position = UDim2.fromOffset(30, 30)
		placeholder.Size = UDim2.fromOffset(360, 60)
		placeholder.Text = "Пассивы скоро"
		placeholder.TextColor3 = Color3.fromRGB(255, 255, 255)
		placeholder.TextScaled = true
		placeholder.TextStrokeTransparency = 0.25
		placeholder.ZIndex = 8
		placeholder.Parent = ui.PassivesScroll
	end
end

cacheGui()
task.wait()
captureBaseLayout()
applyInventoryTextStyles(gui)
applyInventoryAssets()
updateResponsiveScale()
hookButtons()
hookItemSlots()
setupPassivesPlaceholder()
showTab("Items")
updateAllSlots()
updateActiveBuffs(latestInventoryData)

local camera = Workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
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

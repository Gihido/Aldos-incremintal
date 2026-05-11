-- One-time Roblox Studio Command Bar builder for StarterGui.InventoryGui.
-- Paste this whole file into View -> Command Bar and run once.

local ASSETS = {
	InventoryToggleButton = "rbxassetid://0",
	InventoryBackground = "rbxassetid://0",
	CloseButton = "rbxassetid://0",

	ItemsTabButton = "rbxassetid://0",
	PassivesTabButton = "rbxassetid://0",

	ItemSlotBackground = "rbxassetid://0",
	CarrotIcon = "rbxassetid://0",
	CucumberIcon = "rbxassetid://0",
	TomatoIcon = "rbxassetid://0",
	CornIcon = "rbxassetid://0",

	ItemInfoBackground = "rbxassetid://0",
	ActivateButtonBackground = "rbxassetid://0",
	DeleteButtonBackground = "rbxassetid://0",

	TooltipBackground = "rbxassetid://0",

	ActiveBuffsBackground = "rbxassetid://0",
	BuffSlotBackground = "rbxassetid://0",
}

local StarterGui = game:GetService("StarterGui")

local old = StarterGui:FindFirstChild("InventoryGui")
if old then
	old:Destroy()
end

local function setTextStyle(textObject, text, zIndex)
	textObject.BackgroundTransparency = 1
	textObject.Font = Enum.Font.Arcade
	textObject.Text = text or ""
	textObject.TextColor3 = Color3.fromRGB(255, 255, 255)
	textObject.TextScaled = true
	textObject.TextStrokeColor3 = Color3.fromRGB(30, 20, 20)
	textObject.TextStrokeTransparency = 0.25
	textObject.TextWrapped = false
	textObject.ZIndex = zIndex or textObject.ZIndex
end

local function makeImageLabel(parent, name, image, zIndex)
	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = name
	imageLabel.BackgroundTransparency = 1
	imageLabel.BorderSizePixel = 0
	imageLabel.Image = image or ""
	imageLabel.ScaleType = Enum.ScaleType.Stretch
	imageLabel.ZIndex = zIndex or 1
	imageLabel.Parent = parent

	return imageLabel
end

local function makeImageButton(parent, name, image, zIndex)
	local imageButton = Instance.new("ImageButton")
	imageButton.Name = name
	imageButton.AutoButtonColor = true
	imageButton.BackgroundTransparency = 1
	imageButton.BorderSizePixel = 0
	imageButton.Image = image or ""
	imageButton.ScaleType = Enum.ScaleType.Stretch
	imageButton.ZIndex = zIndex or 1
	imageButton.Parent = parent

	return imageButton
end

local function makeTextLabel(parent, name, text, position, size, zIndex)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.Parent = parent
	setTextStyle(label, text, zIndex)

	return label
end

local function makeScale(parent, name, scaleValue)
	local scale = Instance.new("UIScale")
	scale.Name = name
	scale.Scale = scaleValue or 1
	scale.Parent = parent

	return scale
end

local gui = Instance.new("ScreenGui")
gui.Name = "InventoryGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = true
gui.Parent = StarterGui

local inventoryToggleButton = makeImageButton(gui, "InventoryToggleButton", ASSETS.InventoryToggleButton, 20)
inventoryToggleButton.AnchorPoint = Vector2.new(0.5, 1)
inventoryToggleButton.Position = UDim2.fromScale(0.5, 0.97)
inventoryToggleButton.Size = UDim2.fromOffset(76, 76)
inventoryToggleButton.ScaleType = Enum.ScaleType.Fit
makeScale(inventoryToggleButton, "ButtonScale", 1)

local inventoryMain = Instance.new("Frame")
inventoryMain.Name = "InventoryMain"
inventoryMain.Visible = false
inventoryMain.AnchorPoint = Vector2.new(0.5, 0.5)
inventoryMain.Position = UDim2.fromScale(0.5, 0.5)
inventoryMain.Size = UDim2.fromOffset(980, 600)
inventoryMain.BackgroundTransparency = 1
inventoryMain.BorderSizePixel = 0
inventoryMain.ClipsDescendants = true
inventoryMain.ZIndex = 1
inventoryMain.Parent = gui

makeScale(inventoryMain, "InventoryScale", 1)

local inventoryBackground = makeImageLabel(inventoryMain, "InventoryBackground", ASSETS.InventoryBackground, 1)
inventoryBackground.Size = UDim2.fromScale(1, 1)
inventoryBackground.ScaleType = Enum.ScaleType.Stretch

makeTextLabel(inventoryMain, "InventoryTitle", "Inventory", UDim2.fromOffset(200, 28), UDim2.fromOffset(500, 48), 10)

local closeInventoryButton = makeImageButton(inventoryMain, "CloseInventoryButton", ASSETS.CloseButton, 20)
closeInventoryButton.AnchorPoint = Vector2.new(1, 0)
closeInventoryButton.Position = UDim2.new(1, -20, 0, 20)
closeInventoryButton.Size = UDim2.fromOffset(48, 48)
closeInventoryButton.ScaleType = Enum.ScaleType.Fit

local categoryPanel = Instance.new("Frame")
categoryPanel.Name = "CategoryPanel"
categoryPanel.Position = UDim2.fromOffset(28, 90)
categoryPanel.Size = UDim2.new(0, 150, 1, -130)
categoryPanel.BackgroundTransparency = 1
categoryPanel.BorderSizePixel = 0
categoryPanel.ZIndex = 5
categoryPanel.Parent = inventoryMain

local itemsTabButton = makeImageButton(categoryPanel, "ItemsTabButton", ASSETS.ItemsTabButton, 6)
itemsTabButton.Position = UDim2.fromOffset(10, 10)
itemsTabButton.Size = UDim2.fromOffset(120, 90)
itemsTabButton.ScaleType = Enum.ScaleType.Stretch

local passivesTabButton = makeImageButton(categoryPanel, "PassivesTabButton", ASSETS.PassivesTabButton, 6)
passivesTabButton.Position = UDim2.fromOffset(10, 115)
passivesTabButton.Size = UDim2.fromOffset(120, 90)
passivesTabButton.ScaleType = Enum.ScaleType.Stretch

local inventoryContent = Instance.new("Frame")
inventoryContent.Name = "InventoryContent"
inventoryContent.Position = UDim2.fromOffset(200, 90)
inventoryContent.Size = UDim2.fromOffset(730, 460)
inventoryContent.BackgroundTransparency = 1
inventoryContent.BorderSizePixel = 0
inventoryContent.ZIndex = 5
inventoryContent.Parent = inventoryMain

local function makeInventoryScroll(parent, name, visible)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = name
	scroll.Visible = visible
	scroll.Position = UDim2.fromOffset(0, 0)
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 10
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.ZIndex = 6
	scroll.Parent = parent

	local grid = Instance.new("UIGridLayout")
	grid.Name = "UIGridLayout"
	grid.CellSize = UDim2.fromOffset(120, 135)
	grid.CellPadding = UDim2.fromOffset(18, 18)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	local padding = Instance.new("UIPadding")
	padding.Name = "UIPadding"
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = scroll

	return scroll
end

local itemsScroll = makeInventoryScroll(inventoryContent, "ItemsScroll", true)
local passivesScroll = makeInventoryScroll(inventoryContent, "PassivesScroll", false)

local function makeItemSlot(parent, name, displayName, iconImage, layoutOrder)
	local slot = makeImageButton(parent, name, "", 7)
	slot.AutoButtonColor = false
	slot.LayoutOrder = layoutOrder

	local slotBackground = makeImageLabel(slot, "SlotBackground", ASSETS.ItemSlotBackground, 7)
	slotBackground.Size = UDim2.fromScale(1, 1)
	slotBackground.ScaleType = Enum.ScaleType.Stretch

	local itemIcon = makeImageLabel(slot, "ItemIcon", iconImage, 8)
	itemIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	itemIcon.Position = UDim2.fromScale(0.5, 0.42)
	itemIcon.Size = UDim2.fromOffset(76, 76)
	itemIcon.ScaleType = Enum.ScaleType.Fit

	makeTextLabel(slot, "ItemName", displayName, UDim2.new(0, 6, 1, -42), UDim2.new(1, -12, 0, 20), 8)

	local itemCount = makeTextLabel(slot, "ItemCount", "x0", UDim2.new(1, -6, 0, 6), UDim2.fromOffset(42, 24), 9)
	itemCount.AnchorPoint = Vector2.new(1, 0)

	return slot
end

makeItemSlot(itemsScroll, "Item_Carrot", "Carrot", ASSETS.CarrotIcon, 1)
makeItemSlot(itemsScroll, "Item_Cucumber", "Cucumber", ASSETS.CucumberIcon, 2)
makeItemSlot(itemsScroll, "Item_Tomato", "Tomato", ASSETS.TomatoIcon, 3)
makeItemSlot(itemsScroll, "Item_Corn", "Corn", ASSETS.CornIcon, 4)

local itemInfoPanel = Instance.new("Frame")
itemInfoPanel.Name = "ItemInfoPanel"
itemInfoPanel.Visible = false
itemInfoPanel.AnchorPoint = Vector2.new(1, 0)
itemInfoPanel.Position = UDim2.new(1, -24, 0, 90)
itemInfoPanel.Size = UDim2.fromOffset(285, 460)
itemInfoPanel.BackgroundTransparency = 1
itemInfoPanel.BorderSizePixel = 0
itemInfoPanel.ClipsDescendants = true
itemInfoPanel.ZIndex = 30
itemInfoPanel.Parent = inventoryMain

local infoBackground = makeImageLabel(itemInfoPanel, "InfoBackground", ASSETS.ItemInfoBackground, 30)
infoBackground.Size = UDim2.fromScale(1, 1)
infoBackground.ScaleType = Enum.ScaleType.Stretch

local closeInfoButton = makeImageButton(itemInfoPanel, "CloseInfoButton", ASSETS.CloseButton, 40)
closeInfoButton.AnchorPoint = Vector2.new(1, 0)
closeInfoButton.Position = UDim2.new(1, -12, 0, 12)
closeInfoButton.Size = UDim2.fromOffset(38, 38)
closeInfoButton.ScaleType = Enum.ScaleType.Fit

local infoIcon = makeImageLabel(itemInfoPanel, "InfoIcon", "", 35)
infoIcon.AnchorPoint = Vector2.new(0.5, 0)
infoIcon.Position = UDim2.new(0.5, 0, 0, 55)
infoIcon.Size = UDim2.fromOffset(110, 110)
infoIcon.ScaleType = Enum.ScaleType.Fit

makeTextLabel(itemInfoPanel, "InfoName", "Item Name", UDim2.fromOffset(20, 175), UDim2.new(1, -40, 0, 36), 35)
makeTextLabel(itemInfoPanel, "InfoCount", "x0", UDim2.fromOffset(20, 215), UDim2.new(1, -40, 0, 28), 35)
makeTextLabel(itemInfoPanel, "InfoBoost", "+0 Boost", UDim2.fromOffset(20, 250), UDim2.new(1, -40, 0, 32), 35)

local infoDescription = makeTextLabel(itemInfoPanel, "InfoDescription", "Item description", UDim2.fromOffset(20, 290), UDim2.new(1, -40, 0, 70), 35)
infoDescription.TextWrapped = true

local activateButton = makeImageButton(itemInfoPanel, "ActivateButton", ASSETS.ActivateButtonBackground, 35)
activateButton.Position = UDim2.new(0, 28, 1, -86)
activateButton.Size = UDim2.fromOffset(105, 56)
activateButton.ScaleType = Enum.ScaleType.Stretch
makeTextLabel(activateButton, "ButtonText", "Activate", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 36)

local deleteButton = makeImageButton(itemInfoPanel, "DeleteButton", ASSETS.DeleteButtonBackground, 35)
deleteButton.Position = UDim2.new(1, -133, 1, -86)
deleteButton.Size = UDim2.fromOffset(105, 56)
deleteButton.ScaleType = Enum.ScaleType.Stretch
makeTextLabel(deleteButton, "ButtonText", "Delete", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 36)

local itemTooltip = Instance.new("Frame")
itemTooltip.Name = "ItemTooltip"
itemTooltip.Visible = false
itemTooltip.Size = UDim2.fromOffset(210, 90)
itemTooltip.BackgroundTransparency = 1
itemTooltip.BorderSizePixel = 0
itemTooltip.ZIndex = 100
itemTooltip.Parent = gui

makeScale(itemTooltip, "TooltipScale", 1)

local tooltipBackground = makeImageLabel(itemTooltip, "TooltipBackground", ASSETS.TooltipBackground, 100)
tooltipBackground.Size = UDim2.fromScale(1, 1)
tooltipBackground.ScaleType = Enum.ScaleType.Stretch

makeTextLabel(itemTooltip, "TooltipName", "Item Name", UDim2.fromOffset(12, 10), UDim2.new(1, -24, 0, 28), 101)
makeTextLabel(itemTooltip, "TooltipBoost", "+0 Boost", UDim2.fromOffset(12, 45), UDim2.new(1, -24, 0, 30), 101)

local activeBuffsPanel = Instance.new("Frame")
activeBuffsPanel.Name = "ActiveBuffsPanel"
activeBuffsPanel.AnchorPoint = Vector2.new(0, 1)
activeBuffsPanel.Position = UDim2.fromScale(0.02, 0.95)
activeBuffsPanel.Size = UDim2.fromOffset(330, 86)
activeBuffsPanel.BackgroundTransparency = 1
activeBuffsPanel.BorderSizePixel = 0
activeBuffsPanel.ZIndex = 50
activeBuffsPanel.Parent = gui

makeScale(activeBuffsPanel, "BuffsScale", 1)

local buffsBackground = makeImageLabel(activeBuffsPanel, "BuffsBackground", ASSETS.ActiveBuffsBackground, 50)
buffsBackground.Size = UDim2.fromScale(1, 1)
buffsBackground.ScaleType = Enum.ScaleType.Stretch

local buffsScroll = Instance.new("ScrollingFrame")
buffsScroll.Name = "BuffsScroll"
buffsScroll.Position = UDim2.fromOffset(10, 8)
buffsScroll.Size = UDim2.new(1, -20, 1, -16)
buffsScroll.BackgroundTransparency = 1
buffsScroll.BorderSizePixel = 0
buffsScroll.ScrollingDirection = Enum.ScrollingDirection.X
buffsScroll.ScrollBarThickness = 4
buffsScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
buffsScroll.CanvasSize = UDim2.fromOffset(0, 0)
buffsScroll.ZIndex = 51
buffsScroll.Parent = activeBuffsPanel

local buffsLayout = Instance.new("UIListLayout")
buffsLayout.Name = "UIListLayout"
buffsLayout.FillDirection = Enum.FillDirection.Horizontal
buffsLayout.Padding = UDim.new(0, 8)
buffsLayout.SortOrder = Enum.SortOrder.LayoutOrder
buffsLayout.Parent = buffsScroll

local buffTemplate = Instance.new("Frame")
buffTemplate.Name = "BuffTemplate"
buffTemplate.Visible = false
buffTemplate.Size = UDim2.fromOffset(70, 70)
buffTemplate.BackgroundTransparency = 1
buffTemplate.BorderSizePixel = 0
buffTemplate.ZIndex = 52
buffTemplate.Parent = buffsScroll

local buffSlotBackground = makeImageLabel(buffTemplate, "BuffSlotBackground", ASSETS.BuffSlotBackground, 52)
buffSlotBackground.Size = UDim2.fromScale(1, 1)
buffSlotBackground.ScaleType = Enum.ScaleType.Stretch

local buffIcon = makeImageLabel(buffTemplate, "BuffIcon", "", 53)
buffIcon.Size = UDim2.fromScale(1, 1)
buffIcon.ScaleType = Enum.ScaleType.Fit

local buffTime = makeTextLabel(buffTemplate, "BuffTime", "30s", UDim2.new(0.5, 0, 1, -2), UDim2.new(1, 0, 0, 20), 54)
buffTime.AnchorPoint = Vector2.new(0.5, 1)

print("InventoryGui created successfully")

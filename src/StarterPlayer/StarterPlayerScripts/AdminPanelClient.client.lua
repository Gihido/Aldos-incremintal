local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local ResponsiveUI = require(shared:WaitForChild("ResponsiveUI"))
local UIAssetConfig = require(shared:WaitForChild("UIAssetConfig"))
local ItemConfig = require(shared:WaitForChild("ItemConfig"))

local ADMIN_NAME = "Doter24_7"
local UI_PROFILES = {
	Desktop = {
		PanelSize = Vector2.new(310, 500),
		PanelScale = 1,
		Position = UDim2.fromScale(0.98, 0.58),
		OpenButtonSize = UDim2.fromOffset(78, 34),
	},
	Mobile = {
		PanelSize = Vector2.new(310, 500),
		PanelScale = nil,
		Position = UDim2.fromScale(0.98, 0.58),
		OpenButtonSize = UDim2.fromOffset(70, 32),
	},
}
local PANEL_COLOR_TOP = Color3.fromRGB(55, 185, 255)
local PANEL_COLOR_BOTTOM = Color3.fromRGB(16, 70, 190)
local BUTTON_COLOR_TOP = Color3.fromRGB(190, 255, 70)
local BUTTON_COLOR_BOTTOM = Color3.fromRGB(80, 210, 45)
local RED_STROKE = Color3.fromRGB(210, 20, 35)

local localPlayer = Players.LocalPlayer

if localPlayer.Name ~= ADMIN_NAME then
	return
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local adminRequestRemote = remotes:WaitForChild("AdminRequest")
local adminResultRemote = remotes:WaitForChild("AdminResult")

local selectedUserId
local selectedItemId = ItemConfig.Order[1]
local selectedButton
local selectedItemButton
local playerButtons = {}
local itemButtons = {}
local panel
local openButton
local statusLabel
local amountBox
local itemAmountBox
local scaleObject

local function getGameFont()
	return (UIAssetConfig.Fonts and UIAssetConfig.Fonts.Main) or Enum.Font.Arcade
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0
	stroke.Parent = parent

	return stroke
end

local function addGradient(parent, colorA, colorB)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(colorA, colorB)
	gradient.Rotation = 90
	gradient.Parent = parent

	return gradient
end

local function styleText(textObject, textSize)
	textObject.Font = getGameFont()
	textObject.TextColor3 = Color3.fromRGB(255, 255, 255)
	textObject.TextSize = textSize
	textObject.TextScaled = false
	textObject.TextStrokeColor3 = RED_STROKE
	textObject.TextStrokeTransparency = 0.18
	textObject.TextWrapped = true
end

local function createTextLabel(parent, name, text, position, size, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Position = position
	label.Size = size
	label.Text = text
	label.ZIndex = parent.ZIndex + 1
	label.Parent = parent
	styleText(label, textSize)

	return label
end

local function createButton(parent, name, text, position, size)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = true
	button.BackgroundColor3 = BUTTON_COLOR_TOP
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = size
	button.Text = text
	local parentZIndex = parent:IsA("GuiObject") and parent.ZIndex or 1
	button.ZIndex = parentZIndex + 2
	button.Parent = parent
	styleText(button, 18)
	addStroke(button, Color3.fromRGB(30, 85, 20), 2, 0.05)
	addGradient(button, BUTTON_COLOR_TOP, BUTTON_COLOR_BOTTOM)

	return button
end

local function setStatus(message, isSuccess)
	if not statusLabel then
		return
	end

	statusLabel.Text = message or ""
	statusLabel.TextColor3 = isSuccess and Color3.fromRGB(205, 255, 170) or Color3.fromRGB(255, 225, 225)
end

local function setPanelVisible(visible)
	panel.Visible = visible
	openButton.Visible = not visible
end

local function getUIProfile()
	return ResponsiveUI.IsMobileLike() and UI_PROFILES.Mobile or UI_PROFILES.Desktop
end

local function getPanelSize()
	local size = getUIProfile().PanelSize

	return UDim2.fromOffset(size.X, size.Y)
end

local function updateScale()
	if panel then
		panel.Size = getPanelSize()
	end

	if scaleObject then
		scaleObject.Scale = ResponsiveUI.IsMobileViewport() and ResponsiveUI.GetMobileScale("AdminPanel") or getUIProfile().PanelScale
	end

	if openButton then
		openButton.Size = getUIProfile().OpenButtonSize
	end
end

local function selectPlayer(player, button)
	selectedUserId = player.UserId

	if selectedButton then
		selectedButton.BackgroundColor3 = BUTTON_COLOR_TOP
	end

	selectedButton = button
	selectedButton.BackgroundColor3 = Color3.fromRGB(255, 245, 105)
	setStatus(`Selected: {player.Name}`, true)
end

local function selectItem(itemId, button)
	selectedItemId = itemId

	if selectedItemButton then
		selectedItemButton.BackgroundColor3 = BUTTON_COLOR_TOP
	end

	selectedItemButton = button
	if selectedItemButton then
		selectedItemButton.BackgroundColor3 = Color3.fromRGB(255, 245, 105)
	end
end

local function refreshPlayerList(listFrame)
	for _, button in pairs(playerButtons) do
		button:Destroy()
	end

	playerButtons = {}
	selectedButton = nil

	local players = Players:GetPlayers()
	table.sort(players, function(left, right)
		return left.Name < right.Name
	end)

	for index, player in ipairs(players) do
		local button = createButton(listFrame, `Player_{player.UserId}`, player.Name, UDim2.fromOffset(0, (index - 1) * 34), UDim2.new(1, -8, 0, 30))
		button.TextSize = 14
		button.LayoutOrder = index
		button.MouseButton1Click:Connect(function()
			selectPlayer(player, button)
		end)
		playerButtons[player.UserId] = button

		if selectedUserId == player.UserId or (not selectedUserId and player == localPlayer) then
			selectPlayer(player, button)
		end
	end

	listFrame.CanvasSize = UDim2.fromOffset(0, math.max(#players * 34, listFrame.AbsoluteSize.Y))
end

local function createAdminPanel()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AdminPanelGui"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	panel = Instance.new("Frame")
	panel.Name = "AdminPanel"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.BackgroundColor3 = PANEL_COLOR_TOP
	panel.BorderSizePixel = 0
	panel.Position = getUIProfile().Position
	panel.Size = getPanelSize()
	panel.ZIndex = 500
	panel.Parent = screenGui
	addStroke(panel, Color3.fromRGB(185, 235, 255), 3, 0.05)
	addGradient(panel, PANEL_COLOR_TOP, PANEL_COLOR_BOTTOM)

	scaleObject = Instance.new("UIScale")
	scaleObject.Name = "AdminScale"
	scaleObject.Scale = ResponsiveUI.IsMobileViewport() and ResponsiveUI.GetMobileScale("AdminPanel") or getUIProfile().PanelScale
	scaleObject.Parent = panel

	createTextLabel(panel, "Title", "Admin Panel", UDim2.fromOffset(14, 10), UDim2.new(1, -56, 0, 36), 24)

	local closeButton = createButton(panel, "Close", "X", UDim2.new(1, -40, 0, 10), UDim2.fromOffset(28, 28))
	closeButton.MouseButton1Click:Connect(function()
		setPanelVisible(false)
	end)

	createTextLabel(panel, "PlayersTitle", "Players", UDim2.fromOffset(14, 52), UDim2.new(1, -28, 0, 24), 16)

	local listFrame = Instance.new("ScrollingFrame")
	listFrame.Name = "PlayerList"
	listFrame.BackgroundColor3 = Color3.fromRGB(12, 62, 150)
	listFrame.BackgroundTransparency = 0.15
	listFrame.BorderSizePixel = 0
	listFrame.Position = UDim2.fromOffset(14, 80)
	listFrame.ScrollBarImageColor3 = Color3.fromRGB(210, 255, 180)
	listFrame.ScrollBarThickness = 6
	listFrame.Size = UDim2.new(1, -28, 0, 112)
	listFrame.ZIndex = panel.ZIndex + 1
	listFrame.Parent = panel
	addStroke(listFrame, Color3.fromRGB(180, 230, 255), 1, 0.15)

	amountBox = Instance.new("TextBox")
	amountBox.Name = "AmountBox"
	amountBox.BackgroundColor3 = Color3.fromRGB(10, 40, 105)
	amountBox.BackgroundTransparency = 0.08
	amountBox.BorderSizePixel = 0
	amountBox.ClearTextOnFocus = false
	amountBox.PlaceholderText = "Amount"
	amountBox.Position = UDim2.fromOffset(14, 204)
	amountBox.Size = UDim2.new(1, -28, 0, 42)
	amountBox.Text = ""
	amountBox.ZIndex = panel.ZIndex + 2
	amountBox.Parent = panel
	styleText(amountBox, 18)
	addStroke(amountBox, Color3.fromRGB(190, 235, 255), 2, 0.12)

	amountBox:GetPropertyChangedSignal("Text"):Connect(function()
		local filtered = amountBox.Text:gsub("%D", "")
		if filtered ~= amountBox.Text then
			amountBox.Text = filtered
		end
	end)

	local addButton = createButton(panel, "AddCoins", "Add Coins", UDim2.fromOffset(14, 258), UDim2.new(0.48, -18, 0, 44))
	addButton.MouseButton1Click:Connect(function()
		if not selectedUserId then
			setStatus("Select player", false)
			return
		end

		adminRequestRemote:FireServer({
			Action = "AddCoins",
			TargetUserId = selectedUserId,
			Amount = amountBox.Text,
		})
	end)

	local resetButton = createButton(panel, "ResetProgress", "Reset Progress", UDim2.new(0.52, 4, 0, 258), UDim2.new(0.48, -18, 0, 44))
	resetButton.MouseButton1Click:Connect(function()
		if not selectedUserId then
			setStatus("Select player", false)
			return
		end

		adminRequestRemote:FireServer({
			Action = "ResetProgress",
			TargetUserId = selectedUserId,
		})
	end)

	createTextLabel(panel, "ItemsTitle", "Give Item", UDim2.fromOffset(14, 312), UDim2.new(1, -28, 0, 22), 16)

	for index, itemId in ipairs(ItemConfig.Order) do
		local definition = ItemConfig[itemId]
		local column = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		local itemButton = createButton(
			panel,
			`Item_{itemId}`,
			definition and definition.DisplayName or itemId,
			UDim2.new(column * 0.5, 14 + column * 4, 0, 340 + row * 34),
			UDim2.new(0.5, -20, 0, 30)
		)
		itemButton.TextSize = 14
		itemButton.MouseButton1Click:Connect(function()
			selectItem(itemId, itemButton)
		end)
		itemButtons[itemId] = itemButton

		if itemId == selectedItemId then
			selectItem(itemId, itemButton)
		end
	end

	itemAmountBox = Instance.new("TextBox")
	itemAmountBox.Name = "ItemAmountBox"
	itemAmountBox.BackgroundColor3 = Color3.fromRGB(10, 40, 105)
	itemAmountBox.BackgroundTransparency = 0.08
	itemAmountBox.BorderSizePixel = 0
	itemAmountBox.ClearTextOnFocus = false
	itemAmountBox.PlaceholderText = "Item amount"
	itemAmountBox.Position = UDim2.fromOffset(14, 412)
	itemAmountBox.Size = UDim2.new(0.48, -18, 0, 36)
	itemAmountBox.Text = "1"
	itemAmountBox.ZIndex = panel.ZIndex + 2
	itemAmountBox.Parent = panel
	styleText(itemAmountBox, 16)
	addStroke(itemAmountBox, Color3.fromRGB(190, 235, 255), 2, 0.12)

	itemAmountBox:GetPropertyChangedSignal("Text"):Connect(function()
		local filtered = itemAmountBox.Text:gsub("%D", "")
		if filtered ~= itemAmountBox.Text then
			itemAmountBox.Text = filtered
		end
	end)

	local addItemButton = createButton(panel, "AddItem", "Add Item", UDim2.new(0.52, 4, 0, 412), UDim2.new(0.48, -18, 0, 36))
	addItemButton.MouseButton1Click:Connect(function()
		if not selectedUserId then
			setStatus("Select player", false)
			return
		end

		if not selectedItemId then
			setStatus("Select item", false)
			return
		end

		adminRequestRemote:FireServer({
			Action = "AddItem",
			TargetUserId = selectedUserId,
			ItemId = selectedItemId,
			Amount = itemAmountBox.Text,
		})
	end)

	statusLabel = createTextLabel(panel, "Status", "Ready", UDim2.fromOffset(14, 452), UDim2.new(1, -28, 0, 34), 14)
	statusLabel.TextColor3 = Color3.fromRGB(205, 255, 170)

	openButton = createButton(screenGui, "OpenAdmin", "Admin", UDim2.new(1, -92, 0.5, 130), getUIProfile().OpenButtonSize)
	openButton.AnchorPoint = Vector2.new(1, 0.5)
	openButton.ZIndex = 450
	openButton.Visible = false
	openButton.MouseButton1Click:Connect(function()
		setPanelVisible(true)
	end)

	refreshPlayerList(listFrame)
	Players.PlayerAdded:Connect(function()
		refreshPlayerList(listFrame)
	end)
	Players.PlayerRemoving:Connect(function(player)
		if selectedUserId == player.UserId then
			selectedUserId = nil
		end

		task.defer(function()
			refreshPlayerList(listFrame)
		end)
	end)

	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

adminResultRemote.OnClientEvent:Connect(function(result)
	if type(result) ~= "table" then
		setStatus("Invalid server response", false)
		return
	end

	setStatus(result.Message or "Done", result.Success == true)
end)

createAdminPanel()

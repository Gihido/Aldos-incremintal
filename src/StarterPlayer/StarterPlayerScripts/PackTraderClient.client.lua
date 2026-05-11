local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("InventoryGui", 10)

if not gui then
	warn("[PackTraderClient] PlayerGui.InventoryGui was not found. Run the PackTrader builder in Studio first.")
	return
end

local shared = ReplicatedStorage:WaitForChild("Shared")
local FormatNumber = require(shared:WaitForChild("FormatNumber"))
local ItemConfig = require(shared:WaitForChild("ItemConfig"))
local UIAssetConfig = require(shared:WaitForChild("UIAssetConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local packTraderActionRemote = remotes:WaitForChild("PackTraderAction")
local syncPackTraderRemote = remotes:WaitForChild("SyncPackTrader")

local TWEEN_IN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_OUT = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local DIALOG_DEFAULT_TEXT = "Здравствуй, странник, ты что-то хотел?"
local DIALOG_NO_TEXT = "Понял тебя — как хочешь."
local FALLBACK_BACKGROUND = Color3.fromRGB(22, 28, 36)
local FALLBACK_STROKE = Color3.fromRGB(210, 220, 235)

local ui = {}
local baseLayout = {}
local latestOffer
local offerSlots = {}
local activeTooltipSlot

local function hasCustomAssetId(assetId)
	return type(assetId) == "string" and assetId ~= "" and assetId ~= "rbxassetid://0"
end

local function getGameFont()
	return (UIAssetConfig.Fonts and UIAssetConfig.Fonts.Main) or Enum.Font.Arcade
end

local function getInventoryAssets()
	return UIAssetConfig.Inventory or {}
end

local function getMainAssets()
	return getInventoryAssets().Main or {}
end

local function getPackTraderAssets()
	return getInventoryAssets().PackTrader or {}
end

local function getItemAssets(itemId)
	return (getInventoryAssets().Items and getInventoryAssets().Items[itemId]) or {}
end

local function findChild(parent, name)
	if not parent then
		warn("[PackTraderClient] Missing parent while finding", name)
		return nil
	end

	local child = parent:FindFirstChild(name)

	if not child then
		warn("[PackTraderClient] Missing GUI element:", name)
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

local function ensureStroke(guiObject)
	if not guiObject or not guiObject:IsA("GuiObject") then
		return nil
	end

	local stroke = guiObject:FindFirstChild("FallbackStroke")

	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = "FallbackStroke"
		stroke.Parent = guiObject
	end

	stroke.Color = FALLBACK_STROKE
	stroke.Thickness = 2
	stroke.Transparency = 0.35
	return stroke
end

local function setImageOrFallback(imageObject, assetId, fallbackColor)
	if not imageObject or not (imageObject:IsA("ImageLabel") or imageObject:IsA("ImageButton")) then
		return
	end

	local stroke = imageObject:FindFirstChild("FallbackStroke")

	if hasCustomAssetId(assetId) then
		imageObject.Image = assetId
		imageObject.ImageTransparency = 0
		imageObject.BackgroundTransparency = 1

		if stroke then
			stroke.Enabled = false
		end
	else
		imageObject.Image = ""
		imageObject.ImageTransparency = 1
		imageObject.BackgroundColor3 = fallbackColor or FALLBACK_BACKGROUND
		imageObject.BackgroundTransparency = 0.12
		ensureStroke(imageObject).Enabled = true
	end
end

local function styleText(label, maxTextSize)
	if not label or not (label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox")) then
		return
	end

	label.BackgroundTransparency = 1
	label.Font = getGameFont()
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.2
	label.TextWrapped = true

	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")

	if not constraint then
		constraint = Instance.new("UITextSizeConstraint")
		constraint.Parent = label
	end

	constraint.MinTextSize = 10
	constraint.MaxTextSize = maxTextSize or 28
end

local function setButtonText(button, text)
	local label = button and button:FindFirstChild("ButtonText")

	if label and label:IsA("TextLabel") then
		label.Text = text
		styleText(label, 24)
	end
end

local function getHiddenRightPosition(panel, openPosition)
	if not panel then
		return openPosition
	end

	return UDim2.new(
		openPosition.X.Scale,
		openPosition.X.Offset + panel.AbsoluteSize.X + 40,
		openPosition.Y.Scale,
		openPosition.Y.Offset
	)
end

local function cacheGui()
	ui.InventoryMain = findChild(gui, "InventoryMain")
	ui.CategoryPanel = findChild(ui.InventoryMain, "CategoryPanel")
	ui.InventoryContent = findChild(ui.InventoryMain, "InventoryContent")
	ui.PackTraderTabButton = findChild(ui.CategoryPanel, "PackTraderTabButton")
	ui.ItemsTabButton = findChild(ui.CategoryPanel, "ItemsTabButton")
	ui.PassivesTabButton = findChild(ui.CategoryPanel, "PassivesTabButton")
	ui.ItemsScroll = findChild(ui.InventoryContent, "ItemsScroll")
	ui.PassivesScroll = findChild(ui.InventoryContent, "PassivesScroll")
	ui.PackTraderFrame = findChild(ui.InventoryContent, "PackTraderFrame")
	ui.ItemInfoPanel = findChild(ui.InventoryMain, "ItemInfoPanel")

	ui.TraderBackground = findChild(ui.PackTraderFrame, "TraderBackground")
	ui.TraderImage = findChild(ui.PackTraderFrame, "TraderImage")
	ui.DialogPanel = findChild(ui.PackTraderFrame, "DialogPanel")
	ui.DialogBackground = findChild(ui.DialogPanel, "DialogBackground")
	ui.DialogText = findChild(ui.DialogPanel, "DialogText")
	ui.AnswerButton1 = findChild(ui.DialogPanel, "AnswerButton1")
	ui.AnswerButton2 = findChild(ui.DialogPanel, "AnswerButton2")
	ui.OffersPanel = findChild(ui.PackTraderFrame, "OffersPanel")
	ui.OffersBackground = findChild(ui.OffersPanel, "OffersBackground")
	ui.OfferTimerText = findChild(ui.OffersPanel, "OfferTimerText")
	ui.OfferTitleText = findChild(ui.OffersPanel, "OfferTitleText")
	ui.OfferItemsFrame = findChild(ui.OffersPanel, "OfferItemsFrame")
	ui.OfferPriceText = findChild(ui.OffersPanel, "OfferPriceText")
	ui.BuyOfferButton = findChild(ui.OffersPanel, "BuyOfferButton")
	ui.BackToDialogButton = findChild(ui.OffersPanel, "BackToDialogButton")
	ui.TraderTooltip = findChild(ui.PackTraderFrame, "TraderTooltip")
	ui.TooltipBackground = findChild(ui.TraderTooltip, "TooltipBackground")
	ui.TooltipName = findChild(ui.TraderTooltip, "TooltipName")
	ui.TooltipBoost = findChild(ui.TraderTooltip, "TooltipBoost")

	for index = 1, 4 do
		offerSlots[index] = findChild(ui.OfferItemsFrame, "OfferItemSlot" .. index)
	end
end

local function captureBaseLayout()
	if ui.PackTraderFrame then
		baseLayout.PackTraderOpenPosition = ui.PackTraderFrame.Position
		baseLayout.PackTraderOpenSize = ui.PackTraderFrame.Size
	end

	if ui.DialogPanel then
		baseLayout.DialogOpenPosition = ui.DialogPanel.Position
		baseLayout.DialogOpenSize = ui.DialogPanel.Size
	end

	if ui.OffersPanel then
		baseLayout.OffersOpenPosition = ui.OffersPanel.Position
		baseLayout.OffersOpenSize = ui.OffersPanel.Size
	end

	if ui.ItemInfoPanel then
		baseLayout.ItemInfoOpenPosition = ui.ItemInfoPanel.Position
		baseLayout.ItemInfoOpenSize = ui.ItemInfoPanel.Size
	end
end

local function applyAssets()
	local mainAssets = getMainAssets()
	local traderAssets = getPackTraderAssets()
	setImageOrFallback(ui.PackTraderTabButton, mainAssets.PackTraderTabButton, Color3.fromRGB(45, 70, 95))
	setImageOrFallback(ui.TraderBackground, traderAssets.Background, Color3.fromRGB(18, 25, 34))
	setImageOrFallback(ui.TraderImage, traderAssets.TraderImage, Color3.fromRGB(35, 44, 58))
	setImageOrFallback(ui.DialogBackground, traderAssets.DialogBackground, Color3.fromRGB(24, 32, 44))
	setImageOrFallback(ui.OffersBackground, traderAssets.OffersBackground, Color3.fromRGB(24, 32, 44))
	setImageOrFallback(ui.BuyOfferButton, traderAssets.BuyButtonBackground, Color3.fromRGB(55, 110, 55))
	setImageOrFallback(ui.BackToDialogButton, traderAssets.BackButtonBackground, Color3.fromRGB(55, 75, 110))
	setImageOrFallback(ui.TooltipBackground, traderAssets.TooltipBackground, Color3.fromRGB(22, 30, 42))
	setImageOrFallback(ui.AnswerButton1, traderAssets.AnswerButtonBackground, Color3.fromRGB(45, 70, 95))
	setImageOrFallback(ui.AnswerButton2, traderAssets.AnswerButtonBackground, Color3.fromRGB(45, 70, 95))

	for _, slot in ipairs(offerSlots) do
		local background = slot and slot:FindFirstChild("SlotBackground")
		setImageOrFallback(background, traderAssets.OfferSlotBackground, Color3.fromRGB(28, 36, 48))
	end
end

local function applyTextStyles()
	for _, object in ipairs({ ui.DialogText, ui.OfferTimerText, ui.OfferTitleText, ui.OfferPriceText, ui.TooltipName, ui.TooltipBoost }) do
		styleText(object, 28)
	end

	setButtonText(ui.AnswerButton1, "Привет! Хочу узнать, что сегодня предложишь")
	setButtonText(ui.AnswerButton2, "Не, сори, я беден")
	setButtonText(ui.BuyOfferButton, "Купить")
	setButtonText(ui.BackToDialogButton, "Назад")

	for _, slot in ipairs(offerSlots) do
		local itemCount = slot and slot:FindFirstChild("ItemCount")
		styleText(itemCount, 22)
	end
end

local function setPackTraderVisible(isVisible)
	if not ui.PackTraderFrame then
		return
	end

	if isVisible then
		ui.PackTraderFrame.Visible = true
		ui.PackTraderFrame.Position = getHiddenRightPosition(ui.PackTraderFrame, baseLayout.PackTraderOpenPosition or ui.PackTraderFrame.Position)
		TweenService:Create(ui.PackTraderFrame, TWEEN_IN, {
			Position = baseLayout.PackTraderOpenPosition or ui.PackTraderFrame.Position,
		}):Play()
	else
		TweenService:Create(ui.PackTraderFrame, TWEEN_OUT, {
			Position = getHiddenRightPosition(ui.PackTraderFrame, baseLayout.PackTraderOpenPosition or ui.PackTraderFrame.Position),
		}):Play()
		task.delay(0.15, function()
			if ui.PackTraderFrame then
				ui.PackTraderFrame.Visible = false
				ui.PackTraderFrame.Position = baseLayout.PackTraderOpenPosition or ui.PackTraderFrame.Position
			end
		end)
	end
end

local function closeItemInfoPanel()
	if not ui.ItemInfoPanel or not ui.ItemInfoPanel.Visible then
		return
	end

	TweenService:Create(ui.ItemInfoPanel, TWEEN_OUT, {
		Position = getHiddenRightPosition(ui.ItemInfoPanel, baseLayout.ItemInfoOpenPosition or ui.ItemInfoPanel.Position),
	}):Play()
	task.delay(0.15, function()
		if ui.ItemInfoPanel then
			ui.ItemInfoPanel.Visible = false
			ui.ItemInfoPanel.Position = baseLayout.ItemInfoOpenPosition or ui.ItemInfoPanel.Position
		end
	end)
end

local function showDialog()
	if ui.DialogText then
		ui.DialogText.Text = DIALOG_DEFAULT_TEXT
	end

	if ui.DialogPanel then
		ui.DialogPanel.Visible = true
		ui.DialogPanel.Position = getHiddenRightPosition(ui.DialogPanel, baseLayout.DialogOpenPosition or ui.DialogPanel.Position)
		TweenService:Create(ui.DialogPanel, TWEEN_IN, {
			Position = baseLayout.DialogOpenPosition or ui.DialogPanel.Position,
		}):Play()
	end

	if ui.OffersPanel then
		ui.OffersPanel.Visible = false
		ui.OffersPanel.Position = baseLayout.OffersOpenPosition or ui.OffersPanel.Position
	end
end

local function showOffers()
	if ui.DialogPanel then
		ui.DialogPanel.Visible = false
		ui.DialogPanel.Position = baseLayout.DialogOpenPosition or ui.DialogPanel.Position
	end

	if ui.OffersPanel then
		ui.OffersPanel.Visible = true
		ui.OffersPanel.Position = getHiddenRightPosition(ui.OffersPanel, baseLayout.OffersOpenPosition or ui.OffersPanel.Position)
		TweenService:Create(ui.OffersPanel, TWEEN_IN, {
			Position = baseLayout.OffersOpenPosition or ui.OffersPanel.Position,
		}):Play()
	end
end

local function openPackTrader()
	closeItemInfoPanel()

	if ui.ItemsScroll then
		ui.ItemsScroll.Visible = false
	end

	if ui.PassivesScroll then
		ui.PassivesScroll.Visible = false
	end

	setPackTraderVisible(true)
	showDialog()
	packTraderActionRemote:FireServer({
		Action = "RequestSync",
	})
end

local function closePackTrader()
	if ui.PackTraderFrame and ui.PackTraderFrame.Visible then
		setPackTraderVisible(false)
	end
end

local function getItemIcon(itemId)
	local itemAssets = getItemAssets(itemId)
	return itemAssets.Icon or "rbxassetid://0"
end

local function formatRemaining(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	if seconds >= 60 then
		return string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60)
	end
	return string.format("%ds", seconds)
end

local function layoutOfferSlots(count)
	local positions = {
		[1] = { 0.5 },
		[2] = { 0.32, 0.68 },
		[3] = { 0.2, 0.5, 0.8 },
		[4] = { 0.125, 0.375, 0.625, 0.875 },
	}
	local xPositions = positions[count] or positions[4]

	for index, slot in ipairs(offerSlots) do
		if slot then
			slot.AnchorPoint = Vector2.new(0.5, 0.5)
			if index <= count then
				slot.Position = UDim2.fromScale(xPositions[index], 0.5)
			end
		end
	end
end

local function showTooltip(item, position)
	if not ui.TraderTooltip or not item then
		return
	end

	local definition = ItemConfig[item.ItemId]
	if not definition then
		return
	end

	ui.TooltipName.Text = definition.DisplayName
	ui.TooltipBoost.Text = string.format("%s\n%s", definition.BoostText, definition.Description)
	ui.TraderTooltip.Position = position or UDim2.fromOffset(0, 0)
	ui.TraderTooltip.Visible = true
end

local function hideTooltip()
	if ui.TraderTooltip then
		ui.TraderTooltip.Visible = false
	end
	activeTooltipSlot = nil
end

local function updateOfferSlots(offer)
	local items = offer and offer.Items or {}
	layoutOfferSlots(#items)

	for index, slot in ipairs(offerSlots) do
		local item = items[index]

		if slot and item and ItemConfig[item.ItemId] then
			slot.Visible = true
			local icon = slot:FindFirstChild("ItemIcon")
			local count = slot:FindFirstChild("ItemCount")
			setImageOrFallback(icon, getItemIcon(item.ItemId), Color3.fromRGB(40, 48, 56))
			if count and count:IsA("TextLabel") then
				count.Text = "x" .. tostring(item.Amount)
			end
			slot:SetAttribute("ItemId", item.ItemId)
		else
			if slot then
				slot.Visible = false
				slot:SetAttribute("ItemId", nil)
			end
		end
	end
end

local function updateOfferText(offer)
	if not offer then
		return
	end

	if ui.OfferPriceText then
		ui.OfferPriceText.Text = "Цена: " .. FormatNumber(offer.Price or 0) .. " Coins"
	end

	if ui.OfferTimerText then
		ui.OfferTimerText.Text = "Обновление через: " .. formatRemaining(offer.Remaining or ((offer.ExpiresAt or os.time()) - os.time()))
	end
end

local function updateOffer(offer)
	latestOffer = offer
	updateOfferText(offer)
	updateOfferSlots(offer)
end

local function hookButtons()
	if ui.PackTraderTabButton and ui.PackTraderTabButton:IsA("GuiButton") then
		ui.PackTraderTabButton.MouseButton1Click:Connect(openPackTrader)
	end

	for _, tabButton in ipairs({ ui.ItemsTabButton, ui.PassivesTabButton }) do
		if tabButton and tabButton:IsA("GuiButton") then
			tabButton.MouseButton1Click:Connect(closePackTrader)
		end
	end

	if ui.AnswerButton1 and ui.AnswerButton1:IsA("GuiButton") then
		ui.AnswerButton1.MouseButton1Click:Connect(showOffers)
	end

	if ui.AnswerButton2 and ui.AnswerButton2:IsA("GuiButton") then
		ui.AnswerButton2.MouseButton1Click:Connect(function()
			if ui.DialogText then
				ui.DialogText.Text = DIALOG_NO_TEXT
				task.delay(1.2, function()
					if ui.DialogText then
						ui.DialogText.Text = DIALOG_DEFAULT_TEXT
					end
				end)
			end
		end)
	end

	if ui.BackToDialogButton and ui.BackToDialogButton:IsA("GuiButton") then
		ui.BackToDialogButton.MouseButton1Click:Connect(showDialog)
	end

	if ui.BuyOfferButton and ui.BuyOfferButton:IsA("GuiButton") then
		ui.BuyOfferButton.MouseButton1Click:Connect(function()
			packTraderActionRemote:FireServer({
				Action = "BuyOffer",
			})
		end)
	end

	for _, slot in ipairs(offerSlots) do
		if slot and slot:IsA("GuiButton") then
			slot.MouseEnter:Connect(function()
				local itemId = slot:GetAttribute("ItemId")
				if not itemId then
					return
				end
				activeTooltipSlot = slot
				local mousePosition = UserInputService:GetMouseLocation()
				showTooltip({ ItemId = itemId }, UDim2.fromOffset(mousePosition.X + 14, mousePosition.Y + 12))
			end)
			slot.MouseLeave:Connect(function()
				if activeTooltipSlot == slot then
					hideTooltip()
				end
			end)
			slot.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					local itemId = slot:GetAttribute("ItemId")
					if itemId then
						showTooltip({ ItemId = itemId }, UDim2.fromOffset(input.Position.X + 12, input.Position.Y + 12))
					end
				end
			end)
			slot.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					hideTooltip()
				end
			end)
		end
	end
end

local function updateTimerLoop()
	task.spawn(function()
		while true do
			if latestOffer then
				latestOffer.Remaining = math.max(0, (latestOffer.ExpiresAt or os.time()) - os.time())
				updateOfferText(latestOffer)
			end
			task.wait(1)
		end
	end)
end

cacheGui()
task.wait()
captureBaseLayout()
applyAssets()
applyTextStyles()
if ui.PackTraderFrame then
	ui.PackTraderFrame.Visible = false
end
hookButtons()
updateTimerLoop()

syncPackTraderRemote.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end

	if payload.Offer then
		updateOffer(payload.Offer)
	end

	if payload.Message and ui.DialogText and payload.ResultType == "NotEnough" then
		ui.DialogText.Text = payload.Message
		task.delay(1.2, function()
			if ui.DialogText then
				ui.DialogText.Text = DIALOG_DEFAULT_TEXT
			end
		end)
	end
end)

packTraderActionRemote:FireServer({
	Action = "RequestSync",
})

local camera = Workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		hideTooltip()
	end)
end

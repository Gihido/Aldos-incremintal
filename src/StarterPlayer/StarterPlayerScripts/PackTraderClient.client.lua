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
local TYPEWRITER_SECONDS_PER_CHAR = 0.028
local DIALOG_SPEAKER = "Торговец"
local FALLBACK_BACKGROUND = Color3.fromRGB(22, 28, 36)
local FALLBACK_STROKE = Color3.fromRGB(210, 220, 235)

local ui = {}
local baseLayout = {}
local latestOffer
local latestDialogState = "Greeting"
local currentTraderView = "Dialog"
local offerSlots = {}
local activeTooltipSlot
local dialogToken = 0
local answer1Action
local answer2Action
local introPlayedForInventoryOpen = false
local lastInventoryVisible = false

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

local function getOrCreateLocalNotificationEvent()
	local event = ReplicatedStorage:FindFirstChild("LocalNotificationEvent")

	if not event then
		event = Instance.new("BindableEvent")
		event.Name = "LocalNotificationEvent"
		event.Parent = ReplicatedStorage
	end

	return event
end

local localNotificationEvent = getOrCreateLocalNotificationEvent()

local function notify(notificationType, message)
	localNotificationEvent:Fire(notificationType or "Error", message or "Ошибка")
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
		label.Visible = true
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

local function getOfferRarity(totalAmount)
	if totalAmount == 1 then
		return "Обычными"
	elseif totalAmount == 3 then
		return "Необычными"
	elseif totalAmount == 5 then
		return "Редкими"
	elseif totalAmount == 9 then
		return "Эпическими"
	elseif totalAmount == 12 then
		return "Легендарными"
	end

	return "Необычными"
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
	ui.IntroOverlay = ui.PackTraderFrame and ui.PackTraderFrame:FindFirstChild("IntroOverlay")
	ui.DarkFade = ui.IntroOverlay and ui.IntroOverlay:FindFirstChild("DarkFade")
	ui.MistFade = ui.IntroOverlay and ui.IntroOverlay:FindFirstChild("MistFade")
	ui.TraderNameText = ui.PackTraderFrame and ui.PackTraderFrame:FindFirstChild("TraderNameText")
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
	ui.ItemTooltip = findChild(gui, "ItemTooltip")
	ui.TraderTooltip = ui.ItemTooltip or (ui.PackTraderFrame and ui.PackTraderFrame:FindFirstChild("TraderTooltip"))
	if ui.TraderTooltip and ui.TraderTooltip.Parent ~= gui then
		ui.TraderTooltip.Parent = gui
	end
	ui.TooltipBackground = findChild(ui.TraderTooltip, "TooltipBackground")
	ui.TooltipName = findChild(ui.TraderTooltip, "TooltipName")
	ui.TooltipBoost = findChild(ui.TraderTooltip, "TooltipBoost")

	for index = 1, 4 do
		offerSlots[index] = findChild(ui.OfferItemsFrame, "OfferItemSlot" .. index)
	end
end

local function ensureIntroOverlay()
	if not ui.PackTraderFrame then
		return
	end

	if not ui.IntroOverlay then
		ui.IntroOverlay = Instance.new("Frame")
		ui.IntroOverlay.Name = "IntroOverlay"
		ui.IntroOverlay.Size = UDim2.fromScale(1, 1)
		ui.IntroOverlay.Position = UDim2.fromScale(0, 0)
		ui.IntroOverlay.BackgroundTransparency = 1
		ui.IntroOverlay.Visible = false
		ui.IntroOverlay.ZIndex = 80
		ui.IntroOverlay.Parent = ui.PackTraderFrame
	end

	if not ui.DarkFade then
		ui.DarkFade = Instance.new("ImageLabel")
		ui.DarkFade.Name = "DarkFade"
		ui.DarkFade.Size = UDim2.fromScale(1, 1)
		ui.DarkFade.Position = UDim2.fromScale(0, 0)
		ui.DarkFade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		ui.DarkFade.BackgroundTransparency = 0
		ui.DarkFade.ZIndex = 81
		ui.DarkFade.Parent = ui.IntroOverlay
	end

	if not ui.MistFade then
		ui.MistFade = Instance.new("ImageLabel")
		ui.MistFade.Name = "MistFade"
		ui.MistFade.Size = UDim2.fromScale(1, 1)
		ui.MistFade.Position = UDim2.fromScale(0, 0)
		ui.MistFade.BackgroundTransparency = 1
		ui.MistFade.ZIndex = 82
		ui.MistFade.Parent = ui.IntroOverlay
	end

	if not ui.TraderNameText then
		ui.TraderNameText = Instance.new("TextLabel")
		ui.TraderNameText.Name = "TraderNameText"
		ui.TraderNameText.Position = UDim2.fromScale(0.36, 0.02)
		ui.TraderNameText.Size = UDim2.fromScale(0.58, 0.07)
		ui.TraderNameText.Text = DIALOG_SPEAKER
		ui.TraderNameText.ZIndex = 20
		ui.TraderNameText.Parent = ui.PackTraderFrame
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

	if ui.InventoryContent then
		baseLayout.InventoryContentOpenPosition = ui.InventoryContent.Position
		baseLayout.InventoryContentOpenSize = ui.InventoryContent.Size
	end
end

local function applyAssets()
	local mainAssets = getMainAssets()
	local traderAssets = getPackTraderAssets()
	setImageOrFallback(ui.PackTraderTabButton, mainAssets.PackTraderTabButton, Color3.fromRGB(45, 70, 95))
	setImageOrFallback(ui.TraderBackground, traderAssets.Background, Color3.fromRGB(18, 25, 34))
	setImageOrFallback(ui.DialogBackground, traderAssets.DialogBackground, Color3.fromRGB(24, 32, 44))
	setImageOrFallback(ui.OffersBackground, traderAssets.OffersBackground, Color3.fromRGB(24, 32, 44))
	setImageOrFallback(ui.BuyOfferButton, traderAssets.BuyButtonBackground, Color3.fromRGB(55, 110, 55))
	setImageOrFallback(ui.BackToDialogButton, traderAssets.BackButtonBackground, Color3.fromRGB(55, 75, 110))
	setImageOrFallback(ui.TooltipBackground, getMainAssets().TooltipBackground, Color3.fromRGB(22, 30, 42))
	setImageOrFallback(ui.AnswerButton1, traderAssets.AnswerButtonBackground, Color3.fromRGB(45, 70, 95))
	setImageOrFallback(ui.AnswerButton2, traderAssets.AnswerButtonBackground, Color3.fromRGB(45, 70, 95))
	setImageOrFallback(ui.DarkFade, traderAssets.DarkFadeImage, Color3.fromRGB(0, 0, 0))
	setImageOrFallback(ui.MistFade, traderAssets.MistFadeImage, Color3.fromRGB(210, 220, 235))

	for _, slot in ipairs(offerSlots) do
		local background = slot and slot:FindFirstChild("SlotBackground")
		setImageOrFallback(background, traderAssets.OfferSlotBackground, Color3.fromRGB(28, 36, 48))
	end
end

local function applyTextStyles()
	for _, object in ipairs({ ui.DialogText, ui.OfferTimerText, ui.OfferTitleText, ui.OfferPriceText, ui.TooltipName, ui.TooltipBoost, ui.TraderNameText }) do
		styleText(object, 28)
	end

	if ui.TraderNameText then
		ui.TraderNameText.Text = DIALOG_SPEAKER
	end

	for _, slot in ipairs(offerSlots) do
		local itemCount = slot and slot:FindFirstChild("ItemCount")
		styleText(itemCount, 22)
	end
end

local function setTraderImage(state)
	local traderAssets = getPackTraderAssets()
	local imageId = traderAssets.NormalTraderImage

	if state == "Suspicious" then
		imageId = traderAssets.SuspiciousTraderImage
	elseif state == "Angry" then
		imageId = traderAssets.AngryTraderImage
	end

	if not hasCustomAssetId(imageId) then
		imageId = traderAssets.TraderImage
	end

	setImageOrFallback(ui.TraderImage, imageId, Color3.fromRGB(35, 44, 58))
end

local function showAnswerButtons(button1Text, action1, button2Text, action2)
	answer1Action = action1
	answer2Action = action2

	if ui.AnswerButton1 then
		ui.AnswerButton1.Visible = button1Text ~= nil
		setButtonText(ui.AnswerButton1, button1Text or "")
	end

	if ui.AnswerButton2 then
		ui.AnswerButton2.Visible = button2Text ~= nil
		setButtonText(ui.AnswerButton2, button2Text or "")
	end
end

local function hideAnswerButtons()
	answer1Action = nil
	answer2Action = nil

	if ui.AnswerButton1 then
		ui.AnswerButton1.Visible = false
	end

	if ui.AnswerButton2 then
		ui.AnswerButton2.Visible = false
	end
end

local function cancelDialogText()
	dialogToken += 1
	hideAnswerButtons()
end

local function typeDialogText(fullText, onComplete)
	dialogToken += 1
	local token = dialogToken
	hideAnswerButtons()

	if not ui.DialogText then
		if onComplete then
			onComplete()
		end
		return
	end

	ui.DialogText.Text = ""
	task.spawn(function()
		for index = 1, utf8.len(fullText) do
			if token ~= dialogToken then
				return
			end

			local byteIndex = utf8.offset(fullText, index + 1)
			ui.DialogText.Text = byteIndex and string.sub(fullText, 1, byteIndex - 1) or fullText
			local char = string.sub(ui.DialogText.Text, -1)
			local pause = TYPEWRITER_SECONDS_PER_CHAR

			if char == "." or char == "," or char == "!" or char == "?" or char == "—" then
				pause += 0.08
			end

			task.wait(pause)
		end

		if token ~= dialogToken then
			return
		end

		ui.DialogText.Text = fullText

		if onComplete then
			onComplete()
		end
	end)
end

local function playIntroOverlay()
	if not ui.IntroOverlay or not ui.DarkFade or not ui.MistFade then
		return
	end

	ui.IntroOverlay.Visible = true
	ui.DarkFade.BackgroundTransparency = 0
	ui.DarkFade.ImageTransparency = hasCustomAssetId(ui.DarkFade.Image) and 0.2 or 1
	ui.MistFade.ImageTransparency = hasCustomAssetId(ui.MistFade.Image) and 0.15 or 1
	ui.MistFade.BackgroundTransparency = hasCustomAssetId(ui.MistFade.Image) and 1 or 0.55

	TweenService:Create(ui.DarkFade, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
		ImageTransparency = 1,
	}):Play()

	task.delay(0.12, function()
		TweenService:Create(ui.MistFade, TweenInfo.new(0.58, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
			ImageTransparency = 1,
		}):Play()
	end)

	task.delay(0.72, function()
		if ui.IntroOverlay then
			ui.IntroOverlay.Visible = false
		end
	end)
end

local function setPackTraderVisible(isVisible)
	if not ui.PackTraderFrame then
		return
	end

	if isVisible then
		ui.PackTraderFrame.Position = baseLayout.PackTraderOpenPosition or ui.PackTraderFrame.Position
		ui.PackTraderFrame.Visible = true
	else
		ui.PackTraderFrame.Visible = false
		ui.PackTraderFrame.Position = baseLayout.PackTraderOpenPosition or ui.PackTraderFrame.Position
	end
end

local function restoreInventoryContent()
	if ui.InventoryContent and baseLayout.InventoryContentOpenPosition and baseLayout.InventoryContentOpenSize then
		TweenService:Create(ui.InventoryContent, TWEEN_OUT, {
			Position = baseLayout.InventoryContentOpenPosition,
			Size = baseLayout.InventoryContentOpenSize,
		}):Play()
	end
end

local function closeItemInfoPanel()
	restoreInventoryContent()

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

local function showDialogPanel()
	if not ui.DialogPanel then
		return
	end

	ui.DialogPanel.Visible = true
	ui.DialogPanel.Position = getHiddenRightPosition(ui.DialogPanel, baseLayout.DialogOpenPosition or ui.DialogPanel.Position)
	TweenService:Create(ui.DialogPanel, TWEEN_IN, {
		Position = baseLayout.DialogOpenPosition or ui.DialogPanel.Position,
	}):Play()
end

local function hideDialogPanel()
	if not ui.DialogPanel then
		return
	end

	ui.DialogPanel.Visible = false
	ui.DialogPanel.Position = baseLayout.DialogOpenPosition or ui.DialogPanel.Position
end

local function showOffersPanel()
	if not ui.OffersPanel then
		return
	end

	ui.OffersPanel.Visible = true
	ui.OffersPanel.Position = getHiddenRightPosition(ui.OffersPanel, baseLayout.OffersOpenPosition or ui.OffersPanel.Position)
	TweenService:Create(ui.OffersPanel, TWEEN_IN, {
		Position = baseLayout.OffersOpenPosition or ui.OffersPanel.Position,
	}):Play()
end

local function keepOffersPanelVisible()
	if ui.DialogPanel then
		ui.DialogPanel.Visible = false
		ui.DialogPanel.Position = baseLayout.DialogOpenPosition or ui.DialogPanel.Position
	end

	if ui.OffersPanel then
		ui.OffersPanel.Visible = true
		ui.OffersPanel.Position = baseLayout.OffersOpenPosition or ui.OffersPanel.Position
	end
end

local function hideOffersPanel()
	if not ui.OffersPanel then
		return
	end

	ui.OffersPanel.Visible = false
	ui.OffersPanel.Position = baseLayout.OffersOpenPosition or ui.OffersPanel.Position
end

local showGreeting
local showOffers
local showSpecialDialog

showGreeting = function()
	currentTraderView = "Dialog"
	latestDialogState = "Greeting"
	setTraderImage("Greeting")
	hideOffersPanel()
	showDialogPanel()
	local rarity = latestOffer and (latestOffer.Rarity or getOfferRarity(latestOffer.TotalItemAmount)) or "Необычными"
	local text = "Здравствуй, странник, я торгую разными товарами, сегодня — " .. rarity .. " товарами."
	typeDialogText(text, function()
		showAnswerButtons("Покажи свои товары", showOffers, "Пока просто смотрю", function()
			typeDialogText("Смотри, сколько хочешь.", function()
				task.delay(0.15, showOffers)
			end)
		end)
	end)
end

showSpecialDialog = function(state)
	currentTraderView = "Dialog"
	latestDialogState = state
	hideOffersPanel()
	showDialogPanel()
	setTraderImage(state)

	if state == "Suspicious" then
		typeDialogText("ТЫ какой-то подозрительный.. Уходи и не путайся под ногами.", function()
			showAnswerButtons("Понял, извините", function()
				packTraderActionRemote:FireServer({ Action = "ClearSpecialState" })
				showGreeting()
			end)
		end)
	elseif state == "Angry" then
		typeDialogText("Если нету денег — проваливай.", function()
			showAnswerButtons("Просто мелочевки нету..", function()
				packTraderActionRemote:FireServer({ Action = "ClearSpecialState" })
				showGreeting()
			end)
		end)
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

local function getTooltipBackground(itemId)
	local itemAssets = getItemAssets(itemId)
	if hasCustomAssetId(itemAssets.TooltipBackground) then
		return itemAssets.TooltipBackground
	end

	return getMainAssets().TooltipBackground
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

local function getClampedTooltipPosition(screenPosition)
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local padding = 12
	local size = ui.TraderTooltip and ui.TraderTooltip.AbsoluteSize or Vector2.new(220, 120)
	local x = screenPosition.X + 18
	local y = screenPosition.Y + 18

	if x + size.X + padding > viewport.X then
		x = screenPosition.X - size.X - 18
	end

	if y + size.Y + padding > viewport.Y then
		y = screenPosition.Y - size.Y - 18
	end

	x = math.clamp(x, padding, math.max(padding, viewport.X - size.X - padding))
	y = math.clamp(y, padding, math.max(padding, viewport.Y - size.Y - padding))

	return UDim2.fromOffset(x, y)
end

local function showTooltip(item, screenPosition)
	if not ui.TraderTooltip or not item then
		return
	end

	local definition = ItemConfig[item.ItemId]
	if not definition then
		return
	end

	if ui.TraderTooltip.Parent ~= gui then
		ui.TraderTooltip.Parent = gui
	end

	setImageOrFallback(ui.TooltipBackground, getTooltipBackground(item.ItemId), Color3.fromRGB(24, 32, 42))
	ui.TooltipName.Text = definition.DisplayName
	ui.TooltipBoost.Text = string.format("%s / %ss\n%s", definition.BoostText, tostring(definition.Duration or "?"), definition.Description or "")
	setTooltipZIndex(ui.TraderTooltip, 1000)
	ui.TraderTooltip.Visible = true
	ui.TraderTooltip.Position = getClampedTooltipPosition(screenPosition or UserInputService:GetMouseLocation())
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

	if ui.OfferTimerText then
		ui.OfferTimerText.Text = "Обновление через: " .. formatRemaining(offer.Remaining or ((offer.ExpiresAt or os.time()) - os.time()))
	end

	if offer.Purchased then
		if ui.OfferTitleText then
			ui.OfferTitleText.Text = "Товары закончились"
		end
		if ui.OfferPriceText then
			ui.OfferPriceText.Text = "Подожди обновления магазина."
		end
		if ui.BuyOfferButton then
			ui.BuyOfferButton.Visible = false
		end
		return
	end

	if ui.OfferTitleText then
		ui.OfferTitleText.Text = "Сегодня могу предложить:"
	end

	if ui.OfferPriceText then
		ui.OfferPriceText.Text = "Цена: " .. FormatNumber(offer.Price or 0) .. " Coins"
	end

	if ui.BuyOfferButton then
		ui.BuyOfferButton.Visible = true
	end
end

local function updateOffer(offer)
	latestOffer = offer
	updateOfferText(offer)
	updateOfferSlots(offer)
end

showOffers = function()
	cancelDialogText()
	currentTraderView = "Offers"
	latestDialogState = latestOffer and latestOffer.Purchased and "SoldOut" or "Offers"
	setTraderImage("Offers")
	hideDialogPanel()
	updateOffer(latestOffer)
	showOffersPanel()
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
	showGreeting()
	if not introPlayedForInventoryOpen then
		playIntroOverlay()
		introPlayedForInventoryOpen = true
	end
	packTraderActionRemote:FireServer({ Action = "OpenTrader" })
end

local function closePackTrader()
	cancelDialogText()
	hideTooltip()
	currentTraderView = "Dialog"

	if ui.PackTraderFrame and ui.PackTraderFrame.Visible then
		setPackTraderVisible(false)
	end
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
		ui.AnswerButton1.MouseButton1Click:Connect(function()
			if answer1Action then
				answer1Action()
			end
		end)
	end

	if ui.AnswerButton2 and ui.AnswerButton2:IsA("GuiButton") then
		ui.AnswerButton2.MouseButton1Click:Connect(function()
			if answer2Action then
				answer2Action()
			end
		end)
	end

	if ui.BackToDialogButton and ui.BackToDialogButton:IsA("GuiButton") then
		ui.BackToDialogButton.MouseButton1Click:Connect(showGreeting)
	end

	if ui.BuyOfferButton and ui.BuyOfferButton:IsA("GuiButton") then
		ui.BuyOfferButton.MouseButton1Click:Connect(function()
			packTraderActionRemote:FireServer({ Action = "BuyOffer" })
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
				showTooltip({ ItemId = itemId }, mousePosition)
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
						showTooltip({ ItemId = itemId }, Vector2.new(input.Position.X, input.Position.Y))
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

			if ui.InventoryMain and lastInventoryVisible ~= ui.InventoryMain.Visible then
				lastInventoryVisible = ui.InventoryMain.Visible
				if not lastInventoryVisible then
					introPlayedForInventoryOpen = false
					currentTraderView = "Dialog"
					cancelDialogText()
					hideTooltip()
				end
			end
			task.wait(1)
		end
	end)
end

local function handleSync(payload)
	if type(payload) ~= "table" then
		return
	end

	if payload.Offer then
		updateOffer(payload.Offer)
	end

	if payload.ResultType and payload.Message then
		notify(payload.ResultType, payload.Message)
	end

	if not (ui.PackTraderFrame and ui.PackTraderFrame.Visible) then
		return
	end

	if payload.DialogState == "Suspicious" and latestDialogState ~= "Suspicious" then
		showSpecialDialog("Suspicious")
	elseif payload.DialogState == "Angry" and latestDialogState ~= "Angry" then
		showSpecialDialog("Angry")
	elseif currentTraderView == "Offers" then
		keepOffersPanelVisible()
	elseif payload.DialogState == "SoldOut" and latestDialogState ~= "SoldOut" then
		showOffers()
	elseif payload.DialogState == "Greeting" and latestDialogState ~= "Greeting" then
		showGreeting()
	end
end

cacheGui()
ensureIntroOverlay()
task.wait()
captureBaseLayout()
applyAssets()
applyTextStyles()
setTraderImage("Greeting")
hideAnswerButtons()
if ui.PackTraderFrame then
	ui.PackTraderFrame.Visible = false
end
hookButtons()
updateTimerLoop()

syncPackTraderRemote.OnClientEvent:Connect(handleSync)

packTraderActionRemote:FireServer({ Action = "RequestSync" })

local camera = Workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		hideTooltip()
	end)
end

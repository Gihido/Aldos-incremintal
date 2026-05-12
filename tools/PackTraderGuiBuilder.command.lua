local StarterGui = game:GetService("StarterGui")

local ASSETS = {
	PackTraderTabButton = "rbxassetid://0",

	TraderBackground = "rbxassetid://0",
	TraderImage = "rbxassetid://0",
	NormalTraderImage = "rbxassetid://0",
	SuspiciousTraderImage = "rbxassetid://0",
	AngryTraderImage = "rbxassetid://0",

	DarkFadeImage = "rbxassetid://0",
	MistFadeImage = "rbxassetid://0",

	DialogBackground = "rbxassetid://0",
	AnswerButtonBackground = "rbxassetid://0",

	OffersBackground = "rbxassetid://0",
	OfferSlotBackground = "rbxassetid://0",

	BuyButtonBackground = "rbxassetid://0",
	BackButtonBackground = "rbxassetid://0",

	TooltipBackground = "rbxassetid://0",
}

local gui = StarterGui:FindFirstChild("InventoryGui")
assert(gui, "StarterGui.InventoryGui not found. Run InventoryGuiBuilder first.")

local inventoryMain = gui:FindFirstChild("InventoryMain")
assert(inventoryMain, "InventoryGui.InventoryMain not found")

local categoryPanel = inventoryMain:FindFirstChild("CategoryPanel")
assert(categoryPanel, "InventoryMain.CategoryPanel not found")

local inventoryContent = inventoryMain:FindFirstChild("InventoryContent")
assert(inventoryContent, "InventoryMain.InventoryContent not found")

local function getOrCreate(className, parent, name)
	local existing = parent:FindFirstChild(name)

	if existing then
		return existing
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end


local function setImageIfEmpty(imageObject, assetId)
	if imageObject and (imageObject:IsA("ImageLabel") or imageObject:IsA("ImageButton")) and (imageObject.Image == nil or imageObject.Image == "") then
		imageObject.Image = assetId
	end
end

local function styleText(label, text, zIndex)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Arcade
	label.Text = text or label.Text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.2
	label.TextWrapped = true
	label.ZIndex = zIndex or label.ZIndex
end

local function createButtonText(button, text, zIndex)
	local label = getOrCreate("TextLabel", button, "ButtonText")
	label.Size = UDim2.fromScale(1, 1)
	label.Position = UDim2.fromScale(0, 0)
	styleText(label, text, zIndex or (button.ZIndex + 1))
	return label
end

local packTraderTabButton = getOrCreate("ImageButton", categoryPanel, "PackTraderTabButton")
packTraderTabButton.Position = packTraderTabButton.Position == UDim2.new() and UDim2.fromOffset(10, 220) or packTraderTabButton.Position
packTraderTabButton.Size = packTraderTabButton.Size == UDim2.new() and UDim2.fromOffset(120, 90) or packTraderTabButton.Size
packTraderTabButton.BackgroundTransparency = 1
setImageIfEmpty(packTraderTabButton, ASSETS.PackTraderTabButton)
packTraderTabButton.ScaleType = Enum.ScaleType.Stretch
packTraderTabButton.AutoButtonColor = false
packTraderTabButton.ZIndex = packTraderTabButton.ZIndex > 1 and packTraderTabButton.ZIndex or 6

local packTraderFrame = getOrCreate("Frame", inventoryContent, "PackTraderFrame")
packTraderFrame.Visible = false
packTraderFrame.Position = packTraderFrame.Position == UDim2.new() and UDim2.fromOffset(0, 0) or packTraderFrame.Position
packTraderFrame.Size = packTraderFrame.Size == UDim2.new() and UDim2.fromScale(1, 1) or packTraderFrame.Size
packTraderFrame.BackgroundTransparency = 1
packTraderFrame.ClipsDescendants = true
packTraderFrame.ZIndex = packTraderFrame.ZIndex > 1 and packTraderFrame.ZIndex or 6

local traderBackground = getOrCreate("ImageLabel", packTraderFrame, "TraderBackground")
traderBackground.Size = UDim2.fromScale(1, 1)
traderBackground.BackgroundTransparency = 1
setImageIfEmpty(traderBackground, ASSETS.TraderBackground)
traderBackground.ScaleType = Enum.ScaleType.Stretch
traderBackground.ZIndex = 6

local traderImage = getOrCreate("ImageLabel", packTraderFrame, "TraderImage")
traderImage.Position = traderImage.Position == UDim2.new() and UDim2.fromScale(0.03, 0.18) or traderImage.Position
traderImage.Size = traderImage.Size == UDim2.new() and UDim2.fromScale(0.30, 0.62) or traderImage.Size
traderImage.BackgroundTransparency = 1
setImageIfEmpty(traderImage, ASSETS.TraderImage)
traderImage.ScaleType = Enum.ScaleType.Fit
traderImage.ZIndex = 8

local introOverlay = getOrCreate("Frame", packTraderFrame, "IntroOverlay")
introOverlay.Visible = false
introOverlay.Size = UDim2.fromScale(1, 1)
introOverlay.Position = UDim2.fromScale(0, 0)
introOverlay.BackgroundTransparency = 1
introOverlay.ZIndex = 80

local darkFade = getOrCreate("ImageLabel", introOverlay, "DarkFade")
darkFade.Size = UDim2.fromScale(1, 1)
darkFade.Position = UDim2.fromScale(0, 0)
darkFade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
darkFade.BackgroundTransparency = 0
setImageIfEmpty(darkFade, ASSETS.DarkFadeImage)
darkFade.ImageTransparency = 1
darkFade.ScaleType = Enum.ScaleType.Stretch
darkFade.ZIndex = 81

local mistFade = getOrCreate("ImageLabel", introOverlay, "MistFade")
mistFade.Size = UDim2.fromScale(1, 1)
mistFade.Position = UDim2.fromScale(0, 0)
mistFade.BackgroundTransparency = 1
setImageIfEmpty(mistFade, ASSETS.MistFadeImage)
mistFade.ImageTransparency = 1
mistFade.ScaleType = Enum.ScaleType.Stretch
mistFade.ZIndex = 82

local traderNameText = getOrCreate("TextLabel", packTraderFrame, "TraderNameText")
traderNameText.Position = traderNameText.Position == UDim2.new() and UDim2.fromScale(0.36, 0.02) or traderNameText.Position
traderNameText.Size = traderNameText.Size == UDim2.new() and UDim2.fromScale(0.58, 0.07) or traderNameText.Size
styleText(traderNameText, "Торговец", 20)

local dialogPanel = getOrCreate("Frame", packTraderFrame, "DialogPanel")
dialogPanel.Position = dialogPanel.Position == UDim2.new() and UDim2.fromScale(0.36, 0.10) or dialogPanel.Position
dialogPanel.Size = dialogPanel.Size == UDim2.new() and UDim2.fromScale(0.58, 0.42) or dialogPanel.Size
dialogPanel.BackgroundTransparency = 1
dialogPanel.ZIndex = 10

local dialogBackground = getOrCreate("ImageLabel", dialogPanel, "DialogBackground")
dialogBackground.Size = UDim2.fromScale(1, 1)
dialogBackground.BackgroundTransparency = 1
setImageIfEmpty(dialogBackground, ASSETS.DialogBackground)
dialogBackground.ScaleType = Enum.ScaleType.Stretch
dialogBackground.ZIndex = 10

local dialogText = getOrCreate("TextLabel", dialogPanel, "DialogText")
dialogText.Position = dialogText.Position == UDim2.new() and UDim2.fromScale(0.06, 0.08) or dialogText.Position
dialogText.Size = dialogText.Size == UDim2.new() and UDim2.fromScale(0.88, 0.34) or dialogText.Size
styleText(dialogText, "Здравствуй, странник, ты что-то хотел?", 11)

local answerButton1 = getOrCreate("ImageButton", dialogPanel, "AnswerButton1")
answerButton1.Position = answerButton1.Position == UDim2.new() and UDim2.fromScale(0.06, 0.48) or answerButton1.Position
answerButton1.Size = answerButton1.Size == UDim2.new() and UDim2.fromScale(0.88, 0.20) or answerButton1.Size
answerButton1.BackgroundTransparency = 1
setImageIfEmpty(answerButton1, ASSETS.AnswerButtonBackground)
answerButton1.AutoButtonColor = false
answerButton1.ScaleType = Enum.ScaleType.Stretch
answerButton1.ZIndex = 12
createButtonText(answerButton1, "Привет! Хочу узнать, что сегодня предложишь", 13)

local answerButton2 = getOrCreate("ImageButton", dialogPanel, "AnswerButton2")
answerButton2.Position = answerButton2.Position == UDim2.new() and UDim2.fromScale(0.06, 0.72) or answerButton2.Position
answerButton2.Size = answerButton2.Size == UDim2.new() and UDim2.fromScale(0.88, 0.18) or answerButton2.Size
answerButton2.BackgroundTransparency = 1
setImageIfEmpty(answerButton2, ASSETS.AnswerButtonBackground)
answerButton2.AutoButtonColor = false
answerButton2.ScaleType = Enum.ScaleType.Stretch
answerButton2.ZIndex = 12
createButtonText(answerButton2, "Не, сори, я беден", 13)

local offersPanel = getOrCreate("Frame", packTraderFrame, "OffersPanel")
offersPanel.Visible = false
offersPanel.Position = offersPanel.Position == UDim2.new() and UDim2.fromScale(0.36, 0.08) or offersPanel.Position
offersPanel.Size = offersPanel.Size == UDim2.new() and UDim2.fromScale(0.58, 0.78) or offersPanel.Size
offersPanel.BackgroundTransparency = 1
offersPanel.ClipsDescendants = true
offersPanel.ZIndex = 15

local offersBackground = getOrCreate("ImageLabel", offersPanel, "OffersBackground")
offersBackground.Size = UDim2.fromScale(1, 1)
offersBackground.BackgroundTransparency = 1
setImageIfEmpty(offersBackground, ASSETS.OffersBackground)
offersBackground.ScaleType = Enum.ScaleType.Stretch
offersBackground.ZIndex = 15

local offerTitleText = getOrCreate("TextLabel", offersPanel, "OfferTitleText")
offerTitleText.Position = offerTitleText.Position == UDim2.new() and UDim2.fromScale(0.05, 0.05) or offerTitleText.Position
offerTitleText.Size = offerTitleText.Size == UDim2.new() and UDim2.fromScale(0.90, 0.10) or offerTitleText.Size
styleText(offerTitleText, "Сегодня могу предложить:", 16)

local offerTimerText = getOrCreate("TextLabel", offersPanel, "OfferTimerText")
offerTimerText.Position = offerTimerText.Position == UDim2.new() and UDim2.fromScale(0.05, 0.15) or offerTimerText.Position
offerTimerText.Size = offerTimerText.Size == UDim2.new() and UDim2.fromScale(0.90, 0.08) or offerTimerText.Size
styleText(offerTimerText, "Обновление через: 60s", 16)

local offerItemsFrame = getOrCreate("Frame", offersPanel, "OfferItemsFrame")
offerItemsFrame.Position = offerItemsFrame.Position == UDim2.new() and UDim2.fromScale(0.05, 0.26) or offerItemsFrame.Position
offerItemsFrame.Size = offerItemsFrame.Size == UDim2.new() and UDim2.fromScale(0.90, 0.30) or offerItemsFrame.Size
offerItemsFrame.BackgroundTransparency = 1
offerItemsFrame.ZIndex = 16

for index = 1, 4 do
	local slot = getOrCreate("ImageButton", offerItemsFrame, "OfferItemSlot" .. index)
	slot.Size = slot.Size == UDim2.new() and UDim2.fromOffset(90, 105) or slot.Size
	slot.BackgroundTransparency = 1
	slot.Visible = false
	slot.AutoButtonColor = false
	slot.ZIndex = 17

	local slotBackground = getOrCreate("ImageLabel", slot, "SlotBackground")
	slotBackground.Size = UDim2.fromScale(1, 1)
	slotBackground.BackgroundTransparency = 1
	setImageIfEmpty(slotBackground, ASSETS.OfferSlotBackground)
	slotBackground.ScaleType = Enum.ScaleType.Stretch
	slotBackground.ZIndex = 17

	local itemIcon = getOrCreate("ImageLabel", slot, "ItemIcon")
	itemIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	itemIcon.Position = UDim2.fromScale(0.5, 0.42)
	itemIcon.Size = UDim2.fromScale(0.75, 0.65)
	itemIcon.BackgroundTransparency = 1
	itemIcon.ScaleType = Enum.ScaleType.Fit
	itemIcon.ZIndex = 18

	local itemCount = getOrCreate("TextLabel", slot, "ItemCount")
	itemCount.Position = UDim2.fromScale(0, 0.72)
	itemCount.Size = UDim2.fromScale(1, 0.25)
	styleText(itemCount, "x0", 19)
end

local offerPriceText = getOrCreate("TextLabel", offersPanel, "OfferPriceText")
offerPriceText.Position = offerPriceText.Position == UDim2.new() and UDim2.fromScale(0.05, 0.60) or offerPriceText.Position
offerPriceText.Size = offerPriceText.Size == UDim2.new() and UDim2.fromScale(0.90, 0.10) or offerPriceText.Size
styleText(offerPriceText, "Цена: 0 Coins", 16)

local buyOfferButton = getOrCreate("ImageButton", offersPanel, "BuyOfferButton")
buyOfferButton.Position = buyOfferButton.Position == UDim2.new() and UDim2.fromScale(0.08, 0.76) or buyOfferButton.Position
buyOfferButton.Size = buyOfferButton.Size == UDim2.new() and UDim2.fromScale(0.38, 0.15) or buyOfferButton.Size
buyOfferButton.BackgroundTransparency = 1
setImageIfEmpty(buyOfferButton, ASSETS.BuyButtonBackground)
buyOfferButton.AutoButtonColor = false
buyOfferButton.ScaleType = Enum.ScaleType.Stretch
buyOfferButton.ZIndex = 18
createButtonText(buyOfferButton, "Купить", 19)

local backToDialogButton = getOrCreate("ImageButton", offersPanel, "BackToDialogButton")
backToDialogButton.Position = backToDialogButton.Position == UDim2.new() and UDim2.fromScale(0.54, 0.76) or backToDialogButton.Position
backToDialogButton.Size = backToDialogButton.Size == UDim2.new() and UDim2.fromScale(0.38, 0.15) or backToDialogButton.Size
backToDialogButton.BackgroundTransparency = 1
setImageIfEmpty(backToDialogButton, ASSETS.BackButtonBackground)
backToDialogButton.AutoButtonColor = false
backToDialogButton.ScaleType = Enum.ScaleType.Stretch
backToDialogButton.ZIndex = 18
createButtonText(backToDialogButton, "Назад", 19)

local traderTooltip = getOrCreate("Frame", packTraderFrame, "TraderTooltip")
traderTooltip.Visible = false
traderTooltip.Size = traderTooltip.Size == UDim2.new() and UDim2.fromOffset(220, 95) or traderTooltip.Size
traderTooltip.BackgroundTransparency = 1
traderTooltip.ZIndex = 100

local tooltipBackground = getOrCreate("ImageLabel", traderTooltip, "TooltipBackground")
tooltipBackground.Size = UDim2.fromScale(1, 1)
tooltipBackground.BackgroundTransparency = 1
setImageIfEmpty(tooltipBackground, ASSETS.TooltipBackground)
tooltipBackground.ScaleType = Enum.ScaleType.Stretch
tooltipBackground.ZIndex = 100

local tooltipName = getOrCreate("TextLabel", traderTooltip, "TooltipName")
tooltipName.Position = tooltipName.Position == UDim2.new() and UDim2.fromOffset(12, 10) or tooltipName.Position
tooltipName.Size = tooltipName.Size == UDim2.new() and UDim2.new(1, -24, 0, 32) or tooltipName.Size
styleText(tooltipName, "Item", 101)

local tooltipBoost = getOrCreate("TextLabel", traderTooltip, "TooltipBoost")
tooltipBoost.Position = tooltipBoost.Position == UDim2.new() and UDim2.fromOffset(12, 48) or tooltipBoost.Position
tooltipBoost.Size = tooltipBoost.Size == UDim2.new() and UDim2.new(1, -24, 0, 36) or tooltipBoost.Size
styleText(tooltipBoost, "Boost", 101)

print("PackTrader GUI structure created successfully")

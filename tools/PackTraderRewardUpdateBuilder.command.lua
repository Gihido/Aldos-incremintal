-- PackTrader reward update GUI builder for Roblox Studio Command Bar.
-- Paste/run this once in Studio: View -> Command Bar.
-- It only adds missing children under StarterGui.InventoryGui and never recreates InventoryGui.

local ASSETS = {
	RewardBackground = "rbxassetid://0",
	RewardSlotBackground = "rbxassetid://0",
	FallingCoinImage = "rbxassetid://0",

	DarkFadeImage = "rbxassetid://0",
	MistFadeImage = "rbxassetid://0",

	PositiveAnswerButtonBackground = "rbxassetid://0",
	NegativeAnswerButtonBackground = "rbxassetid://0",

	SoldOutBackground = "rbxassetid://0",
}

local StarterGui = game:GetService("StarterGui")
local inventoryGui = StarterGui:FindFirstChild("InventoryGui")
local inventoryMain = inventoryGui and inventoryGui:FindFirstChild("InventoryMain")
local inventoryContent = inventoryMain and inventoryMain:FindFirstChild("InventoryContent")
local packTraderFrame = inventoryContent and inventoryContent:FindFirstChild("PackTraderFrame")

if not packTraderFrame then
	warn("PackTraderFrame was not found at StarterGui.InventoryGui.InventoryMain.InventoryContent.PackTraderFrame")
	return
end

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing, false
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance, true
end

local function applyTextDefaults(label)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Arcade
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.2
end

local function ensureTextConstraint(label, minSize, maxSize)
	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
	if not constraint then
		constraint = Instance.new("UITextSizeConstraint")
		constraint.Parent = label
	end
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	return constraint
end

local function ensureButtonText(button, defaultText)
	if not button then
		return nil
	end

	local buttonText = button:FindFirstChild("ButtonText")
	if not buttonText then
		buttonText = Instance.new("TextLabel")
		buttonText.Name = "ButtonText"
		buttonText.Parent = button
	end

	buttonText.Size = UDim2.fromScale(1, 1)
	buttonText.Position = UDim2.fromScale(0, 0)
	buttonText.BackgroundTransparency = 1
	buttonText.Text = buttonText.Text ~= "" and buttonText.Text or (defaultText or "")
	buttonText.Font = Enum.Font.Arcade
	buttonText.TextScaled = true
	buttonText.TextWrapped = true
	buttonText.TextXAlignment = Enum.TextXAlignment.Center
	buttonText.TextYAlignment = Enum.TextYAlignment.Center
	buttonText.TextColor3 = Color3.fromRGB(255, 255, 255)
	buttonText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	buttonText.TextStrokeTransparency = 0.2
	buttonText.ZIndex = math.max(buttonText.ZIndex, (button:IsA("GuiObject") and button.ZIndex or 1) + 1)
	ensureTextConstraint(buttonText, 10, 22)
	return buttonText
end

local offersPanel = packTraderFrame:FindFirstChild("OffersPanel")
if offersPanel then
	local soldOutText = getOrCreate(offersPanel, "TextLabel", "SoldOutText")
	soldOutText.Visible = false
	soldOutText.AnchorPoint = Vector2.new(0.5, 0.5)
	soldOutText.Position = UDim2.fromScale(0.5, 0.50)
	soldOutText.Size = UDim2.new(0.9, 0, 0, 90)
	applyTextDefaults(soldOutText)
	soldOutText.Text = "Это предложение уже было куплено"
	soldOutText.ZIndex = 80
	ensureTextConstraint(soldOutText, 12, 34)

	local fallingCoinsLayer = getOrCreate(offersPanel, "Frame", "FallingCoinsLayer")
	fallingCoinsLayer.BackgroundTransparency = 1
	fallingCoinsLayer.Size = UDim2.fromScale(1, 1)
	fallingCoinsLayer.Position = UDim2.fromScale(0, 0)
	fallingCoinsLayer.ClipsDescendants = true
	fallingCoinsLayer.Active = false
	fallingCoinsLayer.ZIndex = 16
else
	warn("OffersPanel is missing under PackTraderFrame")
end

local rewardOverlay = getOrCreate(packTraderFrame, "Frame", "PurchaseRewardOverlay")
rewardOverlay.Visible = false
rewardOverlay.BackgroundTransparency = 1
rewardOverlay.Size = UDim2.fromScale(1, 1)
rewardOverlay.Position = UDim2.fromScale(0, 0)
rewardOverlay.Active = true
rewardOverlay.ZIndex = 200

local rewardClickCatcher = getOrCreate(rewardOverlay, "TextButton", "RewardClickCatcher")
rewardClickCatcher.Size = UDim2.fromScale(1, 1)
rewardClickCatcher.Position = UDim2.fromScale(0, 0)
rewardClickCatcher.BackgroundTransparency = 1
rewardClickCatcher.Text = ""
rewardClickCatcher.AutoButtonColor = false
rewardClickCatcher.Active = true
rewardClickCatcher.ZIndex = 200

local rewardPanel = getOrCreate(rewardOverlay, "Frame", "PurchaseRewardPanel")
rewardPanel.AnchorPoint = Vector2.new(0.5, 0.5)
rewardPanel.Position = UDim2.fromScale(0.5, 0.5)
rewardPanel.Size = UDim2.fromScale(0.68, 0.62)
rewardPanel.BackgroundTransparency = 1
rewardPanel.Active = true
rewardPanel.ClipsDescendants = true
rewardPanel.ZIndex = 210

local rewardPulseScale = rewardPanel:FindFirstChild("RewardPulseScale")
if not rewardPulseScale then
	rewardPulseScale = Instance.new("UIScale")
	rewardPulseScale.Name = "RewardPulseScale"
	rewardPulseScale.Parent = rewardPanel
end
rewardPulseScale.Scale = 1

local rewardBackground = getOrCreate(rewardPanel, "ImageLabel", "RewardBackground")
rewardBackground.Size = UDim2.fromScale(1, 1)
rewardBackground.Position = UDim2.fromScale(0, 0)
rewardBackground.BackgroundTransparency = 1
rewardBackground.Image = ASSETS.RewardBackground
rewardBackground.ScaleType = Enum.ScaleType.Stretch
rewardBackground.ZIndex = 211

local rewardFallingCoinsLayer = getOrCreate(rewardPanel, "Frame", "RewardFallingCoinsLayer")
rewardFallingCoinsLayer.Size = UDim2.fromScale(1, 1)
rewardFallingCoinsLayer.Position = UDim2.fromScale(0, 0)
rewardFallingCoinsLayer.BackgroundTransparency = 1
rewardFallingCoinsLayer.ClipsDescendants = true
rewardFallingCoinsLayer.Active = false
rewardFallingCoinsLayer.ZIndex = 215

local rewardTitleText = getOrCreate(rewardPanel, "TextLabel", "RewardTitleText")
rewardTitleText.Position = UDim2.fromScale(0.08, 0.06)
rewardTitleText.Size = UDim2.fromScale(0.84, 0.12)
applyTextDefaults(rewardTitleText)
rewardTitleText.Text = "Получено:"
rewardTitleText.ZIndex = 230
ensureTextConstraint(rewardTitleText, 12, 34)

local rewardItemsFrame = getOrCreate(rewardPanel, "Frame", "RewardItemsFrame")
rewardItemsFrame.Position = UDim2.fromScale(0.08, 0.22)
rewardItemsFrame.Size = UDim2.fromScale(0.84, 0.46)
rewardItemsFrame.BackgroundTransparency = 1
rewardItemsFrame.ZIndex = 230

for index = 1, 4 do
	local slot = getOrCreate(rewardItemsFrame, "ImageButton", "RewardItemSlot" .. index)
	slot.Visible = false
	slot.Size = UDim2.fromOffset(95, 110)
	slot.BackgroundTransparency = 1
	slot.AutoButtonColor = false
	slot.Active = true
	slot.ZIndex = 231

	local slotBackground = getOrCreate(slot, "ImageLabel", "SlotBackground")
	slotBackground.Size = UDim2.fromScale(1, 1)
	slotBackground.Position = UDim2.fromScale(0, 0)
	slotBackground.BackgroundTransparency = 1
	slotBackground.Image = ASSETS.RewardSlotBackground
	slotBackground.ScaleType = Enum.ScaleType.Stretch
	slotBackground.ZIndex = 231

	local itemIcon = getOrCreate(slot, "ImageLabel", "ItemIcon")
	itemIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	itemIcon.Position = UDim2.fromScale(0.5, 0.42)
	itemIcon.Size = UDim2.fromScale(0.76, 0.66)
	itemIcon.BackgroundTransparency = 1
	itemIcon.Image = "rbxassetid://0"
	itemIcon.ScaleType = Enum.ScaleType.Fit
	itemIcon.ZIndex = 232

	local itemCount = getOrCreate(slot, "TextLabel", "ItemCount")
	itemCount.Position = UDim2.fromScale(0, 0.72)
	itemCount.Size = UDim2.fromScale(1, 0.25)
	applyTextDefaults(itemCount)
	itemCount.Text = "x0"
	itemCount.ZIndex = 233
	ensureTextConstraint(itemCount, 10, 24)
end

local rewardHintText = getOrCreate(rewardPanel, "TextLabel", "RewardHintText")
rewardHintText.AnchorPoint = Vector2.new(0.5, 1)
rewardHintText.Position = UDim2.fromScale(0.5, 0.94)
rewardHintText.Size = UDim2.fromScale(0.88, 0.12)
applyTextDefaults(rewardHintText)
rewardHintText.Text = "Нажмите, чтобы продолжить"
rewardHintText.ZIndex = 230
ensureTextConstraint(rewardHintText, 10, 24)

local introOverlay = getOrCreate(packTraderFrame, "Frame", "IntroOverlay")
introOverlay.Visible = false
introOverlay.Size = UDim2.fromScale(1, 1)
introOverlay.Position = UDim2.fromScale(0, 0)
introOverlay.BackgroundTransparency = 1
introOverlay.Active = false
introOverlay.ZIndex = 300

local darkFade = getOrCreate(introOverlay, "ImageLabel", "DarkFade")
darkFade.Size = UDim2.fromScale(1, 1)
darkFade.Position = UDim2.fromScale(0, 0)
darkFade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
darkFade.BackgroundTransparency = 0
darkFade.Image = ASSETS.DarkFadeImage
darkFade.ImageTransparency = 1
darkFade.ZIndex = 301

local mistFade = getOrCreate(introOverlay, "ImageLabel", "MistFade")
mistFade.Size = UDim2.fromScale(1, 1)
mistFade.Position = UDim2.fromScale(0, 0)
mistFade.BackgroundTransparency = 1
mistFade.Image = ASSETS.MistFadeImage
mistFade.ImageTransparency = 1
mistFade.ScaleType = Enum.ScaleType.Stretch
mistFade.ZIndex = 302

local dialogPanel = packTraderFrame:FindFirstChild("DialogPanel")
if dialogPanel then
	local dialogText = dialogPanel:FindFirstChild("DialogText")
	local traderNameText = getOrCreate(dialogPanel, "TextLabel", "TraderNameText")
	traderNameText.Position = UDim2.fromScale(0.06, 0.02)
	traderNameText.Size = UDim2.fromScale(0.5, 0.12)
	applyTextDefaults(traderNameText)
	traderNameText.Text = "Торговец"
	traderNameText.TextXAlignment = Enum.TextXAlignment.Left
	traderNameText.ZIndex = (dialogText and dialogText.ZIndex or 20) + 1
	ensureTextConstraint(traderNameText, 10, 24)

	local answerButton1 = getOrCreate(dialogPanel, "ImageButton", "AnswerButton1")
	answerButton1.Image = ASSETS.PositiveAnswerButtonBackground
	answerButton1.BackgroundTransparency = 1
	answerButton1.AutoButtonColor = true
	answerButton1.Active = true
	ensureButtonText(answerButton1, "")

	local answerButton2 = getOrCreate(dialogPanel, "ImageButton", "AnswerButton2")
	answerButton2.Image = ASSETS.NegativeAnswerButtonBackground
	answerButton2.BackgroundTransparency = 1
	answerButton2.AutoButtonColor = true
	answerButton2.Active = true
	ensureButtonText(answerButton2, "")
else
	warn("DialogPanel is missing under PackTraderFrame")
end

if offersPanel then
	local buyOfferButton = getOrCreate(offersPanel, "ImageButton", "BuyOfferButton")
	buyOfferButton.BackgroundTransparency = 1
	buyOfferButton.AutoButtonColor = true
	buyOfferButton.Active = true
	ensureButtonText(buyOfferButton, "Купить")

	local backToDialogButton = getOrCreate(offersPanel, "ImageButton", "BackToDialogButton")
	backToDialogButton.BackgroundTransparency = 1
	backToDialogButton.AutoButtonColor = true
	backToDialogButton.Active = true
	ensureButtonText(backToDialogButton, "Назад")
end

print("PackTrader reward update GUI elements created successfully")

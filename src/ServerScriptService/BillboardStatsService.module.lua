local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("Shared")
local FormatNumber = require(shared:WaitForChild("FormatNumber"))
local UIAssetConfig = require(shared:WaitForChild("UIAssetConfig"))

local BILLBOARD_NAME = "CoinsBillboard"
local LABEL_NAME = "CoinsText"

local BillboardStatsService = {}

local hookedPlayers = {}
local coinConnections = {}

local function getGameFont()
	return (UIAssetConfig.Fonts and UIAssetConfig.Fonts.Main) or Enum.Font.Arcade
end

local function getCoinsValue(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")

	return coins and coins.Value or 0
end

local function getBillboardAdornee(character)
	return character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
end

local function applyCoinsGradient(textObject)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "CoinsBillboardGradient"
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 90)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 145, 35)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 245, 90)),
	})
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = textObject

	task.spawn(function()
		while gradient.Parent == textObject do
			gradient.Offset = Vector2.new(-1, 0)
			local tween = TweenService:Create(gradient, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Offset = Vector2.new(1, 0),
			})
			tween:Play()
			tween.Completed:Wait()
		end
	end)
end

local function updateBillboard(player)
	local character = player.Character
	local billboard = character and character:FindFirstChild(BILLBOARD_NAME, true)
	local label = billboard and billboard:FindFirstChild(LABEL_NAME, true)

	if label then
		label.Text = `Coins: {FormatNumber(getCoinsValue(player))}`
	end
end

local function createBillboard(player)
	local character = player.Character

	if not character then
		return
	end

	local adornee = getBillboardAdornee(character)

	if not adornee then
		return
	end

	local existing = character:FindFirstChild(BILLBOARD_NAME, true)

	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = BILLBOARD_NAME
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120
<<<<<<< codex/fix-position-bug-in-coinvisualclient-uo2oam
	billboard.Size = UDim2.fromOffset(190, 38)
	billboard.StudsOffset = Vector3.new(0, 2.45, 0)
=======
	billboard.Size = UDim2.fromOffset(220, 44)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
>>>>>>> main
	billboard.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Name = LABEL_NAME
<<<<<<< codex/fix-position-bug-in-coinvisualclient-uo2oam
	label.BackgroundTransparency = 1
=======
>>>>>>> main
	label.BorderSizePixel = 0
	label.Font = getGameFont()
	label.Size = UDim2.fromScale(1, 1)
	label.Text = `Coins: {FormatNumber(getCoinsValue(player))}`
	label.TextColor3 = Color3.fromRGB(255, 235, 90)
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(35, 20, 0)
	label.TextStrokeTransparency = 0.25
<<<<<<< codex/fix-position-bug-in-coinvisualclient-uo2oam

	local textSizeConstraint = Instance.new("UITextSizeConstraint")
	textSizeConstraint.MinTextSize = 10
	textSizeConstraint.MaxTextSize = 20
	textSizeConstraint.Parent = label

=======
>>>>>>> main
	label.Parent = billboard

	applyCoinsGradient(label)
end

local function hookCoinsChanged(player)
	if coinConnections[player] then
		coinConnections[player]:Disconnect()
		coinConnections[player] = nil
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")

	if coins then
		coinConnections[player] = coins:GetPropertyChangedSignal("Value"):Connect(function()
			updateBillboard(player)
		end)
	end
end

local function setupPlayer(player)
	if hookedPlayers[player] then
		return
	end

	hookedPlayers[player] = true

	player.CharacterAdded:Connect(function()
		task.defer(function()
			createBillboard(player)
			hookCoinsChanged(player)
			updateBillboard(player)
		end)
	end)

	player.ChildAdded:Connect(function(child)
		if child.Name == "leaderstats" then
			task.defer(function()
				hookCoinsChanged(player)
				updateBillboard(player)
			end)
		end
	end)

	if player.Character then
		createBillboard(player)
	end

	hookCoinsChanged(player)
	updateBillboard(player)
end

function BillboardStatsService.Init()
	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player)
		hookedPlayers[player] = nil

		if coinConnections[player] then
			coinConnections[player]:Disconnect()
			coinConnections[player] = nil
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayer(player)
	end
end

return BillboardStatsService

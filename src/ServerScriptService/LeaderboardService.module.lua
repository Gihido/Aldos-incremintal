local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent.DataService)
local shared = ReplicatedStorage:WaitForChild("Shared")
local FormatNumber = require(shared:WaitForChild("FormatNumber"))
local UIAssetConfig = require(shared:WaitForChild("UIAssetConfig"))
local BOARD_UPDATE_SECONDS = 1.5

local function hasCustomAssetId(assetId)
	return type(assetId) == "string" and assetId ~= "" and assetId ~= "rbxassetid://0"
end
local function getGameFont()
	return (UIAssetConfig.Fonts and UIAssetConfig.Fonts.Main) or Enum.Font.Arcade
end

local function applyAnimatedTextGradient(textObject)
	if not textObject or not (textObject:IsA("TextLabel") or textObject:IsA("TextButton") or textObject:IsA("TextBox")) then
		return nil
	end

	local gradient = Instance.new("UIGradient")
	gradient.Name = "AnimatedTextGradient"
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.48, Color3.fromRGB(105, 105, 105)),
		ColorSequenceKeypoint.new(0.72, Color3.fromRGB(18, 18, 18)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = textObject

	task.spawn(function()
		while gradient.Parent == textObject do
			gradient.Offset = Vector2.new(-1, 0)
			local tween = TweenService:Create(gradient, TweenInfo.new(2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Offset = Vector2.new(1, 0),
			})
			tween:Play()
			tween.Completed:Wait()
		end
	end)

	return gradient
end

local MAX_LEADERBOARD_ROWS = 100

local LeaderboardService = {}

local rowLabels = {}
local updateLoopStarted = false
local coinChangedConnections = {}
local renderBoard

local function createCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent

	return corner
end

local function createStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.Parent = parent

	return stroke
end

local function createGradient(parent, colorA, colorB, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(colorA, colorB)
	gradient.Rotation = rotation or 0
	gradient.Parent = parent

	return gradient
end

local function createLeaderstats(player)
	local data = DataService.Get(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local coins = leaderstats:FindFirstChild("Coins")

	if not coins then
		coins = Instance.new("NumberValue")
		coins.Name = "Coins"
		coins.Parent = leaderstats
	end

	coins.Value = data.Coins

	if coinChangedConnections[player] then
		coinChangedConnections[player]:Disconnect()
		coinChangedConnections[player] = nil
	end

	coinChangedConnections[player] = coins:GetPropertyChangedSignal("Value"):Connect(function()
		renderBoard()
	end)
end

local function getCoins(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")

	return coins and coins.Value or 0
end

local function getCurrentServerRows()
	local rows = {}

	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(rows, {
			Name = player.DisplayName,
			Coins = getCoins(player),
		})
	end

	table.sort(rows, function(left, right)
		if left.Coins == right.Coins then
			return left.Name < right.Name
		end

		return left.Coins > right.Coins
	end)

	return rows
end

local function getLeaderboardRows()
	-- Current implementation shows only players in this server.
	-- Later this function can be replaced with OrderedDataStore results for a global top.
	return getCurrentServerRows()
end

local function createTextLabel(parent, name, text, size, position, textXAlignment)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = getGameFont()
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.68
	label.TextXAlignment = textXAlignment or Enum.TextXAlignment.Left
	label.ZIndex = 5
	label.Parent = parent
	applyAnimatedTextGradient(label)

	return label
end

local function createRow(parent, index)
	local row = Instance.new("Frame")
	row.Name = `Row{index}`
	row.BackgroundColor3 = Color3.fromRGB(20, 22, 24)
	row.BackgroundTransparency = index % 2 == 0 and 0.18 or 0.3
	row.BorderSizePixel = 0
	row.LayoutOrder = index
	row.Size = UDim2.new(1, -12, 0, 36)
	row.ZIndex = 4
	row.Parent = parent

	createCorner(row, UDim.new(0, 0))
	createStroke(row, Color3.fromRGB(210, 220, 190), 1, 0.78)
	createGradient(row, Color3.fromRGB(34, 36, 40), Color3.fromRGB(12, 14, 18), 0)

	local place = createTextLabel(row, "Place", "", UDim2.fromScale(0.14, 1), UDim2.fromScale(0.02, 0), Enum.TextXAlignment.Left)
	local name = createTextLabel(row, "Player", "", UDim2.fromScale(0.56, 1), UDim2.fromScale(0.18, 0), Enum.TextXAlignment.Left)
	local coins = createTextLabel(row, "Coins", "", UDim2.fromScale(0.24, 1), UDim2.fromScale(0.74, 0), Enum.TextXAlignment.Right)

	return {
		Frame = row,
		Place = place,
		Name = name,
		Coins = coins,
	}
end

local function styleRow(row, index)
	local color = Color3.fromRGB(242, 242, 242)
	local background = Color3.fromRGB(20, 22, 24)
	local strokeColor = Color3.fromRGB(210, 220, 190)
	local strokeTransparency = 0.78

	if index == 1 then
		color = Color3.fromRGB(255, 235, 105)
		background = Color3.fromRGB(78, 66, 20)
		strokeColor = Color3.fromRGB(255, 245, 170)
		strokeTransparency = 0.08
	elseif index == 2 then
		color = Color3.fromRGB(232, 238, 255)
		background = Color3.fromRGB(52, 56, 66)
		strokeColor = Color3.fromRGB(245, 247, 255)
		strokeTransparency = 0.18
	elseif index == 3 then
		color = Color3.fromRGB(255, 195, 125)
		background = Color3.fromRGB(70, 44, 24)
		strokeColor = Color3.fromRGB(255, 210, 145)
		strokeTransparency = 0.22
	end

	row.Frame.BackgroundColor3 = background
	row.Frame.UIStroke.Color = strokeColor
	row.Frame.UIStroke.Transparency = strokeTransparency
	row.Place.TextColor3 = color
	row.Name.TextColor3 = color
	row.Coins.TextColor3 = color
end

local function setupBoard()
	local boardPart = Workspace:FindFirstChild("LeaderstatsBoard")

	if not boardPart then
		warn("LeaderstatsBoard was not found in Workspace; leaderboard GUI will be skipped")
		return false
	end

	local surfaceGui = boardPart:FindFirstChild("LeaderboardSurfaceGui")

	if not surfaceGui then
		surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "LeaderboardSurfaceGui"
		surfaceGui.Face = Enum.NormalId.Front
		surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		surfaceGui.CanvasSize = Vector2.new(1200, 700)
		surfaceGui.PixelsPerStud = 75
		surfaceGui.LightInfluence = 0
		surfaceGui.Parent = boardPart
	else
		surfaceGui:ClearAllChildren()
		surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		surfaceGui.CanvasSize = Vector2.new(1200, 700)
		surfaceGui.PixelsPerStud = 75
		surfaceGui.LightInfluence = 0
	end

	rowLabels = {}

	local leaderboardConfig = UIAssetConfig.Leaderboard or {}
	if hasCustomAssetId(leaderboardConfig.BackgroundImage) then
		local backgroundImage = Instance.new("ImageLabel")
		backgroundImage.Name = "BackgroundImage"
		backgroundImage.Size = UDim2.fromScale(1, 1)
		backgroundImage.Position = UDim2.fromScale(0, 0)
		backgroundImage.BackgroundTransparency = 1
		backgroundImage.Image = leaderboardConfig.BackgroundImage
		backgroundImage.ImageTransparency = 0.08
		backgroundImage.ScaleType = Enum.ScaleType.Stretch
		backgroundImage.ZIndex = 0
		backgroundImage.Parent = surfaceGui
	end

	local darkOverlay = Instance.new("Frame")
	darkOverlay.Name = "DarkOverlay"
	darkOverlay.BackgroundColor3 = Color3.fromRGB(4, 5, 7)
	darkOverlay.BackgroundTransparency = hasCustomAssetId(leaderboardConfig.BackgroundImage) and 0.86 or 0.04
	darkOverlay.BorderSizePixel = 0
	darkOverlay.Size = UDim2.fromScale(1, 1)
	darkOverlay.ZIndex = 1
	darkOverlay.Parent = surfaceGui

	local panel = Instance.new("Frame")
	panel.Name = "LeaderboardPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(10, 12, 15)
	panel.BackgroundTransparency = hasCustomAssetId(leaderboardConfig.BackgroundImage) and 0.18 or 0.08
	panel.BorderSizePixel = 0
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.94, 0.92)
	panel.ZIndex = 2
	panel.Parent = surfaceGui

	createCorner(panel, UDim.new(0, 0))
	createStroke(panel, Color3.fromRGB(225, 230, 180), 3, 0.08)
	createGradient(panel, Color3.fromRGB(28, 32, 34), Color3.fromRGB(8, 9, 12), 90)

	local title = createTextLabel(panel, "Title", "ТОП 100 ИГРОКОВ", UDim2.fromScale(0.96, 0.075), UDim2.fromScale(0.02, 0.02), Enum.TextXAlignment.Center)
	title.Font = getGameFont()
	title.TextColor3 = Color3.fromRGB(235, 235, 210)
	title.TextStrokeTransparency = 0.38

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundColor3 = Color3.fromRGB(210, 220, 150)
	header.BackgroundTransparency = 0.08
	header.BorderSizePixel = 0
	header.Position = UDim2.fromScale(0.03, 0.125)
	header.Size = UDim2.fromScale(0.94, 0.058)
	header.ZIndex = 3
	header.Parent = panel

	createCorner(header, UDim.new(0, 0))
	createStroke(header, Color3.fromRGB(255, 255, 255), 2, 0.24)
	createGradient(header, Color3.fromRGB(255, 245, 165), Color3.fromRGB(150, 170, 105), 0)

	local placeHeader = createTextLabel(header, "PlaceHeader", "Место", UDim2.fromScale(0.14, 1), UDim2.fromScale(0.02, 0), Enum.TextXAlignment.Left)
	local playerHeader = createTextLabel(header, "PlayerHeader", "Игрок", UDim2.fromScale(0.56, 1), UDim2.fromScale(0.18, 0), Enum.TextXAlignment.Left)
	local coinsHeader = createTextLabel(header, "CoinsHeader", "Coins", UDim2.fromScale(0.24, 1), UDim2.fromScale(0.74, 0), Enum.TextXAlignment.Right)

	for _, label in ipairs({ placeHeader, playerHeader, coinsHeader }) do
		label.TextColor3 = Color3.fromRGB(18, 20, 12)
		label.TextStrokeTransparency = 1
	end

	local list = Instance.new("ScrollingFrame")
	list.Name = "Rows"
	list.Active = true
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.CanvasSize = UDim2.fromOffset(0, MAX_LEADERBOARD_ROWS * 42)
	list.Position = UDim2.fromScale(0.03, 0.20)
	list.ScrollBarImageColor3 = Color3.fromRGB(225, 230, 180)
	list.ScrollBarThickness = 8
	list.Size = UDim2.fromScale(0.94, 0.765)
	list.ZIndex = 3
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for index = 1, MAX_LEADERBOARD_ROWS do
		rowLabels[index] = createRow(list, index)
	end

	return true
end

local function animateRow(row)
	row.Frame.BackgroundTransparency = 0.55
	TweenService:Create(row.Frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = row.Frame.LayoutOrder % 2 == 0 and 0.18 or 0.3,
	}):Play()
end

renderBoard = function()
	if #rowLabels == 0 then
		return
	end

	local rows = getLeaderboardRows()

	for index = 1, MAX_LEADERBOARD_ROWS do
		local row = rowLabels[index]
		local data = rows[index]

		if data then
			local previousText = row.Name.Text .. row.Coins.Text
			row.Frame.Visible = true
			row.Place.Text = `#{index}`
			row.Name.Text = data.Name
			row.Coins.Text = FormatNumber(data.Coins)
			styleRow(row, index)

			if previousText ~= row.Name.Text .. row.Coins.Text then
				animateRow(row)
			end
		else
			row.Frame.Visible = false
		end
	end
end

local function startUpdateLoop()
	if updateLoopStarted then
		return
	end

	updateLoopStarted = true
	task.spawn(function()
		while true do
			renderBoard()
			task.wait(BOARD_UPDATE_SECONDS)
		end
	end)
end

function LeaderboardService.Refresh()
	renderBoard()
end

function LeaderboardService.SetCoins(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")

	if coins then
		coins.Value = amount
	end

	LeaderboardService.Refresh()
end

function LeaderboardService.Init()
	setupBoard()
	startUpdateLoop()

	Players.PlayerAdded:Connect(function(player)
		createLeaderstats(player)
		LeaderboardService.Refresh()
	end)

	Players.PlayerRemoving:Connect(function(player)
		if coinChangedConnections[player] then
			coinChangedConnections[player]:Disconnect()
			coinChangedConnections[player] = nil
		end

		task.defer(LeaderboardService.Refresh)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		createLeaderstats(player)
	end

	LeaderboardService.Refresh()
end

return LeaderboardService

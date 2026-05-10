local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent.DataService)

local BOARD_BACKGROUND_IMAGE_ID = "rbxassetid://0"
local BOARD_UPDATE_SECONDS = 2.5
local MAX_LEADERBOARD_ROWS = 100

local LeaderboardService = {}

local rowLabels = {}
local updateLoopStarted = false

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

local function createLeaderstats(player)
	local data = DataService.Load(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local coins = leaderstats:FindFirstChild("Coins")

	if not coins then
		coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Parent = leaderstats
	end

	coins.Value = data.Coins
end

local function getCoins(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")

	return coins and coins.Value or 0
end

local function getCurrentServerRows()
	local rows = {}

	for _, player in Players:GetPlayers() do
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
	label.Font = Enum.Font.GothamBold
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.55
	label.TextXAlignment = textXAlignment or Enum.TextXAlignment.Left
	label.ZIndex = 5
	label.Parent = parent

	return label
end

local function createRow(parent, index)
	local row = Instance.new("Frame")
	row.Name = `Row{index}`
	row.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	row.BackgroundTransparency = index % 2 == 0 and 0.22 or 0.34
	row.BorderSizePixel = 0
	row.LayoutOrder = index
	row.Size = UDim2.new(1, -12, 0, 34)
	row.ZIndex = 4
	row.Parent = parent

	createCorner(row, UDim.new(0, 8))
	createStroke(row, Color3.fromRGB(255, 230, 120), 1, 0.72)

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
	local color = Color3.fromRGB(255, 255, 255)
	local background = Color3.fromRGB(18, 18, 24)
	local strokeColor = Color3.fromRGB(255, 230, 120)
	local strokeTransparency = 0.72

	if index == 1 then
		color = Color3.fromRGB(255, 235, 80)
		background = Color3.fromRGB(86, 66, 10)
		strokeColor = Color3.fromRGB(255, 245, 150)
		strokeTransparency = 0.12
	elseif index == 2 then
		color = Color3.fromRGB(230, 235, 255)
		background = Color3.fromRGB(54, 58, 74)
		strokeColor = Color3.fromRGB(245, 245, 255)
		strokeTransparency = 0.25
	elseif index == 3 then
		color = Color3.fromRGB(255, 190, 115)
		background = Color3.fromRGB(72, 42, 20)
		strokeColor = Color3.fromRGB(255, 205, 135)
		strokeTransparency = 0.3
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
		surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surfaceGui.PixelsPerStud = 65
		surfaceGui.LightInfluence = 0
		surfaceGui.Parent = boardPart
	else
		surfaceGui:ClearAllChildren()
	end

	rowLabels = {}

	local backgroundImage = Instance.new("ImageLabel")
	backgroundImage.Name = "BackgroundImage"
	backgroundImage.Size = UDim2.fromScale(1, 1)
	backgroundImage.Position = UDim2.fromScale(0, 0)
	backgroundImage.BackgroundTransparency = 1
	backgroundImage.Image = BOARD_BACKGROUND_IMAGE_ID
	backgroundImage.ImageTransparency = 0.4
	backgroundImage.ScaleType = Enum.ScaleType.Stretch
	backgroundImage.ZIndex = 0
	backgroundImage.Parent = surfaceGui

	local darkOverlay = Instance.new("Frame")
	darkOverlay.Name = "DarkOverlay"
	darkOverlay.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
	darkOverlay.BackgroundTransparency = 0.25
	darkOverlay.BorderSizePixel = 0
	darkOverlay.Size = UDim2.fromScale(1, 1)
	darkOverlay.ZIndex = 1
	darkOverlay.Parent = surfaceGui

	local panel = Instance.new("Frame")
	panel.Name = "LeaderboardPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
	panel.BackgroundTransparency = 0.16
	panel.BorderSizePixel = 0
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.94, 0.92)
	panel.ZIndex = 2
	panel.Parent = surfaceGui

	createCorner(panel, UDim.new(0, 18))
	createStroke(panel, Color3.fromRGB(255, 230, 120), 3, 0.08)

	local title = createTextLabel(panel, "Title", "ТОП 100 ИГРОКОВ", UDim2.fromScale(0.96, 0.12), UDim2.fromScale(0.02, 0.015), Enum.TextXAlignment.Center)
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = Color3.fromRGB(255, 235, 80)
	title.TextStrokeTransparency = 0.25

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundColor3 = Color3.fromRGB(255, 221, 64)
	header.BackgroundTransparency = 0.1
	header.BorderSizePixel = 0
	header.Position = UDim2.fromScale(0.03, 0.16)
	header.Size = UDim2.fromScale(0.94, 0.065)
	header.ZIndex = 3
	header.Parent = panel

	createCorner(header, UDim.new(0, 10))
	createStroke(header, Color3.fromRGB(255, 255, 255), 2, 0.2)

	local placeHeader = createTextLabel(header, "PlaceHeader", "Место", UDim2.fromScale(0.14, 1), UDim2.fromScale(0.02, 0), Enum.TextXAlignment.Left)
	local playerHeader = createTextLabel(header, "PlayerHeader", "Игрок", UDim2.fromScale(0.56, 1), UDim2.fromScale(0.18, 0), Enum.TextXAlignment.Left)
	local coinsHeader = createTextLabel(header, "CoinsHeader", "Coins", UDim2.fromScale(0.24, 1), UDim2.fromScale(0.74, 0), Enum.TextXAlignment.Right)

	for _, label in { placeHeader, playerHeader, coinsHeader } do
		label.TextColor3 = Color3.fromRGB(20, 18, 8)
		label.TextStrokeTransparency = 1
	end

	local list = Instance.new("ScrollingFrame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.CanvasSize = UDim2.fromOffset(0, MAX_LEADERBOARD_ROWS * 40)
	list.Position = UDim2.fromScale(0.03, 0.245)
	list.ScrollBarImageColor3 = Color3.fromRGB(255, 235, 120)
	list.ScrollBarThickness = 8
	list.Size = UDim2.fromScale(0.94, 0.72)
	list.ZIndex = 3
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for index = 1, MAX_LEADERBOARD_ROWS do
		rowLabels[index] = createRow(list, index)
	end

	return true
end

local function renderBoard()
	if #rowLabels == 0 then
		return
	end

	local rows = getLeaderboardRows()

	for index = 1, MAX_LEADERBOARD_ROWS do
		local row = rowLabels[index]
		local data = rows[index]

		if data then
			row.Frame.Visible = true
			row.Place.Text = `#{index}`
			row.Name.Text = data.Name
			row.Coins.Text = tostring(data.Coins)
			styleRow(row, index)
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

function LeaderboardService.SetCoins(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")

	if coins then
		coins.Value = amount
	end

	renderBoard()
end

function LeaderboardService.Init()
	setupBoard()
	startUpdateLoop()

	Players.PlayerAdded:Connect(function(player)
		createLeaderstats(player)
		renderBoard()
	end)

	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player)
		task.defer(renderBoard)
	end)

	for _, player in Players:GetPlayers() do
		createLeaderstats(player)
	end

	renderBoard()
end

return LeaderboardService

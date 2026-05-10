local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local boardGui
local boardLabel

local function createLeaderstats(player)
	local data = DataService.Load(player)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.Coins
	coins.Parent = leaderstats
end

local function getCoins(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")

	return coins and coins.Value or 0
end

local function getSortedCoinRows()
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

local function renderBoard()
	if not boardLabel then
		return
	end

	local lines = { "Coin Leaders" }
	local rows = getSortedCoinRows()

	for index = 1, math.min(5, #rows) do
		local row = rows[index]
		table.insert(lines, `{index}. {row.Name}: {row.Coins}`)
	end

	if #rows == 0 then
		table.insert(lines, "No players yet")
	end

	boardLabel.Text = table.concat(lines, "\n")
end

local function setupBoard()
	local boardPart = Workspace:WaitForChild("LeaderstatsBoard")

	boardGui = Instance.new("SurfaceGui")
	boardGui.Name = "CoinLeaderboardGui"
	boardGui.Face = Enum.NormalId.Front
	boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	boardGui.PixelsPerStud = 50
	boardGui.Parent = boardPart

	boardLabel = Instance.new("TextLabel")
	boardLabel.Name = "LeaderboardText"
	boardLabel.BackgroundTransparency = 1
	boardLabel.Font = Enum.Font.GothamBold
	boardLabel.Size = UDim2.fromScale(1, 1)
	boardLabel.Text = "Coin Leaders"
	boardLabel.TextColor3 = Color3.fromRGB(255, 235, 120)
	boardLabel.TextScaled = true
	boardLabel.TextStrokeTransparency = 0.3
	boardLabel.Parent = boardGui

	renderBoard()
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

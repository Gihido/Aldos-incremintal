local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local UIAssetConfig = require(shared:WaitForChild("UIAssetConfig"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local collectZoneStateRemote = remotes:WaitForChild("CollectZoneState")

local currentSize = 6
local isVisible = false
local squarePart
local followConnection

local function hasCustomAssetId(assetId)
	return type(assetId) == "string" and assetId ~= "" and assetId ~= "rbxassetid://0"
end

local function getPlayerRoot()
	local character = player.Character

	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function createEdge(parent, name, position, size)
	local edge = Instance.new("Frame")
	edge.Name = name
	edge.BackgroundColor3 = Color3.fromRGB(245, 245, 235)
	edge.BackgroundTransparency = 0.08
	edge.BorderSizePixel = 0
	edge.Position = position
	edge.Size = size
	edge.ZIndex = 5
	edge.Parent = parent

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(90, 90, 90))
	gradient.Rotation = 0
	gradient.Parent = edge

	return edge
end

local function createCollectSquare()
	if squarePart then
		return squarePart
	end

	squarePart = Instance.new("Part")
	squarePart.Name = "CollectSquareVisual"
	squarePart.Anchored = true
	squarePart.CanCollide = false
	squarePart.CanQuery = false
	squarePart.CanTouch = false
	squarePart.CastShadow = false
	squarePart.Color = Color3.fromRGB(130, 130, 130)
	squarePart.Material = Enum.Material.Neon
	squarePart.Size = Vector3.new(currentSize, 0.05, currentSize)
	squarePart.Transparency = 0.72
	squarePart.Parent = Workspace

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "CollectSquareSurface"
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.LightInfluence = 0
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 72
	surfaceGui.Parent = squarePart

	local image = Instance.new("ImageLabel")
	image.Name = "CollectSquareImage"
	image.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
	image.BackgroundTransparency = 0.35
	image.BorderSizePixel = 0
	image.Image = hasCustomAssetId((UIAssetConfig.CollectZone or {}).BackgroundImage) and UIAssetConfig.CollectZone.BackgroundImage or ""
	image.ImageTransparency = hasCustomAssetId(image.Image) and 0.08 or 1
	image.Position = UDim2.fromScale(0, 0)
	image.ScaleType = Enum.ScaleType.Stretch
	image.Size = UDim2.fromScale(1, 1)
	image.ZIndex = 1
	image.Parent = surfaceGui

	createEdge(image, "TopEdge", UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 8))
	createEdge(image, "BottomEdge", UDim2.new(0, 0, 1, -8), UDim2.new(1, 0, 0, 8))
	createEdge(image, "LeftEdge", UDim2.fromScale(0, 0), UDim2.new(0, 8, 1, 0))
	createEdge(image, "RightEdge", UDim2.new(1, -8, 0, 0), UDim2.new(0, 8, 1, 0))

	local selection = Instance.new("SelectionBox")
	selection.Name = "CollectSquareOutline"
	selection.Adornee = squarePart
	selection.Color3 = Color3.fromRGB(255, 255, 245)
	selection.LineThickness = 0.05
	selection.SurfaceTransparency = 1
	selection.Transparency = 0.05
	selection.Parent = squarePart

	return squarePart
end

local function updateSquarePosition()
	if not isVisible or not squarePart then
		return
	end

	local root = getPlayerRoot()

	if not root then
		squarePart.Transparency = 1
		return
	end

	squarePart.Transparency = 0.72
	squarePart.Size = Vector3.new(currentSize, 0.05, currentSize)
	squarePart.CFrame = CFrame.new(root.Position.X, root.Position.Y - 2.85, root.Position.Z)
end

local function setSquareVisible(visible, size)
	isVisible = visible
	currentSize = size or currentSize

	if visible then
		createCollectSquare()
		updateSquarePosition()
	else
		if squarePart then
			squarePart:Destroy()
			squarePart = nil
		end
	end
end

collectZoneStateRemote.OnClientEvent:Connect(function(visible, size)
	setSquareVisible(visible, size)
end)

followConnection = RunService.RenderStepped:Connect(updateSquarePosition)

player.CharacterRemoving:Connect(function()
	setSquareVisible(false)
end)

script.Destroying:Connect(function()
	if followConnection then
		followConnection:Disconnect()
	end

	if squarePart then
		squarePart:Destroy()
	end
end)

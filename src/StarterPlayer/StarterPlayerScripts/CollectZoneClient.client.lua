local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local UIAssetConfig = require(shared:WaitForChild("UIAssetConfig"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local collectZoneStateRemote = remotes:WaitForChild("CollectZoneState")

local currentSize = 3
local isActive = false
local squarePart
local surfaceGui
local imageLabel
local outline
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
		if not squarePart.Parent then
			squarePart.Parent = Workspace
		end

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
	squarePart.Transparency = 1
	squarePart.Parent = Workspace

	surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "CollectSquareSurface"
	surfaceGui.Enabled = false
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.LightInfluence = 0
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 72
	surfaceGui.Parent = squarePart

	imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = "CollectSquareImage"
	imageLabel.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
	imageLabel.BackgroundTransparency = 0.35
	imageLabel.BorderSizePixel = 0
	imageLabel.Image = hasCustomAssetId((UIAssetConfig.CollectZone or {}).BackgroundImage) and UIAssetConfig.CollectZone.BackgroundImage or ""
	imageLabel.ImageTransparency = hasCustomAssetId(imageLabel.Image) and 0.08 or 1
	imageLabel.Position = UDim2.fromScale(0, 0)
	imageLabel.ScaleType = Enum.ScaleType.Stretch
	imageLabel.Size = UDim2.fromScale(1, 1)
	imageLabel.ZIndex = 1
	imageLabel.Parent = surfaceGui

	createEdge(imageLabel, "TopEdge", UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 8))
	createEdge(imageLabel, "BottomEdge", UDim2.new(0, 0, 1, -8), UDim2.new(1, 0, 0, 8))
	createEdge(imageLabel, "LeftEdge", UDim2.fromScale(0, 0), UDim2.new(0, 8, 1, 0))
	createEdge(imageLabel, "RightEdge", UDim2.new(1, -8, 0, 0), UDim2.new(0, 8, 1, 0))

	outline = Instance.new("SelectionBox")
	outline.Name = "CollectSquareOutline"
	outline.Adornee = squarePart
	outline.Color3 = Color3.fromRGB(255, 255, 245)
	outline.LineThickness = 0.05
	outline.SurfaceTransparency = 1
	outline.Transparency = 1
	outline.Parent = squarePart

	return squarePart
end

local function setVisualActive(active)
	createCollectSquare()

	squarePart.Transparency = active and 0.55 or 1

	if surfaceGui then
		surfaceGui.Enabled = active
	end

	if outline then
		outline.Transparency = active and 0.05 or 1
	end
end

local function updateSquarePosition()
	if not isActive then
		return
	end

	createCollectSquare()
	local root = getPlayerRoot()

	if not root then
		setVisualActive(false)
		return
	end

	setVisualActive(true)
	squarePart.Size = Vector3.new(currentSize, 0.05, currentSize)
	squarePart.CFrame = CFrame.new(root.Position.X, root.Position.Y - 2.45, root.Position.Z)
end

local function setSquareVisible(visible, size)
	currentSize = size or currentSize
	isActive = visible == true
	createCollectSquare()
	setVisualActive(isActive)

	if isActive then
		updateSquarePosition()
	end
end

collectZoneStateRemote.OnClientEvent:Connect(function(visible, size)
	setSquareVisible(visible, size)
end)

followConnection = RunService.RenderStepped:Connect(updateSquarePosition)

player.CharacterRemoving:Connect(function()
	setSquareVisible(false)
end)

createCollectSquare()

script.Destroying:Connect(function()
	if followConnection then
		followConnection:Disconnect()
	end

	if squarePart then
		squarePart:Destroy()
	end
end)

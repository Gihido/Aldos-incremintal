local Workspace = game:GetService("Workspace")

local ResponsiveUI = {}

function ResponsiveUI.GetViewportSize()
	local camera = Workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1920, 1080)
end

function ResponsiveUI.IsMobileLike()
	local size = ResponsiveUI.GetViewportSize()
	return math.min(size.X, size.Y) <= 700
end

function ResponsiveUI.GetScreenScale()
	local size = ResponsiveUI.GetViewportSize()
	local minSide = math.min(size.X, size.Y)

	if minSide <= 500 then
		return 0.72
	elseif minSide <= 700 then
		return 0.82
	elseif minSide <= 900 then
		return 0.92
	else
		return 1
	end
end

function ResponsiveUI.ApplyScale(parent, baseScale)
	local scale = parent:FindFirstChildOfClass("UIScale")

	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = parent
	end

	local function updateScale()
		scale.Scale = (baseScale or 1) * ResponsiveUI.GetScreenScale()
	end

	updateScale()

	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	return scale
end

return ResponsiveUI

local Workspace = game:GetService("Workspace")

local ResponsiveUI = {}

function ResponsiveUI.GetViewportSize()
	local camera = Workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1920, 1080)
end

function ResponsiveUI.IsMobileViewport()
	local size = ResponsiveUI.GetViewportSize()
	return math.min(size.X, size.Y) <= 700
end

function ResponsiveUI.IsMobileLike()
	return ResponsiveUI.IsMobileViewport()
end

local MOBILE_SCALES = {
	Small = {
		Inventory = 0.62,
		Tooltip = 0.75,
		BuffsPanel = 0.66,
		ToggleButton = 0.78,
		CoinPopup = 0.68,
		AdminPanel = 0.66,
		Notifications = 0.74,
	},

	Default = {
		Inventory = 0.72,
		Tooltip = 0.82,
		BuffsPanel = 0.75,
		ToggleButton = 0.84,
		CoinPopup = 0.72,
		AdminPanel = 0.72,
		Notifications = 0.78,
	},
}

function ResponsiveUI.GetScreenScale()
	local size = ResponsiveUI.GetViewportSize()
	local minSide = math.min(size.X, size.Y)

	if minSide <= 500 then
		return 0.68
	elseif minSide <= 700 then
		return 0.78
	elseif minSide <= 900 then
		return 0.9
	else
		return 1
	end
end

function ResponsiveUI.GetMobileScale(key)
	if not ResponsiveUI.IsMobileViewport() then
		return 1
	end

	local size = ResponsiveUI.GetViewportSize()
	local minSide = math.min(size.X, size.Y)
	local profile = minSide <= 500 and MOBILE_SCALES.Small or MOBILE_SCALES.Default

	return profile[key] or 1
end

function ResponsiveUI.ApplyScale(parent, baseScale)
	local scale = parent:FindFirstChildOfClass("UIScale")

	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = parent
	end

	scale.Scale = (baseScale or 1) * ResponsiveUI.GetScreenScale()
	return scale
end

return ResponsiveUI

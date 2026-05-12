local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ResponsiveUI = {}

ResponsiveUI.FORCE_MOBILE_IN_STUDIO = false

local MOBILE_SCALES = {
	SmallMobile = {
		Inventory = 0.42,
		Tooltip = 0.56,
		BuffsPanel = 0.50,
		ToggleButton = 0.56,
		CoinPopup = 0.55,
		AdminPanel = 0.50,
		Notifications = 0.58,
	},

	Mobile = {
		Inventory = 0.50,
		Tooltip = 0.64,
		BuffsPanel = 0.58,
		ToggleButton = 0.64,
		CoinPopup = 0.62,
		AdminPanel = 0.58,
		Notifications = 0.65,
	},

	Desktop = {
		Inventory = 1,
		Tooltip = 1,
		BuffsPanel = 1,
		ToggleButton = 1,
		CoinPopup = 1,
		AdminPanel = 1,
		Notifications = 1,
	},
}

function ResponsiveUI.GetViewportSize()
	local camera = Workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1920, 1080)
end

function ResponsiveUI.GetDeviceInfo()
	local viewport = ResponsiveUI.GetViewportSize()
	local minSide = math.min(viewport.X, viewport.Y)
	local maxSide = math.max(viewport.X, viewport.Y)
	local aspect = maxSide / math.max(minSide, 1)

	return {
		Viewport = viewport,
		MinSide = minSide,
		MaxSide = maxSide,
		Aspect = aspect,
		TouchEnabled = UserInputService.TouchEnabled,
		KeyboardEnabled = UserInputService.KeyboardEnabled,
		TenFoot = GuiService:IsTenFootInterface(),
	}
end

function ResponsiveUI.IsMobileViewport()
	local info = ResponsiveUI.GetDeviceInfo()

	if ResponsiveUI.FORCE_MOBILE_IN_STUDIO then
		return true
	end

	if info.TenFoot then
		return false
	end

	if info.MinSide <= 800 then
		return true
	end

	if info.TouchEnabled and not info.KeyboardEnabled then
		return true
	end

	if info.TouchEnabled and info.Aspect >= 1.6 and info.MinSide <= 900 then
		return true
	end

	return false
end

function ResponsiveUI.IsMobileLike()
	return ResponsiveUI.IsMobileViewport()
end

function ResponsiveUI.GetProfileName()
	local info = ResponsiveUI.GetDeviceInfo()

	if ResponsiveUI.IsMobileViewport() then
		if info.MinSide <= 500 then
			return "SmallMobile"
		end

		return "Mobile"
	end

	return "Desktop"
end

function ResponsiveUI.GetScreenScale()
	local profileName = ResponsiveUI.GetProfileName()

	if profileName == "SmallMobile" then
		return 0.55
	elseif profileName == "Mobile" then
		return 0.65
	else
		return 1
	end
end

function ResponsiveUI.GetMobileScale(key)
	local profileName = ResponsiveUI.GetProfileName()
	local profile = MOBILE_SCALES[profileName] or MOBILE_SCALES.Desktop
	return profile[key] or 1
end

function ResponsiveUI.GetScaleProfile()
	local profileName = ResponsiveUI.GetProfileName()
	return profileName, MOBILE_SCALES[profileName] or MOBILE_SCALES.Desktop, ResponsiveUI.GetDeviceInfo()
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

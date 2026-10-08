--!strict
-- Tiny helpers for building UI and effects in code.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)

local UI = {}

-- UI.new("Frame", { Size = ..., Parent = ... }, { child, child })
function UI.new(className: string, props: { [string]: any }?, children: { any }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- Returns `any` so mixed child lists like { UI.corner(), UI.stroke() } type-check.
function UI.corner(radius: number?): any
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UI.stroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.textStroke(color: Color3, thickness: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function UI.gradient(top: Color3, bottom: Color3): UIGradient
	return UI.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
	})
end

function UI.label(props: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
	}
	for k, v in props do
		base[k] = v
	end
	return UI.new("TextLabel", base)
end

-- Big chunky simulator-style text: heavy font with a thick dark outline.
function UI.bigText(props: { [string]: any }, strokeColor: Color3?, thickness: number?): TextLabel
	local base: { [string]: any } = { Font = Enum.Font.LuckiestGuy }
	for k, v in props do
		base[k] = v
	end
	local l = UI.label(base)
	UI.textStroke(strokeColor or Color3.fromRGB(15, 15, 20), thickness or 2.5).Parent = l
	return l
end

function UI.tween(
	inst: Instance,
	seconds: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(
		inst,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

-- Quick scale "bump" on a GuiObject that has a UIScale child named "Bump".
function UI.bump(gui: GuiObject, amount: number?)
	local scale = gui:FindFirstChild("Bump") :: UIScale?
	if not scale then
		scale = UI.new("UIScale", { Name = "Bump", Parent = gui })
	end
	assert(scale, "bump scale missing")
	scale.Scale = 1 + (amount or 0.15)
	UI.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Icon by name: the uploaded image from Config/Assets.Images if set, otherwise an emoji.
function UI.icon(name: string, emoji: string): GuiObject
	local id = (Assets.Images :: any)[name] :: string?
	if id and id ~= "" then
		return UI.new("ImageLabel", {
			Name = name .. "Icon",
			BackgroundTransparency = 1,
			Image = id,
			ScaleType = Enum.ScaleType.Fit,
		})
	end
	return UI.new("TextLabel", {
		Name = name .. "Icon",
		BackgroundTransparency = 1,
		Text = emoji,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
	})
end

-- HUD scale: phones in landscape are ~390 pt tall; bigger on tablets/PC, smaller on tiny screens.
function UI.screenScale(): number
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(844, 390)
	-- Tuned so a landscape phone (~390–460 pt tall) lands around 0.8: chunky but not covering the
	-- farm. Tablets and desktop grow up to 1.25.
	return math.clamp(math.min(size.Y / 520, size.X / 980), 0.65, 1.25)
end

-- Adds a UIScale to a ScreenGui that follows UI.screenScale().
function UI.autoScale(gui: ScreenGui)
	local scale: UIScale = UI.new("UIScale", { Parent = gui })
	scale.Scale = UI.screenScale()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			scale.Scale = UI.screenScale()
		end)
	end
end

function UI.rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

return UI

--!strict
-- Kid-friendly modal panel: bright header band with a big title, red round close button, cream
-- body with a scrolling list. Only one panel is open at a time.
-- No dimmed backdrop: the world stays visible and the joystick keeps working; X closes.

local Players = game:GetService("Players")

local UI = require(script.Parent.UI)
local Sound = require(script.Parent.Sound)

local Panel = {}

export type Panel = {
	gui: ScreenGui,
	frame: Frame,
	body: ScrollingFrame,
	subtitle: TextLabel,
	setOpen: (open: boolean) -> (),
	toggle: () -> (),
	isOpen: () -> boolean,
	onOpen: (() -> ())?,
}

local all: { Panel } = {}

function Panel.new(name: string, title: string, color: Color3, dark: Color3, size: Vector2?): Panel
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local dims = size or Vector2.new(560, 310)

	local gui: ScreenGui = UI.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = 4,
		Enabled = false,
		Parent = playerGui,
	})

	local frame: Frame = UI.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(dims.X, dims.Y),
		BackgroundColor3 = Color3.fromRGB(255, 248, 230),
		Parent = gui,
	}, {
		UI.corner(22),
		UI.stroke(dark, 4),
	})
	-- Only the panel box scales (not the whole layer).
	UI.scaleObject(frame, UI.PANEL_SCALE)

	-- Header band
	local header = UI.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = color,
		Parent = frame,
	}, {
		UI.corner(22),
		UI.new("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
			Rotation = 90,
		}),
	})
	-- square off the header's bottom corners
	UI.new("Frame", {
		Position = UDim2.new(0, 0, 1, -22),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = header,
	}, {
		UI.new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(225, 225, 225), Color3.fromRGB(200, 200, 200)),
			Rotation = 90,
		}),
	})
	UI.bigText({
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.new(0.5, -18, 0, 40),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = header,
	}, dark, 3.5)
	local subtitle = UI.bigText({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -70, 0, 14),
		Size = UDim2.new(0.5, -70, 0, 28),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
		Parent = header,
	}, dark, 2.5)

	local close: TextButton = UI.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(50, 50),
		BackgroundColor3 = Color3.fromRGB(255, 80, 90),
		Text = "",
		ZIndex = 5,
		Parent = frame,
	}, { UI.corner(25), UI.stroke(Color3.fromRGB(130, 20, 30), 3.5) })
	UI.bigText({
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		Text = "X",
		ZIndex = 6,
		Parent = close,
	}, Color3.fromRGB(130, 20, 30), 2.5)

	local body: ScrollingFrame = UI.new("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(10, 62),
		Size = UDim2.new(1, -20, 1, -72),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = dark,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = frame,
	})

	local panel: Panel
	panel = {
		gui = gui,
		frame = frame,
		body = body,
		subtitle = subtitle,
		setOpen = function(open: boolean)
			if open then
				for _, other in all do
					if other ~= panel then
						other.gui.Enabled = false
					end
				end
			end
			gui.Enabled = open
			if open then
				Sound.play("Open")
				-- small slide-up pop (the frame's UIScale is used for screen scaling)
				frame.Position = UDim2.fromScale(0.5, 0.58)
				UI.tween(frame, 0.22, { Position = UDim2.fromScale(0.5, 0.53) }, Enum.EasingStyle.Back)
				if panel.onOpen then
					panel.onOpen()
				end
			end
		end,
		toggle = function()
			panel.setOpen(not gui.Enabled)
		end,
		isOpen = function()
			return gui.Enabled
		end,
		onOpen = nil,
	}
	close.Activated:Connect(function()
		panel.setOpen(false)
	end)
	table.insert(all, panel)
	return panel
end

-- A chunky colored button with big text. Returns (button, label).
function Panel.button(
	props: { [string]: any },
	color: Color3,
	dark: Color3,
	text: string
): (TextButton, TextLabel)
	local base: { [string]: any } = {
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Text = "",
	}
	for k, v in props do
		base[k] = v
	end
	local b: TextButton = UI.new("TextButton", base, {
		UI.corner(12),
		UI.stroke(dark, 3),
		UI.new("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
			Rotation = 90,
		}),
	})
	local l = UI.bigText({
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		Text = text,
		Parent = b,
	}, dark, 2.5)
	return b, l
end

return Panel

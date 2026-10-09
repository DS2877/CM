--!strict
-- Developer messages to every server (admin dashboard): the developer's avatar face pops in at
-- the top of the screen with a speech bubble. Text is filtered on the server before it arrives.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local AdminConfig = require(Shared.Config.Admin)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)

local player = Players.LocalPlayer

local Broadcast = {}

type Message = { text: string, userId: number, name: string }

local queue: { Message } = {}
local showing = false
local gui: ScreenGui

local function headshot(userId: number): string
	local ok, image = pcall(function()
		return Players:GetUserThumbnailAsync(
			userId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size150x150
		)
	end)
	return if ok and typeof(image) == "string" then image else ""
end

local function show(msg: Message)
	local root: Frame = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -140),
		Size = UDim2.fromOffset(520, 110),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	-- Compact: a glanceable note at the top, not a wall
	UI.scaleObject(root, 0.6)

	-- Avatar face in a bright circle
	local face: Frame = UI.new("Frame", {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromOffset(96, 96),
		BackgroundColor3 = Color3.fromRGB(255, 220, 90),
		Parent = root,
	}, { UI.corner(48), UI.stroke(Color3.fromRGB(150, 80, 0), 4) })
	UI.new("ImageLabel", {
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundTransparency = 1,
		Image = headshot(msg.userId),
		Parent = face,
	}, { UI.corner(44) })
	UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.fromOffset(84, 20),
		Text = "DEV",
		TextColor3 = Color3.fromRGB(255, 120, 60),
		Parent = face,
	}, Color3.fromRGB(110, 30, 0), 2)

	-- Speech bubble with a little tail pointing at the face
	local bubble: Frame = UI.new("Frame", {
		Position = UDim2.fromOffset(112, 0),
		Size = UDim2.new(1, -112, 1, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Parent = root,
	}, { UI.corner(22), UI.stroke(Color3.fromRGB(150, 80, 0), 3.5) })
	UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0, 56),
		Size = UDim2.fromOffset(20, 20),
		Rotation = 45,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 0,
		Parent = bubble,
	}, { UI.stroke(Color3.fromRGB(150, 80, 0), 3.5) })
	UI.bigText({
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, 22),
		Text = msg.name .. " says:",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 150, 40),
		ZIndex = 2,
		Parent = bubble,
	}, Color3.fromRGB(110, 50, 0), 2)
	UI.label({
		Position = UDim2.fromOffset(16, 34),
		Size = UDim2.new(1, -32, 1, -42),
		Text = msg.text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(60, 50, 40),
		ZIndex = 2,
		Parent = bubble,
	})

	Sound.play("Bell", { volume = 0.7 })
	UI.tween(root, 0.45, { Position = UDim2.new(0.5, 0, 0, 56) }, Enum.EasingStyle.Back)
	task.wait(AdminConfig.MessageSeconds)
	UI.tween(
		root,
		0.35,
		{ Position = UDim2.new(0.5, 0, 0, -140) },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	task.wait(0.4)
	root:Destroy()
end

local function pump()
	if showing then
		return
	end
	showing = true
	while #queue > 0 do
		show(table.remove(queue, 1) :: Message)
	end
	showing = false
end

function Broadcast.start()
	gui = UI.new("ScreenGui", {
		Name = "DevMessages",
		ResetOnSpawn = false,
		DisplayOrder = 9,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Remotes.get(Remotes.Names.AdminMessage).OnClientEvent:Connect(function(msg: Message)
		if typeof(msg) == "table" and typeof(msg.text) == "string" then
			table.insert(queue, msg)
			task.spawn(pump)
		end
	end)
end

return Broadcast

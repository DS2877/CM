--!strict
-- Bunny Launchers: step on the purple pad at your farm gate and a giant bunny spring flings you
-- over the valley to the Bunny Market (and from the square's end of each road back to that
-- farm). The flight is a smooth arc you control nothing in - pure fun, about 3 seconds.
-- Movement only: the client moves its own character (which it owns anyway).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local World = require(ReplicatedStorage.Shared.Config.World)
local Sound = require(script.Parent.Parent.Util.Sound)

local player = Players.LocalPlayer

local Launcher = {}

local flying = false
local cooldownUntil = 0

local function launch(root: BasePart, humanoid: Humanoid, from: Vector3, to: Vector3, padPart: BasePart?)
	flying = true
	Sound.play("Boing")
	if padPart then
		-- the spring squashes and pops
		local rest = padPart.CFrame
		padPart.CFrame = rest - Vector3.new(0, 0.6, 0)
		TweenService:Create(padPart, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = rest,
		}):Play()
	end
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 200, 255), Color3.fromRGB(255, 230, 120))
	trail.LightEmission = 0.7
	trail.Size = NumberSequence.new(0.8, 0)
	trail.Lifetime = NumberRange.new(0.6, 1)
	trail.Rate = 60
	trail.Speed = NumberRange.new(0.5, 1)
	trail.Parent = root
	humanoid.PlatformStand = true
	local start = from + Vector3.new(0, 3, 0)
	local finish = to + Vector3.new(0, 3.5, 0)
	local flat = Vector3.new(finish.X - start.X, 0, finish.Z - start.Z)
	local face = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, -1)
	local duration = World.LaunchSeconds
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local k = math.clamp((os.clock() - t0) / duration, 0, 1)
		local ease = k * k * (3 - 2 * k) -- smooth start and landing
		local pos = start:Lerp(finish, ease) + Vector3.new(0, 4 * World.LaunchHeight * ease * (1 - ease), 0)
		-- a happy forward flip in the middle of the flight
		local flip = if k > 0.3 and k < 0.7 then (k - 0.3) / 0.4 * math.pi * 2 else 0
		root.CFrame = CFrame.lookAt(pos, pos + face) * CFrame.Angles(-flip, 0, 0)
		root.AssemblyLinearVelocity = Vector3.zero
		if k >= 1 then
			conn:Disconnect()
			humanoid.PlatformStand = false
			root.CFrame = CFrame.lookAt(finish, finish + face)
			trail.Enabled = false
			task.delay(1, function()
				trail:Destroy()
			end)
			flying = false
			cooldownUntil = os.clock() + 1.5
		end
	end)
end

function Launcher.start()
	local launchers = World.launchers()
	local homes = World.homeLaunchers()
	local world = workspace:WaitForChild("World")
	local plaza = world:WaitForChild("Plaza", 10)
	local folder = plaza and plaza:WaitForChild("Launchers", 10)

	-- The launcher to your own farm says so
	local function labelOwn()
		if not folder then
			return
		end
		local mine = player:GetAttribute("FarmId")
		for i, l in launchers do
			local m = folder:FindFirstChild("Launcher_" .. i)
			local board = m and m:FindFirstChild("LaunchSign")
			if board and l.toFarm then
				for _, g in board:GetChildren() do
					local text = g:FindFirstChildOfClass("TextLabel")
					if text then
						local own = l.farmId == mine
						text.Text = if own then "🐰 → YOUR FARM" else "🐰 → FARM " .. l.farmId
						text.TextColor3 = if own
							then Color3.fromRGB(255, 220, 90)
							else Color3.fromRGB(255, 255, 255)
					end
				end
			end
		end
	end
	player:GetAttributeChangedSignal("FarmId"):Connect(labelOwn)
	labelOwn()

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 or flying or os.clock() < cooldownUntil then
			return
		end
		acc = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
			return
		end
		local p = (root :: BasePart).Position
		-- HOME pads: to my own farm
		local mine = player:GetAttribute("FarmId")
		for i, home in homes do
			local d = Vector3.new(p.X - home.X, 0, p.Z - home.Z).Magnitude
			if d <= World.LauncherRadius and p.Y < home.Y + 8 then
				for _, l in launchers do
					if l.toFarm and l.farmId == mine then
						local m = folder and folder:FindFirstChild("HomeLauncher_" .. i)
						local padPart = m and m:FindFirstChild("LaunchPad")
						launch(
							root :: BasePart,
							humanoid :: Humanoid,
							home,
							l.to,
							if padPart and padPart:IsA("BasePart") then padPart else nil
						)
						return
					end
				end
			end
		end
		for i, l in launchers do
			local d = Vector3.new(p.X - l.from.X, 0, p.Z - l.from.Z).Magnitude
			if d <= World.LauncherRadius and p.Y < l.from.Y + 8 then
				local m = folder and folder:FindFirstChild("Launcher_" .. i)
				local padPart = m and m:FindFirstChild("LaunchPad")
				launch(
					root :: BasePart,
					humanoid :: Humanoid,
					l.from,
					l.to,
					if padPart and padPart:IsA("BasePart") then padPart else nil
				)
				return
			end
		end
	end)
end

return Launcher

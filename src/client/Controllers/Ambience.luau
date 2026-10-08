--!strict
-- Life in the valley: butterflies flutter around near the camera (client only, capped, never
-- collide, cost ~nothing). A still world reads as cheap; small motion everywhere reads as alive.

local RunService = game:GetService("RunService")

local Ambience = {}

local COUNT = 10
local RANGE = 60 -- studs around the camera where butterflies live
local COLORS = {
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(255, 140, 200),
	Color3.fromRGB(150, 200, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 150, 70),
}

type Fly = {
	model: Model,
	left: BasePart,
	right: BasePart,
	pos: Vector3,
	target: Vector3,
	speed: number,
	phase: number,
}

local flies: { Fly } = {}
local folder: Folder

local function wing(color: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = Vector3.new(0.05, 0.45, 0.35)
	return p
end

local function randomSpot(around: Vector3): Vector3
	local a = math.random() * math.pi * 2
	local r = 8 + math.random() * RANGE
	return Vector3.new(around.X + math.cos(a) * r, 1.5 + math.random() * 3.5, around.Z + math.sin(a) * r)
end

local function spawnFly(around: Vector3): Fly
	local color = COLORS[math.random(1, #COLORS)]
	local model = Instance.new("Model")
	model.Name = "Butterfly"
	local left, right = wing(color), wing(color)
	left.Parent = model
	right.Parent = model
	model.Parent = folder
	local pos = randomSpot(around)
	return {
		model = model,
		left = left,
		right = right,
		pos = pos,
		target = randomSpot(around),
		speed = 3 + math.random() * 2.5,
		phase = math.random() * 10,
	}
end

function Ambience.start()
	folder = Instance.new("Folder")
	folder.Name = "Ambience"
	folder.Parent = workspace
	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local center = camera.Focus.Position
		while #flies < COUNT do
			table.insert(flies, spawnFly(center))
		end
		local t = os.clock()
		for _, f in flies do
			local offset = f.target - f.pos
			if
				offset.Magnitude < 1
				or (Vector3.new(f.pos.X - center.X, 0, f.pos.Z - center.Z)).Magnitude > RANGE * 1.6
			then
				-- New wander target; butterflies left behind hop back near the camera
				if (Vector3.new(f.pos.X - center.X, 0, f.pos.Z - center.Z)).Magnitude > RANGE * 1.6 then
					f.pos = randomSpot(center)
				end
				f.target = randomSpot(center)
				offset = f.target - f.pos
			end
			local dir = offset.Unit
			f.pos += dir * f.speed * dt + Vector3.new(0, math.sin(t * 3 + f.phase) * 0.02, 0)
			local flap = math.sin(t * 22 + f.phase) * 0.9
			local base = CFrame.lookAt(f.pos, f.pos + Vector3.new(dir.X, 0, dir.Z) + Vector3.new(0, 0, 1e-3))
			f.left.CFrame = base * CFrame.Angles(0, 0, flap) * CFrame.new(-0.2, 0, 0)
			f.right.CFrame = base * CFrame.Angles(0, 0, -flap) * CFrame.new(0.2, 0, 0)
		end
	end)
end

return Ambience

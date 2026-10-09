--!strict
-- Things that make the valley feel like a playground, not a spreadsheet (built once at startup):
--   * giant bouncy mushrooms between the farm paths: jump on the cap and you fly (the client
--     launches its own character; it's just movement, nothing economic)
--   * bunting with triangle flags and balloon bunches around the plaza
--   * candy-colored tulips along both sides of every farm path
-- Balloons and tulips sit in named folders so the client can make them bob and sway.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Config.World)

local WorldFun = {}

local CANDY = {
	Color3.fromRGB(255, 105, 150), -- pink
	Color3.fromRGB(255, 205, 50), -- yellow
	Color3.fromRGB(110, 190, 255), -- sky blue
	Color3.fromRGB(175, 120, 255), -- lilac
	Color3.fromRGB(255, 140, 60), -- orange
	Color3.fromRGB(120, 220, 110), -- mint
}

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = false
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function flatDir(deg: number): Vector3
	local a = math.rad(deg)
	return Vector3.new(math.sin(a), 0, math.cos(a))
end

-- A mushroom: white stem, round cap with white dots. The cap's top is a "BounceCap".
local function mushroom(parent: Instance, base: Vector3, scale: number, color: Color3, bounce: number)
	local stemH = 2.6 * scale
	part(parent, {
		Name = "MushroomStem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(stemH, 2.6 * scale, 2.6 * scale),
		CFrame = CFrame.new(base + Vector3.new(0, stemH / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 245, 225),
	})
	local capW, capH = 9 * scale, 3.6 * scale
	local capCenter = base + Vector3.new(0, stemH + capH * 0.35, 0)
	local cap = part(parent, {
		Name = "BounceCap",
		Size = Vector3.new(capW, capH, capW),
		CFrame = CFrame.new(capCenter),
		Color = color,
	})
	cap:SetAttribute("Bounce", bounce)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = cap
	-- White dots around the dome
	for k = 0, 6 do
		local a = k * (2 * math.pi / 7)
		local r = capW * 0.3
		local p = capCenter + Vector3.new(math.cos(a) * r, capH * 0.3, math.sin(a) * r)
		part(parent, {
			Name = "MushroomDot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (1.1 * scale),
			CFrame = CFrame.new(p),
			Color = Color3.fromRGB(255, 255, 255),
			CanCollide = false,
			CanQuery = false,
		})
	end
	part(parent, {
		Name = "MushroomDot",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (1.3 * scale),
		CFrame = CFrame.new(capCenter + Vector3.new(0, capH * 0.48, 0)),
		Color = Color3.fromRGB(255, 255, 255),
		CanCollide = false,
		CanQuery = false,
	})
end

local function buildMushrooms(parent: Instance)
	local f = folder("Mushrooms", parent)
	for i, deg in World.MushroomAngles do
		local dir = flatDir(deg)
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local base = dir * World.MushroomRadius
		local color = if i % 2 == 0 then Color3.fromRGB(235, 70, 80) else Color3.fromRGB(255, 120, 190)
		-- One big launcher and a small step-up next to it (easy to hop onto from the ground)
		mushroom(f, base, 1, color, World.MushroomBounce)
		mushroom(
			f,
			base + side * 6.5 - dir * 3,
			0.55,
			Color3.fromRGB(255, 170, 60),
			World.MushroomBounceSmall
		)
		mushroom(
			f,
			base - side * 5.5 + dir * 2,
			0.4,
			Color3.fromRGB(150, 110, 255),
			World.MushroomBounceSmall
		)
	end
end

local function buildBunting(parent: Instance)
	local f = folder("Bunting", parent)
	local balloons = folder("Balloons", parent)
	local posts: { Vector3 } = {}
	for i = 0, World.FarmCount - 1 do
		local deg = (i + 0.5) * (360 / World.FarmCount)
		table.insert(posts, flatDir(deg) * World.BuntingRadius)
	end
	local postH = 10
	for i, p in posts do
		part(f, {
			Name = "BuntingPost",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(postH, 0.6, 0.6),
			CFrame = CFrame.new(p + Vector3.new(0, postH / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 252, 245),
		})
		part(f, {
			Name = "BuntingTop",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.1,
			CFrame = CFrame.new(p + Vector3.new(0, postH + 0.3, 0)),
			Color = CANDY[(i % #CANDY) + 1],
		})
		-- A bunch of three balloons tied to the post
		for k = 0, 2 do
			local off = Vector3.new(math.cos(k * 2.1 + i) * 1.1, 4 + k * 0.9, math.sin(k * 2.1 + i) * 1.1)
			local top = p + Vector3.new(0, postH, 0) + off
			local balloon = part(balloons, {
				Name = "Balloon",
				Size = Vector3.new(2, 2.4, 2),
				CFrame = CFrame.new(top),
				Color = CANDY[((i + k) % #CANDY) + 1],
				Material = Enum.Material.Glass,
				Transparency = 0.05,
				CanCollide = false,
				CanQuery = false,
			})
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = balloon
			local from = p + Vector3.new(0, postH, 0)
			local to = top - Vector3.new(0, 1.2, 0)
			part(balloons, {
				Name = "BalloonString",
				Size = Vector3.new(0.06, 0.06, (to - from).Magnitude),
				CFrame = CFrame.lookAt((from + to) / 2, to),
				Color = Color3.fromRGB(255, 255, 255),
				CanCollide = false,
				CanQuery = false,
			})
		end
	end
	-- Sagging strings of little diamond pennants between neighboring posts (over the farm paths)
	local hang = postH - 0.4
	for i, a in posts do
		local b = posts[(i % #posts) + 1]
		local along = (b - a).Unit
		local flags = 11
		local function at(t: number): Vector3
			return a:Lerp(b, t) + Vector3.new(0, hang - math.sin(t * math.pi) * 2.2, 0)
		end
		for k = 1, flags do
			local pos = at(k / (flags + 1))
			part(f, {
				Name = "Flag",
				Size = Vector3.new(0.1, 1.15, 1.15),
				CFrame = CFrame.lookAt(pos, pos + along)
					* CFrame.new(0, -0.85, 0)
					* CFrame.Angles(math.rad(45), 0, 0),
				Color = CANDY[((i + k) % #CANDY) + 1],
				CanCollide = false,
				CanQuery = false,
			})
		end
		-- the string, as a few straight pieces following the sag
		local pieces = 4
		for k = 0, pieces - 1 do
			local p0, p1 = at(k / pieces), at((k + 1) / pieces)
			part(f, {
				Name = "FlagString",
				Size = Vector3.new(0.08, 0.08, (p1 - p0).Magnitude),
				CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
				Color = Color3.fromRGB(255, 255, 255),
				CanCollide = false,
				CanQuery = false,
			})
		end
	end
end

local function buildTulips(parent: Instance)
	local f = folder("Tulips", parent)
	local start = 36
	local stop = World.FarmRingRadius - 3 * (World.PlotSize + World.PlotGap) - World.FarmPadding - 14
	for i = 0, World.FarmCount - 1 do
		local dir = flatDir(i * (360 / World.FarmCount))
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local n = 0
		for r = start, stop, World.TulipSpacing do
			for _, s in { -1, 1 } do
				n += 1
				local base = dir * r + side * s * 6.2
				local color = CANDY[(n % #CANDY) + 1]
				part(f, {
					Name = "TulipStem",
					Size = Vector3.new(0.25, 1.6, 0.25),
					CFrame = CFrame.new(base + Vector3.new(0, 0.8, 0)),
					Color = Color3.fromRGB(80, 170, 70),
					CanCollide = false,
					CanQuery = false,
				})
				local head = part(f, {
					Name = "Tulip",
					Size = Vector3.new(0.9, 1.1, 0.9),
					CFrame = CFrame.new(base + Vector3.new(0, 1.9, 0)),
					Color = color,
					CanCollide = false,
					CanQuery = false,
				})
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = head
			end
		end
	end
end

function WorldFun.build(world: Instance)
	local fun = folder("Fun", world)
	buildMushrooms(fun)
	buildBunting(fun)
	buildTulips(fun)
end

-- Spots the random decor (trees, bushes, rocks) must keep clear of.
function WorldFun.blocked(flat: Vector3): boolean
	for _, deg in World.MushroomAngles do
		if (flat - flatDir(deg) * World.MushroomRadius).Magnitude < 12 then
			return true
		end
	end
	return false
end

return WorldFun

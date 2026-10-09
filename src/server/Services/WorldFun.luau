--!strict
-- Things that make the valley feel like a playground, not a spreadsheet (built once at startup):
--   * giant bouncy mushrooms between the farm paths: jump on the cap and you fly (the client
--     launches its own character; it's just movement, nothing economic)
--   * bunting with triangle flags and balloon bunches around the plaza
--   * candy-colored tulips along both sides of every farm path
-- Balloons and tulips sit in named folders so the client can make them bob and sway.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Config.World)
local Landscape = require(script.Parent.Landscape)

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
	local start = World.PlazaRadius + 8
	local stop = World.FarmRingRadius - World.farmHalf() - World.LauncherGateOffset - 10
	for i = 0, World.FarmCount - 1 do
		local dir = flatDir(i * (360 / World.FarmCount))
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local n = 0
		for r = start, stop, World.TulipSpacing do
			for _, s in { -1, 1 } do
				n += 1
				local base = dir * r + side * s * 8.5
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

local function cylinder(
	parent: Instance,
	name: string,
	length: number,
	d: number,
	cf: CFrame,
	color: Color3
): Part
	-- Roblox cylinders run along X; `cf` places the middle, its X axis is the length
	return part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, d, d),
		CFrame = cf,
		Color = color,
	})
end

-- Campsite: a crackling campfire in a ring of stones, three logs to sit on (the bots roast
-- marshmallows there), a tent and a lantern. Seats are invisible "CampSeat" parts for the bots.
local function buildCampsite(parent: Instance)
	local f = folder("Campsite", parent)
	local dir = flatDir(World.CampAngle)
	local c = dir * World.CampRadius
	Landscape.flatDisc(c, 10)
	-- trampled dirt patch
	cylinder(
		f,
		"CampGround",
		0.2,
		18,
		CFrame.new(c + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(170, 130, 90)
	).CanCollide =
		false
	for k = 0, 9 do
		local a = k * math.pi * 2 / 10
		part(f, {
			Name = "FireStone",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.1,
			CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 2, 0.35, math.sin(a) * 2)),
			Color = Color3.fromRGB(150, 150, 158),
		})
	end
	for _, rot in { 0.6, -0.6 } do
		cylinder(
			f,
			"FireLog",
			3,
			0.6,
			CFrame.new(c + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, rot, 0),
			Color3.fromRGB(110, 70, 40)
		).Material =
			Enum.Material.Wood
	end
	local flame = part(f, {
		Name = "Campfire",
		Size = Vector3.new(1.5, 1, 1.5),
		CFrame = CFrame.new(c + Vector3.new(0, 1, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 8
	fire.Color = Color3.fromRGB(255, 140, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
	fire.Parent = flame
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 80)
	light.Range = 18
	light.Brightness = 2
	light.Parent = flame
	-- Logs to sit on, facing the fire
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3 + 0.4
		local pos = c + Vector3.new(math.cos(a) * 5.2, 0, math.sin(a) * 5.2)
		local toFire = (c - pos).Unit
		local tangent = Vector3.new(-toFire.Z, 0, toFire.X)
		cylinder(
			f,
			"SitLog",
			3.6,
			1.3,
			CFrame.lookAt(pos + Vector3.new(0, 0.65, 0), pos + Vector3.new(0, 0.65, 0) + tangent)
				* CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(130, 85, 50)
		).Material =
			Enum.Material.Wood
		local seat = part(f, {
			Name = "CampSeat",
			Size = Vector3.one,
			CFrame = CFrame.lookAt(pos + Vector3.new(0, 2.35, 0), c + Vector3.new(0, 2.35, 0)),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		seat:SetAttribute("Seat", k + 1)
	end
	-- Tent behind the fire (two sloped panels + a door flap)
	local tentPos = c + dir * 8.5
	local tentCF = CFrame.lookAt(tentPos, c)
	for _, sx in { -1, 1 } do
		part(f, {
			Name = "Tent",
			Size = Vector3.new(0.2, 5.6, 6.5),
			CFrame = tentCF * CFrame.new(sx * 1.9, 2.1, 0) * CFrame.Angles(0, 0, math.rad(sx * 34)),
			Color = Color3.fromRGB(255, 140, 50),
			Material = Enum.Material.Fabric,
		})
	end
	part(f, {
		Name = "TentBack",
		Size = Vector3.new(0.6, 0.4, 6.6),
		CFrame = tentCF * CFrame.new(0, 4.4, 0),
		Color = Color3.fromRGB(220, 100, 30),
		Material = Enum.Material.Fabric,
	})
	-- Lantern on a post
	local lp = c + Vector3.new(-dir.Z, 0, dir.X) * 7
	part(f, {
		Name = "LanternPost",
		Size = Vector3.new(0.35, 4, 0.35),
		CFrame = CFrame.new(lp + Vector3.new(0, 2, 0)),
		Color = Color3.fromRGB(110, 70, 40),
		Material = Enum.Material.Wood,
	})
	local lantern = part(f, {
		Name = "Lantern",
		Size = Vector3.new(0.8, 1, 0.8),
		CFrame = CFrame.new(lp + Vector3.new(0, 4.3, 0)),
		Color = Color3.fromRGB(255, 220, 140),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local ll = Instance.new("PointLight")
	ll.Color = Color3.fromRGB(255, 210, 140)
	ll.Range = 10
	ll.Parent = lantern
end

-- Fishing lake: water in a sandy rim, reeds, lily pads and a little dock pointing at the middle.
-- The dock end ("FishSpot") is where the fishing bot stands; "Bobber" floats on the water.
local function buildLake(parent: Instance)
	local f = folder("Lake", parent)
	local dir = flatDir(World.LakeAngle)
	local c = dir * World.LakeRadius
	local r = World.LakeSize / 2
	-- real terrain water with a sandy shore (waves, reflections)
	Landscape.lake(c, r, 5)
	-- reeds around the edge
	for k = 0, 13 do
		local a = k * math.pi * 2 / 14 + 0.2
		local base = c + Vector3.new(math.cos(a) * (r + 0.8), 0, math.sin(a) * (r + 0.8))
		if (base - (c - dir * r)).Magnitude > 4 then -- keep the dock side clear
			for j = -1, 1 do
				part(f, {
					Name = "Reed",
					Size = Vector3.new(0.18, 2.4 + j * 0.3, 0.18),
					CFrame = CFrame.new(base + Vector3.new(j * 0.35, 1.2, 0)) * CFrame.Angles(0, 0, j * 0.12),
					Color = Color3.fromRGB(90, 160, 70),
					CanCollide = false,
				})
			end
			part(f, {
				Name = "Cattail",
				Size = Vector3.new(0.35, 0.8, 0.35),
				CFrame = CFrame.new(base + Vector3.new(0, 2.6, 0)),
				Color = Color3.fromRGB(120, 80, 45),
				CanCollide = false,
			})
		end
	end
	-- lily pads with a flower
	for k = 0, 4 do
		local a = k * 1.3 + 1
		local p = c + Vector3.new(math.cos(a) * r * 0.6, 0.08, math.sin(a) * r * 0.6)
		cylinder(
			f,
			"LilyPad",
			0.08,
			2,
			CFrame.new(p) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(90, 180, 80)
		).CanCollide =
			false
		if k % 2 == 0 then
			part(f, {
				Name = "LilyFlower",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.6,
				CFrame = CFrame.new(p + Vector3.new(0.3, 0.2, 0)),
				Color = Color3.fromRGB(255, 160, 200),
				CanCollide = false,
			})
		end
	end
	-- Dock from the plaza-side shore toward the middle
	local inward = dir -- from the plaza-side edge toward the lake center
	local dockStart = c - dir * (r + 1.5)
	local dockEnd = c - dir * (r - 5)
	local dockMid = (dockStart + dockEnd) / 2
	part(f, {
		Name = "Dock",
		Size = Vector3.new(3.2, 0.4, (dockEnd - dockStart).Magnitude),
		CFrame = CFrame.lookAt(dockMid + Vector3.new(0, 0.7, 0), dockMid + Vector3.new(0, 0.7, 0) + inward),
		Color = Color3.fromRGB(190, 132, 78),
		Material = Enum.Material.WoodPlanks,
	})
	for _, along in { 0.2, 0.8 } do
		for _, sx in { -1, 1 } do
			local p = dockStart:Lerp(dockEnd, along) + Vector3.new(-inward.Z, 0, inward.X) * sx * 1.5
			part(f, {
				Name = "DockPost",
				Size = Vector3.new(0.4, 1.4, 0.4),
				CFrame = CFrame.new(p + Vector3.new(0, 0.4, 0)),
				Color = Color3.fromRGB(120, 78, 46),
				Material = Enum.Material.Wood,
			})
		end
	end
	local spot = dockEnd - inward * 0.8
	part(f, {
		Name = "FishSpot",
		Size = Vector3.one,
		CFrame = CFrame.lookAt(spot + Vector3.new(0, 3.9, 0), spot + inward * 5 + Vector3.new(0, 3.9, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	-- Rod (anchored, held out over the water) and line to a red-white bobber
	local tip = spot + inward * 3.6 + Vector3.new(0, 6, 0)
	local hand = spot + inward * 0.9 + Vector3.new(0, 3.6, 0)
	part(f, {
		Name = "Rod",
		Size = Vector3.new(0.15, 0.15, (tip - hand).Magnitude),
		CFrame = CFrame.lookAt((hand + tip) / 2, tip),
		Color = Color3.fromRGB(120, 78, 46),
		CanCollide = false,
	})
	local bobberPos = spot + inward * 6.5 + Vector3.new(0, 0.5, 0)
	part(f, {
		Name = "FishingLine",
		Size = Vector3.new(0.05, 0.05, (bobberPos - tip).Magnitude),
		CFrame = CFrame.lookAt((tip + bobberPos) / 2, bobberPos),
		Color = Color3.fromRGB(255, 255, 255),
		CanCollide = false,
		CanQuery = false,
	})
	local bobber = part(f, {
		Name = "Bobber",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.6,
		CFrame = CFrame.new(bobberPos),
		Color = Color3.fromRGB(235, 60, 60),
		CanCollide = false,
		CanQuery = false,
	})
	bobber:SetAttribute("Rest", bobberPos)
end

-- Picnic: a checkered blanket with a basket and snacks, two "PicnicSeat" spots facing each other.
local function buildPicnic(parent: Instance)
	local f = folder("Picnic", parent)
	local dir = flatDir(World.PicnicAngle)
	local c = dir * World.PicnicRadius
	Landscape.flatDisc(c, 5, Enum.Material.LeafyGrass)
	local cf = CFrame.lookAt(c, c + dir)
	local n, cell = 4, 1.6
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			part(f, {
				Name = "Blanket",
				Size = Vector3.new(cell, 0.1, cell),
				CFrame = cf * CFrame.new((i - (n - 1) / 2) * cell, 0.06, (j - (n - 1) / 2) * cell),
				Color = if (i + j) % 2 == 0
					then Color3.fromRGB(230, 70, 80)
					else Color3.fromRGB(255, 255, 255),
				Material = Enum.Material.Fabric,
				CanCollide = false,
			})
		end
	end
	-- basket with a handle
	part(f, {
		Name = "Basket",
		Size = Vector3.new(1.4, 0.9, 1),
		CFrame = cf * CFrame.new(0, 0.55, 0.9),
		Color = Color3.fromRGB(190, 140, 80),
		Material = Enum.Material.WoodPlanks,
	})
	part(f, {
		Name = "BasketHandle",
		Size = Vector3.new(0.12, 0.9, 0.12),
		CFrame = cf * CFrame.new(0, 1.3, 0.9),
		Color = Color3.fromRGB(150, 100, 55),
		CanCollide = false,
	})
	-- snacks: a cake, cupcakes, a juice bottle
	cylinder(
		f,
		"Cake",
		0.5,
		1,
		cf * CFrame.new(-0.6, 0.35, -0.6) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 190, 220)
	).CanCollide =
		false
	for k = 0, 2 do
		part(f, {
			Name = "Cupcake",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.45,
			CFrame = cf * CFrame.new(0.5 + k * 0.4, 0.3, -0.4),
			Color = ({
				Color3.fromRGB(255, 220, 90),
				Color3.fromRGB(150, 220, 255),
				Color3.fromRGB(255, 150, 200),
			})[k + 1],
			CanCollide = false,
		})
	end
	cylinder(
		f,
		"Juice",
		0.8,
		0.35,
		cf * CFrame.new(1.1, 0.5, 0.6) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 160, 40)
	).CanCollide =
		false
	for k, side in { -1, 1 } do
		local seat = part(f, {
			Name = "PicnicSeat",
			Size = Vector3.one,
			CFrame = CFrame.lookAt(
				(cf * CFrame.new(side * 2.2, 1.55, 0)).Position,
				(cf * CFrame.new(0, 1.55, 0)).Position
			),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		seat:SetAttribute("Seat", k)
	end
end

-- Kite meadow: where the kite flyer stands ("KiteSpot"); the kite itself is moved by the bot.
local function buildKiteSpot(parent: Instance)
	local f = folder("KiteMeadow", parent)
	local dir = flatDir(World.KiteAngle)
	local c = dir * World.KiteRadius
	part(f, {
		Name = "KiteSpot",
		Size = Vector3.one,
		-- facing out over the meadow, where the kite flies
		CFrame = CFrame.lookAt(c + Vector3.new(0, 3, 0), c + dir * 10 + Vector3.new(0, 3, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local kite = part(f, {
		Name = "Kite",
		Size = Vector3.new(3.2, 3.2, 0.15),
		CFrame = CFrame.new(c + dir * 22 + Vector3.new(0, 30, 0)),
		Color = Color3.fromRGB(255, 90, 140),
		CanCollide = false,
		CanQuery = false,
	})
	part(kite, {
		Name = "KiteStripe",
		Size = Vector3.new(0.4, 4.4, 0.18),
		CFrame = kite.CFrame,
		Color = Color3.fromRGB(255, 220, 60),
		CanCollide = false,
		CanQuery = false,
	})
	for k = 1, 4 do
		part(f, {
			Name = "KiteBow",
			Size = Vector3.new(0.7, 0.35, 0.1),
			CFrame = kite.CFrame * CFrame.new(0, -2 - k * 1.1, 0),
			Color = ({
				Color3.fromRGB(110, 190, 255),
				Color3.fromRGB(120, 220, 110),
				Color3.fromRGB(255, 205, 50),
				Color3.fromRGB(175, 120, 255),
			})[k],
			CanCollide = false,
			CanQuery = false,
		})
	end
	part(f, {
		Name = "KiteString",
		Size = Vector3.new(0.05, 0.05, 1),
		CFrame = CFrame.new(c),
		Color = Color3.fromRGB(255, 255, 255),
		CanCollide = false,
		CanQuery = false,
	})
end

-- Painter's corner: an easel with a canvas facing the plaza (the painter faces the valley).
local function buildEasel(parent: Instance)
	local f = folder("Easel", parent)
	local dir = flatDir(World.PaintAngle)
	local c = dir * World.PaintRadius
	local spot = c - dir * 1.8
	part(f, {
		Name = "PaintSpot",
		Size = Vector3.one,
		CFrame = CFrame.lookAt(spot + Vector3.new(0, 3, 0), c + Vector3.new(0, 3, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local cf = CFrame.lookAt(c, c - dir) -- canvas front faces the painter / plaza
	for _, x in { -1.1, 1.1 } do
		part(f, {
			Name = "EaselLeg",
			Size = Vector3.new(0.18, 5, 0.18),
			CFrame = cf * CFrame.new(x, 2.4, 0) * CFrame.Angles(math.rad(-8), 0, math.rad(x * 6)),
			Color = Color3.fromRGB(150, 100, 55),
			Material = Enum.Material.Wood,
		})
	end
	part(f, {
		Name = "EaselBackLeg",
		Size = Vector3.new(0.18, 5, 0.18),
		CFrame = cf * CFrame.new(0, 2.3, 0.9) * CFrame.Angles(math.rad(20), 0, 0),
		Color = Color3.fromRGB(150, 100, 55),
		Material = Enum.Material.Wood,
	})
	local canvas = part(f, {
		Name = "Canvas",
		Size = Vector3.new(3.2, 2.5, 0.12),
		CFrame = cf * CFrame.new(0, 3.6, -0.2) * CFrame.Angles(math.rad(-8), 0, 0),
		Color = Color3.fromRGB(255, 252, 240),
	})
	local g = Instance.new("SurfaceGui")
	g.Name = "Painting"
	g.Face = Enum.NormalId.Front
	g.CanvasSize = Vector2.new(320, 250)
	g.LightInfluence = 0.3
	g.MaxDistance = 80
	g.Parent = canvas
	-- palette on a stool
	cylinder(
		f,
		"Stool",
		1.6,
		1.2,
		CFrame.new(spot + (CFrame.lookAt(c, c - dir)).RightVector * 1.6 + Vector3.new(0, 0.8, 0))
			* CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(150, 100, 55)
	).Material =
		Enum.Material.Wood
	for k = 0, 3 do
		part(f, {
			Name = "PaintBlob",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.35,
			CFrame = CFrame.new(
				spot
					+ (CFrame.lookAt(c, c - dir)).RightVector * 1.6
					+ Vector3.new(math.cos(k) * 0.35, 1.7, math.sin(k) * 0.35)
			),
			Color = ({
				Color3.fromRGB(255, 80, 90),
				Color3.fromRGB(80, 160, 255),
				Color3.fromRGB(255, 220, 60),
				Color3.fromRGB(110, 210, 90),
			})[k + 1],
			CanCollide = false,
		})
	end
end

function WorldFun.build(world: Instance)
	local fun = folder("Fun", world)
	buildMushrooms(fun)
	buildBunting(fun)
	buildTulips(fun)
	buildCampsite(fun)
	buildLake(fun)
	buildPicnic(fun)
	buildKiteSpot(fun)
	buildEasel(fun)
end

-- Spots the random decor (trees, bushes, rocks) must keep clear of.
function WorldFun.blocked(flat: Vector3): boolean
	for _, deg in World.MushroomAngles do
		if (flat - flatDir(deg) * World.MushroomRadius).Magnitude < 12 then
			return true
		end
	end
	if (flat - flatDir(World.CampAngle) * World.CampRadius).Magnitude < 20 then
		return true
	end
	if (flat - flatDir(World.LakeAngle) * World.LakeRadius).Magnitude < World.LakeSize / 2 + 8 then
		return true
	end
	for _, spot in
		{
			{ World.PicnicAngle, World.PicnicRadius },
			{ World.KiteAngle, World.KiteRadius },
			{ World.PaintAngle, World.PaintRadius },
		}
	do
		if (flat - flatDir(spot[1]) * spot[2]).Magnitude < 10 then
			return true
		end
	end
	return false
end

return WorldFun

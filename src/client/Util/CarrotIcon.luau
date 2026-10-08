--!strict
-- A 3D carrot in a ViewportFrame for UI (CarrotDex, offline reveal). `silhouette` renders it
-- black for carrots not found yet.

local CarrotModel = require(script.Parent.CarrotModel)

local CarrotIcon = {}

function CarrotIcon.new(typeId: string, mutations: { string }, silhouette: boolean?): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(200, 200, 200)
	vf.LightColor = Color3.fromRGB(255, 255, 255)
	vf.LightDirection = Vector3.new(-1, -1, -1)
	if silhouette then
		vf.ImageColor3 = Color3.fromRGB(40, 30, 60)
	end
	CarrotIcon.set(vf, typeId, mutations)
	return vf
end

-- Replace the carrot shown in an existing icon.
function CarrotIcon.set(vf: ViewportFrame, typeId: string, mutations: { string })
	vf:ClearAllChildren()
	local model = CarrotModel.build(typeId, mutations, 1)
	local length = CarrotModel.length(model)
	model:PivotTo(CFrame.Angles(0, math.rad(30), math.rad(-22)))
	model.Parent = vf

	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	local centerY = (-length + 1.4) / 2
	local distance = (length + 1.6) * 1.75
	camera.CFrame = CFrame.lookAt(Vector3.new(0, centerY + 0.4, distance), Vector3.new(0, centerY, 0))
	camera.Parent = vf
	vf.CurrentCamera = camera
end

return CarrotIcon

--!strict
-- Lookups over the carrot configs, plus value for a concrete carrot.
-- Used by both server (authoritative) and client (display).

local Config = script.Parent:WaitForChild("Config")
local Carrots = require(Config:WaitForChild("Carrots"))
local Rarity = require(Config:WaitForChild("Rarity"))
local Sizes = require(Config:WaitForChild("Sizes"))
local Mutations = require(Config:WaitForChild("Mutations"))
local Economy = require(Config:WaitForChild("Economy"))
local Value = require(script.Parent:WaitForChild("Value"))
local Types = require(script.Parent:WaitForChild("Types"))

export type CarrotDef = Carrots.CarrotDef
export type RarityDef = Rarity.RarityDef
export type SizeDef = Sizes.SizeDef
export type MutationDef = Mutations.MutationDef

export type ValueContext = {
	market: number?,
	valueUpgrade: number?,
	prestige: number?,
	boosts: number?,
}

local CarrotInfo = {}

local typeById: { [string]: CarrotDef } = {}
local rarityById: { [string]: RarityDef } = {}
local sizeById: { [string]: SizeDef } = {}
local mutationById: { [string]: MutationDef } = {}

for _, c in Carrots do
	typeById[c.id] = c
end
for _, r in Rarity do
	rarityById[r.id] = r
end
for _, s in Sizes do
	sizeById[s.id] = s
end
for _, m in Mutations.List do
	mutationById[m.id] = m
end

CarrotInfo.TotalTypes = #Carrots
CarrotInfo.TotalStamps = #Carrots * #Mutations.List

function CarrotInfo.type(id: string): CarrotDef?
	return typeById[id]
end

function CarrotInfo.rarity(id: string): RarityDef?
	return rarityById[id]
end

function CarrotInfo.size(id: string): SizeDef?
	return sizeById[id]
end

function CarrotInfo.mutation(id: string): MutationDef?
	return mutationById[id]
end

function CarrotInfo.rarityOfType(typeId: string): RarityDef
	local t = typeById[typeId]
	local r = t and rarityById[t.rarity]
	return r or Rarity[1]
end

function CarrotInfo.rarityOrder(id: string): number
	local r = rarityById[id]
	return if r then r.order else 1
end

function CarrotInfo.isValid(carrot: Types.Carrot): boolean
	if not typeById[carrot.type] or not sizeById[carrot.size] then
		return false
	end
	for _, m in carrot.mutations do
		if not mutationById[m] then
			return false
		end
	end
	return true
end

function CarrotInfo.mutationMultiplier(mutations: { string }): number
	local mults = {}
	for _, id in mutations do
		local m = mutationById[id]
		if m then
			table.insert(mults, m.mult)
		end
	end
	return Value.mutationMultiplier(mults)
end

function CarrotInfo.value(carrot: Types.Carrot, ctx: ValueContext?): number
	local t = typeById[carrot.type]
	local s = sizeById[carrot.size]
	if not t or not s then
		return 0
	end
	local r = CarrotInfo.rarityOfType(carrot.type)
	local c: ValueContext = ctx or {}
	return Value.compute({
		base = r.baseValue * t.valueMult,
		size = s.mult,
		mutation = CarrotInfo.mutationMultiplier(carrot.mutations),
		market = c.market,
		valueUpgrade = c.valueUpgrade,
		prestige = c.prestige,
		boosts = c.boosts,
		boostCap = Economy.BoostCap,
	})
end

-- "Giant Golden Purple Carrot"
function CarrotInfo.displayName(carrot: Types.Carrot): string
	local parts = {}
	local s = sizeById[carrot.size]
	if s and s.id ~= "Normal" then
		table.insert(parts, s.name)
	end
	for _, id in carrot.mutations do
		local m = mutationById[id]
		if m then
			table.insert(parts, m.name)
		end
	end
	local t = typeById[carrot.type]
	table.insert(parts, if t then t.name else carrot.type)
	return table.concat(parts, " ")
end

-- Basket key "type|size|mut+mut" <-> Carrot
function CarrotInfo.key(carrot: Types.Carrot): string
	return carrot.type .. "|" .. carrot.size .. "|" .. table.concat(carrot.mutations, "+")
end

function CarrotInfo.fromKey(key: string): Types.Carrot?
	local parts = string.split(key, "|")
	if #parts ~= 3 then
		return nil
	end
	local mutations = if parts[3] == "" then {} else string.split(parts[3], "+")
	local carrot: Types.Carrot = { type = parts[1], size = parts[2], mutations = mutations }
	return if CarrotInfo.isValid(carrot) then carrot else nil
end

function CarrotInfo.color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- A rarity's color at time `t` (os.clock()). Divine ("rainbow") cycles every hue; Secret
-- ("mono") pulses between near-black and white when `animatedMono` is set (world labels), and is
-- plain white on UI text (which has dark outlines). Everything else is its static color.
function CarrotInfo.rarityColor(def: RarityDef, t: number?, animatedMono: boolean?): Color3
	local now = t or 0
	if def.style == "rainbow" then
		return Color3.fromHSV((now * 0.35) % 1, 0.72, 1)
	elseif def.style == "mono" then
		if animatedMono then
			local k = 0.5 + 0.5 * math.sin(now * 5)
			return Color3.fromRGB(15, 15, 18):Lerp(Color3.fromRGB(250, 250, 250), k)
		end
		return Color3.fromRGB(250, 250, 250)
	end
	return CarrotInfo.color(def.color)
end

-- Particle colors for a rarity: rainbow for Divine, black-and-white for Secret, otherwise the
-- rarity color fading to white.
function CarrotInfo.raritySequence(def: RarityDef): ColorSequence
	if def.style == "rainbow" then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 60)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 255, 120)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 200, 255)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(150, 90, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 220)),
		})
	elseif def.style == "mono" then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 10, 12)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 12)),
		})
	end
	return ColorSequence.new(CarrotInfo.color(def.color), Color3.new(1, 1, 1))
end

return CarrotInfo

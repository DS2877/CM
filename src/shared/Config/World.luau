--!strict
-- World layout (built in code by WorldBuilder).

local World = {
	FarmCount = 8,
	FarmRingRadius = 150, -- distance from market (origin) to each farm center (6x6 farms, ~17 stud gaps)
	PlotSize = 7,
	PlotGap = 3,
	FarmPadding = 9, -- grass between plots and fence (room for the spawn pad and pedestal)

	-- Grid cell (col, row) for each plot index, in unlock order. The farm grows outward:
	-- 4 = 2x2, 9 = 3x3, 16 = 4x4, 25 = 5x5, 36 = 6x6 (with the in-between steps filling a side).
	PlotCells = {
		{ -0.5, -0.5 },
		{ 0.5, -0.5 },
		{ -0.5, 0.5 },
		{ 0.5, 0.5 },
		{ 1.5, -0.5 },
		{ 1.5, 0.5 },
		{ -0.5, 1.5 },
		{ 0.5, 1.5 },
		{ 1.5, 1.5 },
		{ -1.5, -0.5 },
		{ -1.5, 0.5 },
		{ -1.5, 1.5 },
		{ -1.5, -1.5 },
		{ -0.5, -1.5 },
		{ 0.5, -1.5 },
		{ 1.5, -1.5 },
		{ 2.5, -1.5 },
		{ 2.5, -0.5 },
		{ 2.5, 0.5 },
		{ 2.5, 1.5 },
		{ -1.5, 2.5 },
		{ -0.5, 2.5 },
		{ 0.5, 2.5 },
		{ 1.5, 2.5 },
		{ 2.5, 2.5 },
		{ -2.5, -1.5 },
		{ -2.5, -0.5 },
		{ -2.5, 0.5 },
		{ -2.5, 1.5 },
		{ -2.5, 2.5 },
		{ -2.5, -2.5 },
		{ -1.5, -2.5 },
		{ -0.5, -2.5 },
		{ 0.5, -2.5 },
		{ 1.5, -2.5 },
		{ 2.5, -2.5 },
	},

	TreeCount = 46,
	Seed = 2026,
}

return World

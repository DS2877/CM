--!strict
-- World layout (built in code by WorldBuilder).

local World = {
	FarmCount = 8,
	FarmRingRadius = 100, -- distance from market (origin) to each farm center
	PlotSize = 7,
	PlotGap = 3,
	FarmPadding = 7, -- grass between plots and fence

	-- Grid cell (col, row) for each plot index, in unlock order.
	-- 4 = 2x2, 6 = 2x3, 9 = 3x3, 12 = 3x4, 16 = 4x4. Cells are centered on the farm.
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
	},

	TreeCount = 46,
	Seed = 2026,
}

return World

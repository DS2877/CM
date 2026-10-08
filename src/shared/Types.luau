--!strict
-- Shared types.

-- A harvested or growing carrot. Stored compactly in the profile basket as "type|size|mut+mut".
export type Carrot = {
	type: string,
	size: string,
	mutations: { string },
}

export type PlotState = "Empty" | "Growing" | "Ready"

-- Server -> owner, after a harvest.
export type HarvestResult = {
	plot: number,
	type: string,
	size: string,
	mutations: { string },
	rarity: string,
	value: number,
	isNewType: boolean,
	autoSold: boolean,
	found: number,
	totalTypes: number,
}

export type SellResult = {
	total: number,
	count: number,
}

export type Announcement = {
	playerName: string,
	userId: number,
	type: string,
	size: string,
	mutations: { string },
	rarity: string,
	value: number,
	scope: number, -- 1 personal toast, 2 server, 3 global
}

export type Notice = {
	text: string,
	kind: string?, -- "info" | "good" | "bad"
}

return {}

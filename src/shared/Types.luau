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
	bonus: number, -- market boom multiplier on this sale (1 = none)
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
	otherServer: boolean, -- arrived from another server via MessagingService
	jobId: string?, -- sender server (cross-server payload only)
}

export type DexState = {
	types: { [string]: boolean },
	stamps: { [string]: boolean }, -- "type|mutation"
}

export type RevealedCarrot = {
	type: string,
	size: string,
	mutations: { string },
	rarity: string,
	value: number,
	isNewType: boolean,
}

export type OfflineResult = {
	seconds: number,
	carrots: { RevealedCarrot }, -- sorted by value, best last
	total: number,
	soldTotal: number, -- part that went straight to cash because the basket was full
}

export type Notice = {
	text: string,
	kind: string?, -- "info" | "good" | "bad"
}

return {}

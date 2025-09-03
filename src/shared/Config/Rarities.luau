--!strict
-- Rarities module
-- Provides rarity config used by LuckService / ThingFactory / UI
-- Fields:
--   Chance: number (relative weight)
--   Colour: Color3 (display / highlight color)
--   ChatAnnouncement: boolean (announce spawn to chat)
--   VisualTier: number (1 = none, larger = fancier visuals)
--   VFX: string? (optional key for VFX prefab lookup)
--   EventOnly: boolean? (if true, only include when an event enables it)

export type RarityConfig = {
	Chance: number,
	Colour: Color3,
	ChatAnnouncement: boolean,
	VisualTier: number?,
	VFX: string?,
	EventOnly: boolean?,
}

export type Rarities = { [string]: RarityConfig }

local Rarities: Rarities = {
	-- Core rarities (always available)
	Common = {
		Chance = 60,
		Colour = Color3.fromRGB(200, 200, 200),
		ChatAnnouncement = false,
		VisualTier = 1,
		VFX = nil,
		EventOnly = false,
	},

	Uncommon = {
		Chance = 25,
		Colour = Color3.fromRGB(120, 200, 120),
		ChatAnnouncement = false,
		VisualTier = 2,
		VFX = "UncommonSwirl",
		EventOnly = false,
	},

	Rare = {
		Chance = 10,
		Colour = Color3.fromRGB(80, 160, 255),
		ChatAnnouncement = true,
		VisualTier = 3,
		VFX = "RareSparkle",
		EventOnly = false,
	},

	Epic = {
		Chance = 4,
		Colour = Color3.fromRGB(190, 90, 255),
		ChatAnnouncement = true,
		VisualTier = 4,
		VFX = "EpicAura",
		EventOnly = false,
	},

	Legendary = {
		Chance = 1,
		Colour = Color3.fromRGB(255, 200, 50),
		ChatAnnouncement = true,
		VisualTier = 5,
		VFX = "LegendaryFlare",
		EventOnly = false,
	},

	------------------------------------------------------------
	-- Event-only: Pixel Team (pixel-themed seasonal/event rarities)
	-- These are included in roll pools only when the corresponding
	-- event is active (EventService will merge these in).
	------------------------------------------------------------
	Pixel_Common = {
		Chance = 50, -- relative weight inside event pool
		Colour = Color3.fromRGB(150, 150, 150),
		ChatAnnouncement = false,
		VisualTier = 1,
		VFX = "PixelDustSmall",
		EventOnly = true,
	},

	Pixel_Rare = {
		Chance = 8,
		Colour = Color3.fromRGB(80, 220, 180),
		ChatAnnouncement = true,
		VisualTier = 3,
		VFX = "PixelSwirl",
		EventOnly = true,
	},

	Pixel_Epic = {
		Chance = 2,
		Colour = Color3.fromRGB(255, 120, 200),
		ChatAnnouncement = true,
		VisualTier = 4,
		VFX = "PixelBurst",
		EventOnly = true,
	},

	Pixel_Mythic = {
		Chance = 0.5,
		Colour = Color3.fromRGB(255, 90, 40),
		ChatAnnouncement = true,
		VisualTier = 5,
		VFX = "PixelSupernova",
		EventOnly = true,
	},
}

return Rarities

--[[
Spells-related enumerations
--]]
local enum = DataStore.Enum

enum.RidingSkills = {
	[33388] = { speed = 60, minLevel = 10, cost = 4 },		-- Apprentice Riding (Level 10 / Ground 60%)
	[33391] = { speed = 100, minLevel = 20, cost = 50 },		-- Journeyman Riding (Level 20 / Ground 100%)
	[34090] = { speed = 150, minLevel = 30, cost = 250 },		-- Expert Riding (Level 30 / Ground 100% Flying 150%)
	[34091] = { speed = 280, minLevel = 40, cost = 5000 },		-- Artisan Riding (Level 40 / Ground 100% Flying 280%)
	[90265] = { speed = 310, minLevel = 40, cost = 5000 },		-- Master Riding (Level 40 / Ground 100% Flying 310%)
}

enum.RidingSkillsSorted = { 33388, 33391, 34090, 34091, 90265 }

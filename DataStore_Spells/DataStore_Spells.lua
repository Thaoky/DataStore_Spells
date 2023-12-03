--[[	*** DataStore_Spells ***
Written by : Thaoky, EU-Marécages de Zangar
July 6th, 2009
--]]
if not DataStore then return end

local addonName = "DataStore_Spells"

_G[addonName] = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

local addon = _G[addonName]

local enum = DataStore.Enum

local AddonDB_Defaults = {
	global = {
		Characters = {
			['*'] = {				-- ["Account.Realm.Name"] 
				lastUpdate = nil,
				SpellTabs = {},
				Spells = {
					['*'] = {		-- "General", "Arcane", "Fire", etc...
						['*'] = nil
					}
				},
				ridingSkill = 0,
				ridingEquipment = nil,
			}
		}
	}
}

-- *** Utility functions ***
local bAnd = bit.band
local LeftShift = DataStore.LeftShift
local RightShift = DataStore.RightShift

-- *** Scanning functions ***
local function ScanSpellTab_Retail(tabID)
	local tabName, _, offset, numSpells = GetSpellTabInfo(tabID);
	if not tabName then return end
	
	local char = addon.ThisCharacter
	
	char.SpellTabs[tabID] = tabName
	
	local spells = char.Spells
	wipe(spells[tabName])
	
	local attrib
	
	for index = offset + 1, offset + numSpells do
		local spellType, spellID = GetSpellBookItemInfo(index, BOOKTYPE_SPELL)
		if spellID then
			-- spellLevel = 0 if the spell is known, or the actual future level if it is not known
			local spellLevel = GetSpellAvailableLevel(index, BOOKTYPE_SPELL)
		
			-- special treatment for the riding skill
			if enum.RidingSkills[spellID] and spellLevel == 0 then
				char.ridingSkill = spellID
			end
		
			attrib = 0
			if spellType == "FUTURESPELL" then
				attrib = spellLevel	-- 8 bits for the level
			end

			if spellType == "FLYOUT" then	-- flyout spells, like list of mage portals
				local flyoutID = spellID
				local _, _, numSlots, isKnown = GetFlyoutInfo(flyoutID)
				
				if isKnown then
					for i = 1, numSlots do
						local flyoutSpellID, _, isFlyoutSpellKnown = GetFlyoutSlotInfo(flyoutID, i)
						if isFlyoutSpellKnown then
							-- all info on this spell can be retrieved with GetSpellInfo()
							table.insert(spells[tabName], LeftShift(flyoutSpellID, 8))
						end
					end
				end
			else
				-- bits 0-7 : level (0 if known spell)
				-- bits 8- : spellID
				
				attrib = attrib + LeftShift(spellID, 8)
				-- all info on this spell can be retrieved with GetSpellInfo()
				table.insert(spells[tabName], attrib)
			end
		end
	end
end

local function ScanSpellTab_Classic(tabID)
	local tabName, _, offset, numSpells = GetSpellTabInfo(tabID);
	if not tabName then return end
	
	local char = addon.ThisCharacter
	
	char.SpellTabs[tabID] = tabName
	
	local spells = char.Spells
	local newSpells = {}
	-- wipe(spells[tabName])
	
	local spellType, spellID
	for index = offset + 1, offset + numSpells do
		local spellType, spellID = GetSpellBookItemInfo(index, BOOKTYPE_SPELL)
		
		if spellID then
			local _, rank = GetSpellBookItemName(index, BOOKTYPE_SPELL)
			-- all info on this spell can be retrieved with GetSpellInfo()
			if rank then
				table.insert(newSpells, format("%s|%s", spellID, rank))		-- ex: "43017|Rank 1",
			end
		end
	end
	
	-- if the spells were not properly loaded after logon, there is a risk that ranks will not properly be read
	-- thus newspells will contain nothing .. so update only if we could read something
	if #newSpells > 0 then
		spells[tabName] = newSpells
	end
end

local ScanSpellTab = ScanSpellTab_Classic

local function ScanSpells()
	local char = addon.ThisCharacter

	wipe(char.SpellTabs)
	for tabID = 1, GetNumSpellTabs() do
		ScanSpellTab(tabID)
	end

	char.lastUpdate = time()
end

-- *** Event Handlers ***
local function OnPlayerAlive()
	ScanSpells()
end

local function OnLearnedSpellInTab()
	ScanSpells()
end

local function OnMountJournalUsabilityChanged()
	addon.ThisCharacter.ridingEquipment = C_MountJournal.GetAppliedMountEquipmentID()
end

-- ** Mixins **
	
local _GetSpellInfo

if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
	-- Retail version
	_GetSpellInfo = function(character, school, index)
		-- bits 0-7 : level (0 if known spell)
		-- bits 8- : spellID

		local spellID, availableAt
		
		local spell = character.Spells[school][index]
		if spell then
			availableAt = bAnd(spell, 255)
			spellID = RightShift(spell, 8)
		end
		
		return spellID, availableAt
	end

else
	-- Vanilla & BC version
	_GetSpellInfo = function(character, school, index)
		if not character.Spells[school] or not character.Spells[school][index] then return end

		local spellID, rank = strsplit("|", character.Spells[school][index])
		
		return tonumber(spellID), rank
	end
end

local mixins = {
	GetNumSpells = function(character, school)
		return #character.Spells[school]
	end,
	
	GetSpellInfo = _GetSpellInfo,
	
	IsSpellKnown = function(character, spellID)
		-- Parse all magic schools
		for schoolName, _ in pairs(character.Spells) do
		
			-- Parse all spells
			for i = 1, #character.Spells[schoolName] do
				local id = _GetSpellInfo(character, schoolName, i)
				if id == spellID then
					return true
				end
			end
		end
	end,
	
	GetSpellTabs = function(character)
		return character.SpellTabs
	end,
}

if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then

	mixins["GetRidingSkill"] = function(character)
		local spellID = character.ridingSkill
		
		if enum.RidingSkills[spellID] then
			local spellName = GetSpellInfo(spellID)
			
			-- return the mount speed, the spell name, and the spell id in case the caller wants more info
			return enum.RidingSkills[spellID].speed, spellName, spellID, character.ridingEquipment
		end
		
		return 0, ""
	end
	
	mixins["IterateRidingSkills"] = function(callback)
		for _, spellID in ipairs(enum.RidingSkillsSorted) do
			callback(enum.RidingSkills[spellID])
		end
	end
end

function addon:OnInitialize()
	addon.db = LibStub("AceDB-3.0"):New(format("%sDB", addonName), AddonDB_Defaults)

	DataStore:RegisterModule(addonName, addon, mixins)
	DataStore:SetCharacterBasedMethod("GetNumSpells")
	DataStore:SetCharacterBasedMethod("GetSpellInfo")
	DataStore:SetCharacterBasedMethod("IsSpellKnown")
	DataStore:SetCharacterBasedMethod("GetSpellTabs")
	
	if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
		DataStore:SetCharacterBasedMethod("GetRidingSkill")
		ScanSpellTab = ScanSpellTab_Retail
	end
end

function addon:OnEnable()
	addon:RegisterEvent("PLAYER_ALIVE", OnPlayerAlive)
	addon:RegisterEvent("LEARNED_SPELL_IN_TAB", OnLearnedSpellInTab)
	
	if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
		addon:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED", OnMountJournalUsabilityChanged)
	end
end

function addon:OnDisable()
	addon:UnregisterEvent("PLAYER_ALIVE")
	addon:UnregisterEvent("LEARNED_SPELL_IN_TAB")
	
	if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
		addon:UnregisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
	end
end

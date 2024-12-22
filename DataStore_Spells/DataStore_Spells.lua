--[[	*** DataStore_Spells ***
Written by : Thaoky, EU-Marécages de Zangar
July 6th, 2009
--]]
if not DataStore then return end

local addonName, addon = ...
local thisCharacter
local spellTabs

local TableInsert = table.insert
local GetSpellTabInfo, GetSpellBookItemName = GetSpellTabInfo, GetSpellBookItemName
local GetFlyoutInfo, GetFlyoutSlotInfo, C_MountJournal = GetFlyoutInfo, GetFlyoutSlotInfo, C_MountJournal
local isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)

local enum = DataStore.Enum
local bit64 = LibStub("LibBit64")

-- *** Scanning functions ***
local function ScanSpellTab_Retail(tabID)
	local info = C_SpellBook.GetSpellBookSkillLineInfo(tabID)
	if not info then return end
	
	local tabName = info.name
	spellTabs[tabID] = tabName
	
	local char = thisCharacter
	char.Spells = char.Spells or {}
	local spells = char.Spells
	spells[tabName] = spells[tabName] or {}
	wipe(spells[tabName])
	
	local attrib
	local offset = info.itemIndexOffset
	local numSpells = info.numSpellBookItems
	
	for index = offset + 1, offset + numSpells do
		local info = C_SpellBook.GetSpellBookItemInfo(index, Enum.SpellBookSpellBank.Player)
		local spellID = info.spellID
		local spellType = info.itemType
		
		if spellID then
			-- spellLevel = 0 if the spell is known, or the actual future level if it is not known
			local spellLevel = C_SpellBook.GetSpellBookItemLevelLearned(index, Enum.SpellBookSpellBank.Player)
		
			-- special treatment for the riding skill
			if enum.RidingSkills[spellID] and spellLevel == 0 then
				char.ridingSkill = spellID
			end
		
			attrib = 0
			if spellType == Enum.SpellBookItemType.FutureSpell then
				attrib = spellLevel	-- 8 bits for the level
			end

			if spellType == Enum.SpellBookItemType.Flyout then	-- flyout spells, like list of mage portals
				local flyoutID = spellID
				local _, _, numSlots, isKnown = GetFlyoutInfo(flyoutID)
				
				if isKnown then
					for i = 1, numSlots do
						local flyoutSpellID, _, isFlyoutSpellKnown = GetFlyoutSlotInfo(flyoutID, i)
						if isFlyoutSpellKnown then
							-- all info on this spell can be retrieved with GetSpellInfo()
							TableInsert(spells[tabName], bit64:LeftShift(flyoutSpellID, 8))
						end
					end
				end
			else
				-- bits 0-7 : level (0 if known spell)
				-- bits 8- : spellID
				
				attrib = attrib + bit64:LeftShift(spellID, 8)
				-- all info on this spell can be retrieved with GetSpellInfo()
				TableInsert(spells[tabName], attrib)
			end
		end
	end

end

local function ScanSpellTab_Classic(tabID)
	local tabName, _, offset, numSpells = GetSpellTabInfo(tabID)
	if not tabName then return end
	
	spellTabs[tabID] = tabName
	
	local char = thisCharacter
	char.Spells = char.Spells or {}
	local spells = char.Spells
	
	spells[tabName] = spells[tabName] or {}
	wipe(spells[tabName])
	
	for index = offset + 1, offset + numSpells do
		local spellType, spellID = GetSpellBookItemInfo(index, BOOKTYPE_SPELL)
		
		if spellID then
			local _, rank = GetSpellBookItemName(index, BOOKTYPE_SPELL)
			-- all info on this spell can be retrieved with GetSpellInfo()
			if rank then
				TableInsert(spells[tabName], format("%s|%s", spellID, rank))		-- ex: "43017|Rank 1",
			end
		end
	end
end

local ScanSpellTab = isRetail and ScanSpellTab_Retail or ScanSpellTab_Classic
local GetNumSpellTabs = isRetail and C_SpellBook.GetNumSpellBookSkillLines or GetNumSpellTabs

local function ScanSpells()
	for tabID = 1, GetNumSpellTabs() do
		ScanSpellTab(tabID)
	end

	thisCharacter.lastUpdate = time()
end

-- ** Mixins **
local function _GetSpellInfo_Retail(character, school, index)
	-- bits 0-7 : level (0 if known spell)
	-- bits 8- : spellID

	local spellID, availableAt
	
	local spell = character.Spells[school][index]
	if spell then
		availableAt = bit64:GetBits(spell, 0, 8)
		spellID = bit64:RightShift(spell, 8)
	end
	
	return spellID, availableAt
end

local function _GetSpellInfo_Classic(character, school, index)
	if not character.Spells[school] or not character.Spells[school][index] then return end

	local spellID, rank = strsplit("|", character.Spells[school][index])
	
	return tonumber(spellID), rank
end

AddonFactory:OnAddonLoaded(addonName, function()
	DataStore:RegisterModule({
		addon = addon,
		addonName = addonName,
		rawTables = {
			"DataStore_Spells_Tabs"
		},
		characterTables = {
			["DataStore_Spells_Characters"] = {
				GetNumSpells = function(character, school)
					return #character.Spells[school]
				end,
				GetSpellTabs = function(character)
					return DataStore_Spells_Tabs[character.englishClass]
				end,
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
				GetRidingSkill = isRetail and function(character)
					local spellID = character.ridingSkill
					
					if enum.RidingSkills[spellID] then
						local spellName = C_Spell.GetSpellName(spellID)
						
						-- return the mount speed, the spell name, and the spell id in case the caller wants more info
						return enum.RidingSkills[spellID].speed, spellName, spellID, character.ridingEquipment
					end
					
					return 0, ""
				end,
				
				GetSpellInfo = isRetail and _GetSpellInfo_Retail or _GetSpellInfo_Classic
			},
		}
	})

	if isRetail then
		DataStore:RegisterMethod(addon, "IterateRidingSkills", function(callback)
			for _, spellID in ipairs(enum.RidingSkillsSorted) do
				callback(enum.RidingSkills[spellID])
			end
		end)
	end

	thisCharacter = DataStore:GetCharacterDB("DataStore_Spells_Characters", true)
	
	local _, englishClass = UnitClass("player")
	thisCharacter.englishClass = englishClass
	
	DataStore_Spells_Tabs[englishClass] = DataStore_Spells_Tabs[englishClass] or {}
	spellTabs = DataStore_Spells_Tabs[englishClass]		-- directly point to the proper table for this alt.
end)

AddonFactory:OnPlayerLogin(function() 
	addon:ListenTo("PLAYER_ALIVE", ScanSpells)
	addon:ListenTo("LEARNED_SPELL_IN_TAB", ScanSpells)
	
	if isRetail then
		addon:ListenTo("MOUNT_JOURNAL_USABILITY_CHANGED", function()
			thisCharacter.ridingEquipment = C_MountJournal.GetAppliedMountEquipmentID()
		end)
	end
end)

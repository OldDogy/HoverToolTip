local E, L = unpack(ElvUI)
local HTT = _G.HoverToolTip

local FONT_FLAGS = {
	NONE = "None",
	OUTLINE = "Outline",
	THICKOUTLINE = "Thick Outline",
	MONOCHROME = "Monochrome",
	MONOCHROMEOUTLINE = "Monochrome Outline",
	MONOCHROMETHICKOUTLINE = "Monochrome Thick Outline",
	SHADOW = "Shadow",
	SHADOWOUTLINE = "Shadow Outline",
	SHADOWTHICKOUTLINE = "Shadow Thick Outline",
}

local function RefreshHoverToolTip()
	if HTT and HTT.Refresh then
		HTT:Refresh()
	end
end

local function InlineGroup(order, name, args)
	return {
		order = order,
		type = "group",
		name = name,
		guiInline = true,
		args = args,
	}
end

local function Toggle(order, name, desc)
	return {
		order = order,
		type = "toggle",
		name = name,
		desc = desc,
		width = "full",
	}
end

local function Range(order, name, min, max, step, isPercent)
	return {
		order = order,
		type = "range",
		name = name,
		min = min,
		max = max,
		step = step,
		isPercent = isPercent,
	}
end

local function FontFlag(order, name)
	return {
		order = order,
		type = "select",
		name = name,
		values = FONT_FLAGS,
		sortByValue = true,
	}
end

local function GetLibrary(key, libName)
	if E and E.Libs and E.Libs[key] then
		return E.Libs[key]
	end

	if _G.LibStub then
		return _G.LibStub(libName, true)
	end
end

local options = {
	type = "group",
	name = "Hover ToolTip",
	get = function(info)
		local db = HTT and HTT:GetDB()
		return db and db[info[#info]]
	end,
	set = function(info, value)
		local db = HTT and HTT:GetDB()
		if not db then
			return
		end

		db[info[#info]] = value
		if HTT then
			HTT.db = db
		end

		RefreshHoverToolTip()
	end,
	args = {
		enable = {
			order = 1,
			type = "toggle",
			name = L and L["Enable"] or "Enable",
			desc = "Style Blizzard's own tooltip instead of copying protected tooltip text into a custom frame.",
			width = "full",
		},
		appearance = {
			order = 2,
			type = "group",
			name = "Appearance",
			args = {
				chrome = InlineGroup(1, "Chrome", {
					hideBackdrop = Toggle(1, "Transparent Backdrop", "Make the Blizzard tooltip backdrop and border transparent."),
					statusBar = Toggle(2, "Status Bar", "Show the tooltip status bar when Blizzard provides one."),
					unitInfoAboveName = Toggle(3, "Hover ToolTip Styling", "Move safe unit info above the name in the open world."),
				}),
				opacity = InlineGroup(2, "Opacity and Scale", {
					alpha = Range(1, "Backdrop Alpha", 0, 1, 0.01, true),
					textAlpha = Range(2, "Text Alpha", 0, 1, 0.01, true),
					scale = Range(3, "Scale", 0.5, 2, 0.01, true),
				}),
				fullDetails = InlineGroup(3, "Full Details", {
					detailsKey = {
						order = 1,
						type = "select",
						name = "Modifier Fallback",
						desc = "Use the WoW Key Bindings menu for the Hold Full Details bind. This modifier remains available as a fallback.",
						values = {
							SHIFT = "SHIFT",
							CTRL = "CTRL",
							ALT = "ALT",
							NONE = "NONE",
						},
					},
					detailsOnUnitFrames = Toggle(2, "Enable On Unit Frames", "Allow the full-details modifier to bypass player line hiding on styled unit-frame tooltips."),
				}),
			},
		},
		text = {
			order = 3,
			type = "group",
			name = "Text",
			args = {
				unitText = InlineGroup(1, "Units and Players", {
					titleTextSize = Range(1, "Title Size", 5, 60, 1),
					bodyTextSize = Range(2, "Body Size", 5, 60, 1),
				}),
				objectText = InlineGroup(2, "World Objects", {
					objectTitleTextSize = Range(1, "Object Title Size", 5, 60, 1),
					objectBodyTextSize = Range(2, "Object Body Size", 5, 60, 1),
				}),
				outlines = InlineGroup(3, "Outlines", {
					titleTextOutline = FontFlag(1, "Title Outline"),
					bodyTextOutline = FontFlag(2, "Body Outline"),
				}),
			},
		},
		data = {
			order = 4,
			type = "group",
			name = "Data",
			args = {
				quests = InlineGroup(1, "Quest Lines", {
					hideQuestTitles = Toggle(1, "Hide Quest Titles", "Hide Blizzard tooltip lines marked as quest titles."),
					hideQuestObjectives = Toggle(2, "Hide Quest Objectives", "Hide Blizzard tooltip lines marked as quest objectives."),
					hideQuestPlayers = Toggle(3, "Hide Quest Players", "Hide Blizzard tooltip lines marked as quest player progress."),
				}),
				players = InlineGroup(2, "Player Lines", {
					hidePlayerGuild = Toggle(1, "Hide Guild", "Hide the guild line on styled player mouseover and unit-frame tooltips."),
					hidePlayerTitle = Toggle(2, "Hide Title", "Replace the player name line with the unit's plain name when Blizzard includes a selected title."),
					hidePlayerRealm = Toggle(3, "Hide Realm", "Hide realm suffixes from player names and guild lines."),
					hidePlayerLevel = Toggle(4, "Hide Level", "Hide only the level from the player level/race line."),
					hidePlayerRace = Toggle(5, "Hide Race", "Hide only the race from the player level/race line."),
					hidePlayerClass = Toggle(6, "Hide Spec and Class", "Hide the spec/class line on styled player mouseover and unit-frame tooltips."),
					hidePlayerFaction = Toggle(7, "Hide Faction", "Hide the faction line on styled player mouseover and unit-frame tooltips."),
					hidePlayerPvP = Toggle(8, "Hide PvP", "Hide the PvP line on styled player mouseover and unit-frame tooltips."),
					hidePlayerMount = Toggle(9, "Hide Mount", "Hide the mount line shown on player tooltips."),
					hidePlayerTarget = Toggle(10, "Hide Target", "Hide the target line shown on player tooltips."),
					hidePlayerRole = Toggle(11, "Hide Role", "Hide the role line shown on player unit-frame tooltips."),
				}),
				npcs = InlineGroup(3, "NPC Lines", {
					hideNPCLevel = Toggle(1, "Hide Level", "Hide the level line on open-world NPC mouseover tooltips."),
					hideNPCCreatureType = Toggle(2, "Hide Creature Type", "Hide the creature type line on open-world NPC mouseover tooltips."),
					hideNPCClassification = Toggle(3, "Hide Classification", "Hide NPC classification text such as Elite, Rare, Rare Elite, or Boss."),
					hideNPCTitle = Toggle(4, "Hide Title", "Hide plain NPC title/subtitle lines that appear before the level/type row."),
					hideNPCAffiliation = Toggle(5, "Hide Affiliation", "Hide plain NPC affiliation lines that appear after the level/type row."),
					hideNPCThreat = Toggle(6, "Hide Threat", "Hide combat threat lines such as 100% Threat on NPC tooltips."),
					hideNPCTarget = Toggle(7, "Hide Target", "Hide target lines shown on NPC tooltips during combat."),
				}),
			},
		},
	},
}

function HTT:RegisterOptions()
	if self.optionsRegistered then
		return
	end

	local AceConfig = GetLibrary("AceConfig", "AceConfig-3.0")
	local AceConfigDialog = GetLibrary("AceConfigDialog", "AceConfigDialog-3.0")
	if not AceConfig or not AceConfigDialog then
		return
	end

	AceConfig:RegisterOptionsTable("HoverToolTip", options)
	AceConfigDialog:AddToBlizOptions("HoverToolTip", "Hover ToolTip")

	self.optionsRegistered = true
end

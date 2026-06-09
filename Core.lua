local E, L
if _G.ElvUI then
	E, L = unpack(_G.ElvUI)
end
local module = _G.HoverToolTip

local _G = _G
local floor = math.floor
local format = string.format
local max = math.max
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local strfind = string.find
local strgsub = string.gsub
local strlower = string.lower
local strmatch = string.match
local tconcat = table.concat
local tinsert = table.insert
local type = type
local wipe = wipe

local Enum = Enum
local GameTooltip = GameTooltip
local TooltipUtil = TooltipUtil

module.detailsBindingHeld = false
module.debugLog = module.debugLog or {}
module.traceLog = module.traceLog or {}
module.styledTooltips = {}

_G.BINDING_NAME_HOVERTOOLTIP_DETAILS = _G.BINDING_NAME_HOVERTOOLTIP_DETAILS or "HoverToolTip: Hold Full Details"

local IsDetailsOverrideActive
local IsDetailsOverrideForContext
local IsDataModificationAllowed
local IsVisualLayoutAllowed
local IsObjectTooltip
local IsUnitTooltip
local GetFirstTextureAlpha
local TraceLog
local GetBlizzardUnitFrameUnit

local TOOLTIP_NAMES = {
	"GameTooltip",
}

local BACKDROP_REGIONS = {
	"Bg",
	"Backdrop",
	"Background",
	"Center",
	"NineSlice",
	"Overlay",
	"Texture",
	"TopEdge",
	"BottomEdge",
	"LeftEdge",
	"RightEdge",
	"TopLeftCorner",
	"TopRightCorner",
	"BottomLeftCorner",
	"BottomRightCorner",
}

local CHROME_FRAME_KEYS = {
	"shadow",
	"MERStyle",
	"backdrop",
	"Backdrop",
	"Border",
	"NineSlice",
}

local COLOR_ELITE = { r = 213 / 255, g = 154 / 255, b = 18 / 255 }
local COLOR_RARE = { r = 226 / 255, g = 228 / 255, b = 226 / 255 }
local UNIT_INFO_ABOVE_NAME_REVEAL_DELAY = 0.08
local UNIT_FRAME_FIRST_REVEAL_DELAY = 0.08
local UNIT_FRAME_REFRESH_REVEAL_DELAY = 0.03
local RECENT_MOUSE_DOWN_WINDOW = 0.25
local DEBUG_SCHEMA_VERSION = 3

module.lingeringWorldHideGrace = module.lingeringWorldHideGrace or 0.8

local TooltipDataLineType = Enum and Enum.TooltipDataLineType
local TooltipDataType = Enum and Enum.TooltipDataType
local TOOLTIP_DATA_TYPE_UNIT = TooltipDataType and TooltipDataType.Unit or 2
local TOOLTIP_DATA_TYPE_OBJECT = TooltipDataType and TooltipDataType.Object
local LINE_TYPE_QUEST_OBJECTIVE = TooltipDataLineType and TooltipDataLineType.QuestObjective or 8
local LINE_TYPE_QUEST_TITLE = TooltipDataLineType and TooltipDataLineType.QuestTitle or 17
local LINE_TYPE_QUEST_PLAYER = TooltipDataLineType and TooltipDataLineType.QuestPlayer or 18

-- Retail 12.0.x exposes UnitName and UnitOwner as typed unit tooltip lines, but
-- level/race/class/guild are plain text lines and must not be filtered by text
-- unless the full-details override is active and secret values are handled.
local KNOWN_TOOLTIP_LINE_TYPES = {
	None = 0,
	Blank = 1,
	UnitName = 2,
	GemSocket = 3,
	AzeriteEssenceSlot = 4,
	AzeriteEssencePower = 5,
	LearnableSpell = 6,
	UnitThreat = 7,
	QuestObjective = 8,
	AzeriteItemPowerDescription = 9,
	RuneforgeLegendaryPowerDescription = 10,
	SellPrice = 11,
	ProfessionCraftingQuality = 12,
	SpellName = 13,
	CurrencyTotal = 14,
	ItemEnchantmentPermanent = 15,
	UnitOwner = 16,
	QuestTitle = 17,
	QuestPlayer = 18,
	NestedBlock = 19,
	ItemBinding = 20,
	EquipSlot = 21,
	ItemName = 22,
	Separator = 23,
	ToyName = 24,
	ToyText = 25,
	ToyEffect = 26,
	ToyDuration = 27,
	ToyDescription = 28,
	ToySource = 29,
	GemSocketEnchantment = 30,
	ItemLevel = 31,
	ItemUpgradeLevel = 32,
	SpellPassive = 33,
	SpellDescription = 34,
	ItemQuality = 35,
	TradeTimeRemaining = 36,
	FlavorText = 37,
	ItemSpellTriggerLearn = 38,
	LearnTransmogSet = 39,
	LearnTransmogIllusion = 40,
	ErrorLine = 41,
}

local LINE_TYPE_NAMES = {}
for name, value in pairs(KNOWN_TOOLTIP_LINE_TYPES) do
	LINE_TYPE_NAMES[value] = name
end
if type(TooltipDataLineType) == "table" then
	for name, value in pairs(TooltipDataLineType) do
		LINE_TYPE_NAMES[value] = name
	end
end

local TOOLTIP_DATA_TYPE_NAMES = {}
if type(TooltipDataType) == "table" then
	for name, value in pairs(TooltipDataType) do
		TOOLTIP_DATA_TYPE_NAMES[value] = name
	end
end

local function IsForbidden(frame)
	return frame and frame.IsForbidden and frame:IsForbidden()
end

local function SafeCall(object, method, ...)
	if not object or type(object[method]) ~= "function" or IsForbidden(object) then
		return
	end

	pcall(object[method], object, ...)
end

local function SafeText(value)
	if value == nil then
		return "nil"
	end

	if issecretvalue and issecretvalue(value) then
		return "<secret>"
	end

	return tostring(value)
end

local function IsSecretValue(value)
	return issecretvalue and issecretvalue(value)
end

function module:NormalizeTooltipLabelText(text)
	if not text or type(text) ~= "string" or IsSecretValue(text) then
		return nil
	end

	text = strgsub(text, "|c%x%x%x%x%x%x%x%x", "")
	text = strgsub(text, "|r", "")
	return strmatch(text, "^%s*(.-)%s*$")
end

function module:EscapePatternText(text)
	if not text then
		return nil
	end

	return strgsub(text, "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

function module:GetRestrictedInstanceState(tooltip)
	if tooltip ~= nil and tooltip ~= GameTooltip then
		return false, "none"
	end

	if type(IsInInstance) ~= "function" then
		return false, "none"
	end

	local ok, inInstance, instanceType = pcall(IsInInstance)
	if not ok then
		return false, "none"
	end

	if IsSecretValue(inInstance) or IsSecretValue(instanceType) then
		return true, "secret"
	end

	return inInstance == true and instanceType ~= "none", instanceType
end

function module:IsRestrictedInstanceTooltip(tooltip)
	return self:GetRestrictedInstanceState(tooltip)
end

function module:ShouldUseRestrictedInstancePath(tooltip)
	if not self:IsRestrictedInstanceTooltip(tooltip) then
		return false
	end

	local owner = tooltip == GameTooltip and tooltip.hoverToolTipForcedUnitFrameOwner
	if owner and GetBlizzardUnitFrameUnit(owner) then
		return false
	end

	local context = self:GetTooltipContext(tooltip)
	return not (
		context
		and context.isUnitFrameTooltip
		and context.unitKind == "player"
		and not context.unitIsSecret
	)
end

function module:IsMerathilisModuleEnabled(key)
	if type(_G.ElvUI_MerathilisUI) ~= "table" or not E or not E.db or not E.db.mui then
		return false
	end

	local merathilisDB = E.db.mui[key]
	if type(merathilisDB) == "table" then
		return merathilisDB.enable ~= false
	end

	return false
end

function module:IsMerathilisHoverToolTipEnabled()
	return self:IsMerathilisModuleEnabled("hoverToolTip")
end

function module:IsMerathilisNameHoverEnabled()
	return self:IsMerathilisModuleEnabled("nameHover")
end

function module:ShouldStandDownForMerathilis()
	return self:IsMerathilisHoverToolTipEnabled() or self:IsMerathilisNameHoverEnabled()
end

function module:HasElvUIUnitFrames()
	if not E or type(E.GetModule) ~= "function" then
		return false
	end

	if E.private and E.private.unitframe and E.private.unitframe.enable == false then
		return false
	end

	local ok, UF = pcall(E.GetModule, E, "UnitFrames", true)
	return ok and UF ~= nil
end

function module:OpenMerathilisHoverToolTipOptions()
	if not E then
		return
	end

	if type(E.ToggleOptions) == "function" then
		pcall(E.ToggleOptions, E)
	end

	local ACD = E.Libs and E.Libs.AceConfigDialog
	if ACD and type(ACD.SelectGroup) == "function" then
		local function selectGroup()
			pcall(ACD.SelectGroup, ACD, "ElvUI", "mui", "modules", "hoverToolTip")
		end

		if C_Timer and type(C_Timer.After) == "function" then
			C_Timer.After(0, selectGroup)
		else
			selectGroup()
		end
	end
end

local function GetFrameNameSafe(frame)
	if not frame or type(frame.GetName) ~= "function" or IsForbidden(frame) then
		return nil
	end

	local ok, name = pcall(frame.GetName, frame)
	return ok and name or nil
end

local function GetFrameDebugName(frame)
	if not frame then
		return "nil"
	end

	local name = GetFrameNameSafe(frame)
	if name then
		return name
	end

	if type(frame.GetDebugName) == "function" and not IsForbidden(frame) then
		local ok, debugName = pcall(frame.GetDebugName, frame)
		if ok and debugName then
			return debugName
		end
	end

	if type(frame.GetObjectType) == "function" and not IsForbidden(frame) then
		local ok, objectType = pcall(frame.GetObjectType, frame)
		if ok and objectType then
			return "<" .. objectType .. ">"
		end
	end

	return "<frame>"
end

local function GetFrameParentSafe(frame)
	if not frame or type(frame.GetParent) ~= "function" or IsForbidden(frame) then
		return nil
	end

	local ok, parent = pcall(frame.GetParent, frame)
	return ok and parent or nil
end

local function GetFrameUnitSafe(frame)
	if not frame or IsForbidden(frame) then
		return nil
	end

	if frame.unit then
		return frame.unit
	end

	if type(frame.GetAttribute) == "function" then
		local ok, unit = pcall(frame.GetAttribute, frame, "unit")
		return ok and unit or nil
	end
end

local function UnitExistsSafe(unit)
	if not unit or IsSecretValue(unit) then
		return false
	end

	local ok, exists = pcall(UnitExists, unit)
	return ok and not IsSecretValue(exists) and exists == true
end

local function UnitBoolSafe(func, unit, ...)
	if not UnitExistsSafe(unit) or type(func) ~= "function" then
		return false
	end

	local ok, result = pcall(func, unit, ...)
	return ok and not IsSecretValue(result) and result == true
end

local function UnitNumberSafe(func, unit, ...)
	if not UnitExistsSafe(unit) or type(func) ~= "function" then
		return nil
	end

	local ok, result = pcall(func, unit, ...)
	if ok and not IsSecretValue(result) and type(result) == "number" then
		return result
	end
end

local function UnitStringSafe(func, unit, ...)
	if not UnitExistsSafe(unit) or type(func) ~= "function" then
		return nil
	end

	local results = { pcall(func, unit, ...) }
	if not results[1] then
		return nil
	end

	for index = 2, #results do
		local value = results[index]
		if value ~= nil and not IsSecretValue(value) then
			return value
		end
	end
end

local function IsWorldFrameLike(frame)
	if frame == WorldFrame then
		return true
	end

	local name = GetFrameNameSafe(frame)
	return name == "WorldFrame"
end

local function IsDefaultWorldTooltipOwner(frame)
	if not frame then
		return true
	end

	if IsWorldFrameLike(frame) or frame == UIParent then
		return true
	end

	local name = GetFrameNameSafe(frame)
	return name == "UIParent"
end

local function IsNameplateFrame(frame)
	local name = GetFrameNameSafe(frame)
	return type(name) == "string" and (strfind(name, "NamePlate", 1, true) or strfind(name, "Plater", 1, true))
end

local BLIZZARD_UNIT_FRAME_NAMES = {
	PlayerFrame = true,
	PetFrame = true,
	TargetFrame = true,
	TargetFrameToT = true,
	FocusFrame = true,
	FocusFrameToT = true,
}

local function IsBlizzardUnitFrame(frame)
	local name = GetFrameNameSafe(frame)
	if type(name) ~= "string" then
		return false
	end

	if BLIZZARD_UNIT_FRAME_NAMES[name] then
		return true
	end

	return strfind(name, "^Compact") ~= nil
		or strfind(name, "^PartyMemberFrame%d+") ~= nil
		or strfind(name, "^Boss%dTargetFrame") ~= nil
		or strfind(name, "^ArenaEnemyFrame%d+") ~= nil
end

GetBlizzardUnitFrameUnit = function(frame)
	local current = frame
	for _ = 1, 8 do
		if not current then
			break
		end

		local unit = GetFrameUnitSafe(current)
		if UnitExistsSafe(unit) then
			return unit
		end

		local name = GetFrameNameSafe(current)
		if name == "PlayerFrame" or name == "PlayerFrameContent" then
			return "player"
		elseif name == "PetFrame" then
			return "pet"
		elseif name == "TargetFrame" then
			return "target"
		elseif name == "TargetFrameToT" then
			return "targettarget"
		elseif name == "FocusFrame" then
			return "focus"
		elseif name == "FocusFrameToT" then
			return "focustarget"
		elseif type(name) == "string" then
			local partyIndex = strmatch(name, "^PartyMemberFrame(%d+)")
			local bossIndex = strmatch(name, "^Boss(%d+)TargetFrame")
			local arenaIndex = strmatch(name, "^ArenaEnemyFrame(%d+)")
			if partyIndex then
				return "party" .. partyIndex
			elseif bossIndex then
				return "boss" .. bossIndex
			elseif arenaIndex then
				return "arena" .. arenaIndex
			end
		end

		current = GetFrameParentSafe(current)
	end
end

local function IsUnitOrNameplateFrame(frame)
	local current = frame
	for _ = 1, 8 do
		if not current then
			break
		end

		if UnitExistsSafe(GetFrameUnitSafe(current)) or UnitExistsSafe(GetBlizzardUnitFrameUnit(current)) or IsNameplateFrame(current) or IsBlizzardUnitFrame(current) then
			return true
		end

		current = GetFrameParentSafe(current)
	end

	return false
end

local function GetTooltipOwner(tooltip)
	if not tooltip or type(tooltip.GetOwner) ~= "function" or IsForbidden(tooltip) then
		return nil
	end

	local ok, owner = pcall(tooltip.GetOwner, tooltip)
	return ok and owner or nil
end

local function GetMouseFocusSafe()
	local focusFunc = GetMouseFocus or (GetMouseFoci and function()
		local foci = { GetMouseFoci() }
		return foci[1]
	end)

	if not focusFunc then
		return nil
	end

	local ok, focus = pcall(focusFunc)
	return ok and focus or nil
end

local function GetDisplayedUnitSafe(tooltip)
	if TooltipUtil and type(TooltipUtil.GetDisplayedUnit) == "function" then
		local ok, _, unit = pcall(TooltipUtil.GetDisplayedUnit, tooltip)
		if ok then
			return unit
		end
	end

	if tooltip and type(tooltip.GetUnit) == "function" and not IsForbidden(tooltip) then
		local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
		if ok then
			return unit
		end
	end
end

local function IsMouseoverUnit(unit)
	if not UnitExistsSafe(unit) then
		return false
	end

	if unit == "mouseover" then
		return true
	end

	if not UnitExistsSafe("mouseover") then
		return false
	end

	local ok, isUnit = pcall(UnitIsUnit, unit, "mouseover")
	return ok and isUnit == true
end

local function GetTimeSafe()
	return type(_G.GetTime) == "function" and _G.GetTime() or 0
end

local function IsPhysicalMouseButtonDown()
	if type(_G.IsMouseButtonDown) ~= "function" then
		return false
	end

	local ok, leftDown = pcall(_G.IsMouseButtonDown, "LeftButton")
	if ok and leftDown then
		return true
	end

	local rightOk, rightDown = pcall(_G.IsMouseButtonDown, "RightButton")
	return rightOk and rightDown == true
end

local function MarkMouseButtonDown(button)
	module.mouseButtonDown = true
	module.lastMouseDownButton = button
	module.lastMouseDownTime = GetTimeSafe()
end

local function MarkMouseButtonUp()
	module.mouseButtonDown = IsPhysicalMouseButtonDown()
	if not module.mouseButtonDown then
		module.lastMouseDownButton = nil
		module.lastMouseDownTime = nil
	end
end

local function IsRecentMouseButtonDown()
	if module.mouseButtonDown then
		return true
	end

	local lastMouseDownTime = module.lastMouseDownTime
	return type(lastMouseDownTime) == "number" and (GetTimeSafe() - lastMouseDownTime) <= RECENT_MOUSE_DOWN_WINDOW
end

local function IsAnyMouseButtonDown()
	return IsPhysicalMouseButtonDown() or IsRecentMouseButtonDown()
end

local function IsWorldMouseoverUnitTooltip(tooltip, context)
	if not IsUnitTooltip(tooltip) then
		return false
	end

	if IsMouseoverUnit(context.unit) then
		return true
	end

	if context.unitIsSecret and context.ownerWorld then
		return true
	end

	return IsUnitOrNameplateFrame(context.owner) or IsUnitOrNameplateFrame(context.focus)
end

local function IsWorldTargetUnitTooltip(context)
	return context
		and context.isGameTooltip
		and context.isUnit
		and context.isMouseoverUnit
		and context.ownerWorld
		and not context.ownerUnitFrame
		and not context.focusUnitFrame
		and context.unit == "target"
end

local function IsSoftTargetUnitTooltip(context)
	return context
		and context.isGameTooltip
		and context.isUnit
		and context.ownerWorld
		and type(context.unit) == "string"
		and strmatch(context.unit, "^soft")
		and not context.isUnitFrameTooltip
		and not context.ownerUnitFrame
		and not context.focusUnitFrame
end

local function IsClickedWorldUnitTooltip(context)
	return context
		and context.isGameTooltip
		and context.isUnit
		and context.ownerWorld
		and context.mouseButtonDown
		and not context.isUnitFrameTooltip
		and not context.ownerUnitFrame
		and not context.focusUnitFrame
end

local function GetTooltipDataSafe(tooltip)
	if tooltip and type(tooltip.GetTooltipData) == "function" and not IsForbidden(tooltip) then
		local ok, data = pcall(tooltip.GetTooltipData, tooltip)
		if ok and not IsSecretValue(data) then
			return data
		end
	end
end

local function GetReactionName(reaction)
	if not reaction then
		return nil
	elseif reaction >= 5 then
		return "friendly"
	elseif reaction == 4 then
		return "neutral"
	else
		return "hostile"
	end
end

local function GetClassificationKind(context)
	if not context or not context.isUnit or not UnitExistsSafe(context.unit) then
		return "none"
	elseif context.unitIsPlayer then
		return "player"
	elseif context.unitPlayerControlled then
		return "controlled"
	elseif context.unitCreatureType then
		return "npc"
	else
		return "unit"
	end
end

local function PopulateUnitClassification(context)
	local unit = context.unit
	local inInstance, instanceType = module:GetRestrictedInstanceState()
	context.inInstance = inInstance and true or false
	context.instanceType = instanceType

	if not context.isUnit then
		context.unitKind = "none"
		return
	end

	context.unitIsSecret = IsSecretValue(unit)
	if context.unitIsSecret then
		context.unitKind = "secretUnit"
		return
	end

	if not UnitExistsSafe(unit) then
		context.unitKind = "none"
		return
	end

	context.unitExists = true
	context.unitIsPlayer = UnitBoolSafe(UnitIsPlayer, unit)
	context.unitPlayerControlled = UnitBoolSafe(UnitPlayerControlled, unit)
	context.unitIsDead = UnitBoolSafe(UnitIsDeadOrGhost or UnitIsDead, unit)
	context.unitIsTapDenied = UnitBoolSafe(UnitIsTapDenied, unit)
	context.unitLevel = UnitNumberSafe(UnitLevel, unit)
	context.unitReaction = UnitNumberSafe(UnitReaction, unit, "player")
	context.unitReactionName = GetReactionName(context.unitReaction)

	if context.unitIsPlayer then
		context.unitClass = UnitStringSafe(UnitClass, unit)
		context.unitRace = UnitStringSafe(UnitRace, unit)
	else
		context.unitCreatureType = UnitStringSafe(UnitCreatureType, unit)
		context.unitClassification = UnitStringSafe(UnitClassification, unit)
	end

	context.unitKind = GetClassificationKind(context)
end

function module:IsNPCStyleUnit(context)
	return context
		and (
			context.unitKind == "npc"
			or (
				context.unitKind == "controlled"
				and not context.unitIsPlayer
				and context.unitCreatureType
			)
		)
end

function module:GetTooltipContext(tooltip)
	local data = GetTooltipDataSafe(tooltip)
	local context = {
		isGameTooltip = tooltip == GameTooltip,
		tooltipName = GetFrameNameSafe(tooltip),
		owner = GetTooltipOwner(tooltip),
		focus = GetMouseFocusSafe(),
		unit = GetDisplayedUnitSafe(tooltip),
	}

	context.ownerName = GetFrameDebugName(context.owner)
	context.focusName = GetFrameDebugName(context.focus)
	context.isUnit = IsUnitTooltip(tooltip) or IsSecretValue(context.unit) or UnitExistsSafe(context.unit)
	context.isObject = IsObjectTooltip(tooltip)
	context.isMouseoverUnit = IsMouseoverUnit(context.unit)
	context.ownerWorld = IsDefaultWorldTooltipOwner(context.owner)
	context.focusWorld = IsDefaultWorldTooltipOwner(context.focus)
	context.ownerUnitFrame = IsUnitOrNameplateFrame(context.owner)
	context.focusUnitFrame = IsUnitOrNameplateFrame(context.focus)
	context.unitIsSecret = IsSecretValue(context.unit)
	context.mouseButtonDown = IsAnyMouseButtonDown()
	PopulateUnitClassification(context)
	context.isUnitFrameTooltip = context.isGameTooltip
		and context.isUnit
		and (context.ownerUnitFrame or context.focusUnitFrame)
	context.isWorldTooltip = context.isGameTooltip
		and not context.isUnitFrameTooltip
		and (
			IsWorldMouseoverUnitTooltip(tooltip, context)
			or IsWorldTargetUnitTooltip(context)
			or IsSoftTargetUnitTooltip(context)
			or IsClickedWorldUnitTooltip(context)
			or (context.isObject and context.ownerWorld)
			or (not data and not context.isUnit and context.ownerWorld and context.focusWorld)
		)
	context.shouldStyleTooltip = context.isWorldTooltip or context.isUnitFrameTooltip

	if IsDetailsOverrideActive() then
		context.reason = "full-details-override"
	elseif not context.isGameTooltip then
		context.reason = "not-game-tooltip"
	elseif context.isWorldTooltip then
		context.reason = "world-mouseover"
	elseif context.isUnitFrameTooltip then
		context.reason = "unit-frame"
	else
		context.reason = "ui-or-unknown"
	end

	return context
end

function module:ShouldModifyTooltip(tooltip)
	local context = self:GetTooltipContext(tooltip)
	return context.shouldStyleTooltip, context
end

function module:IsWorldPlayerTooltip(tooltip)
	local shouldModify, context = self:ShouldModifyTooltip(tooltip)
	return shouldModify and context.unitKind == "player", context
end

function module:IsWorldNPCTooltip(tooltip)
	local shouldModify, context = self:ShouldModifyTooltip(tooltip)
	return shouldModify and self:IsNPCStyleUnit(context), context
end

function module:IsWorldControlledUnitTooltip(tooltip)
	local shouldModify, context = self:ShouldModifyTooltip(tooltip)
	return shouldModify and context.unitKind == "controlled", context
end

local function IsStaleStyledWorldUnitTooltip(tooltip, context)
	return tooltip
		and tooltip.hoverToolTipStyledData
		and context
		and context.isGameTooltip
		and context.isUnit
		and context.ownerWorld
		and not context.isUnitFrameTooltip
		and not context.isWorldTooltip
		and not context.isMouseoverUnit
		and not context.mouseButtonDown
end

local function IsLingeringWorldUnitTooltip(context)
	return context
		and context.isGameTooltip
		and context.isUnit
		and context.ownerWorld
		and not context.isUnitFrameTooltip
		and not context.isWorldTooltip
		and not context.isMouseoverUnit
		and not context.mouseButtonDown
end

local function HookTooltipScript(tooltip, scriptName, func)
	if not tooltip or type(tooltip.HookScript) ~= "function" or IsForbidden(tooltip) then
		return
	end

	if type(tooltip.HasScript) == "function" then
		local ok, hasScript = pcall(tooltip.HasScript, tooltip, scriptName)
		if not ok or not hasScript then
			return
		end
	end

	pcall(tooltip.HookScript, tooltip, scriptName, func)
end

local function SetRegionAlpha(region, alpha)
	if region and type(region.SetAlpha) == "function" and not IsForbidden(region) and not IsSecretValue(alpha) then
		pcall(region.SetAlpha, region, alpha)
	end
end

function module:SetRegionVertexColor(region, r, g, b, a)
	if region and type(region.SetVertexColor) == "function" and not IsForbidden(region) then
		pcall(region.SetVertexColor, region, r, g, b, a)
	end
end

local function GetFrameAlpha(frame)
	if frame and type(frame.GetAlpha) == "function" and not IsForbidden(frame) then
		local ok, alpha = pcall(frame.GetAlpha, frame)
		if ok and not IsSecretValue(alpha) and type(alpha) == "number" then
			return alpha
		end
	end
end

local function IsShownSafe(frame)
	if frame and type(frame.IsShown) == "function" and not IsForbidden(frame) then
		local ok, shown = pcall(frame.IsShown, frame)
		if ok then
			return not IsSecretValue(shown) and shown == true
		end
	end
end

local function IsTextureRegion(region)
	if not region or type(region.GetObjectType) ~= "function" or IsForbidden(region) then
		return false
	end

	local ok, objectType = pcall(region.GetObjectType, region)
	return ok and objectType == "Texture"
end

local function ForEachNineSliceRegion(tooltip, func)
	local nineSlice = tooltip and tooltip.NineSlice
	if not nineSlice or type(nineSlice.GetRegions) ~= "function" or IsForbidden(nineSlice) then
		return
	end

	local regions = { pcall(nineSlice.GetRegions, nineSlice) }
	if not regions[1] then
		return
	end

	for index = 2, #regions do
		func(index - 1, regions[index])
	end
end

local function ForEachTooltipTextureRegion(tooltip, func)
	if not tooltip or type(tooltip.GetRegions) ~= "function" or IsForbidden(tooltip) then
		return
	end

	local regions = { pcall(tooltip.GetRegions, tooltip) }
	if not regions[1] then
		return
	end

	for index = 2, #regions do
		local region = regions[index]
		if IsTextureRegion(region) then
			func(region)
		end
	end
end

local function ForEachTooltipChromeFrame(tooltip, func)
	if not tooltip then
		return
	end

	local seen = {}
	for _, key in ipairs(CHROME_FRAME_KEYS) do
		local frame = tooltip[key]
		if frame and not seen[frame] and type(frame.SetAlpha) == "function" and not IsForbidden(frame) then
			seen[frame] = true
			func(key, frame)
		end
	end
end

IsUnitTooltip = function(tooltip)
	if not tooltip or type(tooltip.IsTooltipType) ~= "function" or IsForbidden(tooltip) then
		return false
	end

	local ok, isUnitTooltip = pcall(tooltip.IsTooltipType, tooltip, TOOLTIP_DATA_TYPE_UNIT)
	return ok and not IsSecretValue(isUnitTooltip) and isUnitTooltip == true
end

IsObjectTooltip = function(tooltip)
	if not tooltip or IsForbidden(tooltip) then
		return false
	end

	if TOOLTIP_DATA_TYPE_OBJECT and type(tooltip.IsTooltipType) == "function" then
		local ok, isObjectTooltip = pcall(tooltip.IsTooltipType, tooltip, TOOLTIP_DATA_TYPE_OBJECT)
		if ok and not IsSecretValue(isObjectTooltip) and isObjectTooltip == true then
			return true
		end
	end

	local data = GetTooltipDataSafe(tooltip)
	local dataType = data and data.type
	if IsSecretValue(dataType) then
		return false
	end

	return dataType and TOOLTIP_DATA_TYPE_NAMES[dataType] == "Object"
end

local GetTooltipLine
local GetFontStringTextSafe
local GetNPCInfoLine
local GetUnitInfoLineIndex
local UnitFullNameSafe

local function ResetOriginalTooltipState(tooltip)
	if not tooltip then
		return
	end

	tooltip.hoverToolTipOriginal = nil
	tooltip.hoverToolTipStyledData = nil
	tooltip.hoverToolTipInfoAboveNameData = nil
	tooltip.hoverToolTipLastWorldStyleTime = nil
end

local function SuppressTooltipUntilStyled(tooltip)
	if not tooltip or IsForbidden(tooltip) or tooltip.hoverToolTipSuppressing then
		return
	end

	local shouldModify = module:ShouldModifyTooltip(tooltip)
	if not shouldModify then
		return
	end

	tooltip.hoverToolTipSuppressing = true
	tooltip.hoverToolTipSuppressedAlpha = GetFrameAlpha(tooltip) or 1
	SafeCall(tooltip, "SetAlpha", 0)
end

local function StopUnitFrameTooltipRefresh(context)
	local owner = context and context.owner
	if not context or not context.isUnitFrameTooltip or not owner or IsForbidden(owner) then
		return
	end

	if owner.UpdateTooltip then
		owner.UpdateTooltip = nil
	end
end

local function SetUnitFrameEnterScript(frame, onEnter)
	if not frame or IsForbidden(frame) or type(frame.SetScript) ~= "function" or type(frame.GetScript) ~= "function" then
		return
	end

	local ok, current = pcall(frame.GetScript, frame, "OnEnter")
	if ok and current then
		pcall(frame.SetScript, frame, "OnEnter", onEnter)
	end
end

local function StoreOriginalTooltipState(tooltip)
	if not tooltip or tooltip.hoverToolTipOriginal or IsForbidden(tooltip) then
		return
	end

	local original = {
		alpha = tooltip.hoverToolTipSuppressedAlpha or GetFrameAlpha(tooltip),
		statusBarAlpha = GetFrameAlpha(tooltip.StatusBar),
		regions = {},
		chromeFrames = {},
		fonts = {},
	}

	if type(tooltip.GetScale) == "function" then
		local ok, scale = pcall(tooltip.GetScale, tooltip)
		if ok and not IsSecretValue(scale) and type(scale) == "number" then
			original.scale = scale
		end
	end

	if type(tooltip.GetWidth) == "function" then
		local ok, width = pcall(tooltip.GetWidth, tooltip)
		if ok and not IsSecretValue(width) and type(width) == "number" then
			original.width = width
		end
	end

	if type(tooltip.GetHeight) == "function" then
		local ok, height = pcall(tooltip.GetHeight, tooltip)
		if ok and not IsSecretValue(height) and type(height) == "number" then
			original.height = height
		end
	end

	for _, key in ipairs(BACKDROP_REGIONS) do
		local region = tooltip[key]
		if region and type(region.GetAlpha) == "function" and not IsForbidden(region) then
			local ok, alpha = pcall(region.GetAlpha, region)
			if ok and not IsSecretValue(alpha) then
				original.regions[key] = alpha
			end
		end
	end

	original.nineSliceRegions = {}
	ForEachNineSliceRegion(tooltip, function(index, region)
		if region and type(region.GetAlpha) == "function" and not IsForbidden(region) then
			local ok, alpha = pcall(region.GetAlpha, region)
			if ok and not IsSecretValue(alpha) then
				original.nineSliceRegions[index] = alpha
			end
		end
	end)

	original.textureRegions = {}
	ForEachTooltipTextureRegion(tooltip, function(region)
		if region and type(region.GetAlpha) == "function" and not IsForbidden(region) then
			local ok, alpha = pcall(region.GetAlpha, region)
			if ok and not IsSecretValue(alpha) then
				original.textureRegions[region] = alpha
			end
		end
	end)

	ForEachTooltipChromeFrame(tooltip, function(_, frame)
		local alpha = GetFrameAlpha(frame)
		if alpha then
			original.chromeFrames[frame] = alpha
		end
	end)

	for i = 1, 30 do
		for _, side in ipairs({ "Left", "Right" }) do
			local line = GetTooltipLine(tooltip, side, i)
			if line and type(line.GetFont) == "function" and not IsForbidden(line) then
				local ok, file, size, flags = pcall(line.GetFont, line)
				if ok then
					local font = { file, size, flags, GetFrameAlpha(line) }
					if type(line.GetTextColor) == "function" then
						local colorOk, r, g, b, a = pcall(line.GetTextColor, line)
						if colorOk then
							font[5], font[6], font[7], font[8] = r, g, b, a
						end
					end

					original.fonts[side .. i] = font
				end
			end
		end
	end

	tooltip.hoverToolTipOriginal = original
end

local function RestoreTooltipState(tooltip)
	local original = tooltip and tooltip.hoverToolTipOriginal
	if not original or IsForbidden(tooltip) then
		return
	end

	if original.alpha then
		SafeCall(tooltip, "SetAlpha", original.alpha)
	end

	if original.scale then
		SafeCall(tooltip, "SetScale", original.scale)
	end

	if tooltip.hoverToolTipResizedToVisibleText then
		if original.width and type(tooltip.SetWidth) == "function" then
			pcall(tooltip.SetWidth, tooltip, original.width)
		end

		if original.height and type(tooltip.SetHeight) == "function" then
			pcall(tooltip.SetHeight, tooltip, original.height)
		end
	end

	for key, alpha in pairs(original.regions or {}) do
		SetRegionAlpha(tooltip[key], alpha)
	end

	if original.nineSliceRegions then
		ForEachNineSliceRegion(tooltip, function(index, region)
			if original.nineSliceRegions[index] then
				SetRegionAlpha(region, original.nineSliceRegions[index])
			end
		end)
	end

	for region, alpha in pairs(original.textureRegions or {}) do
		SetRegionAlpha(region, alpha)
	end

	for frame, alpha in pairs(original.chromeFrames or {}) do
		SetRegionAlpha(frame, alpha)
	end

	for i = 1, 30 do
		for _, side in ipairs({ "Left", "Right" }) do
			local line = GetTooltipLine(tooltip, side, i)
			if line then
				line.hoverToolTipSize = nil
				line.hoverToolTipOutline = nil
				if not original.fonts or not original.fonts[side .. i] then
					SetRegionAlpha(line, 1)
				end
			end
		end
	end

	if tooltip.StatusBar and original.statusBarAlpha then
		SetRegionAlpha(tooltip.StatusBar, original.statusBarAlpha)
	end

	for i = 1, 30 do
		for _, side in ipairs({ "Left", "Right" }) do
			local line = GetTooltipLine(tooltip, side, i)
			local font = original.fonts and original.fonts[side .. i]
			if line and font and font[1] and font[2] and type(line.SetFont) == "function" and not IsForbidden(line) then
				pcall(line.SetFont, line, font[1], font[2], font[3])
				SetRegionAlpha(line, font[4] or 1)
				if font[5] and font[6] and font[7] and type(line.SetTextColor) == "function" then
					pcall(line.SetTextColor, line, font[5], font[6], font[7], font[8] or 1)
				end
				line.hoverToolTipSize = nil
				line.hoverToolTipOutline = nil
			end

		end
	end

	if tooltip.hoverToolTipCustomBackdrop then
		SetRegionAlpha(tooltip.hoverToolTipCustomBackdrop, 0)
		SafeCall(tooltip.hoverToolTipCustomBackdrop, "Hide")
	end

	tooltip.hoverToolTipResizedToVisibleText = nil
end

local function ReleaseTooltipState(tooltip)
	RestoreTooltipState(tooltip)
	if tooltip and tooltip.hoverToolTipCustomBackdrop then
		SetRegionAlpha(tooltip.hoverToolTipCustomBackdrop, 0)
		SafeCall(tooltip.hoverToolTipCustomBackdrop, "Hide")
	end
	ResetOriginalTooltipState(tooltip)
end

local function ReleaseTooltipStatePreservingSuppression(tooltip)
	if not tooltip then
		return
	end

	local wasSuppressing = tooltip.hoverToolTipSuppressing
	local suppressedAlpha = tooltip.hoverToolTipSuppressedAlpha
	local holdSuppression = tooltip.hoverToolTipHoldSuppression

	ReleaseTooltipState(tooltip)

	if wasSuppressing or holdSuppression then
		tooltip.hoverToolTipSuppressing = true
		tooltip.hoverToolTipSuppressedAlpha = suppressedAlpha or GetFrameAlpha(tooltip) or 1
		tooltip.hoverToolTipHoldSuppression = holdSuppression
		SafeCall(tooltip, "SetAlpha", 0)
	end
end

local function ApplyPixelSettings(fontString)
	if not fontString or IsForbidden(fontString) then
		return
	end

	if fontString.SetSnapToPixelGrid then
		fontString:SetSnapToPixelGrid(true)
		fontString:SetTexelSnappingBias(0)
	end
end

function module:GetConfiguredFontPath()
	local db = module.db
	local key = db and db.fontFace
	if not key or key == "DEFAULT" then
		return
	end

	for _, font in ipairs(module.fontChoices or {}) do
		if font.key == key then
			local styleKey = db.fontStyle or "REGULAR"
			for _, style in ipairs(module.fontStyleChoices or {}) do
				if style.key == styleKey then
					return font[style.field] or font.bold or font.regular
				end
			end

			return font.regular
		end
	end
end

local function ApplyFont(fontString, size, outline)
	if not fontString or IsForbidden(fontString) then
		return false
	end

	local configuredFont = module:GetConfiguredFontPath()
	if fontString.FontTemplate and not configuredFont then
		fontString:FontTemplate(nil, size, outline)
	elseif fontString.SetFont then
		local font = configuredFont or (fontString.GetFont and fontString:GetFont())
		if not font and GameTooltipText and GameTooltipText.GetFont then
			font = GameTooltipText:GetFont()
		end
		font = font or STANDARD_TEXT_FONT

		local flags = outline or ""
		local shadow = false
		if flags == "NONE" then
			flags = ""
		elseif strfind(flags, "SHADOW", 1, true) then
			shadow = true
			flags = strgsub(flags, "SHADOW", "")
		end

		pcall(fontString.SetFont, fontString, font, size, flags)

		if fontString.SetShadowOffset then
			fontString:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
		end

		if fontString.SetShadowColor then
			fontString:SetShadowColor(0, 0, 0, shadow and 1 or 0)
		end
	end

	ApplyPixelSettings(fontString)
	fontString.hoverToolTipSize = size
	fontString.hoverToolTipOutline = outline
	return true
end

local function ApplyConfiguredLineStyle(tooltip, index, isTitle)
	local db = module.db
	if not db or not tooltip then
		return
	end

	local size = isTitle and (db.titleTextSize or 14) or (db.bodyTextSize or 11)
	local outline = isTitle and (db.titleTextOutline or "SHADOWOUTLINE") or (db.bodyTextOutline or "SHADOWOUTLINE")
	local alpha = isTitle and (db.titleTextAlpha or 1) or (db.textAlpha or 1)
	local left = GetTooltipLine(tooltip, "Left", index)
	local right = GetTooltipLine(tooltip, "Right", index)

	ApplyFont(left, size, outline)
	ApplyFont(right, size, outline)
	module:SetFontStringVisualAlpha(left, alpha)
	module:SetFontStringVisualAlpha(right, alpha)
end

function module:GetTooltipBackdropStyle(key)
	for _, style in ipairs(module.tooltipBackdropStyles or {}) do
		if style.key == key then
			return style
		end
	end

	return module.tooltipBackdropStyles and module.tooltipBackdropStyles[1]
end

function module:SetFontStringVisualAlpha(fontString, alpha)
	if not fontString or IsForbidden(fontString) or IsSecretValue(alpha) then
		return
	end

	SetRegionAlpha(fontString, alpha)
end

function module:SetCustomTooltipBackdrop(tooltip, db)
	if not tooltip or IsForbidden(tooltip) then
		return
	end

	if not db.customTooltipBackdrop then
		if tooltip.hoverToolTipCustomBackdrop then
			SetRegionAlpha(tooltip.hoverToolTipCustomBackdrop, 0)
			SafeCall(tooltip.hoverToolTipCustomBackdrop, "Hide")
		end
		return
	end

	local style = module:GetTooltipBackdropStyle(db.tooltipBackdropStyle)
	if not style or not style.texture then
		return
	end

	if not tooltip.hoverToolTipCustomBackdrop and type(tooltip.CreateTexture) == "function" then
		local texture = tooltip:CreateTexture(nil, "BACKGROUND", nil, -7)
		texture:SetPoint("TOPLEFT", tooltip, "TOPLEFT", -10, 10)
		texture:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", 10, -10)
		tooltip.hoverToolTipCustomBackdrop = texture
	end

	local texture = tooltip.hoverToolTipCustomBackdrop
	if texture then
		local scale = tonumber(db.customTooltipBackdropScale) or 1
		scale = math.max(0.5, math.min(scale, 1.75))
		local outsetX = 10 + ((scale - 1) * 42)
		local outsetY = 10 + ((scale - 1) * 24)

		SafeCall(texture, "ClearAllPoints")
		texture:SetPoint("TOPLEFT", tooltip, "TOPLEFT", -outsetX, outsetY)
		texture:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", outsetX, -outsetY)
		texture:SetTexture(style.texture)
		module:SetRegionVertexColor(texture, 1, 1, 1, 1)
		if texture.SetBlendMode then
			texture:SetBlendMode("BLEND")
		end
		if texture.SetHorizTile then
			texture:SetHorizTile(false)
		end
		if texture.SetVertTile then
			texture:SetVertTile(false)
		end
		texture:SetTexCoord(0, 1, 0, 1)
		SetRegionAlpha(texture, db.customTooltipBackdropAlpha or 0.85)
		SafeCall(texture, "Show")
	end
end

local function SetTooltipBackdropAlpha(tooltip, db)
	local usingCustomBackdrop = db.customTooltipBackdrop == true
	local backdropAlpha = (db.hideBackdrop or usingCustomBackdrop) and 0 or (db.backdropAlpha or db.alpha or 0.75)
	local borderAlpha = (db.hideBackdrop or usingCustomBackdrop) and 0 or (db.borderAlpha or backdropAlpha)
	local backdropR, backdropG, backdropB = 0, 0, 0
	local borderR, borderG, borderB = 0, 0, 0

	SafeCall(tooltip, "SetBackdropColor", backdropR, backdropG, backdropB, backdropAlpha)
	SafeCall(tooltip, "SetBackdropBorderColor", borderR, borderG, borderB, borderAlpha)

	for _, key in ipairs(BACKDROP_REGIONS) do
		if key == "NineSlice" then
			module:SetRegionVertexColor(tooltip[key], borderR, borderG, borderB, borderAlpha)
		else
			module:SetRegionVertexColor(tooltip[key], backdropR, backdropG, backdropB, backdropAlpha)
		end
		SetRegionAlpha(tooltip[key], key == "NineSlice" and borderAlpha or backdropAlpha)
	end

	ForEachNineSliceRegion(tooltip, function(_, region)
		module:SetRegionVertexColor(region, borderR, borderG, borderB, borderAlpha)
		SetRegionAlpha(region, borderAlpha)
	end)

	ForEachTooltipTextureRegion(tooltip, function(region)
		if region == tooltip.hoverToolTipCustomBackdrop then
			return
		end

		module:SetRegionVertexColor(region, backdropR, backdropG, backdropB, backdropAlpha)
		SetRegionAlpha(region, backdropAlpha)
	end)

	ForEachTooltipChromeFrame(tooltip, function(_, frame)
		SetRegionAlpha(frame, backdropAlpha)
	end)

	module:SetCustomTooltipBackdrop(tooltip, db)
end

local function PreHideUnitFrameTooltipChrome(tooltip, owner)
	if not module.db or not module.db.enable or tooltip ~= GameTooltip or IsForbidden(tooltip) then
		return
	end

	if module:IsRestrictedInstanceTooltip(tooltip) and not GetBlizzardUnitFrameUnit(owner) then
		return
	end

	if not IsUnitOrNameplateFrame(owner) then
		return
	end

	StoreOriginalTooltipState(tooltip)
	SetTooltipBackdropAlpha(tooltip, module.db)

	if tooltip.StatusBar then
		SetRegionAlpha(tooltip.StatusBar, module.db.statusBar and 1 or 0)
	end

	if not tooltip.hoverToolTipSuppressing then
		tooltip.hoverToolTipSuppressing = true
		tooltip.hoverToolTipSuppressedAlpha = GetFrameAlpha(tooltip) or 1
		SafeCall(tooltip, "SetAlpha", 0)
	end
end

local function SweepStyledTooltipChrome(tooltip)
	local db = module.db
	if not db or not db.enable or not tooltip or IsForbidden(tooltip) then
		return
	end

	local shouldModify, context = module:ShouldModifyTooltip(tooltip)
	if not shouldModify then
		return
	end

	if db.unitInfoAboveName
		and context
		and context.isUnit
		and IsVisualLayoutAllowed(context)
		and not tooltip.hoverToolTipStyling
	then
		local left1 = GetFontStringTextSafe(GetTooltipLine(tooltip, "Left", 1))
		local data = GetTooltipDataSafe(tooltip)
		local unitName = data and type(data.lines) == "table" and data.lines[1] and data.lines[1].leftText
		if not unitName and context.unit and not context.unitIsSecret then
			unitName = (UnitFullNameSafe and UnitFullNameSafe(context.unit)) or UnitStringSafe(UnitName, context.unit)
		end

		if left1 and unitName and (left1 == unitName or strfind(left1, unitName, 1, true)) then
			TraceLog("sweep-restyle-unit-info", tooltip, context)
			module:StyleTooltip(tooltip, true)
			return
		end
	end

	if module.traceEnabled then
	local textureAlpha = GetFirstTextureAlpha(tooltip)
	local statusAlpha = GetFrameAlpha(tooltip.StatusBar)
		if (not IsSecretValue(textureAlpha) and type(textureAlpha) == "number" and textureAlpha ~= 0)
			or (not db.statusBar and not IsSecretValue(statusAlpha) and type(statusAlpha) == "number" and statusAlpha ~= 0)
		then
			TraceLog("sweep-chrome", tooltip)
		end
	end
	SetTooltipBackdropAlpha(tooltip, db)

	if tooltip.StatusBar then
		SetRegionAlpha(tooltip.StatusBar, db.statusBar and 1 or 0)
	end
end

function GetTooltipLine(tooltip, side, index)
	local name = tooltip and tooltip.GetName and tooltip:GetName()
	if not name then
		return
	end

	return _G[name .. "Text" .. side .. index]
end

local function GetTooltipLineCount(tooltip)
	if tooltip and type(tooltip.NumLines) == "function" and not IsForbidden(tooltip) then
		local ok, count = pcall(tooltip.NumLines, tooltip)
		if ok and not IsSecretValue(count) and type(count) == "number" then
			return count
		end
	end

	return 30
end

GetFontStringTextSafe = function(fontString)
	if fontString and type(fontString.GetText) == "function" and not IsForbidden(fontString) then
		local ok, text = pcall(fontString.GetText, fontString)
		if ok and not IsSecretValue(text) then
			return text
		end
	end
end

local function HasVisibleTooltipText(tooltip)
	for index = 1, GetTooltipLineCount(tooltip) do
		local left = GetTooltipLine(tooltip, "Left", index)
		local right = GetTooltipLine(tooltip, "Right", index)
		local leftText = GetFontStringTextSafe(left)
		local rightText = GetFontStringTextSafe(right)

		if leftText and leftText ~= "" and IsShownSafe(left) and (GetFrameAlpha(left) or 0) > 0 then
			return true
		end

		if rightText and rightText ~= "" and IsShownSafe(right) and (GetFrameAlpha(right) or 0) > 0 then
			return true
		end
	end

	return false
end

function module:ShouldHoldRecentWorldTooltip(tooltip)
	if not HasVisibleTooltipText(tooltip) then
		return false
	end

	local textureAlpha = GetFirstTextureAlpha(tooltip)
	local statusAlpha = GetFrameAlpha(tooltip and tooltip.StatusBar)
	if (not IsSecretValue(textureAlpha) and type(textureAlpha) == "number" and textureAlpha ~= 0)
		or (self.db and not self.db.statusBar and not IsSecretValue(statusAlpha) and type(statusAlpha) == "number" and statusAlpha ~= 0)
	then
		return false
	end

	if self:HasActiveWorldUnitUnderCursor() then
		return true
	end

	local lastStyleTime = tooltip and tooltip.hoverToolTipLastWorldStyleTime
	return not IsSecretValue(lastStyleTime)
		and type(lastStyleTime) == "number"
		and (GetTimeSafe() - lastStyleTime) <= (self.lingeringWorldHideGrace or 0.8)
end

function module:HasActiveWorldUnitUnderCursor()
	if UnitExistsSafe("mouseover")
		or UnitExistsSafe("softenemy")
		or UnitExistsSafe("softfriend")
		or UnitExistsSafe("softinteract")
	then
		return true
	end

	return IsUnitOrNameplateFrame(GetMouseFocusSafe())
end

local function IsEmptyTooltipShell(tooltip, context)
	return tooltip
		and context
		and context.isGameTooltip
		and not context.isUnit
		and not context.isObject
		and not GetTooltipDataSafe(tooltip)
		and (not context.owner or context.ownerWorld)
		and not HasVisibleTooltipText(tooltip)
end

local function GetFontStringWidthSafe(fontString)
	if fontString and type(fontString.GetStringWidth) == "function" and not IsForbidden(fontString) then
		local ok, width = pcall(fontString.GetStringWidth, fontString)
		if ok and not IsSecretValue(width) and type(width) == "number" then
			return width
		end
	end

	return 0
end

local function GetFontStringHeightSafe(fontString)
	if fontString and type(fontString.GetStringHeight) == "function" and not IsForbidden(fontString) then
		local ok, height = pcall(fontString.GetStringHeight, fontString)
		if ok and not IsSecretValue(height) and type(height) == "number" then
			return height
		end
	end

	return 0
end

function module:GetFontStringDisplayWidth(fontString)
	local regionWidth = 0
	local stringWidth = GetFontStringWidthSafe(fontString) or 0

	if fontString and type(fontString.GetWidth) == "function" and not IsForbidden(fontString) then
		local ok, width = pcall(fontString.GetWidth, fontString)
		if ok and not IsSecretValue(width) and type(width) == "number" then
			regionWidth = width
		end
	end

	if stringWidth <= 1 then
		local text = GetFontStringTextSafe(fontString)
		if text and text ~= "" and type(text) == "string" then
			text = text:gsub("|cff%x%x%x%x%x%x", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
			stringWidth = max(stringWidth, (#text * 7) + 4)
		end
	end

	if stringWidth > 1 and (regionWidth <= 1 or stringWidth > regionWidth) then
		return stringWidth
	end

	return regionWidth
end

local function GetRegionLeftSafe(region)
	if region and type(region.GetLeft) == "function" and not IsForbidden(region) then
		local ok, left = pcall(region.GetLeft, region)
		if ok and not IsSecretValue(left) and type(left) == "number" then
			return left
		end
	end
end

local function GetRegionRightSafe(region)
	if region and type(region.GetRight) == "function" and not IsForbidden(region) then
		local ok, right = pcall(region.GetRight, region)
		if ok and not IsSecretValue(right) and type(right) == "number" then
			return right
		end
	end
end

local function GetRegionTopSafe(region)
	if region and type(region.GetTop) == "function" and not IsForbidden(region) then
		local ok, top = pcall(region.GetTop, region)
		if ok and not IsSecretValue(top) and type(top) == "number" then
			return top
		end
	end
end

local function GetRegionBottomSafe(region)
	if region and type(region.GetBottom) == "function" and not IsForbidden(region) then
		local ok, bottom = pcall(region.GetBottom, region)
		if ok and not IsSecretValue(bottom) and type(bottom) == "number" then
			return bottom
		end
	end
end

local function GetRegionWidthSafe(region)
	if region and type(region.GetWidth) == "function" and not IsForbidden(region) then
		local ok, width = pcall(region.GetWidth, region)
		if ok and not IsSecretValue(width) and type(width) == "number" then
			return width
		end
	end
end

local function GetRegionHeightSafe(region)
	if region and type(region.GetHeight) == "function" and not IsForbidden(region) then
		local ok, height = pcall(region.GetHeight, region)
		if ok and not IsSecretValue(height) and type(height) == "number" then
			return height
		end
	end
end

local function GetFramePointSafe(frame)
	if frame and type(frame.GetPoint) == "function" and not IsForbidden(frame) then
		local ok, point, relativeTo, relativePoint, x, y = pcall(frame.GetPoint, frame, 1)
		if ok then
			if IsSecretValue(x) then
				x = nil
			end
			if IsSecretValue(y) then
				y = nil
			end

			return point, relativeTo, relativePoint, x, y
		end
	end
end

local function SetFontStringTextSafe(fontString, text)
	if fontString and type(fontString.SetText) == "function" and not IsForbidden(fontString) then
		pcall(fontString.SetText, fontString, text)
	end
end

local function SetFontStringColorSafe(fontString, r, g, b, a)
	if fontString and type(fontString.SetTextColor) == "function" and not IsForbidden(fontString) then
		pcall(fontString.SetTextColor, fontString, r or 1, g or 1, b or 1, a or 1)
	end
end

local function GetFontStringColorSafe(fontString)
	if fontString and type(fontString.GetTextColor) == "function" and not IsForbidden(fontString) then
		local ok, r, g, b, a = pcall(fontString.GetTextColor, fontString)
		if ok and not IsSecretValue(r) and not IsSecretValue(g) and not IsSecretValue(b) and not IsSecretValue(a) then
			return r, g, b, a
		end
	end
end

local function ShowFontStringSafe(fontString)
	if fontString and type(fontString.Show) == "function" and not IsForbidden(fontString) then
		pcall(fontString.Show, fontString)
	end
end

local function ClearTooltipLine(tooltip, index)
	local left = GetTooltipLine(tooltip, "Left", index)
	local right = GetTooltipLine(tooltip, "Right", index)

	-- Keep the fontstring participating in Blizzard's tooltip layout. Calling
	-- Hide() can collapse compact unit rows in Retail 12.0.x.
	if left then
		SetFontStringTextSafe(left, "")
		ShowFontStringSafe(left)
		SetRegionAlpha(left, 0)
	end

	if right then
		SetFontStringTextSafe(right, "")
		ShowFontStringSafe(right)
		SetRegionAlpha(right, 0)
	end
end

function module:RestoreTooltipLineFromData(tooltip, index)
	local data = GetTooltipDataSafe(tooltip)
	local line = data and type(data.lines) == "table" and data.lines[index]
	if not line then
		return
	end

	local leftText = not IsSecretValue(line.leftText) and line.leftText or nil
	local rightText = not IsSecretValue(line.rightText) and line.rightText or nil
	local left = GetTooltipLine(tooltip, "Left", index)
	local right = GetTooltipLine(tooltip, "Right", index)
	local alpha = index == 1 and ((module.db and module.db.titleTextAlpha) or 1) or ((module.db and module.db.textAlpha) or 1)

	if left and leftText then
		SetFontStringTextSafe(left, leftText)
		ShowFontStringSafe(left)
		module:SetFontStringVisualAlpha(left, alpha)
	end

	if right and rightText then
		SetFontStringTextSafe(right, rightText)
		ShowFontStringSafe(right)
		module:SetFontStringVisualAlpha(right, alpha)
	end
end

function module:RestoreTooltipLinesFromData(tooltip)
	local data = GetTooltipDataSafe(tooltip)
	if not data or type(data.lines) ~= "table" then
		return
	end

	for index = 1, #data.lines do
		self:RestoreTooltipLineFromData(tooltip, index)
	end
end

local function ReplaceTooltipLineLeft(tooltip, index, text, r, g, b)
	local left = GetTooltipLine(tooltip, "Left", index)
	if not left then
		return
	end

	SetFontStringTextSafe(left, text or "")
	if r and g and b then
		SetFontStringColorSafe(left, r, g, b, 1)
	end
	ShowFontStringSafe(left)
	SetRegionAlpha(left, text and ((module.db and module.db.textAlpha) or 1) or 0)
end

local function ReplaceTooltipLineRight(tooltip, index, text, r, g, b)
	local right = GetTooltipLine(tooltip, "Right", index)
	if not right then
		return
	end

	SetFontStringTextSafe(right, text or "")
	if r and g and b then
		SetFontStringColorSafe(right, r, g, b, 1)
	end

	if text and text ~= "" then
		if type(right.SetJustifyH) == "function" then
			pcall(right.SetJustifyH, right, "RIGHT")
		end
	end

	ShowFontStringSafe(right)
	SetRegionAlpha(right, text and ((module.db and module.db.textAlpha) or 1) or 0)
end

local function ColorToHex(value)
	value = floor(((value or 1) * 255) + 0.5)
	if value < 0 then
		value = 0
	elseif value > 255 then
		value = 255
	end

	return format("%02x", value)
end

local function WrapColorText(text, r, g, b)
	if not text then
		return nil
	end

	return "|cff" .. ColorToHex(r) .. ColorToHex(g) .. ColorToHex(b) .. text .. "|r"
end

local function IsLineSafeToHide(tooltip, index)
	local data = GetTooltipDataSafe(tooltip)
	local line = data and type(data.lines) == "table" and data.lines[index]
	if not line then
		return true
	end

	if line.type and line.type ~= KNOWN_TOOLTIP_LINE_TYPES.None and line.type ~= KNOWN_TOOLTIP_LINE_TYPES.Blank then
		return false
	end

	if IsSecretValue(line.leftText) or IsSecretValue(line.rightText) then
		return false
	end

	return true
end

local function HideOptionalLine(tooltip, index)
	if IsLineSafeToHide(tooltip, index) then
		ClearTooltipLine(tooltip, index)
	end
end

local function GetSafeTooltipDataLineText(tooltip, index)
	local data = GetTooltipDataSafe(tooltip)
	local line = data and type(data.lines) == "table" and data.lines[index]
	if not line or IsSecretValue(line.leftText) or IsSecretValue(line.rightText) then
		return nil
	end

	if line.type and line.type ~= KNOWN_TOOLTIP_LINE_TYPES.None and line.type ~= KNOWN_TOOLTIP_LINE_TYPES.Blank then
		return nil
	end

	return line.leftText
end

function module:GetTooltipDataLineLeftText(tooltip, index)
	local data = GetTooltipDataSafe(tooltip)
	local line = data and type(data.lines) == "table" and data.lines[index]
	if not line or IsSecretValue(line.leftText) then
		return nil
	end

	return line.leftText
end

UnitFullNameSafe = function(unit)
	if not UnitExistsSafe(unit) or type(UnitFullName) ~= "function" then
		return nil
	end

	local ok, name, realm = pcall(UnitFullName, unit)
	if not ok or IsSecretValue(name) or IsSecretValue(realm) then
		return nil
	end

	if realm and realm ~= "" and not (module.db and module.db.hidePlayerRealm) then
		return name .. "-" .. realm
	end

	return name
end

local function StripRealmSuffix(text)
	if not text or text == "" then
		return text
	end

	return strgsub(text, "%-[^%-]+$", "")
end

local function StripRealmFromLine(tooltip, index)
	local line = GetTooltipLine(tooltip, "Left", index)
	local text = GetFontStringTextSafe(line)
	local stripped = StripRealmSuffix(text)
	if stripped and stripped ~= text then
		ReplaceTooltipLineLeft(tooltip, index, stripped)
	end
end

local function GetUnitClassColor(unit)
	if not UnitExistsSafe(unit) or type(UnitClass) ~= "function" then
		return nil
	end

	local ok, _, classFile = pcall(UnitClass, unit)
	if not ok or IsSecretValue(classFile) then
		return nil
	end

	local color = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
	if color then
		return color.r, color.g, color.b
	end
end

local function GetUnitNameColor(context)
	if not context or not context.unit then
		return nil
	end

	if context.unitKind == "player" then
		return GetUnitClassColor(context.unit)
	end

	if UnitBoolSafe(UnitIsTapDenied, context.unit) and _G.TAPPED_COLOR then
		return _G.TAPPED_COLOR.r, _G.TAPPED_COLOR.g, _G.TAPPED_COLOR.b
	end

	local reaction = context.unitReaction
	local colors = ElvUF and ElvUF.colors and ElvUF.colors.reaction
	local color = reaction and colors and colors[reaction]
	if color then
		return color.r, color.g, color.b
	end

	if reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction] then
		color = FACTION_BAR_COLORS[reaction]
		return color.r, color.g, color.b
	end

	return 1, 1, 1
end

local GetPlayerInfoParts

local function ApplyPlayerNameFilters(tooltip, context, index)
	local db = module.db
	if not db or not tooltip or not context or not context.unit then
		return
	end

	index = index or 1

	local line = GetTooltipLine(tooltip, "Left", index)
	local currentText = GetFontStringTextSafe(line)
	if not currentText then
		return
	end

	if db.hidePlayerTitle then
		local plainName = UnitFullNameSafe(context.unit) or UnitStringSafe(UnitName, context.unit)
		if plainName then
			ReplaceTooltipLineLeft(tooltip, index, plainName, GetUnitClassColor(context.unit))
			return
		end
	end

	if db.hidePlayerRealm then
		StripRealmFromLine(tooltip, index)
		local r, g, b = GetUnitClassColor(context.unit)
		if r and g and b then
			SetFontStringColorSafe(line, r, g, b, 1)
		end
	end
end

local function IsPlayerLevelRaceText(text)
	if not text then
		return false
	end

	local levelPrefix = _G.LEVEL or "Level"
	return strmatch(text, "^" .. levelPrefix .. "%s+") or strfind(text, "%(Player%)") ~= nil
end

local function IsPlayerFactionText(text)
	return text == (_G.FACTION_HORDE or "Horde")
		or text == (_G.FACTION_ALLIANCE or "Alliance")
		or text == "Horde"
		or text == "Alliance"
end

local function IsPlayerPvPText(text)
	return text == (_G.PVP or "PvP") or text == "PvP"
end

local function IsPlayerSocialStatusText(text)
	if not text then
		return false
	end

	text = strgsub(text, "|c%x%x%x%x%x%x%x%x", "")
	text = strgsub(text, "|r", "")
	text = strgsub(text, "|T.-|t", "")
	text = strmatch(text, "^%s*(.-)%s*$") or text
	return text == "Recent Allies" or text == "Recent Ally" or strfind(text, "Recent Allies", 1, true) ~= nil
end

local function ClearPlayerSocialStatusLines(tooltip)
	for index = 2, GetTooltipLineCount(tooltip) do
		local text = GetFontStringTextSafe(GetTooltipLine(tooltip, "Left", index)) or GetSafeTooltipDataLineText(tooltip, index)
		if IsPlayerSocialStatusText(text) then
			ClearTooltipLine(tooltip, index)
		end
	end
end

local function IsPlayerMountLine(tooltip, index)
	local left = GetTooltipLine(tooltip, "Left", index)
	local text = module:NormalizeTooltipLabelText(GetFontStringTextSafe(left) or GetSafeTooltipDataLineText(tooltip, index))
	if not text then
		return false
	end

	local mountText = module:NormalizeTooltipLabelText(_G.MOUNT or "Mount")
	local mountColonText = module:NormalizeTooltipLabelText(_G.MOUNT_COLON or (mountText and (mountText .. ":")))
	local mountPattern = module:EscapePatternText(mountText)
	return text == mountText
		or text == mountColonText
		or (mountPattern and strfind(text, "^" .. mountPattern .. "%s*:", 1, false) ~= nil)
end

local function IsPlayerTargetLine(tooltip, index)
	local left = GetTooltipLine(tooltip, "Left", index)
	local text = module:NormalizeTooltipLabelText(GetFontStringTextSafe(left) or GetSafeTooltipDataLineText(tooltip, index))
	if not text then
		return false
	end

	local targetText = module:NormalizeTooltipLabelText(_G.TARGET or "Target")
	local targetColonText = module:NormalizeTooltipLabelText(_G.TARGET_COLON or (targetText and (targetText .. ":")))
	local targetPattern = module:EscapePatternText(targetText)
	return text == targetText
		or text == targetColonText
		or (targetPattern and strfind(text, "^" .. targetPattern .. "%s*:", 1, false) ~= nil)
end

function module:GetTooltipTargetLine(tooltip)
	if not tooltip then
		return nil
	end

	local data = GetTooltipDataSafe(tooltip)
	for index = 2, GetTooltipLineCount(tooltip) do
		if IsPlayerTargetLine(tooltip, index) then
			local line = data and type(data.lines) == "table" and data.lines[index]
			local right = GetTooltipLine(tooltip, "Right", index)
			local targetText = GetFontStringTextSafe(right)

			if (not targetText or targetText == "") and line and not IsSecretValue(line.rightText) then
				targetText = line.rightText
			end

			local targetR, targetG, targetB, targetA = GetFontStringColorSafe(right)
			return index, targetText, targetR or 1, targetG or 1, targetB or 1, targetA or 1
		end
	end
end

function module:GetTooltipThreatLine(tooltip)
	if not tooltip then
		return nil
	end

	local data = GetTooltipDataSafe(tooltip)
	for index = 2, GetTooltipLineCount(tooltip) do
		local line = data and type(data.lines) == "table" and data.lines[index]
		if line and line.type == KNOWN_TOOLTIP_LINE_TYPES.UnitThreat then
			local left = GetTooltipLine(tooltip, "Left", index)
			local threatText = GetFontStringTextSafe(left)

			if (not threatText or threatText == "") and line and not IsSecretValue(line.leftText) then
				threatText = line.leftText
			end

			local percent = threatText and strmatch(threatText, "([%d%.]+%%)")
			local threatR, threatG, threatB, threatA = GetFontStringColorSafe(left)
			return index, percent, threatR or 1, threatG or 1, threatB or 1, threatA or 1
		end
	end
end

function module:IsPlayerRoleLine(tooltip, index)
	local left = GetTooltipLine(tooltip, "Left", index)
	local text = self:NormalizeTooltipLabelText(GetFontStringTextSafe(left) or GetSafeTooltipDataLineText(tooltip, index))
	if not text then
		return false
	end

	local roleText = self:NormalizeTooltipLabelText(_G.ROLE or "Role")
	local roleColonText = self:NormalizeTooltipLabelText(_G.ROLE_COLON or (roleText and (roleText .. ":")))
	local rolePattern = self:EscapePatternText(roleText)
	return text == roleText
		or text == roleColonText
		or (rolePattern and strfind(text, "^" .. rolePattern .. "%s*:", 1, false) ~= nil)
end

function module:GetUnitThreatPercent(context)
	if not context or not context.unit or type(UnitDetailedThreatSituation) ~= "function" then
		return nil
	end

	local ok, _, _, scaledPercent = pcall(UnitDetailedThreatSituation, "player", context.unit)
	if not ok or IsSecretValue(scaledPercent) or type(scaledPercent) ~= "number" then
		return nil
	end

	return format("%d%%", floor(scaledPercent + 0.5))
end

function module:ApplyThreatPercentToInfoLine(tooltip, context, infoIndex)
	local db = self.db
	if not db or not tooltip or not context or not context.isUnit or not infoIndex then
		return
	end

	local threatIndex, percent, threatR, threatG, threatB = self:GetTooltipThreatLine(tooltip)
	if not percent or percent == "" then
		percent = self:GetUnitThreatPercent(context)
		threatR, threatG, threatB = 1, 1, 1
	end
	if not threatIndex and (not percent or percent == "") then
		return
	end

	local showFullDetails = IsDetailsOverrideForContext(context)
	local hideThreat = not showFullDetails and self:IsNPCStyleUnit(context) and db.hideNPCThreat
	if hideThreat then
		if threatIndex then
			ClearTooltipLine(tooltip, threatIndex)
		end
		return
	end

	local right = GetTooltipLine(tooltip, "Right", infoIndex)
	local currentRight = GetFontStringTextSafe(right)
	if currentRight and currentRight ~= "" then
		currentRight = strgsub(currentRight, "%s*[%d%.]+%%%s*$", "")
	end

	local text = WrapColorText(percent, threatR or 1, threatG or 1, threatB or 1)
	if currentRight and currentRight ~= "" then
		text = currentRight .. " " .. text
	end

	ReplaceTooltipLineRight(tooltip, infoIndex, text, 1, 1, 1)
	if threatIndex then
		ClearTooltipLine(tooltip, threatIndex)
	end
end

function module:GetUnitTargetNameAndColor(context)
	if not context or not context.unit then
		return nil
	end

	local targetUnit = context.unit .. "target"
	if not UnitExistsSafe(targetUnit) then
		return nil
	end

	local targetText = UnitFullNameSafe(targetUnit) or UnitStringSafe(UnitName, targetUnit)
	if not targetText or targetText == "" then
		return nil
	end

	local targetR, targetG, targetB
	if UnitBoolSafe(UnitIsPlayer, targetUnit) then
		targetR, targetG, targetB = GetUnitClassColor(targetUnit)
	end

	if not targetR or not targetG or not targetB then
		local reaction = UnitNumberSafe(UnitReaction, targetUnit, "player")
		local colors = ElvUF and ElvUF.colors and ElvUF.colors.reaction
		local color = reaction and colors and colors[reaction]
		if color then
			targetR, targetG, targetB = color.r, color.g, color.b
		elseif reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction] then
			color = FACTION_BAR_COLORS[reaction]
			targetR, targetG, targetB = color.r, color.g, color.b
		end
	end

	return targetText, targetR or 1, targetG or 1, targetB or 1
end

function module:ApplyTargetNameToNameLine(tooltip, context, nameIndex)
	local db = self.db
	if not db or not tooltip or not context or not context.isUnit or not nameIndex then
		return
	end

	if context.unitKind ~= "player" and not self:IsNPCStyleUnit(context) then
		return
	end

	local targetIndex, targetText, targetR, targetG, targetB = self:GetTooltipTargetLine(tooltip)
	if not targetText or targetText == "" then
		targetText, targetR, targetG, targetB = self:GetUnitTargetNameAndColor(context)
	end
	if not targetIndex and (not targetText or targetText == "") then
		return
	end

	local showFullDetails = IsDetailsOverrideForContext(context)
	local hideTarget = not showFullDetails
		and ((context.unitKind == "player" and db.hidePlayerTarget) or (self:IsNPCStyleUnit(context) and db.hideNPCTarget))
	if hideTarget then
		if targetIndex then
			ClearTooltipLine(tooltip, targetIndex)
		end
		return
	end

	local nameLine = GetTooltipLine(tooltip, "Left", nameIndex)
	local nameText = GetFontStringTextSafe(nameLine)
	if not nameLine or not nameText or nameText == "" or not targetText or targetText == "" then
		if targetIndex then
			ClearTooltipLine(tooltip, targetIndex)
		end
		return
	end

	nameText = strmatch(nameText, "^(.-)%s+=>%s+.*$") or strmatch(nameText, "^(.-)%s+|cff%x%x%x%x%x%x%-%>|r%s+.*$") or strmatch(nameText, "^(.-)%s+|cff%x%x%x%x%x%x➜|r%s+.*$") or nameText

	local nameR, nameG, nameB = GetUnitNameColor(context)
	if not nameR or not nameG or not nameB then
		nameR, nameG, nameB = GetFontStringColorSafe(nameLine)
	end

	SetFontStringTextSafe(
		nameLine,
		WrapColorText(nameText, nameR or 1, nameG or 1, nameB or 1) .. " " .. WrapColorText("->", 0.95, 0.25, 0.22) .. " " .. WrapColorText(targetText, targetR, targetG, targetB)
	)
	SetFontStringColorSafe(nameLine, 1, 1, 1, 1)
	ShowFontStringSafe(nameLine)
	self:SetFontStringVisualAlpha(nameLine, db.titleTextAlpha or 1)
	ReplaceTooltipLineRight(tooltip, nameIndex, nil)
	if targetIndex then
		ClearTooltipLine(tooltip, targetIndex)
	end
end

local function IsPlayerMythicLine(tooltip, index)
	local left = GetTooltipLine(tooltip, "Left", index)
	local text = GetFontStringTextSafe(left)
	if not text then
		return false
	end

	local scoreText = (L and L["Mythic+ Score:"]) or "Mythic+ Score:"
	local bestRunText = (L and L["Mythic+ Best Run:"]) or "Mythic+ Best Run:"
	return text == scoreText or text == bestRunText or strfind(text, "^Mythic%+", 1, false) ~= nil
end

local function GetPlayerLineIndexes(tooltip, context)
	local indexes = {}
	local mythicIndexes = {}
	local socialIndexes = {}
	local unitClass = context and context.unitClass
	local levelIndex

	for index = 2, GetTooltipLineCount(tooltip) do
		local text = GetSafeTooltipDataLineText(tooltip, index)
		local renderedText = GetFontStringTextSafe(GetTooltipLine(tooltip, "Left", index))
		if not indexes.mount and IsPlayerMountLine(tooltip, index) then
			indexes.mount = index
		end
		if not indexes.target and IsPlayerTargetLine(tooltip, index) then
			indexes.target = index
		end
		if not indexes.role and module:IsPlayerRoleLine(tooltip, index) then
			indexes.role = index
		end
		if IsPlayerMythicLine(tooltip, index) then
			tinsert(mythicIndexes, index)
		end
		if IsPlayerSocialStatusText(renderedText) then
			tinsert(socialIndexes, index)
		end

		if text then
			if not indexes.levelRace and IsPlayerLevelRaceText(text) then
				indexes.levelRace = index
				levelIndex = index
			elseif not indexes.class and unitClass and strfind(text, unitClass, 1, true) then
				indexes.class = index
			elseif not indexes.faction and IsPlayerFactionText(text) then
				indexes.faction = index
			elseif not indexes.pvp and IsPlayerPvPText(text) then
				indexes.pvp = index
			elseif not IsPlayerSocialStatusText(renderedText) and IsPlayerSocialStatusText(text) then
				tinsert(socialIndexes, index)
			end
		end
	end

	if levelIndex and levelIndex > 2 then
		for index = 2, levelIndex - 1 do
			local text = GetSafeTooltipDataLineText(tooltip, index)
			if text then
				indexes.guild = index
				break
			end
		end
	end

	indexes.mythic = mythicIndexes
	indexes.social = socialIndexes

	return indexes
end

local function IsPlayerClassText(text, context)
	return text and context and context.unitClass and strfind(text, context.unitClass, 1, true) ~= nil
end

local function ApplyPlayerLineFilters(tooltip, context)
	local db = module.db
	if not db or not tooltip then
		return
	end

	ApplyPlayerNameFilters(tooltip, context)

	local indexes = GetPlayerLineIndexes(tooltip, context)
	if db.hidePlayerRealm and indexes.guild then StripRealmFromLine(tooltip, indexes.guild) end
	if db.hidePlayerGuild and indexes.guild then HideOptionalLine(tooltip, indexes.guild) end
	if indexes.levelRace and (db.hidePlayerLevel or db.hidePlayerRace) then
		local showLevel = not db.hidePlayerLevel
		local showRace = not db.hidePlayerRace
		local levelText, raceText = GetPlayerInfoParts(context, showLevel, showRace)
		local text

		if levelText and raceText then
			text = levelText .. " " .. raceText
		else
			text = levelText or raceText
		end

		ReplaceTooltipLineLeft(tooltip, indexes.levelRace, text, 1, 1, 1)
		ReplaceTooltipLineRight(tooltip, indexes.levelRace, nil)
	end
	if db.hidePlayerClass and indexes.class then HideOptionalLine(tooltip, indexes.class) end
	if db.hidePlayerFaction and indexes.faction then HideOptionalLine(tooltip, indexes.faction) end
	if db.hidePlayerPvP and indexes.pvp then HideOptionalLine(tooltip, indexes.pvp) end
	if db.hidePlayerSocialStatus then
		ClearPlayerSocialStatusLines(tooltip)
	end
	if db.hidePlayerMount and indexes.mount then HideOptionalLine(tooltip, indexes.mount) end
	if db.hidePlayerTarget and indexes.target then ClearTooltipLine(tooltip, indexes.target) end
	if db.hidePlayerRole and indexes.role then ClearTooltipLine(tooltip, indexes.role) end
	for _, index in ipairs(indexes.mythic or {}) do
		ClearTooltipLine(tooltip, index)
	end
end

function module:GetInstancePlayerContext(tooltip)
	local unit = GetDisplayedUnitSafe(tooltip)
	if IsSecretValue(unit) or not UnitExistsSafe(unit) or not UnitBoolSafe(UnitIsPlayer, unit) then
		return
	end

	local context = {
		isGameTooltip = tooltip == GameTooltip,
		tooltipName = GetFrameNameSafe(tooltip),
		owner = GetTooltipOwner(tooltip),
		focus = GetMouseFocusSafe(),
		unit = unit,
		isUnit = true,
		isObject = false,
		shouldStyleTooltip = true,
		inInstance = true,
		unitIsPlayer = true,
		unitKind = "player",
	}

	context.ownerName = GetFrameDebugName(context.owner)
	context.focusName = GetFrameDebugName(context.focus)
	context.isMouseoverUnit = IsMouseoverUnit(unit)
	context.ownerWorld = IsDefaultWorldTooltipOwner(context.owner)
	context.focusWorld = IsDefaultWorldTooltipOwner(context.focus)
	context.ownerUnitFrame = IsUnitOrNameplateFrame(context.owner)
	context.focusUnitFrame = IsUnitOrNameplateFrame(context.focus)
	context.unitIsSecret = false
	context.mouseButtonDown = IsAnyMouseButtonDown()
	PopulateUnitClassification(context)
	context.isUnitFrameTooltip = context.isGameTooltip
		and context.isUnit
		and (context.ownerUnitFrame or context.focusUnitFrame)
	context.isWorldTooltip = context.isGameTooltip and not context.isUnitFrameTooltip

	return context
end

function module:ApplyInstancePlayerLineFilters(tooltip)
	local context = self:GetInstancePlayerContext(tooltip)
	if not context or context.unitKind ~= "player" or IsDetailsOverrideForContext(context) then
		return
	end

	ApplyPlayerLineFilters(tooltip, context)
end

function module:ApplyInstanceSecretUnitLineFilters(tooltip)
	local db = self.db
	if not db or not tooltip or IsDetailsOverrideActive() then
		return
	end

	local data = GetTooltipDataSafe(tooltip)
	if not data or data.type ~= TOOLTIP_DATA_TYPE_UNIT or type(data.lines) ~= "table" then
		return
	end

	local firstLine = data.lines[1]
	if not firstLine or not IsSecretValue(firstLine.leftText) then
		return
	end

	if not db.hideNPCThreat then
		return
	end

	for index, line in ipairs(data.lines) do
		if line and line.type == KNOWN_TOOLTIP_LINE_TYPES.UnitThreat then
			ClearTooltipLine(tooltip, index)
		end
	end
end

function module:IsSafeMouseoverLevelUnit()
	if not UnitExistsSafe("mouseover") then
		return false
	end

	if UnitBoolSafe(UnitIsGameObject, "mouseover") then
		return false
	end

	if UnitBoolSafe(UnitIsPlayer, "mouseover")
		or UnitBoolSafe(UnitCanAttack, "player", "mouseover")
		or UnitBoolSafe(UnitCanAssist, "player", "mouseover")
	then
		return true
	end

	local reaction = UnitNumberSafe(UnitReaction, "mouseover", "player")
	return reaction and reaction >= 5
end

local function GetSafeMouseoverLevelText()
	if not module:IsSafeMouseoverLevelUnit() then
		return nil
	end

	local level = UnitNumberSafe(UnitEffectiveLevel, "mouseover") or UnitNumberSafe(UnitLevel, "mouseover")
	if type(level) ~= "number" then
		return nil
	end

	if level == -1 then
		return "??", 1, 0.15, 0.15
	elseif level > 0 then
		return tostring(level), 1, 0.82, 0
	end
end

local function HideSecureInstanceLevelText(tooltip)
	local levelText = tooltip and tooltip.hoverToolTipSecureInstanceLevel
	if not levelText then
		return
	end

	SetRegionAlpha(levelText, 0)
	SafeCall(levelText, "SetText", "")
	SafeCall(levelText, "Hide")
end

function module:IsCurrentSecretUnitTooltipData(tooltip)
	local data = GetTooltipDataSafe(tooltip)
	local firstLine = data and data.type == TOOLTIP_DATA_TYPE_UNIT and type(data.lines) == "table" and data.lines[1]
	return firstLine and IsSecretValue(firstLine.leftText) == true
end

function module:ApplySecureInstanceSecretUnitStyle(tooltip)
	HideSecureInstanceLevelText(tooltip)

	local db = self.db
	if not db or not db.secureInstanceStyling or not tooltip or IsDetailsOverrideActive() then
		return
	end

	local data = GetTooltipDataSafe(tooltip)
	if not data or data.type ~= TOOLTIP_DATA_TYPE_UNIT or type(data.lines) ~= "table" then
		return
	end

	local firstLine = data.lines[1]
	if not firstLine or not IsSecretValue(firstLine.leftText) then
		return
	end

	if #data.lines < 2 then
		return
	end

	local levelTextValue, levelR, levelG, levelB = GetSafeMouseoverLevelText()
	if not levelTextValue then
		HideSecureInstanceLevelText(tooltip)
		return
	end

	local count = GetTooltipLineCount(tooltip)
	for index = 2, count do
		local left = GetTooltipLine(tooltip, "Left", index)
		local right = GetTooltipLine(tooltip, "Right", index)
		ShowFontStringSafe(left)
		ShowFontStringSafe(right)
		SetRegionAlpha(left, 0)
		SetRegionAlpha(right, 0)
	end

	local levelText = tooltip.hoverToolTipSecureInstanceLevel
	if not levelText and type(tooltip.CreateFontString) == "function" then
		levelText = tooltip:CreateFontString(nil, "OVERLAY", "GameTooltipText")
		tooltip.hoverToolTipSecureInstanceLevel = levelText
	end

	if not levelText then
		return
	end

	levelText:ClearAllPoints()
	local nameLine = GetTooltipLine(tooltip, "Left", 1)
	if nameLine then
		levelText:SetPoint("BOTTOMLEFT", nameLine, "TOPLEFT", 0, 2)
	else
		levelText:SetPoint("BOTTOMLEFT", tooltip, "TOPLEFT", 10, 2)
	end
	levelText:SetText(levelTextValue)
	ApplyFont(levelText, db.bodyTextSize or 11, db.bodyTextOutline or "SHADOWOUTLINE")
	SetFontStringColorSafe(levelText, levelR or 1, levelG or 1, levelB or 1, 1)
	SetRegionAlpha(levelText, db.textAlpha or 1)
	ShowFontStringSafe(levelText)
end

GetUnitInfoLineIndex = function(tooltip, context)
	if not tooltip or not context then
		return nil
	end

	if context.unitKind == "player" then
		local indexes = GetPlayerLineIndexes(tooltip, context)
		return indexes.levelRace
	elseif module:IsNPCStyleUnit(context) then
		return GetNPCInfoLine(tooltip, context)
	end
end

local function GetCompactLevelText(context, levelText)
	local level = context and context.unitLevel
	if not IsSecretValue(level) and type(level) == "number" then
		return level < 0 and "??" or tostring(level)
	end

	if levelText then
		local levelPrefix = _G.LEVEL or "Level"
		local compact = strgsub(levelText, "^" .. levelPrefix .. "%s+", "")
		return compact
	end
end

local function GetUnitLevelColor(context)
	local level = context and context.unitLevel
	if not IsSecretValue(level) and type(level) == "number" and type(GetQuestDifficultyColor) == "function" then
		local ok, color = pcall(GetQuestDifficultyColor, level)
		if ok and type(color) == "table" and color.r and color.g and color.b then
			return color.r, color.g, color.b
		end
	end

	return 1, 1, 1
end

local function GetPlayerGenderPrefix(context)
	if not E or not E.db or not E.db.tooltip or not E.db.tooltip.gender or not context or not context.unit then
		return nil
	end

	local gender = UnitNumberSafe(UnitSex, context.unit)
	if gender == 2 then
		return _G.MALE or "Male"
	elseif gender == 3 then
		return _G.FEMALE or "Female"
	end
end

local function GetPlayerRaceText(context)
	local race = context and context.unitRace
	if not race or race == "" then
		return nil
	end

	local gender = GetPlayerGenderPrefix(context)
	return gender and (gender .. " " .. race) or race
end

local function GetPlayerLevelText(context)
	local level = context and context.unitLevel
	if not IsSecretValue(level) and type(level) == "number" then
		return level < 0 and "??" or tostring(level)
	end
end

GetPlayerInfoParts = function(context, includeLevel, includeRace)
	local levelText = includeLevel and GetPlayerLevelText(context)
	local raceText = includeRace and GetPlayerRaceText(context)
	local levelR, levelG, levelB = GetUnitLevelColor(context)

	if levelText and levelText ~= "" then
		levelText = WrapColorText(levelText, levelR, levelG, levelB)
	end

	return levelText, raceText
end

local function GetClassificationText(context)
	local classification = context and context.unitClassification
	if not classification or classification == "normal" or classification == "minus" then
		return nil
	elseif classification == "elite" then
		return _G.ELITE or "Elite"
	elseif classification == "rare" then
		return _G.RARE or "Rare"
	elseif classification == "rareelite" then
		return _G.RARE_ELITE or "Rare Elite"
	elseif classification == "worldboss" then
		return _G.BOSS or "Boss"
	end

	return classification
end

local function GetClassificationColor(context)
	local classification = context and context.unitClassification
	if classification == "elite" or classification == "worldboss" then
		return COLOR_ELITE.r, COLOR_ELITE.g, COLOR_ELITE.b
	elseif classification == "rare" or classification == "rareelite" then
		return COLOR_RARE.r, COLOR_RARE.g, COLOR_RARE.b
	end

	return 1, 1, 1
end

local function IsUsefulCreatureType(creatureType)
	return creatureType and creatureType ~= "" and creatureType ~= (_G.NOT_APPLICABLE or "Not specified") and creatureType ~= "Not specified"
end

local function BuildNPCInfoText(context, levelText, includeLevel, includeClassification, includeCreatureType)
	local parts = {}
	if includeLevel then
		local level = GetCompactLevelText(context, levelText)
		if level and level ~= "" then
			tinsert(parts, WrapColorText(level, GetUnitLevelColor(context)))
		end
	end

	local classification = GetClassificationText(context)
	if includeClassification and classification then
		tinsert(parts, WrapColorText(classification, GetClassificationColor(context)))
	end

	if includeCreatureType and IsUsefulCreatureType(context and context.unitCreatureType) then
		tinsert(parts, context.unitCreatureType)
	end

	if #parts > 0 then
		return tconcat(parts, " ")
	end
end

local function BuildNPCInfoSides(context, levelText, includeLevel, includeClassification, includeCreatureType)
	local leftParts = {}
	if includeLevel then
		local level = GetCompactLevelText(context, levelText)
		if level and level ~= "" then
			tinsert(leftParts, WrapColorText(level, GetUnitLevelColor(context)))
		end
	end

	if includeCreatureType and IsUsefulCreatureType(context and context.unitCreatureType) then
		tinsert(leftParts, context.unitCreatureType)
	end

	local rightText
	local classification = GetClassificationText(context)
	if includeClassification and classification then
		rightText = WrapColorText(classification, GetClassificationColor(context))
	end

	return (#leftParts > 0 and tconcat(leftParts, " ") or nil), rightText
end

local function IsNPCInfoText(text, context)
	if not text then
		return false
	end

	local levelPrefix = _G.LEVEL or "Level"
	if strmatch(text, "^" .. levelPrefix .. "%s+") then
		return true
	end

	local creatureType = context and context.unitCreatureType
	return creatureType and text == creatureType
end

local function GetTooltipDataLineType(tooltip, index)
	local data = GetTooltipDataSafe(tooltip)
	local line = data and type(data.lines) == "table" and data.lines[index]
	return line and line.type
end

function module:IsTitleTextLine(tooltip, context, index)
	if tooltip and tooltip.hoverToolTipInfoAboveNameActive and context and context.isUnit then
		return index == 2
	end

	local lineType = GetTooltipDataLineType(tooltip, index)
	return index == 1 or lineType == KNOWN_TOOLTIP_LINE_TYPES.UnitName
end

local function IsQuestObjectiveText(text)
	return text and (strmatch(text, "^%s*%-%s+") or strmatch(text, "^%s*%d+%s*/%s*%d+"))
end

function module:NormalizeQuestPlayerName(text)
	if not text then
		return nil
	end

	text = strgsub(text, "|c%x%x%x%x%x%x%x%x", "")
	text = strgsub(text, "|r", "")
	text = strmatch(text, "^%s*(.-)%s*$") or text
	text = StripRealmSuffix(text)
	return strlower(text)
end

function module:IsOwnQuestPlayerText(text)
	local playerName = UnitStringSafe(UnitName, "player")
	if not playerName then
		return false
	end

	local normalizedText = self:NormalizeQuestPlayerName(text)
	if not normalizedText then
		return false
	end

	local normalizedPlayerName = self:NormalizeQuestPlayerName(playerName)
	if normalizedText == normalizedPlayerName then
		return true
	end

	local fullName = UnitFullNameSafe("player")
	return fullName and normalizedText == self:NormalizeQuestPlayerName(fullName)
end

function module:IsOwnQuestObjectiveLine(tooltip, index)
	if not self.db or not self.db.hideOwnQuestPlayer then
		return false
	end

	local lineType = GetTooltipDataLineType(tooltip, index)
	local text = GetSafeTooltipDataLineText(tooltip, index)
	if lineType ~= LINE_TYPE_QUEST_OBJECTIVE and not IsQuestObjectiveText(text) then
		return false
	end

	for previousIndex = index - 1, 2, -1 do
		local previousType = GetTooltipDataLineType(tooltip, previousIndex)
		if previousType == LINE_TYPE_QUEST_PLAYER then
			return self:IsOwnQuestPlayerText(self:GetTooltipDataLineLeftText(tooltip, previousIndex))
		elseif previousType ~= LINE_TYPE_QUEST_OBJECTIVE then
			return false
		end
	end

	return false
end

local function ShouldKeepQuestLikeLine(tooltip, index)
	local db = module.db
	if not db then
		return false
	end

	local lineType = GetTooltipDataLineType(tooltip, index)
	if lineType == LINE_TYPE_QUEST_OBJECTIVE then
		return not db.hideQuestObjectives or module:IsOwnQuestObjectiveLine(tooltip, index)
	elseif lineType == LINE_TYPE_QUEST_TITLE then
		return not db.hideQuestTitles
	elseif lineType == LINE_TYPE_QUEST_PLAYER then
		return not db.hideQuestPlayers
			or (not db.hideOwnQuestPlayer and module:IsOwnQuestPlayerText(module:GetTooltipDataLineLeftText(tooltip, index)))
	end

	local text = GetSafeTooltipDataLineText(tooltip, index)
	if IsQuestObjectiveText(text) then
		return not db.hideQuestObjectives or module:IsOwnQuestObjectiveLine(tooltip, index)
	end

	local nextText = GetSafeTooltipDataLineText(tooltip, index + 1)
	if IsQuestObjectiveText(nextText) then
		return not db.hideQuestTitles
	end

	return false
end

function module:ApplyQuestLineFilters(tooltip)
	local db = module.db
	if not db or not tooltip then
		return
	end

	if not db.hideQuestObjectives and not db.hideQuestTitles and not db.hideQuestPlayers then
		return
	end

	for index = 2, GetTooltipLineCount(tooltip) do
		local lineType = GetTooltipDataLineType(tooltip, index)
		if lineType == LINE_TYPE_QUEST_OBJECTIVE and db.hideQuestObjectives then
			if not self:IsOwnQuestObjectiveLine(tooltip, index) then
				ClearTooltipLine(tooltip, index)
			end
		elseif lineType == LINE_TYPE_QUEST_TITLE and db.hideQuestTitles then
			ClearTooltipLine(tooltip, index)
		elseif lineType == LINE_TYPE_QUEST_PLAYER and db.hideQuestPlayers then
			local playerText = self:GetTooltipDataLineLeftText(tooltip, index)
			local isOwnQuestPlayer = self:IsOwnQuestPlayerText(playerText)
			if db.hideOwnQuestPlayer and isOwnQuestPlayer then
				ClearTooltipLine(tooltip, index)
			elseif not isOwnQuestPlayer then
				ClearTooltipLine(tooltip, index)
				local nextIndex = index + 1
				local nextType = GetTooltipDataLineType(tooltip, nextIndex)
				local nextText = GetSafeTooltipDataLineText(tooltip, nextIndex)
				while nextType == LINE_TYPE_QUEST_OBJECTIVE or IsQuestObjectiveText(nextText) do
					ClearTooltipLine(tooltip, nextIndex)
					nextIndex = nextIndex + 1
					nextType = GetTooltipDataLineType(tooltip, nextIndex)
					nextText = GetSafeTooltipDataLineText(tooltip, nextIndex)
				end
			end
		else
			local text = GetSafeTooltipDataLineText(tooltip, index)
			local nextText = GetSafeTooltipDataLineText(tooltip, index + 1)
			if db.hideQuestObjectives and IsQuestObjectiveText(text) and not self:IsOwnQuestObjectiveLine(tooltip, index) then
				ClearTooltipLine(tooltip, index)
			elseif db.hideQuestTitles and IsQuestObjectiveText(nextText) then
				ClearTooltipLine(tooltip, index)
			end
		end
	end
end

local function ClearCreatureTypeLineIfSeparate(tooltip, creatureTypeText, context)
	if not context or not creatureTypeText or creatureTypeText ~= context.unitCreatureType then
		return
	end

	for index = 2, GetTooltipLineCount(tooltip) do
		local text = GetSafeTooltipDataLineText(tooltip, index)
		if text == creatureTypeText then
			ClearTooltipLine(tooltip, index)
			return
		end
	end
end

GetNPCInfoLine = function(tooltip, context)
	local levelPrefix = _G.LEVEL or "Level"
	local creatureType = context and context.unitCreatureType

	for index = 2, GetTooltipLineCount(tooltip) do
		local text = GetSafeTooltipDataLineText(tooltip, index)
		if text then
			if strmatch(text, "^" .. levelPrefix .. "%s+") then
				return index, text
			end

			if creatureType and text == creatureType then
				return index, text
			end
		end
	end
end

local function HideNPCTitleLines(tooltip, context, infoIndex)
	if not infoIndex then
		return
	end

	for index = 2, infoIndex - 1 do
		local text = GetSafeTooltipDataLineText(tooltip, index)
		if text and not IsNPCInfoText(text, context) and not ShouldKeepQuestLikeLine(tooltip, index) then
			HideOptionalLine(tooltip, index)
		end
	end
end

local function HideNPCAffiliationLines(tooltip, context, infoIndex)
	if not infoIndex then
		return
	end

	for index = 2, GetTooltipLineCount(tooltip) do
		if index > infoIndex then
			local text = GetSafeTooltipDataLineText(tooltip, index)
			if text and not IsNPCInfoText(text, context) and not ShouldKeepQuestLikeLine(tooltip, index) then
				HideOptionalLine(tooltip, index)
				return
			end
		end
	end
end

local function ClearNPCCombatExtraLines(tooltip, hideThreat, hideTarget)
	if not tooltip or (not hideThreat and not hideTarget) then
		return
	end

	for index = 2, GetTooltipLineCount(tooltip) do
		if hideThreat and GetTooltipDataLineType(tooltip, index) == KNOWN_TOOLTIP_LINE_TYPES.UnitThreat then
			ClearTooltipLine(tooltip, index)
		elseif hideTarget and IsPlayerTargetLine(tooltip, index) then
			ClearTooltipLine(tooltip, index)
		end
	end
end

local function ApplyNPCLineFilters(tooltip, context)
	local db = module.db
	if not db or not tooltip then
		return
	end

	local hideLevel = db.hideNPCLevel
	local hideClassification = db.hideNPCClassification
	local hideCreatureType = db.hideNPCCreatureType
	local hideTitle = db.hideNPCTitle
	local hideAffiliation = db.hideNPCAffiliation
	local hideThreat = db.hideNPCThreat
	local hideTarget = db.hideNPCTarget
	if not hideLevel
		and not hideClassification
		and not hideCreatureType
		and not hideTitle
		and not hideAffiliation
		and not hideThreat
		and not hideTarget
	then
		return
	end

	local infoIndex, levelText = GetNPCInfoLine(tooltip, context)
	local creatureTypeText = context and context.unitCreatureType

	ClearNPCCombatExtraLines(tooltip, hideThreat, hideTarget)

	if infoIndex and (hideLevel or hideClassification or hideCreatureType) then
		-- Blizzard may expose level/classification/creature type as separate data
		-- lines while rendering them through one visible unit-info fontstring.
		ReplaceTooltipLineLeft(
			tooltip,
			infoIndex,
			BuildNPCInfoText(context, levelText, not hideLevel, not hideClassification, not hideCreatureType),
			1,
			1,
			1
		)
		ClearCreatureTypeLineIfSeparate(tooltip, creatureTypeText, context)
	end

	if hideAffiliation then
		HideNPCAffiliationLines(tooltip, context, infoIndex)
	end

	if hideTitle then
		HideNPCTitleLines(tooltip, context, infoIndex)
	end
end

function module:ApplyManualLineFilters(tooltip, context)
	local db = self.db
	if not db or not tooltip or not context or not context.shouldStyleTooltip then
		return
	end

	if context.isObject then
		if IsDetailsOverrideActive() then
			self:RestoreTooltipLinesFromData(tooltip)
			return
		end

		if not context.inInstance then
			self:ApplyQuestLineFilters(tooltip)
		end
		return
	end

	if not context.isUnit then
		return
	end

	if not IsDataModificationAllowed(context) then
		return
	end

	self:ApplyQuestLineFilters(tooltip)

	if context.unitKind == "player" then
		ApplyPlayerLineFilters(tooltip, context)
	elseif self:IsNPCStyleUnit(context) then
		ApplyNPCLineFilters(tooltip, context)
	end
end

local function ApplyUnitInfoAboveNameSides(tooltip, context, levelText)
	local db = module.db
	if not db or not tooltip or not context then
		return
	end

	local showFullDetails = IsDetailsOverrideForContext(context)

	if context.unitKind == "player" then
		local showLevel = showFullDetails or not db.hidePlayerLevel
		local showRace = showFullDetails or not db.hidePlayerRace
		local levelSide, raceSide = GetPlayerInfoParts(context, showLevel, showRace)
		local leftSide

		if levelSide and raceSide then
			leftSide = levelSide .. " " .. raceSide
		else
			leftSide = levelSide or raceSide
		end

		ReplaceTooltipLineLeft(tooltip, 1, leftSide, 1, 1, 1)
		ReplaceTooltipLineRight(tooltip, 1, nil)
	elseif module:IsNPCStyleUnit(context) then
		local leftSide, rightSide = BuildNPCInfoSides(
			context,
			levelText,
			showFullDetails or not db.hideNPCLevel,
			showFullDetails or not db.hideNPCClassification,
			showFullDetails or not db.hideNPCCreatureType
		)
		local rightR, rightG, rightB = GetClassificationColor(context)

		ReplaceTooltipLineLeft(tooltip, 1, leftSide, 1, 1, 1)
		ReplaceTooltipLineRight(tooltip, 1, rightSide, rightR, rightG, rightB)
	end
end

local function ClearDuplicateNPCInfoAboveNameLines(tooltip, context)
	if not tooltip or not context or not module:IsNPCStyleUnit(context) then
		return
	end

	local creatureType = context.unitCreatureType
	local levelPrefix = _G.LEVEL or "Level"

	for index = 3, GetTooltipLineCount(tooltip) do
		local text = GetFontStringTextSafe(GetTooltipLine(tooltip, "Left", index))
		if text
			and text ~= ""
			and (
				(creatureType and text == creatureType)
				or strmatch(text, "^" .. levelPrefix .. "%s+")
			)
		then
			ClearTooltipLine(tooltip, index)
		end
	end
end

function module:ApplyUnitInfoPosition(tooltip, context)
	local db = self.db
	if not db or not db.unitInfoAboveName or not tooltip or not context or not context.isUnit then
		return
	end

	if not IsVisualLayoutAllowed(context) then
		return
	end

	if context.unitKind ~= "player" and not self:IsNPCStyleUnit(context) then
		return
	end

	local infoIndex = GetUnitInfoLineIndex(tooltip, context)
	if not infoIndex or infoIndex == 1 then
		return
	end

	local data = GetTooltipDataSafe(tooltip)
	local levelText
	if self:IsNPCStyleUnit(context) then
		_, levelText = GetNPCInfoLine(tooltip, context)
	end

	local function CaptureDataLine(index)
		local line = data and type(data.lines) == "table" and data.lines[index]
		if not line or IsSecretValue(line.leftText) or IsSecretValue(line.rightText) then
			return nil
		end

		local left = GetTooltipLine(tooltip, "Left", index)
		local right = GetTooltipLine(tooltip, "Right", index)
		local visibleLeftText = GetFontStringTextSafe(left)
		local visibleRightText = GetFontStringTextSafe(right)
		local leftR, leftG, leftB, leftA
		local rightR, rightG, rightB, rightA

		if line.type == KNOWN_TOOLTIP_LINE_TYPES.UnitName then
			leftR, leftG, leftB = GetUnitNameColor(context)
			leftA = db.titleTextAlpha or 1
		elseif visibleLeftText == line.leftText then
			leftR, leftG, leftB, leftA = GetFontStringColorSafe(left)
		else
			leftR, leftG, leftB, leftA = 1, 1, 1, 1
		end

		if visibleRightText == line.rightText then
			rightR, rightG, rightB, rightA = GetFontStringColorSafe(right)
		else
			rightR, rightG, rightB, rightA = 1, 1, 1, 1
		end

		return {
			leftText = line.leftText,
			leftR = leftR,
			leftG = leftG,
			leftB = leftB,
			leftA = leftA,
			rightText = line.rightText,
			rightR = rightR,
			rightG = rightG,
			rightB = rightB,
			rightA = rightA,
		}
	end

	local function CaptureLine(index)
		local fromData = CaptureDataLine(index)
		if fromData then
			return fromData
		end

		local left = GetTooltipLine(tooltip, "Left", index)
		local right = GetTooltipLine(tooltip, "Right", index)
		local leftR, leftG, leftB, leftA = GetFontStringColorSafe(left)
		local rightR, rightG, rightB, rightA = GetFontStringColorSafe(right)

		return {
			leftText = GetFontStringTextSafe(left),
			leftR = leftR,
			leftG = leftG,
			leftB = leftB,
			leftA = leftA,
			rightText = GetFontStringTextSafe(right),
			rightR = rightR,
			rightG = rightG,
			rightB = rightB,
			rightA = rightA,
		}
	end

	local function ApplyCapturedLine(index, captured)
		local left = GetTooltipLine(tooltip, "Left", index)
		local right = GetTooltipLine(tooltip, "Right", index)

		if left then
			SetFontStringTextSafe(left, captured.leftText or "")
			SetFontStringColorSafe(left, captured.leftR or 1, captured.leftG or 1, captured.leftB or 1, captured.leftA or 1)
			ShowFontStringSafe(left)
			SetRegionAlpha(left, captured.leftText and captured.leftText ~= "" and (db.textAlpha or 1) or 0)
		end

		if right then
			SetFontStringTextSafe(right, captured.rightText or "")
			SetFontStringColorSafe(right, captured.rightR or 1, captured.rightG or 1, captured.rightB or 1, captured.rightA or 1)
			ShowFontStringSafe(right)
			SetRegionAlpha(right, captured.rightText and captured.rightText ~= "" and (db.textAlpha or 1) or 0)
		end
	end

	local lines = {}
	for index = 1, infoIndex do
		lines[index] = CaptureLine(index)
	end

	if not lines[1].leftText or lines[1].leftText == "" or not lines[infoIndex].leftText or lines[infoIndex].leftText == "" then
		return
	end

	ApplyCapturedLine(1, lines[infoIndex])
	ApplyUnitInfoAboveNameSides(tooltip, context, levelText)
	self:ApplyThreatPercentToInfoLine(tooltip, context, 1)
	ApplyConfiguredLineStyle(tooltip, 1, false)

	for index = 2, infoIndex do
		ApplyCapturedLine(index, lines[index - 1])
	end

	ApplyConfiguredLineStyle(tooltip, 2, true)
	ReplaceTooltipLineRight(tooltip, 2, nil)

	if context.unitKind == "player" and not IsDetailsOverrideForContext(context) then
		ApplyPlayerNameFilters(tooltip, context, 2)

		if db.hidePlayerGuild and infoIndex > 2 then
			ClearTooltipLine(tooltip, 3)
		end
	elseif self:IsNPCStyleUnit(context) and db.hideNPCTitle and not IsDetailsOverrideForContext(context) then
		for index = 3, infoIndex do
			ClearTooltipLine(tooltip, index)
		end
	end

	local nameR, nameG, nameB = GetUnitNameColor(context)
	if nameR and nameG and nameB then
		SetFontStringColorSafe(GetTooltipLine(tooltip, "Left", 2), nameR, nameG, nameB, 1)
		self:SetFontStringVisualAlpha(GetTooltipLine(tooltip, "Left", 2), db.titleTextAlpha or 1)
	end
	self:ApplyTargetNameToNameLine(tooltip, context, 2)
	ClearDuplicateNPCInfoAboveNameLines(tooltip, context)

	for index = 3, infoIndex do
		if GetFontStringTextSafe(GetTooltipLine(tooltip, "Left", index)) then
			ApplyConfiguredLineStyle(tooltip, index, false)
		end
	end

	tooltip.hoverToolTipInfoAboveNameData = data
	tooltip.hoverToolTipInfoAboveNameActive = true
end

local function IsVisibleTooltipText(fontString)
	local text = GetFontStringTextSafe(fontString)
	if not text or text == "" then
		return false
	end

	local alpha = GetFrameAlpha(fontString)
	return alpha ~= 0 and IsShownSafe(fontString)
end

function module:CollapseEmptyRightTextLines(tooltip)
	if not tooltip or IsForbidden(tooltip) then
		return
	end

	local shouldModify, context = module:ShouldModifyTooltip(tooltip)
	if not shouldModify or not context or not IsVisualLayoutAllowed(context) then
		return
	end

	for index = 1, GetTooltipLineCount(tooltip) do
		local right = GetTooltipLine(tooltip, "Right", index)
		if right and IsVisibleTooltipText(right) then
			if type(right.SetJustifyH) == "function" then
				pcall(right.SetJustifyH, right, "RIGHT")
			end
		elseif right then
			SetFontStringTextSafe(right, "")
			ShowFontStringSafe(right)
			SetRegionAlpha(right, 0)
		end
	end
end

function module:ApplyVisibleTextTooltipSize(tooltip, context)
	if not tooltip or IsForbidden(tooltip) or not context or not IsVisualLayoutAllowed(context) then
		return false
	end

	module:CollapseEmptyRightTextLines(tooltip)

	local lineCount = GetTooltipLineCount(tooltip)
	local tooltipLeft = GetRegionLeftSafe(tooltip) or 0
	local maxLineWidth = 0
	local totalTextHeight = 0
	local visibleRows = 0
	local lineGap = 1
	local leftPadding = 10
	local rightPadding = 12
	local topBottomPadding = 20
	local sideGap = 24

	for index = 1, lineCount do
		local left = GetTooltipLine(tooltip, "Left", index)
		local right = GetTooltipLine(tooltip, "Right", index)
		local leftVisible = IsVisibleTooltipText(left)
		local rightVisible = IsVisibleTooltipText(right)

		if leftVisible or rightVisible then
			local leftOffset = leftVisible and max((GetRegionLeftSafe(left) or tooltipLeft + leftPadding) - tooltipLeft, leftPadding) or leftPadding
			local leftWidth = leftVisible and (module:GetFontStringDisplayWidth(left) or 0) or 0
			local rightWidth = rightVisible and (module:GetFontStringDisplayWidth(right) or 0) or 0
			local leftHeight = leftVisible and (GetRegionHeightSafe(left) or GetFontStringHeightSafe(left)) or 0
			local rightHeight = rightVisible and (GetRegionHeightSafe(right) or GetFontStringHeightSafe(right)) or 0
			local lineWidth = leftOffset + leftWidth

			if rightWidth > 0 then
				lineWidth = leftOffset + (leftWidth > 0 and (leftWidth + sideGap) or 0) + rightWidth
			end

			maxLineWidth = max(maxLineWidth, lineWidth)
			totalTextHeight = totalTextHeight + max(leftHeight, rightHeight, 1)
			visibleRows = visibleRows + 1
		end
	end

	if visibleRows == 0 or maxLineWidth == 0 then
		return false
	end

	local width = maxLineWidth + rightPadding
	local height = totalTextHeight + ((visibleRows - 1) * lineGap) + topBottomPadding

	if tooltip.StatusBar and IsShownSafe(tooltip.StatusBar) and (GetFrameAlpha(tooltip.StatusBar) or 0) > 0 then
		height = height + 8
	end

	if type(tooltip.SetMinimumWidth) == "function" then
		pcall(tooltip.SetMinimumWidth, tooltip, width)
	end

	if type(tooltip.SetWidth) == "function" then
		pcall(tooltip.SetWidth, tooltip, width)
	end

	if type(tooltip.SetHeight) == "function" then
		pcall(tooltip.SetHeight, tooltip, height)
	end

	tooltip.hoverToolTipResizedToVisibleText = true
	if context.isObject then
		tooltip.hoverToolTipVisibleWidth = width
		tooltip.hoverToolTipVisibleHeight = height
	end

	return true
end

function module:QueueVisibleTextTooltipResize(tooltip, context)
	if not tooltip or IsForbidden(tooltip) or tooltip.hoverToolTipResizeQueued then
		return
	end

	if not context or not context.isObject or not C_Timer or type(C_Timer.After) ~= "function" then
		return
	end

	tooltip.hoverToolTipResizeQueued = true
	C_Timer.After(0, function()
		if tooltip and not IsForbidden(tooltip) then
			tooltip.hoverToolTipResizeQueued = nil
			module:ApplyVisibleTextTooltipSize(tooltip, context)
		end
	end)
end

local function ResizeTooltipToVisibleText(tooltip, context)
	if module:ApplyVisibleTextTooltipSize(tooltip, context) then
		module:QueueVisibleTextTooltipResize(tooltip, context)
	end
end

function module:HideInstanceTooltip()
	self.instanceStyleQueued = nil

	local frame = self.instanceTooltip or GameTooltip
	if frame and not IsForbidden(frame) then
		ReleaseTooltipState(frame)
		frame.hoverToolTipInstanceStyleQueued = nil
		frame.hoverToolTipInstanceStyleUntil = nil
		pcall(frame.Hide, frame)
	end
end

function module:ShouldStyleInstanceTooltip(tooltip)
	if not self:ShouldUseRestrictedInstancePath(tooltip) then
		return false
	end

	local shouldModify, context = self:ShouldModifyTooltip(tooltip)
	return shouldModify == true, context
end

function module:StyleInstanceTooltip(tooltip, maintainOnly)
	local db = self.db
	if self.disabledByMerathilisHoverToolTip or self:ShouldStandDownForMerathilis() then
		self.disabledByMerathilisHoverToolTip = true
		return false
	end

	if not db or not db.enable or not tooltip or tooltip ~= GameTooltip or IsForbidden(tooltip) then
		return false
	end

	local shouldModify = self:ShouldStyleInstanceTooltip(tooltip)
	if not shouldModify then
		ReleaseTooltipState(tooltip)
		tooltip.hoverToolTipInstanceStyleUntil = nil
		return false
	end

	if IsDetailsOverrideActive() then
		ReleaseTooltipState(tooltip)
		HideSecureInstanceLevelText(tooltip)
	end

	local instanceDB = self:CopyTable(db, {})
	instanceDB.customTooltipBackdrop = false
	StoreOriginalTooltipState(tooltip)
	SafeCall(tooltip, "SetScale", db.scale or 1)
	SetTooltipBackdropAlpha(tooltip, instanceDB)
	self:ApplyTextStyle(tooltip, { isObject = false })
	self:ApplyInstancePlayerLineFilters(tooltip)
	self:ApplySecureInstanceSecretUnitStyle(tooltip)
	self:ApplyInstanceSecretUnitLineFilters(tooltip)
	if not self:IsCurrentSecretUnitTooltipData(tooltip) then
		HideSecureInstanceLevelText(tooltip)
	end

	if tooltip.StatusBar then
		SetRegionAlpha(tooltip.StatusBar, db.statusBar and 1 or 0)
	end

	if not maintainOnly then
		tooltip.hoverToolTipInstanceStyleUntil = GetTimeSafe() + 0.25
	end

	return true
end

function module:QueueInstanceStyleTooltip(tooltip)
	if not tooltip or tooltip ~= GameTooltip or IsForbidden(tooltip) then
		return
	end

	if not self:StyleInstanceTooltip(tooltip) then
		return
	end

	if tooltip.hoverToolTipInstanceStyleQueued then
		return
	end

	if not C_Timer or type(C_Timer.After) ~= "function" then
		return
	end

	tooltip.hoverToolTipInstanceStyleQueued = true
	C_Timer.After(0, function()
		tooltip.hoverToolTipInstanceStyleQueued = nil
		if tooltip and not IsForbidden(tooltip) and IsShownSafe(tooltip) and module:ShouldUseRestrictedInstancePath(tooltip) then
			module:StyleInstanceTooltip(tooltip)
		end
	end)
end

local function IsDetailsKeyDown()
	local db = module.db
	local key = db and db.detailsKey or "NONE"

	if key == "SHIFT" then
		return IsShiftKeyDown()
	elseif key == "CTRL" then
		return IsControlKeyDown()
	elseif key == "ALT" then
		return IsAltKeyDown()
	end

	return false
end

IsDetailsOverrideActive = function()
	return module.detailsBindingHeld or IsDetailsKeyDown()
end

IsDetailsOverrideForContext = function(context)
	local db = module.db
	if context and context.isUnitFrameTooltip and db and db.detailsOnUnitFrames == true then
		return true
	end

	return IsDetailsOverrideActive()
end

IsDataModificationAllowed = function(context)
	if not context or not context.shouldStyleTooltip or not context.isUnit then
		return false, "not-unit-tooltip"
	elseif context.unitIsSecret then
		return false, "secret-unit"
	elseif IsDetailsOverrideForContext(context) then
		return false, "full-details"
	elseif context.inInstance and not (context.isUnitFrameTooltip and context.unitKind == "player") then
		return false, "instance"
	end

	return true, "allowed"
end

IsVisualLayoutAllowed = function(context)
	if not context or not context.shouldStyleTooltip then
		return false, "not-styled-tooltip"
	elseif context.isObject then
		return true, "object"
	elseif not context.isUnit then
		return false, "not-unit-tooltip"
	elseif context.unitIsSecret then
		return false, "secret-unit"
	elseif context.inInstance and not (context.isUnitFrameTooltip and context.unitKind == "player") then
		return false, "instance"
	end

	return true, "allowed"
end

local function IsTooltipDataRefreshSafe(context)
	if not context or not context.isUnit or context.unitIsSecret then
		return false
	elseif context.inInstance and not (context.isUnitFrameTooltip and context.unitKind == "player") then
		return false
	end

	return true
end

local function RefreshTooltipData(tooltip, context)
	if tooltip and type(tooltip.RefreshData) == "function" and not IsForbidden(tooltip) and IsTooltipDataRefreshSafe(context) then
		pcall(tooltip.RefreshData, tooltip)
	end
end

local function QueueTooltipLayoutRefresh(tooltip, context)
	if not tooltip or IsForbidden(tooltip) or tooltip.hoverToolTipLayoutRefreshed or tooltip.hoverToolTipLayoutRefreshQueued then
		return
	end

	if not C_Timer or type(C_Timer.After) ~= "function" then
		return
	end

	TraceLog("layout-refresh-queue", tooltip)
	tooltip.hoverToolTipLayoutRefreshQueued = true
	C_Timer.After(0, function()
		tooltip.hoverToolTipLayoutRefreshQueued = nil
		if not tooltip or IsForbidden(tooltip) or type(tooltip.IsShown) ~= "function" or not tooltip:IsShown() then
			return
		end

		TraceLog("layout-refresh-run", tooltip)
		tooltip.hoverToolTipLayoutRefreshed = true
		SuppressTooltipUntilStyled(tooltip)
		tooltip.hoverToolTipRefreshing = true
		context = module:GetTooltipContext(tooltip)
		RefreshTooltipData(tooltip, context)
		tooltip.hoverToolTipRefreshing = nil
		module:StyleTooltip(tooltip, true)
	end)
end

local function DebugLog(event, tooltip, context)
	if not module.debugEnabled then
		return
	end

	context = context or module:GetTooltipContext(tooltip or GameTooltip)
	local dataAllowed, dataReason = IsDataModificationAllowed(context)

	local parts = {
		event or "event",
		"reason=" .. SafeText(context.reason),
		"tooltip=" .. SafeText(context.tooltipName),
		"owner=" .. SafeText(context.ownerName),
		"focus=" .. SafeText(context.focusName),
		"unit=" .. SafeText(context.unit),
		"isUnit=" .. SafeText(context.isUnit),
		"kind=" .. SafeText(context.unitKind),
		"secretUnit=" .. SafeText(context.unitIsSecret),
		"player=" .. SafeText(context.unitIsPlayer),
		"reaction=" .. SafeText(context.unitReactionName),
		"mouseoverUnit=" .. SafeText(context.isMouseoverUnit),
		"mouseDown=" .. SafeText(context.mouseButtonDown),
		"world=" .. SafeText(context.isWorldTooltip),
		"unitFrame=" .. SafeText(context.isUnitFrameTooltip),
		"style=" .. SafeText(context.shouldStyleTooltip),
		"dataModify=" .. SafeText(dataAllowed),
		"dataReason=" .. SafeText(dataReason),
	}

	tinsert(module.debugLog, table.concat(parts, " | "))
	if #module.debugLog > 60 then
		table.remove(module.debugLog, 1)
	end
end

GetFirstTextureAlpha = function(tooltip)
	local alpha
	ForEachTooltipTextureRegion(tooltip, function(region)
		if alpha == nil then
			alpha = GetFrameAlpha(region)
		end
	end)
	return alpha
end

local function GetLineTypeName(lineType)
	return (lineType and LINE_TYPE_NAMES[lineType]) or SafeText(lineType)
end

TraceLog = function(event, tooltip, context, extra)
	if not module.traceEnabled then
		return
	end

	tooltip = tooltip or GameTooltip
	context = context or module:GetTooltipContext(tooltip)

	local dataAllowed, dataReason = IsDataModificationAllowed(context)
	local now = type(_G.GetTime) == "function" and _G.GetTime() or 0
	local parts = {
		format("%.3f", now),
		event or "event",
		"reason=" .. SafeText(context.reason),
		"owner=" .. SafeText(context.ownerName),
		"unit=" .. SafeText(context.unit),
		"kind=" .. SafeText(context.unitKind),
		"world=" .. SafeText(context.isWorldTooltip),
		"uuf=" .. SafeText(context.isUnitFrameTooltip),
		"mouseover=" .. SafeText(context.isMouseoverUnit),
		"mouseDown=" .. SafeText(context.mouseButtonDown),
		"style=" .. SafeText(context.shouldStyleTooltip),
		"data=" .. SafeText(dataAllowed) .. "(" .. SafeText(dataReason) .. ")",
		"dead=" .. SafeText(context.unitIsDead),
		"alpha=" .. SafeText(GetFrameAlpha(tooltip)),
		"tex1=" .. SafeText(GetFirstTextureAlpha(tooltip)),
		"bar=" .. SafeText(GetFrameAlpha(tooltip and tooltip.StatusBar)),
		"suppress=" .. SafeText(tooltip and tooltip.hoverToolTipSuppressing),
		"hold=" .. SafeText(tooltip and tooltip.hoverToolTipHoldSuppression),
		"queued=" .. SafeText(tooltip and tooltip.hoverToolTipStyleQueued),
		"styled=" .. SafeText(tooltip and tooltip.hoverToolTipStyledData ~= nil),
		"l1=" .. SafeText(GetFontStringTextSafe(GetTooltipLine(tooltip, "Left", 1))),
		"l2=" .. SafeText(GetFontStringTextSafe(GetTooltipLine(tooltip, "Left", 2))),
	}

	if extra then
		tinsert(parts, "extra=" .. SafeText(extra))
	end

	tinsert(module.traceLog, tconcat(parts, " | "))
	if #module.traceLog > 400 then
		table.remove(module.traceLog, 1)
	end
end

local function GetTooltipDataTypeName(dataType)
	return (dataType and TOOLTIP_DATA_TYPE_NAMES[dataType]) or SafeText(dataType)
end

function module:ShowDebugOutput(title, text)
	if not self.debugOutputFrame then
		local frame = CreateFrame("Frame", "HoverToolTipDebugOutputFrame", UIParent, "BasicFrameTemplateWithInset")
		frame:SetSize(760, 520)
		frame:SetPoint("CENTER")
		frame:SetFrameStrata("DIALOG")
		frame:Hide()
		frame:SetMovable(true)
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", frame.StartMoving)
		frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

		frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 8, 0)

		local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 12, -34)
		scroll:SetPoint("BOTTOMRIGHT", -30, 42)

		local editBox = CreateFrame("EditBox", nil, scroll)
		editBox:SetMultiLine(true)
		editBox:SetAutoFocus(false)
		editBox:SetFontObject(ChatFontNormal)
		editBox:SetWidth(690)
		editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
		scroll:SetScrollChild(editBox)

		local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		close:SetSize(90, 24)
		close:SetPoint("BOTTOMRIGHT", -12, 12)
		close:SetText("Close")
		close:SetScript("OnClick", function() frame:Hide() end)

		local selectAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		selectAll:SetSize(90, 24)
		selectAll:SetPoint("RIGHT", close, "LEFT", -8, 0)
		selectAll:SetText("Select All")
		selectAll:SetScript("OnClick", function()
			editBox:SetFocus()
			editBox:HighlightText()
		end)

		frame.scroll = scroll
		frame.editBox = editBox
		self.debugOutputFrame = frame
	end

	local frame = self.debugOutputFrame
	frame.title:SetText(title or "HoverToolTip Debug")
	frame.editBox:SetText(text or "")
	frame.editBox:SetCursorPosition(0)
	frame.editBox:ClearFocus()
	frame:Show()
end

function module:CaptureDebugOutput(title, func)
	local lines = {}
	local oldPrint = print
	print = function(...)
		local parts = {}
		for index = 1, select("#", ...) do
			parts[index] = SafeText(select(index, ...))
		end
		tinsert(lines, tconcat(parts, "\t"))
	end

	local ok, err = pcall(func)
	print = oldPrint

	if not ok then
		tinsert(lines, "ERROR: " .. SafeText(err))
	end

	self:ShowDebugOutput(title, tconcat(lines, "\n"))
end

local function PrintFrameChain(label, frame)
	print(label .. ":")
	if not frame then
		print("  nil")
		return
	end

	local current = frame
	for index = 1, 8 do
		if not current then
			break
		end

		print(
			"  "
				.. index
				.. ". "
				.. GetFrameDebugName(current)
				.. " unit="
				.. SafeText(GetFrameUnitSafe(current))
				.. " world="
				.. SafeText(IsWorldFrameLike(current))
				.. " nameplate="
				.. SafeText(IsNameplateFrame(current))
		)

		current = GetFrameParentSafe(current)
	end
end

local function PrintTooltipTextureDump(tooltip)
	print("HoverToolTip texture regions:")

	local count = 0
	ForEachTooltipTextureRegion(tooltip, function(region)
		count = count + 1
		print("  " .. count .. ". " .. GetFrameDebugName(region) .. " alpha=" .. SafeText(GetFrameAlpha(region)))
	end)

	if count == 0 then
		print("  <none>")
	end
end

local function PrintTooltipChromeFrameDump(tooltip)
	print("HoverToolTip chrome frames:")

	local count = 0
	ForEachTooltipChromeFrame(tooltip, function(key, frame)
		count = count + 1
		print("  " .. count .. ". " .. key .. "=" .. GetFrameDebugName(frame) .. " alpha=" .. SafeText(GetFrameAlpha(frame)))
	end)

	if count == 0 then
		print("  <none>")
	end
end

local function PrintTooltipDataDump(tooltip)
	local data = GetTooltipDataSafe(tooltip)
	if not data or type(data.lines) ~= "table" then
		print("HoverToolTip debug: no tooltip data available.")
		return
	end

	print("HoverToolTip data:")
	print("  type=" .. GetTooltipDataTypeName(data.type) .. " id=" .. SafeText(data.id) .. " lines=" .. SafeText(#data.lines))

	for index, line in ipairs(data.lines) do
		local left = line and line.leftText
		local right = line and line.rightText
		print(
			index
				.. ". type="
				.. GetLineTypeName(line and line.type)
				.. " left="
				.. SafeText(left)
				.. " right="
				.. SafeText(right)
		)
	end
end

local function FormatDebugNumber(value)
	return not IsSecretValue(value) and type(value) == "number" and format("%.1f", value) or SafeText(value)
end

local function FormatFrameRect(frame, parent)
	local left = GetRegionLeftSafe(frame)
	local right = GetRegionRightSafe(frame)
	local top = GetRegionTopSafe(frame)
	local bottom = GetRegionBottomSafe(frame)
	local width = GetRegionWidthSafe(frame)
	local height = GetRegionHeightSafe(frame)

	if parent then
		local parentLeft = GetRegionLeftSafe(parent)
		local parentBottom = GetRegionBottomSafe(parent)
		if type(left) == "number" and type(parentLeft) == "number" then
			left = left - parentLeft
		end
		if type(right) == "number" and type(parentLeft) == "number" then
			right = right - parentLeft
		end
		if type(top) == "number" and type(parentBottom) == "number" then
			top = top - parentBottom
		end
		if type(bottom) == "number" and type(parentBottom) == "number" then
			bottom = bottom - parentBottom
		end
	end

	return "l="
		.. FormatDebugNumber(left)
		.. " r="
		.. FormatDebugNumber(right)
		.. " t="
		.. FormatDebugNumber(top)
		.. " b="
		.. FormatDebugNumber(bottom)
		.. " w="
		.. FormatDebugNumber(width)
		.. " h="
		.. FormatDebugNumber(height)
end

local function PrintTooltipGeometryDump(tooltip)
	print("HoverToolTip geometry:")

	if not tooltip then
		print("  <none>")
		return
	end

	local point, relativeTo, relativePoint, x, y = GetFramePointSafe(tooltip)
	local scale
	if type(tooltip.GetEffectiveScale) == "function" and not IsForbidden(tooltip) then
		local ok, effectiveScale = pcall(tooltip.GetEffectiveScale, tooltip)
		if ok and not IsSecretValue(effectiveScale) and type(effectiveScale) == "number" then
			scale = effectiveScale
		end
	end

	print(
		"  point="
			.. SafeText(point)
			.. " relativeTo="
			.. GetFrameDebugName(relativeTo)
			.. " relativePoint="
			.. SafeText(relativePoint)
			.. " x="
			.. FormatDebugNumber(x)
			.. " y="
			.. FormatDebugNumber(y)
			.. " scale="
			.. FormatDebugNumber(scale)
			.. " alpha="
			.. SafeText(GetFrameAlpha(tooltip))
	)
	print("  rect=" .. FormatFrameRect(tooltip))
	if tooltip.hoverToolTipVisibleWidth or tooltip.hoverToolTipVisibleHeight then
		print(
			"  visualTarget=w="
				.. FormatDebugNumber(tooltip.hoverToolTipVisibleWidth)
				.. " h="
				.. FormatDebugNumber(tooltip.hoverToolTipVisibleHeight)
				.. " actual=w="
				.. FormatDebugNumber(GetRegionWidthSafe(tooltip))
				.. " h="
				.. FormatDebugNumber(GetRegionHeightSafe(tooltip))
		)
	end
end

local function PrintTooltipFontStringDump(tooltip)
	print("HoverToolTip visible font strings:")

	local count = GetTooltipLineCount(tooltip)
	if count == 0 then
		print("  <none>")
		return
	end

	for index = 1, count do
		local left = GetTooltipLine(tooltip, "Left", index)
		local right = GetTooltipLine(tooltip, "Right", index)
		print(
			"  "
				.. index
				.. ". left="
				.. SafeText(GetFontStringTextSafe(left))
				.. " leftAlpha="
				.. SafeText(GetFrameAlpha(left))
				.. " leftShown="
				.. SafeText(IsShownSafe(left))
				.. " leftRect="
				.. FormatFrameRect(left, tooltip)
				.. " right="
				.. SafeText(GetFontStringTextSafe(right))
				.. " rightAlpha="
				.. SafeText(GetFrameAlpha(right))
				.. " rightShown="
				.. SafeText(IsShownSafe(right))
				.. " rightRect="
				.. FormatFrameRect(right, tooltip)
		)
	end
end

function module:GetFontStringDebugText(fontString)
	if not fontString or type(fontString.GetText) ~= "function" or IsForbidden(fontString) then
		return "missing", nil
	end

	local ok, text = pcall(fontString.GetText, fontString)
	if not ok then
		return "error", nil
	elseif IsSecretValue(text) then
		return "secret", nil
	elseif text == nil then
		return "nil", nil
	elseif text == "" then
		return "empty", text
	end

	return "plain", text
end

function module:PrintTooltipRenderedFontStringDump(tooltip)
	print("HoverToolTip rendered font string regions:")

	if not tooltip or type(tooltip.GetRegions) ~= "function" or IsForbidden(tooltip) then
		print("  <none>")
		return
	end

	local regions = { pcall(tooltip.GetRegions, tooltip) }
	if not regions[1] then
		print("  <none>")
		return
	end

	local count = 0
	for index = 2, #regions do
		local region = regions[index]
		local objectType
		if region and type(region.GetObjectType) == "function" and not IsForbidden(region) then
			local ok, value = pcall(region.GetObjectType, region)
			if ok then
				objectType = value
			end
		end

		if objectType == "FontString" then
			count = count + 1
			local textState, text = self:GetFontStringDebugText(region)
			print(
				"  "
					.. count
					.. ". "
					.. GetFrameDebugName(region)
					.. " textState="
					.. SafeText(textState)
					.. " text="
					.. SafeText(text)
					.. " alpha="
					.. SafeText(GetFrameAlpha(region))
					.. " shown="
					.. SafeText(IsShownSafe(region))
					.. " rect="
					.. FormatFrameRect(region, tooltip)
			)
		end
	end

	if count == 0 then
		print("  <none>")
	end
end

function module:PrintDebugSnapshot()
	local tooltip = GameTooltip
	local context = self:GetTooltipContext(tooltip)
	local dataAllowed, dataReason = IsDataModificationAllowed(context)

	print("HoverToolTip debug snapshot:")
	print("  debugSchema=" .. DEBUG_SCHEMA_VERSION)
	print("  reason=" .. SafeText(context.reason))
	print("  tooltip=" .. SafeText(context.tooltipName) .. " gameTooltip=" .. SafeText(context.isGameTooltip))
	print("  owner=" .. SafeText(context.ownerName) .. " ownerWorld=" .. SafeText(context.ownerWorld) .. " ownerUnitFrame=" .. SafeText(context.ownerUnitFrame))
	print("  focus=" .. SafeText(context.focusName) .. " focusWorld=" .. SafeText(context.focusWorld) .. " focusUnitFrame=" .. SafeText(context.focusUnitFrame))
	print("  unitFrameTooltip=" .. SafeText(context.isUnitFrameTooltip) .. " objectTooltip=" .. SafeText(context.isObject) .. " shouldStyle=" .. SafeText(context.shouldStyleTooltip))
	print(
		"  unit="
			.. SafeText(context.unit)
			.. " isUnit="
			.. SafeText(context.isUnit)
			.. " secretUnit="
			.. SafeText(context.unitIsSecret)
			.. " mouseoverUnit="
			.. SafeText(context.isMouseoverUnit)
	)
	print(
		"  unitKind="
			.. SafeText(context.unitKind)
			.. " player="
			.. SafeText(context.unitIsPlayer)
			.. " controlled="
			.. SafeText(context.unitPlayerControlled)
			.. " reaction="
			.. SafeText(context.unitReactionName)
			.. "("
			.. SafeText(context.unitReaction)
			.. ")"
	)
	print(
		"  level="
			.. SafeText(context.unitLevel)
			.. " class="
			.. SafeText(context.unitClass)
			.. " race="
			.. SafeText(context.unitRace)
			.. " creatureType="
			.. SafeText(context.unitCreatureType)
			.. " classification="
			.. SafeText(context.unitClassification)
	)
	print(
		"  dead="
			.. SafeText(context.unitIsDead)
			.. " tapDenied="
			.. SafeText(context.unitIsTapDenied)
			.. " inInstance="
			.. SafeText(context.inInstance)
			.. " instanceType="
			.. SafeText(context.instanceType)
	)
	print(
		"  worldTooltip="
			.. SafeText(context.isWorldTooltip)
			.. " detailsOverride="
			.. SafeText(IsDetailsOverrideActive())
			.. " detailsBypassesData="
			.. SafeText(IsDetailsOverrideForContext(context))
			.. " dataModify="
			.. SafeText(dataAllowed)
			.. "("
			.. SafeText(dataReason)
			.. ")"
	)

	PrintFrameChain("HoverToolTip owner chain", context.owner)
	PrintFrameChain("HoverToolTip focus chain", context.focus)
	PrintTooltipGeometryDump(tooltip)
	PrintTooltipTextureDump(tooltip)
	PrintTooltipChromeFrameDump(tooltip)
	PrintTooltipDataDump(tooltip)
	PrintTooltipFontStringDump(tooltip)
	self:PrintTooltipRenderedFontStringDump(tooltip)
end

function module:PrintDebugLog()
	print("HoverToolTip debug log:")
	if not self.debugLog or #self.debugLog == 0 then
		print("  <empty>")
		return
	end

	for i, line in ipairs(self.debugLog) do
		print(i .. ". " .. line)
	end
end

function module:SetDebugEnabled(enabled)
	self.debugEnabled = enabled == true
	if self.debugEnabled then
		wipe(self.debugLog)
		DebugLog("debug-enabled", GameTooltip)
		print("HoverToolTip debug: ON. Hover something, then run /httdebug dump or /httdebug show.")
	else
		print("HoverToolTip debug: OFF.")
	end
end

function module:PrintTraceLog()
	print("HoverToolTip trace log:")
	if not self.traceLog or #self.traceLog == 0 then
		print("  <empty>")
		return
	end

	for i, line in ipairs(self.traceLog) do
		print(i .. ". " .. line)
	end
end

function module:SetTraceEnabled(enabled)
	self.traceEnabled = enabled == true
	if self.traceEnabled then
		wipe(self.traceLog)
		TraceLog("trace-start", GameTooltip)
		print("HoverToolTip trace: ON. Reproduce the hover/click, then run /httdebug trace stop.")
	else
		TraceLog("trace-stop", GameTooltip)
			print("HoverToolTip trace: OFF. Run /httdebug trace dump to print it.")
	end
end

function module:RegisterDebugCommand()
	if self.debugCommandRegistered and not self.forceCommandRegistration then
		return
	end

	local function handler(msg)
		msg = strlower(msg or "")
		local traceCommand = strmatch(msg, "^trace%s+(%S+)$")
		if traceCommand == "start" or traceCommand == "on" then
			module:SetTraceEnabled(true)
		elseif traceCommand == "stop" or traceCommand == "off" then
			module:SetTraceEnabled(false)
		elseif traceCommand == "dump" or traceCommand == "show" then
			module:CaptureDebugOutput("HoverToolTip Trace Log", function()
				module:PrintTraceLog()
			end)
		elseif traceCommand == "clear" then
			wipe(module.traceLog)
			print("HoverToolTip trace log cleared.")
		elseif msg == "trace" then
			print("Usage: /httdebug trace start|stop|dump|clear")
		elseif msg == "on" or msg == "1" then
			module:SetDebugEnabled(true)
		elseif msg == "off" or msg == "0" then
			module:SetDebugEnabled(false)
		elseif msg == "clear" then
			wipe(module.debugLog)
			print("HoverToolTip debug log cleared.")
		elseif msg == "show" then
			module:CaptureDebugOutput("HoverToolTip Debug Log", function()
				module:PrintDebugLog()
			end)
		elseif msg == "dump" or msg == "snapshot" or msg == "" then
			module:CaptureDebugOutput("HoverToolTip Debug Snapshot", function()
				module:PrintDebugSnapshot()
			end)
		else
			print("Usage: /httdebug on|off|dump|show|clear")
			print("Trace: /httdebug trace start|stop|dump|clear")
		end
	end

	_G.SLASH_HOVERTOOLTIPDEBUG1 = "/hovertooltipdebug"
	_G.SLASH_HOVERTOOLTIPDEBUG2 = "/httdebug"
	_G.SlashCmdList.HOVERTOOLTIPDEBUG = handler

	self.debugCommandRegistered = true
end

function module:OpenOptions()
	if type(self.ToggleOptionsPanel) == "function" then
		self:ToggleOptionsPanel()
	end
end

function module:RegisterOptionsCommand()
	if self.optionsCommandRegistered and not self.forceCommandRegistration then
		return
	end

	local handler = function()
		if module:ShouldStandDownForMerathilis() then
			module:OpenMerathilisHoverToolTipOptions()
			return
		end

		module:OpenOptions()
	end

	_G.SLASH_HOVERTOOLTIP1 = "/htt"
	_G.SlashCmdList.HOVERTOOLTIP = handler

	self.optionsCommandRegistered = true
end

function module:RegisterSlashCommands(force)
	if self.disabledByMerathilisHoverToolTip or self:ShouldStandDownForMerathilis() then
		self.disabledByMerathilisHoverToolTip = true
		return
	end

	self.forceCommandRegistration = force and true or false
	self:RegisterDebugCommand()
	self:RegisterOptionsCommand()
	self.forceCommandRegistration = nil
end

function module:RegisterCommandRefresh()
	if self.commandRefreshRegistered or type(CreateFrame) ~= "function" then
		return
	end

	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:SetScript("OnEvent", function()
		if module.disabledByMerathilisHoverToolTip or module:ShouldStandDownForMerathilis() then
			module.disabledByMerathilisHoverToolTip = true
			return
		end

		module:RegisterSlashCommands(true)
		if C_Timer and type(C_Timer.After) == "function" then
			local function refreshCommands()
				if module.disabledByMerathilisHoverToolTip or module:ShouldStandDownForMerathilis() then
					module.disabledByMerathilisHoverToolTip = true
					return
				end

				module:RegisterSlashCommands(true)
			end

			C_Timer.After(1, refreshCommands)
			C_Timer.After(3, refreshCommands)
		end
	end)

	self.commandRefreshFrame = frame
	self.commandRefreshRegistered = true
end

function module:ApplyTextStyle(tooltip, context)
	local db = self.db
	if not db or not tooltip or IsForbidden(tooltip) then
		return false
	end

	local lineCount = GetTooltipLineCount(tooltip)
	local changed = false

	for i = 1, lineCount do
		local isTitle = self:IsTitleTextLine(tooltip, context, i)
		local titleSize = context and context.isObject and (db.objectTitleTextSize or db.titleTextSize or 14) or (db.titleTextSize or 14)
		local bodySize = context and context.isObject and (db.objectBodyTextSize or db.bodyTextSize or 11) or (db.bodyTextSize or 11)
		local size = isTitle and titleSize or bodySize
		local outline = isTitle and (db.titleTextOutline or "SHADOWOUTLINE") or (db.bodyTextOutline or "SHADOWOUTLINE")
		local alpha = isTitle and (db.titleTextAlpha or 1) or (db.textAlpha or 1)
		local left = GetTooltipLine(tooltip, "Left", i)
		local right = GetTooltipLine(tooltip, "Right", i)

		changed = ApplyFont(left, size, outline) or changed
		changed = ApplyFont(right, size, outline) or changed

		self:SetFontStringVisualAlpha(left, alpha)
		self:SetFontStringVisualAlpha(right, alpha)
	end

	return changed
end

function module:ShouldFilterLine(tooltip, lineType)
	local db = self.db
	if not db or not db.enable or not tooltip or IsForbidden(tooltip) then
		return
	end

	local shouldModify, context = self:ShouldModifyTooltip(tooltip)
	DebugLog("filter-check:" .. GetLineTypeName(lineType), tooltip, context)

	if not shouldModify or not context.isWorldTooltip or not IsDataModificationAllowed(context) then
		return
	end

	if lineType == LINE_TYPE_QUEST_OBJECTIVE then
		return db.hideQuestObjectives
	elseif lineType == LINE_TYPE_QUEST_TITLE then
		return db.hideQuestTitles
	elseif lineType == LINE_TYPE_QUEST_PLAYER then
		return db.hideQuestPlayers
	end
end

function module:StyleTooltip(tooltip, releaseSuppression)
	local db = self.db
	if not tooltip or IsForbidden(tooltip) then
		return
	end

	if self.disabledByMerathilisHoverToolTip or self:ShouldStandDownForMerathilis() then
		self.disabledByMerathilisHoverToolTip = true
		return
	end

	if self:ShouldUseRestrictedInstancePath(tooltip) then
		self:StyleInstanceTooltip(tooltip)
		return
	end

	if tooltip.hoverToolTipStyling then
		return
	end

	tooltip.hoverToolTipStyling = true
	local data = GetTooltipDataSafe(tooltip)
	if tooltip.hoverToolTipStyledData and tooltip.hoverToolTipStyledData ~= data then
		ReleaseTooltipStatePreservingSuppression(tooltip)
	end
	tooltip.hoverToolTipStyledData = data

	StoreOriginalTooltipState(tooltip)

	if not db or not db.enable then
		ReleaseTooltipState(tooltip)
		tooltip.hoverToolTipStyling = nil
		return
	end

	local shouldModify, context = self:ShouldModifyTooltip(tooltip)
	DebugLog("style", tooltip, context)
	TraceLog("style-begin", tooltip, context, "release=" .. SafeText(releaseSuppression))
	if not shouldModify then
		if IsEmptyTooltipShell(tooltip, context) then
			TraceLog("style-empty-shell-hide", tooltip, context)
			ReleaseTooltipState(tooltip)
			SafeCall(tooltip, "Hide")
			tooltip.hoverToolTipStyling = nil
			return
		end

		if IsLingeringWorldUnitTooltip(context) or IsStaleStyledWorldUnitTooltip(tooltip, context) then
			if self:ShouldHoldRecentWorldTooltip(tooltip) then
				TraceLog("style-hold-lingering", tooltip, context)
				tooltip.hoverToolTipStyling = nil
				return
			end

			TraceLog("style-stale-hide", tooltip, context)
			ReleaseTooltipState(tooltip)
			SafeCall(tooltip, "Hide")
			tooltip.hoverToolTipStyling = nil
			return
		end

		TraceLog("style-release-unmodified", tooltip, context)
		ReleaseTooltipState(tooltip)
		tooltip.hoverToolTipStyling = nil
		return
	end

	if not self:IsCurrentSecretUnitTooltipData(tooltip) then
		HideSecureInstanceLevelText(tooltip)
	end

	if context.isWorldTooltip then
		tooltip.hoverToolTipLastWorldStyleTime = GetTimeSafe()
	end

	StopUnitFrameTooltipRefresh(context)

	SafeCall(tooltip, "SetScale", db.scale or 1)
	SafeCall(tooltip, "SetClampedToScreen", true)

	SetTooltipBackdropAlpha(tooltip, db)
	TraceLog("after-backdrop", tooltip, context)
	tooltip.hoverToolTipInfoAboveNameActive = nil
	self:ApplyTextStyle(tooltip, context)
	TraceLog("after-text", tooltip, context)
	self:ApplyManualLineFilters(tooltip, context)
	TraceLog("after-filters", tooltip, context)
	self:ApplyUnitInfoPosition(tooltip, context)
	TraceLog("after-unit-info", tooltip, context)
	if context.unitKind == "player" and db.hidePlayerSocialStatus and IsDataModificationAllowed(context) then
		ClearPlayerSocialStatusLines(tooltip)
	end
	self:ApplyTextStyle(tooltip, context)
	TraceLog("after-final-text", tooltip, context)
	ResizeTooltipToVisibleText(tooltip, context)
	TraceLog("after-resize", tooltip, context)

	if tooltip.StatusBar then
		SetRegionAlpha(tooltip.StatusBar, db.statusBar and 1 or 0)
		TraceLog("after-statusbar", tooltip, context)
	end

	if tooltip.hoverToolTipSuppressing
		and (releaseSuppression or not context.isUnitFrameTooltip)
	then
		if tooltip.hoverToolTipHoldSuppression and context.isUnitFrameTooltip then
			TraceLog("release-held", tooltip, context)
			SafeCall(tooltip, "SetAlpha", 0)
			tooltip.hoverToolTipStyling = nil
			return
		end

		TraceLog("release-visible", tooltip, context)
		SafeCall(tooltip, "SetAlpha", tooltip.hoverToolTipSuppressedAlpha or 1)
		tooltip.hoverToolTipSuppressing = nil
		tooltip.hoverToolTipSuppressedAlpha = nil
	end

	if context.isWorldTooltip and IsDataModificationAllowed(context) then
		QueueTooltipLayoutRefresh(tooltip, context)
	end

	TraceLog("style-end", tooltip, context)
	tooltip.hoverToolTipStyling = nil
end

function module:QueueStyleTooltip(tooltip)
	if not tooltip or IsForbidden(tooltip) then
		return
	end

	if self:ShouldUseRestrictedInstancePath(tooltip) then
		self:QueueInstanceStyleTooltip(tooltip)
		return
	end

	TraceLog("queue-style", tooltip)
	local shouldModify, context = self:ShouldModifyTooltip(tooltip)
	if not shouldModify and IsEmptyTooltipShell(tooltip, context) then
		TraceLog("queue-style-empty-shell-hide", tooltip, context)
		ReleaseTooltipState(tooltip)
		SafeCall(tooltip, "Hide")
		return
	end

	if not shouldModify and (IsLingeringWorldUnitTooltip(context) or IsStaleStyledWorldUnitTooltip(tooltip, context)) then
		if self:ShouldHoldRecentWorldTooltip(tooltip) then
			TraceLog("queue-style-hold-lingering", tooltip, context)
			return
		end

		TraceLog("queue-style-stale-hide", tooltip, context)
		ReleaseTooltipState(tooltip)
		SafeCall(tooltip, "Hide")
		return
	end

	SuppressTooltipUntilStyled(tooltip)

	if tooltip.hoverToolTipStyleQueued then
		TraceLog("queue-style-skip", tooltip, nil, "already-queued")
		return
	end

	if not C_Timer or type(C_Timer.After) ~= "function" then
		TraceLog("queue-style-immediate", tooltip)
		self:StyleTooltip(tooltip)
		return
	end

	tooltip.hoverToolTipStyleQueued = true
	C_Timer.After(0, function()
		tooltip.hoverToolTipStyleQueued = nil
		if tooltip and not IsForbidden(tooltip) and type(tooltip.IsShown) == "function" and tooltip:IsShown() then
			TraceLog("queue-style-run", tooltip)
			module:StyleTooltip(tooltip)
		end
	end)
end

local function ResetTooltipLayoutRefresh(tooltip)
	if not tooltip or tooltip.hoverToolTipRefreshing then
		return
	end

	tooltip.hoverToolTipLayoutRefreshQueued = nil
	tooltip.hoverToolTipLayoutRefreshed = nil
end

function module:StyleShownTooltips()
	if not self.db or not self.db.enable then
		return
	end

	for _, tooltip in ipairs(self.tooltips or {}) do
		if tooltip and tooltip:IsShown() then
			self:QueueStyleTooltip(tooltip)
		end
	end
end

function module:QueueUnitFrameTooltipRelease(tooltip, delay)
	if not tooltip or IsForbidden(tooltip) then
		return
	end

	if not C_Timer or type(C_Timer.After) ~= "function" then
		self:StyleTooltip(tooltip, true)
		return
	end

	if tooltip.hoverToolTipElvUIReleaseQueued then
		return
	end

	tooltip.hoverToolTipElvUIReleaseQueued = true
	C_Timer.After(delay or UNIT_FRAME_REFRESH_REVEAL_DELAY, function()
		tooltip.hoverToolTipElvUIReleaseQueued = nil
		if tooltip and not IsForbidden(tooltip) and type(tooltip.IsShown) == "function" and tooltip:IsShown() then
			tooltip.hoverToolTipHoldSuppression = nil
			module:StyleTooltip(tooltip, true)
		end
	end)
end

function module:StyleShownTooltipsNow(refreshData)
	if not self.db or not self.db.enable then
		return
	end

	for _, tooltip in ipairs(self.tooltips or {}) do
		if tooltip and tooltip:IsShown() then
			if self:ShouldUseRestrictedInstancePath(tooltip) then
				self:QueueInstanceStyleTooltip(tooltip)
				return
			end

			tooltip.hoverToolTipInfoAboveNameData = nil
			tooltip.hoverToolTipLayoutRefreshed = nil
			tooltip.hoverToolTipLayoutRefreshQueued = nil

			local _, context = self:ShouldModifyTooltip(tooltip)
			if refreshData then
				RefreshTooltipData(tooltip, context)
			end

			if context and context.isUnitFrameTooltip and tooltip.hoverToolTipSuppressing then
				self:StyleTooltip(tooltip, false)
				self:QueueUnitFrameTooltipRelease(tooltip, UNIT_FRAME_REFRESH_REVEAL_DELAY)
				return
			end

			self:StyleTooltip(tooltip, true)
		end
	end
end

function module:SuppressShownTooltips()
	if not self.db or not self.db.enable then
		return
	end

	for _, tooltip in ipairs(self.tooltips or {}) do
		if tooltip and tooltip:IsShown() and not self:ShouldUseRestrictedInstancePath(tooltip) then
			SuppressTooltipUntilStyled(tooltip)
		end
	end
end

function module:QueueModifierRestyle(refreshData, suppress)
	if self.modifierRestyleQueued then
		self.modifierRestyleRefreshData = self.modifierRestyleRefreshData or refreshData
		self.modifierRestyleSuppress = self.modifierRestyleSuppress or suppress
		return
	end

	if not C_Timer or type(C_Timer.After) ~= "function" then
		if suppress then
			self:SuppressShownTooltips()
		end
		self:StyleShownTooltipsNow(refreshData)
		return
	end

	self.modifierRestyleQueued = true
	self.modifierRestyleRefreshData = refreshData
	self.modifierRestyleSuppress = suppress
	C_Timer.After(suppress and 0.08 or 0.03, function()
		local shouldRefresh = module.modifierRestyleRefreshData
		local shouldSuppress = module.modifierRestyleSuppress
		module.modifierRestyleQueued = nil
		module.modifierRestyleRefreshData = nil
		module.modifierRestyleSuppress = nil
		if shouldSuppress then
			module:SuppressShownTooltips()
		end
		module:StyleShownTooltipsNow(shouldRefresh)
	end)
end

local function IsDetailsModifierEvent(key)
	local db = module.db
	local detailsKey = db and db.detailsKey or "NONE"

	if detailsKey == "NONE" or not key then
		return false
	end

	if detailsKey == "SHIFT" then
		return strfind(key, "SHIFT", 1, true) ~= nil
	elseif detailsKey == "CTRL" then
		return strfind(key, "CTRL", 1, true) ~= nil
	elseif detailsKey == "ALT" then
		return strfind(key, "ALT", 1, true) ~= nil
	end

	return false
end

local function ShouldBlockElvUIModifierRefresh(key)
	if not module.db or not module.db.enable or IsDetailsModifierEvent(key) then
		return false
	end

	local tooltip = GameTooltip
	if not tooltip or IsForbidden(tooltip) or type(tooltip.IsShown) ~= "function" or not tooltip:IsShown() then
		return false
	end

	if module:ShouldUseRestrictedInstancePath(tooltip) then
		return false
	end

	local shouldModify, context = module:ShouldModifyTooltip(tooltip)
	return shouldModify and context and not context.inInstance and context.isGameTooltip and context.isWorldTooltip
end

local function ShouldRefreshForElvUIUnitModifierExtras(key)
	if not key or not E or type(E.GetModule) ~= "function" then
		return false
	end

	local TT = E:GetModule("Tooltip", true)
	if not TT or not TT.db then
		return false
	end

	local tooltip = GameTooltip
	if not tooltip or IsForbidden(tooltip) or type(tooltip.IsShown) ~= "function" or not tooltip:IsShown() then
		return false
	end

	if module:ShouldUseRestrictedInstancePath(tooltip) then
		return false
	end

	local shouldModify, context = module:ShouldModifyTooltip(tooltip)
	if not shouldModify or not context or not context.isGameTooltip or not context.isUnit then
		return false
	end

	if not context.isWorldTooltip and not context.isUnitFrameTooltip then
		return false
	end

	local isShift = strfind(key, "SHIFT", 1, true) ~= nil
	local isCtrl = strfind(key, "CTRL", 1, true) ~= nil
	local isAlt = strfind(key, "ALT", 1, true) ~= nil

	if isShift then
		if context.unitKind == "player" and (TT.db.inspectDataEnable or TT.db.alwaysShowRealm or TT.db.targetInfo or TT.db.showMount) then
			return true
		end

		return TT:IsModKeyDown()
	elseif isCtrl then
		if TT.db.modifierID == "CTRL" then
			return true
		end

		if context.unitKind == "player" and TT.db.showMount then
			for index = 2, GetTooltipLineCount(tooltip) do
				if IsPlayerMountLine(tooltip, index) then
					return true
				end
			end
		end
	elseif isAlt then
		return TT:IsModKeyDown()
	end

	return false
end

function module:QueueInspectSettleRestyle()
	if not C_Timer or type(C_Timer.After) ~= "function" then
		return
	end

	local token = (self.inspectSettleToken or 0) + 1
	self.inspectSettleToken = token

	C_Timer.After(0.4, function()
		if module.inspectSettleToken == token then
			module:StyleShownTooltipsNow(false)
		end
	end)
end

function module:RegisterModifierWatcher()
	if self.modifierWatcherRegistered or type(CreateFrame) ~= "function" then
		return
	end

	local frame = CreateFrame("Frame")
	frame:RegisterEvent("MODIFIER_STATE_CHANGED")
	frame:SetScript("OnEvent", function(_, _, key, state)
		local isDetailsModifier = IsDetailsModifierEvent(key)
		local isActive = IsDetailsOverrideActive()
		local detailsStateChanged = module.lastDetailsOverrideActive ~= isActive

		module.lastDetailsOverrideActive = isActive

		if isDetailsModifier then
			module:QueueModifierRestyle(true, true)
		elseif ShouldRefreshForElvUIUnitModifierExtras(key) then
			module:QueueModifierRestyle(true, true)
			module:QueueInspectSettleRestyle()
		elseif detailsStateChanged then
			module:QueueModifierRestyle(true, true)
		end
	end)

	self.modifierWatcher = frame
	self.modifierWatcherRegistered = true
end

function module:RegisterInstanceWatcher()
	if self.instanceWatcherRegistered or type(CreateFrame) ~= "function" then
		return
	end

	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	frame:SetScript("OnEvent", function()
		module:HideInstanceTooltip()
		if GameTooltip and module:IsRestrictedInstanceTooltip(GameTooltip) and IsShownSafe(GameTooltip) then
			module:QueueInstanceStyleTooltip(GameTooltip)
		end
	end)

	self.instanceWatcher = frame
	self.instanceWatcherRegistered = true
end

function module:RegisterMouseWatcher()
	if self.mouseWatcherRegistered then
		return
	end

	local function OnMouseDown(_, button)
		MarkMouseButtonDown(button)
	end

	local function OnMouseUp()
		MarkMouseButtonUp()
	end

	if type(CreateFrame) == "function" then
		local frame = CreateFrame("Frame")
		pcall(frame.RegisterEvent, frame, "GLOBAL_MOUSE_DOWN")
		pcall(frame.RegisterEvent, frame, "GLOBAL_MOUSE_UP")
		frame:SetScript("OnEvent", function(_, event, button)
			if event == "GLOBAL_MOUSE_DOWN" then
				MarkMouseButtonDown(button)
			elseif event == "GLOBAL_MOUSE_UP" then
				MarkMouseButtonUp()
			end
		end)
		self.mouseWatcher = frame
	end

	if _G.WorldFrame and type(_G.WorldFrame.HookScript) == "function" then
		pcall(_G.WorldFrame.HookScript, _G.WorldFrame, "OnMouseDown", OnMouseDown)
		pcall(_G.WorldFrame.HookScript, _G.WorldFrame, "OnMouseUp", OnMouseUp)
	end

	self.mouseWatcherRegistered = true
end

function module:StyleAfterElvUIUnitInfo(tooltip)
	if not tooltip or tooltip ~= GameTooltip or IsForbidden(tooltip) then
		return
	end

	if self:ShouldUseRestrictedInstancePath(tooltip) then
		self:QueueInstanceStyleTooltip(tooltip)
		return
	end

	local shouldModify, context = self:ShouldModifyTooltip(tooltip)
	if shouldModify and context and context.isUnitFrameTooltip then
		TraceLog("uuf-style-after-elvui", tooltip, context)
		StopUnitFrameTooltipRefresh(context)
		tooltip.hoverToolTipHoldSuppression = true
		SuppressTooltipUntilStyled(tooltip)
		SafeCall(tooltip, "SetAlpha", 0)
		self:StyleTooltip(tooltip, false)

		if not C_Timer or type(C_Timer.After) ~= "function" then
			tooltip.hoverToolTipHoldSuppression = nil
			self:StyleTooltip(tooltip, true)
			return
		end

		self:QueueUnitFrameTooltipRelease(
			tooltip,
			tooltip.hoverToolTipHoldSuppression and UNIT_FRAME_FIRST_REVEAL_DELAY or UNIT_FRAME_REFRESH_REVEAL_DELAY
		)
	end
end

function module:PreSuppressElvUIUnitFrameTooltip(owner)
	if self:IsRestrictedInstanceTooltip(GameTooltip) and not GetBlizzardUnitFrameUnit(owner) then
		return
	end

	if not owner or IsForbidden(owner) or not IsUnitOrNameplateFrame(owner) then
		return
	end

	PreHideUnitFrameTooltipChrome(GameTooltip, owner)
	GameTooltip.hoverToolTipHoldSuppression = true
	DebugLog("uuf-pre-suppress", GameTooltip, self:GetTooltipContext(GameTooltip))
	TraceLog("uuf-pre-suppress", GameTooltip, self:GetTooltipContext(GameTooltip), GetFrameDebugName(owner))
end

function module:StyleAfterUnitFrameTooltip(owner)
	if not GameTooltip or IsForbidden(GameTooltip) then
		return
	end

	if owner and not IsForbidden(owner) and IsUnitOrNameplateFrame(owner) then
		PreHideUnitFrameTooltipChrome(GameTooltip, owner)
		GameTooltip.hoverToolTipHoldSuppression = true
	end

	local unit = GetBlizzardUnitFrameUnit(owner)
	if unit and UnitExistsSafe(unit) and (not IsUnitTooltip(GameTooltip) or IsEmptyTooltipShell(GameTooltip, self:GetTooltipContext(GameTooltip))) then
		if type(GameTooltip.SetOwner) == "function" then
			local anchorType = self.db and self.db.cursorAnchorType
			pcall(GameTooltip.SetOwner, GameTooltip, owner or UIParent, anchorType ~= "NONE" and anchorType or "ANCHOR_RIGHT")
		end
		if type(GameTooltip.SetUnit) == "function" then
			GameTooltip.hoverToolTipForcedUnitFrameOwner = owner
			pcall(GameTooltip.SetUnit, GameTooltip, unit)
		end
	end

	if self:ShouldUseRestrictedInstancePath(GameTooltip) then
		self:QueueInstanceStyleTooltip(GameTooltip)
		return
	end

	local shouldModify, context = self:ShouldModifyTooltip(GameTooltip)
	if shouldModify and context and context.isUnitFrameTooltip then
		StopUnitFrameTooltipRefresh(context)
		SuppressTooltipUntilStyled(GameTooltip)
		self:StyleTooltip(GameTooltip, false)
		self:QueueUnitFrameTooltipRelease(GameTooltip, UNIT_FRAME_REFRESH_REVEAL_DELAY)
	end
end

function module:HideForcedUnitFrameTooltip(owner)
	if not GameTooltip or IsForbidden(GameTooltip) then
		return
	end

	if GameTooltip.hoverToolTipForcedUnitFrameOwner ~= owner then
		return
	end

	GameTooltip.hoverToolTipForcedUnitFrameOwner = nil
	GameTooltip.hoverToolTipHoldSuppression = nil
	GameTooltip.hoverToolTipSuppressing = nil
	GameTooltip.hoverToolTipSuppressedAlpha = nil
	ReleaseTooltipState(GameTooltip)
	SafeCall(GameTooltip, "Hide")
end

function module:HookBlizzardUnitFrame(frame)
	if not frame or frame.hoverToolTipUnitFrameHooked or IsForbidden(frame) then
		return
	end

	local function afterEnter(owner)
		if C_Timer and type(C_Timer.After) == "function" then
			C_Timer.After(0, function() module:StyleAfterUnitFrameTooltip(owner) end)
		else
			module:StyleAfterUnitFrameTooltip(owner)
		end
	end

	local function afterLeave(owner)
		if C_Timer and type(C_Timer.After) == "function" then
			C_Timer.After(0, function() module:HideForcedUnitFrameTooltip(owner) end)
		else
			module:HideForcedUnitFrameTooltip(owner)
		end
	end

	local hooked = false
	if type(frame.GetScript) == "function" and type(frame.SetScript) == "function" then
		local ok, original = pcall(frame.GetScript, frame, "OnEnter")
		if ok and type(original) == "function" then
			pcall(frame.SetScript, frame, "OnEnter", function(owner, ...)
				module:PreSuppressElvUIUnitFrameTooltip(owner)
				local result = original(owner, ...)
				afterEnter(owner)
				return result
			end)
			hooked = true
		elseif ok and original == nil then
			pcall(frame.SetScript, frame, "OnEnter", function(owner)
				module:PreSuppressElvUIUnitFrameTooltip(owner)
				afterEnter(owner)
			end)
			hooked = true
		end
	end

	if type(frame.GetScript) == "function" and type(frame.SetScript) == "function" then
		local ok, originalLeave = pcall(frame.GetScript, frame, "OnLeave")
		if ok and type(originalLeave) == "function" then
			pcall(frame.SetScript, frame, "OnLeave", function(owner, ...)
				local result = originalLeave(owner, ...)
				afterLeave(owner)
				return result
			end)
		elseif ok and originalLeave == nil then
			pcall(frame.SetScript, frame, "OnLeave", function(owner)
				afterLeave(owner)
			end)
		end
	end

	if type(frame.HookScript) == "function" then
		if not hooked then
			frame:HookScript("OnEnter", function(owner)
				module:PreSuppressElvUIUnitFrameTooltip(owner)
				afterEnter(owner)
			end)
		end

		frame:HookScript("OnLeave", function(owner)
			afterLeave(owner)
		end)

		hooked = true
	end

	if hooked then
		frame.hoverToolTipUnitFrameHooked = true
	end
end

function module:HookBlizzardUnitFrameTree(frame, depth)
	if not frame or depth > 3 or IsForbidden(frame) then
		return
	end

	self:HookBlizzardUnitFrame(frame)

	if type(frame.GetChildren) ~= "function" then
		return
	end

	local children = { pcall(frame.GetChildren, frame) }
	if not children[1] then
		return
	end

	for index = 2, #children do
		self:HookBlizzardUnitFrameTree(children[index], depth + 1)
	end
end

function module:RegisterBlizzardUnitFrameHooks(isRetry)
	if self.blizzardUnitFrameHooksRegistered and not isRetry then
		return
	end

	if self:HasElvUIUnitFrames() then
		return
	end

	local frameNames = {
		"PlayerFrame",
		"PlayerFrameContent",
		"PlayerFrame.PlayerFrameContent",
		"PetFrame",
		"TargetFrame",
		"TargetFrameToT",
		"FocusFrame",
		"FocusFrameToT",
	}

	for _, name in ipairs(frameNames) do
		local frame = _G[name]
		if not frame and strfind(name, ".", 1, true) then
			local rootName, childName = strmatch(name, "^([^%.]+)%.(.+)$")
			frame = rootName and childName and _G[rootName] and _G[rootName][childName]
		end
		self:HookBlizzardUnitFrameTree(frame, 1)
	end

	if not isRetry and C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(1, function()
			module:RegisterBlizzardUnitFrameHooks(true)
		end)
	end

	self.blizzardUnitFrameHooksRegistered = true
end

function module:RegisterDefaultAnchorHook()
	if self.defaultAnchorHooked or type(hooksecurefunc) ~= "function" or type(_G.GameTooltip_SetDefaultAnchor) ~= "function" then
		return
	end

	hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, owner)
		PreHideUnitFrameTooltipChrome(tooltip, owner)

		local db = module.db
		local anchorType = db and db.cursorAnchorType
		if _G.ElvUI
			or not tooltip
			or IsForbidden(tooltip)
			or tooltip.hoverToolTipApplyingDefaultAnchor
			or not owner
			or IsForbidden(owner)
			or not anchorType
			or anchorType == "NONE"
			or type(tooltip.SetOwner) ~= "function"
		then
			return
		end

		tooltip.hoverToolTipApplyingDefaultAnchor = true
		pcall(tooltip.SetOwner, tooltip, owner, anchorType)
		tooltip.hoverToolTipApplyingDefaultAnchor = nil
	end)

	self.defaultAnchorHooked = true
end

function module:RegisterElvUITooltipHooks()
	if self.elvUITooltipHooksRegistered or type(hooksecurefunc) ~= "function" or not E or type(E.GetModule) ~= "function" then
		return
	end

	local TT = E:GetModule("Tooltip", true)
	if not TT then
		return
	end

	if type(TT.MODIFIER_STATE_CHANGED) == "function" and not TT.hoverToolTipOriginalModifierStateChanged then
		TT.hoverToolTipOriginalModifierStateChanged = TT.MODIFIER_STATE_CHANGED
		TT.MODIFIER_STATE_CHANGED = function(elvTooltip, event, key, state, ...)
			if ShouldBlockElvUIModifierRefresh(key) then
				return
			end

			return TT.hoverToolTipOriginalModifierStateChanged(elvTooltip, event, key, state, ...)
		end
	end

	if type(TT.SetUnitInfo) == "function" then
		hooksecurefunc(TT, "SetUnitInfo", function(_, tooltip)
			module:StyleAfterElvUIUnitInfo(tooltip)
		end)
	end

	if type(TT.GameTooltip_OnTooltipSetUnit) == "function" then
		hooksecurefunc(TT, "GameTooltip_OnTooltipSetUnit", function(tooltip)
			module:StyleAfterElvUIUnitInfo(tooltip)
		end)
	end

	local UF = E:GetModule("UnitFrames", true)
	if UF and type(UF.UnitFrame_OnEnter) == "function" and not UF.hoverToolTipOriginalUnitFrameOnEnter then
		UF.hoverToolTipOriginalUnitFrameOnEnter = UF.UnitFrame_OnEnter
		UF.UnitFrame_OnEnter = function(owner, ...)
			module:PreSuppressElvUIUnitFrameTooltip(owner)
			local result = UF.hoverToolTipOriginalUnitFrameOnEnter(owner, ...)
			module:PreSuppressElvUIUnitFrameTooltip(owner)
			module:StyleAfterElvUIUnitInfo(GameTooltip)
			return result
		end

		for _, unit in ipairs({ "player", "target", "focus", "pet", "targettarget", "focustarget", "pettarget" }) do
			SetUnitFrameEnterScript(UF[unit], UF.UnitFrame_OnEnter)
		end
	end

	self.elvUITooltipHooksRegistered = true
end

function module:HookTooltip(tooltip)
	if not tooltip or self.styledTooltips[tooltip] or IsForbidden(tooltip) then
		return
	end

	self.styledTooltips[tooltip] = true

	HookTooltipScript(tooltip, "OnShow", function(frame)
		if module:ShouldUseRestrictedInstancePath(frame) then
			module:QueueInstanceStyleTooltip(frame)
			return
		end

		TraceLog("hook-onshow", frame)
		ResetTooltipLayoutRefresh(frame)
		module:QueueStyleTooltip(frame)
	end)

	HookTooltipScript(tooltip, "OnTooltipSetUnit", function(frame)
		if module:ShouldUseRestrictedInstancePath(frame) then
			module:QueueInstanceStyleTooltip(frame)
			return
		end

		TraceLog("hook-setunit", frame)
		ResetTooltipLayoutRefresh(frame)
		local shouldModify, context = module:ShouldModifyTooltip(frame)
		if shouldModify and context and context.isWorldTooltip then
			TraceLog("hook-setunit-world-sync", frame, context)
			SuppressTooltipUntilStyled(frame)
			module:StyleTooltip(frame, true)
		else
			TraceLog("hook-setunit-queue", frame, context)
			module:QueueStyleTooltip(frame)
		end
	end)

	HookTooltipScript(tooltip, "OnTooltipSetItem", function(frame)
		if module:ShouldUseRestrictedInstancePath(frame) then
			module:QueueInstanceStyleTooltip(frame)
			return
		end

		TraceLog("hook-setitem", frame)
		ResetTooltipLayoutRefresh(frame)
		module:QueueStyleTooltip(frame)
	end)

	HookTooltipScript(tooltip, "OnUpdate", function(frame)
		if module:ShouldUseRestrictedInstancePath(frame) then
			local styleUntil = frame.hoverToolTipInstanceStyleUntil
			if not IsSecretValue(styleUntil) and type(styleUntil) == "number" and GetTimeSafe() <= styleUntil then
				module:StyleInstanceTooltip(frame, true)
			end
			return
		end

		local shouldModify, context = module:ShouldModifyTooltip(frame)
		if not shouldModify and IsEmptyTooltipShell(frame, context) then
			TraceLog("update-empty-shell-hide", frame, context)
			ReleaseTooltipState(frame)
			SafeCall(frame, "Hide")
			return
		end

		if not shouldModify and IsLingeringWorldUnitTooltip(context) then
			if module:ShouldHoldRecentWorldTooltip(frame) then
				TraceLog("update-hold-lingering", frame, context)
				return
			end

			TraceLog("update-lingering-hide", frame, context)
			ReleaseTooltipState(frame)
			SafeCall(frame, "Hide")
			return
		end

		if frame.hoverToolTipStyledData then
			SweepStyledTooltipChrome(frame)
		end
	end)

	HookTooltipScript(tooltip, "OnHide", function(frame)
		if module:ShouldUseRestrictedInstancePath(frame) then
			module:HideInstanceTooltip()
			return
		end

		TraceLog("hook-onhide", frame)
		frame.hoverToolTipLayoutRefreshQueued = nil
		frame.hoverToolTipLayoutRefreshed = nil
		frame.hoverToolTipRefreshing = nil
		frame.hoverToolTipStyleQueued = nil
		frame.hoverToolTipInstanceStyleQueued = nil
		frame.hoverToolTipInstanceStyleUntil = nil
		frame.hoverToolTipUnitFrameStyleQueued = nil
		frame.hoverToolTipElvUIReleaseQueued = nil
		frame.hoverToolTipHoldSuppression = nil
		frame.hoverToolTipSuppressing = nil
		frame.hoverToolTipSuppressedAlpha = nil
		HideSecureInstanceLevelText(frame)
		ReleaseTooltipState(frame)
	end)
end

function module:RegisterLineFilters()
	if self.lineFiltersRegistered then
		return
	end

	-- Do not register TooltipDataProcessor pre-calls here. In Retail 12.x,
	-- addon callbacks in Blizzard's tooltip data pipeline can make secret
	-- world-cursor tooltip processing run tainted before Blizzard applies unit
	-- color rules. Quest filtering is handled after the tooltip is built.
	self.lineFiltersRegistered = true
end

function module:CollectTooltips()
	self.tooltips = {}

	for _, name in ipairs(TOOLTIP_NAMES) do
		local tooltip = _G[name]
		if tooltip then
			self.tooltips[#self.tooltips + 1] = tooltip
			self:HookTooltip(tooltip)
		end
	end
end

function module:Refresh()
	if self:ShouldStandDownForMerathilis() then
		self.disabledByMerathilisHoverToolTip = true
		self:HideInstanceTooltip()
		return
	end

	self.disabledByMerathilisHoverToolTip = nil
	self.db = self:GetDB()
	if not self.db or not self.db.enable then
		self:HideInstanceTooltip()
	end
	self:StyleShownTooltips()
end

function module:ProfileUpdate()
	self:Refresh()
end

function module:Initialize()
	self.db = self:GetDB()
	if self:ShouldStandDownForMerathilis() then
		self.disabledByMerathilisHoverToolTip = true
		print("HoverToolTip disabled: MerathilisUI HoverToolTip or Name Hover is enabled.")
		return
	end

	self.disabledByMerathilisHoverToolTip = nil
	self:CollectTooltips()
	self:RegisterLineFilters()
	self:RegisterSlashCommands()
	self:RegisterCommandRefresh()
	self:RegisterModifierWatcher()
	self:RegisterInstanceWatcher()
	self:RegisterMouseWatcher()
	self:RegisterDefaultAnchorHook()
	if self:HasElvUIUnitFrames() then
		self:RegisterElvUITooltipHooks()
	else
		self:RegisterBlizzardUnitFrameHooks()
	end

	self.initialized = true
end

-- Standalone addon is initialized through ADDON_LOADED in Init.lua

_G.HoverToolTip_SetDetailsBindingState = function(isHeld)
	if module.disabledByMerathilisHoverToolTip or module:ShouldStandDownForMerathilis() then
		module.disabledByMerathilisHoverToolTip = true
		return
	end

	module.detailsBindingHeld = isHeld and true or false
	module.lastDetailsOverrideActive = IsDetailsOverrideActive()
	module:StyleShownTooltipsNow(true)
end

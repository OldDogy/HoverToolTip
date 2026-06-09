local HTT = _G.HoverToolTip
if not HTT then return end

local ceil = math.ceil
local floor = math.floor
local max = math.max
local min = math.min

local FONT_FLAGS = {
	"NONE",
	"OUTLINE",
	"THICKOUTLINE",
	"MONOCHROME",
	"MONOCHROMEOUTLINE",
	"MONOCHROMETHICKOUTLINE",
	"SHADOW",
	"SHADOWOUTLINE",
	"SHADOWTHICKOUTLINE",
}

local DETAILS_KEYS = { "NONE", "SHIFT", "CTRL", "ALT" }
local ANCHORS = {
	"ANCHOR_CURSOR",
	"ANCHOR_CURSOR_LEFT",
	"ANCHOR_CURSOR_RIGHT",
	"NONE",
}

local ANCHOR_LABELS = {
	ANCHOR_CURSOR = "Cursor Center",
	ANCHOR_CURSOR_LEFT = "Cursor Left",
	ANCHOR_CURSOR_RIGHT = "Cursor Right",
	NONE = "Disabled",
}

local FONT_FACE_VALUES = {}
for _, font in ipairs(HTT.fontChoices or {}) do
	FONT_FACE_VALUES[#FONT_FACE_VALUES + 1] = font.key
end

local FONT_STYLE_VALUES = {}
for _, style in ipairs(HTT.fontStyleChoices or {}) do
	FONT_STYLE_VALUES[#FONT_STYLE_VALUES + 1] = style.key
end

local TOOLTIP_BACKDROP_VALUES = {}
for _, style in ipairs(HTT.tooltipBackdropStyles or {}) do
	TOOLTIP_BACKDROP_VALUES[#TOOLTIP_BACKDROP_VALUES + 1] = style.key
end

local PRESETS = {
	{
		name = "Minimal",
		settings = {
			hideBackdrop = true,
			statusBar = false,
			unitInfoAboveName = true,
			secureInstanceStyling = true,
			hideQuestTitles = true,
			hideQuestObjectives = true,
			hideQuestPlayers = true,
			hideOwnQuestPlayer = false,
			hidePlayerGuild = true,
			hidePlayerTitle = true,
			hidePlayerRealm = true,
			hidePlayerLevel = false,
			hidePlayerRace = true,
			hidePlayerClass = true,
			hidePlayerFaction = true,
			hidePlayerPvP = true,
			hidePlayerSocialStatus = true,
			hidePlayerMount = true,
			hidePlayerTarget = true,
			hidePlayerRole = true,
			hideNPCLevel = false,
			hideNPCClassification = false,
			hideNPCCreatureType = true,
			hideNPCTitle = true,
			hideNPCAffiliation = true,
			hideNPCThreat = true,
			hideNPCTarget = true,
		},
	},
	{
		name = "Clean",
		settings = {
			hideBackdrop = true,
			statusBar = false,
			unitInfoAboveName = true,
			secureInstanceStyling = false,
			hideQuestTitles = false,
			hideQuestObjectives = false,
			hideQuestPlayers = false,
			hideOwnQuestPlayer = false,
			hidePlayerGuild = true,
			hidePlayerTitle = true,
			hidePlayerRealm = true,
			hidePlayerLevel = false,
			hidePlayerRace = false,
			hidePlayerClass = false,
			hidePlayerFaction = true,
			hidePlayerPvP = true,
			hidePlayerSocialStatus = true,
			hidePlayerMount = true,
			hidePlayerTarget = false,
			hidePlayerRole = true,
			hideNPCLevel = false,
			hideNPCClassification = false,
			hideNPCCreatureType = false,
			hideNPCTitle = true,
			hideNPCAffiliation = true,
			hideNPCThreat = false,
			hideNPCTarget = false,
		},
	},
	{
		name = "Full Info",
		settings = {
			hideBackdrop = false,
			statusBar = true,
			unitInfoAboveName = false,
			secureInstanceStyling = false,
			hideQuestTitles = false,
			hideQuestObjectives = false,
			hideQuestPlayers = false,
			hideOwnQuestPlayer = false,
			hidePlayerGuild = false,
			hidePlayerTitle = false,
			hidePlayerRealm = false,
			hidePlayerLevel = false,
			hidePlayerRace = false,
			hidePlayerClass = false,
			hidePlayerFaction = false,
			hidePlayerPvP = false,
			hidePlayerSocialStatus = false,
			hidePlayerMount = false,
			hidePlayerTarget = false,
			hidePlayerRole = false,
			hideNPCLevel = false,
			hideNPCClassification = false,
			hideNPCCreatureType = false,
			hideNPCTitle = false,
			hideNPCAffiliation = false,
			hideNPCThreat = false,
			hideNPCTarget = false,
		},
	},
}

local TABS = {
	{ key = "setup", label = "Setup" },
	{ key = "general", label = "General" },
	{ key = "text", label = "Text" },
	{ key = "lines", label = "Lines" },
}

local GROUPS = {
	{
		tab = "setup",
		title = "Profiles",
		custom = "profiles",
	},
	{
		tab = "setup",
		title = "Presets",
		custom = "presets",
	},
	{
		tab = "setup",
		title = "Import / Export",
		custom = "importExport",
	},
	{
		tab = "general",
		title = "General",
		selects = {
			{ "cursorAnchorType", "Cursor anchor", ANCHORS },
			{ "detailsKey", "Modifier fallback", DETAILS_KEYS },
		},
		checks = {
			{ "enable", "Enable" },
			{ "hideBackdrop", "Transparent backdrop" },
			{ "statusBar", "Status bar" },
			{ "unitInfoAboveName", "HoverToolTip styling" },
			{ "secureInstanceStyling", "Compact secret instance tooltips" },
			{ "detailsOnUnitFrames", "Full details on unit frames" },
		},
	},
	{
		tab = "general",
		title = "Appearance",
		sliders = {
			{ "optionsBackdropAlpha", "Options backdrop alpha", 0, 1, 0.01, true },
			{ "alpha", "Backdrop alpha", 0, 1, 0.01, true },
			{ "scale", "Scale", 0.5, 2, 0.01, false },
		},
	},
	{
		tab = "text",
		title = "Text",
		selects = {
			{ "fontFace", "Font", FONT_FACE_VALUES },
			{ "fontStyle", "Font style", FONT_STYLE_VALUES },
			{ "titleTextOutline", "Title outline", FONT_FLAGS },
			{ "bodyTextOutline", "Body outline", FONT_FLAGS },
		},
		sliders = {
			{
				{ "titleTextSize", "Title text size", 5, 60, 1, false },
				{ "titleTextAlpha", "Title text alpha", 0, 1, 0.01, true },
			},
			{
				{ "bodyTextSize", "Body text size", 5, 60, 1, false },
				{ "textAlpha", "Body text alpha", 0, 1, 0.01, true },
			},
			{ "objectTitleTextSize", "Object title text size", 5, 60, 1, false },
			{ "objectBodyTextSize", "Object body text size", 5, 60, 1, false },
		},
	},
	{
		tab = "text",
		title = "Tooltip Backdrop",
		checksFirst = true,
		checks = {
			{ "customTooltipBackdrop", "Enabled" },
		},
		selects = {
			{ "tooltipBackdropStyle", "Style", TOOLTIP_BACKDROP_VALUES },
		},
		sliders = {
			{ "customTooltipBackdropAlpha", "Custom backdrop alpha", 0, 1, 0.01, true },
			{ "customTooltipBackdropScale", "Custom backdrop scale", 0.5, 1.75, 0.01, false },
		},
	},
	{
		tab = "lines",
		title = "Hide Quest Lines",
		checks = {
			{ "hideQuestTitles", "Quest Titles" },
			{ "hideQuestObjectives", "Quest Objectives" },
			{ "hideQuestPlayers", "Party Quest Players" },
			{ "hideOwnQuestPlayer", "Your Character Name" },
		},
	},
	{
		tab = "lines",
		title = "Hide Player Lines",
		checks = {
			{ "hidePlayerGuild", "Guild" },
			{ "hidePlayerTitle", "Title" },
			{ "hidePlayerRealm", "Realm" },
			{ "hidePlayerLevel", "Level" },
			{ "hidePlayerRace", "Race" },
			{ "hidePlayerClass", "Spec/Class" },
			{ "hidePlayerFaction", "Faction" },
			{ "hidePlayerPvP", "PvP" },
			{ "hidePlayerSocialStatus", "Social Status" },
			{ "hidePlayerMount", "Mount" },
			{ "hidePlayerTarget", "Target" },
			{ "hidePlayerRole", "Role" },
		},
	},
	{
		tab = "lines",
		title = "Hide NPC Lines",
		checks = {
			{ "hideNPCLevel", "Level" },
			{ "hideNPCClassification", "Classification" },
			{ "hideNPCCreatureType", "Creature Type" },
			{ "hideNPCTitle", "Title" },
			{ "hideNPCAffiliation", "Affiliation" },
			{ "hideNPCThreat", "Threat" },
			{ "hideNPCTarget", "Target" },
		},
	},
}

local function Refresh()
	if HTT.Refresh then
		HTT:Refresh()
	end
end

local BuildOptionsContent
local ApplyOptionsFrameBackdrop

local function SetPointSafe(frame, ...)
	if frame and frame.SetPoint then
		frame:SetPoint(...)
	end
end

local function SetDBValue(key, value)
	local db = HTT:GetDB()
	db[key] = value
	HTT.db = db
	if key == "optionsBackdropAlpha" and HTT.optionsPanel then
		ApplyOptionsFrameBackdrop(HTT.optionsPanel)
	end
	Refresh()
end

local function GetFontChoice(value)
	for _, font in ipairs(HTT.fontChoices or {}) do
		if font.key == value then
			return font
		end
	end
end

local function GetTooltipBackdropChoice(value)
	for _, style in ipairs(HTT.tooltipBackdropStyles or {}) do
		if style.key == value then
			return style
		end
	end
end

local function GetFontStyleChoice(value)
	for _, style in ipairs(HTT.fontStyleChoices or {}) do
		if style.key == value then
			return style
		end
	end
end

ApplyOptionsFrameBackdrop = function(frame)
	if not frame or (type(frame.IsForbidden) == "function" and frame:IsForbidden()) then
		return
	end

	local alpha = tonumber(HTT:GetDB().optionsBackdropAlpha) or 0.85
	alpha = min(max(alpha, 0), 1)
	for _, key in ipairs({ "Bg", "InsetBg", "TitleBg", "TopTileStreaks" }) do
		if frame[key] and frame[key].SetAlpha then
			frame[key]:SetAlpha(alpha)
		end
	end
end

local function SetButtonTextureColor(texture, r, g, b, a)
	if texture and texture.SetColorTexture then
		texture:SetColorTexture(r, g, b, a)
	end
end

local function StyleButton(button, selected)
	if not button then
		return
	end

	if not button.hoverToolTipStyled then
		local normal = button:CreateTexture(nil, "BACKGROUND")
		normal:SetAllPoints()
		button:SetNormalTexture(normal)

		local highlight = button:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		button:SetHighlightTexture(highlight)

		local pushed = button:CreateTexture(nil, "BACKGROUND")
		pushed:SetAllPoints()
		button:SetPushedTexture(pushed)

		button.hoverToolTipNormal = normal
		button.hoverToolTipHighlight = highlight
		button.hoverToolTipPushed = pushed
		button.hoverToolTipStyled = true
	end

	SetButtonTextureColor(button.hoverToolTipNormal, selected and 0.42 or 0.08, selected and 0.02 or 0.015, selected and 0.02 or 0.015, 0.92)
	SetButtonTextureColor(button.hoverToolTipHighlight, 0.55, 0.05, 0.04, 0.40)
	SetButtonTextureColor(button.hoverToolTipPushed, 0.02, 0.02, 0.025, 0.95)

	if button.SetNormalFontObject then
		button:SetNormalFontObject(selected and GameFontHighlightSmall or GameFontNormalSmall)
	end
	if button.SetHighlightFontObject then
		button:SetHighlightFontObject(GameFontHighlightSmall)
	end
	if button.SetDisabledFontObject then
		button:SetDisabledFontObject(GameFontDisableSmall)
	end
end

local function RebuildOptions(frame)
	if frame then
		BuildOptionsContent(frame)
	end
	Refresh()
end

local function Clamp(value, minValue, maxValue)
	value = tonumber(value) or minValue
	return min(max(value, minValue), maxValue)
end

local function CreateSection(parent, text, y, layout)
	local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	SetPointSafe(title, "TOPLEFT", 16, y)
	title:SetText(text)

	local line = parent:CreateTexture(nil, "ARTWORK")
	SetPointSafe(line, "TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	line:SetSize(layout.contentWidth - 32, 1)
	line:SetColorTexture(1, 1, 1, 0.18)

	return y - 34
end

local function CreateCheck(parent, key, label, x, y, layout)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	SetPointSafe(check, "TOPLEFT", x, y)
	check.Text:SetText(label)
	check.Text:SetWidth(layout.checkTextWidth)
	check.Text:SetJustifyH("LEFT")
	check:SetScript("OnShow", function(self)
		self:SetChecked(HTT:GetDB()[key] and true or false)
	end)
	check:SetScript("OnClick", function(self)
		SetDBValue(key, self:GetChecked() and true or false)
	end)
	check:SetChecked(HTT:GetDB()[key] and true or false)
end

local function CreateSlider(parent, key, label, minValue, maxValue, step, isPercent, y, layout, x, width)
	local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
	x = x or 24
	width = width or layout.sliderWidth
	SetPointSafe(slider, "TOPLEFT", x, y - 24)
	slider:SetWidth(width)
	slider:SetMinMaxValues(minValue, maxValue)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)

	local text = slider:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	SetPointSafe(text, "TOPLEFT", parent, "TOPLEFT", x, y)
	text:SetWidth(width)
	text:SetJustifyH("LEFT")
	slider.label = text

	if slider.Low then
		slider.Low:ClearAllPoints()
		slider.Low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
	end

	if slider.High then
		slider.High:ClearAllPoints()
		slider.High:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
	end

	if slider.Text then
		slider.Text:SetText("")
	end

	local function FormatValue(value)
		if isPercent then
			return ("%d%%"):format((value or 0) * 100)
		elseif step < 1 then
			return ("%.2f"):format(value or 0)
		end
		return ("%d"):format(value or 0)
	end

	local function UpdateLabel(value)
		text:SetText(label .. ": " .. FormatValue(value))
	end

	slider:SetScript("OnShow", function(self)
		local value = HTT:GetDB()[key] or minValue
		self:SetValue(value)
		UpdateLabel(value)
	end)
	slider:SetScript("OnValueChanged", function(_, value)
		value = tonumber(value) or minValue
		SetDBValue(key, value)
		UpdateLabel(value)
	end)

	local value = HTT:GetDB()[key] or minValue
	slider:SetValue(value)
	UpdateLabel(value)
	return y - 68
end

local function GetValueIndex(values, value)
	for index, candidate in ipairs(values) do
		if candidate == value then
			return index
		end
	end
	return 1
end

local function IsElvUIControlledSelect(key)
	return key == "cursorAnchorType" and _G.ElvUI ~= nil
end

local function GetSelectDisplayText(key, value)
	if key == "cursorAnchorType" then
		return ANCHOR_LABELS[value] or value
	elseif key == "fontFace" then
		local font = GetFontChoice(value)
		return font and font.label or value
	elseif key == "fontStyle" then
		local style = GetFontStyleChoice(value)
		return style and style.label or value
	elseif key == "tooltipBackdropStyle" then
		local style = GetTooltipBackdropChoice(value)
		return style and style.label or value
	end

	return value
end

local function GetDropdownFontObject(value)
	local font = GetFontChoice(value)
	if not font or not font.regular or not CreateFont then
		return GameFontHighlightSmall
	end

	local objectName = "HoverToolTipDropdownFont_" .. value
	local fontObject = _G[objectName] or CreateFont(objectName)
	if fontObject and fontObject.SetFont then
		fontObject:SetFont(font.bold or font.regular, 12, "")
	end
	return fontObject or GameFontHighlightSmall
end

local function CreateCycleButton(parent, key, values, x, y, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	SetPointSafe(button, "TOPLEFT", x, y)
	button:SetSize(width, 24)
	StyleButton(button)

	local function Update()
		if IsElvUIControlledSelect(key) then
			button:SetText("ElvUI")
			button:Disable()
		else
			button:SetText(GetSelectDisplayText(key, HTT:GetDB()[key] or values[1]))
			button:Enable()
		end
	end

	button:SetScript("OnClick", function()
		if IsElvUIControlledSelect(key) then
			Update()
			return
		end

		local index = GetValueIndex(values, HTT:GetDB()[key]) + 1
		if index > #values then
			index = 1
		end

		SetDBValue(key, values[index])
		Update()
	end)
	button:SetScript("OnShow", Update)
	Update()
end

local function CreateDropdown(parent, key, values, x, y, width)
	if not UIDropDownMenu_Initialize or not UIDropDownMenu_CreateInfo or not UIDropDownMenu_AddButton then
		CreateCycleButton(parent, key, values, x + 14, y, width)
		return
	end

	local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
	SetPointSafe(dropdown, "TOPLEFT", x - 20, y + 4)
	UIDropDownMenu_SetWidth(dropdown, width - 20)

	local function Update()
		if IsElvUIControlledSelect(key) then
			UIDropDownMenu_SetText(dropdown, "ElvUI")
			if UIDropDownMenu_DisableDropDown then
				UIDropDownMenu_DisableDropDown(dropdown)
			end
		else
			if UIDropDownMenu_EnableDropDown then
				UIDropDownMenu_EnableDropDown(dropdown)
			end
			UIDropDownMenu_SetText(dropdown, GetSelectDisplayText(key, HTT:GetDB()[key] or values[1]))
		end
	end

	Update()

	UIDropDownMenu_Initialize(dropdown, function()
		if IsElvUIControlledSelect(key) then
			local info = UIDropDownMenu_CreateInfo()
			info.text = "ElvUI"
			info.disabled = true
			info.checked = false
			UIDropDownMenu_AddButton(info)
			return
		end

		for _, value in ipairs(values) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = GetSelectDisplayText(key, value)
			info.value = value
			info.checked = false
			if key == "fontFace" then
				info.fontObject = GetDropdownFontObject(value)
			end
			info.func = function()
				SetDBValue(key, value)
				UIDropDownMenu_SetText(dropdown, GetSelectDisplayText(key, value))
			end
			UIDropDownMenu_AddButton(info)
		end
	end)

	dropdown:SetScript("OnShow", function(self)
		Update()
	end)
end

local function CreateSelect(parent, key, label, values, x, y, layout)
	local text = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	SetPointSafe(text, "TOPLEFT", x, y - 6)
	text:SetText(label)
	text:SetWidth(layout.selectLabelWidth)
	text:SetJustifyH("LEFT")

	CreateDropdown(parent, key, values, x + layout.selectLabelWidth + 12, y, layout.selectControlWidth)
end

local function CreateButton(parent, label, x, y, width, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	SetPointSafe(button, "TOPLEFT", x, y)
	button:SetSize(width, 24)
	button:SetText(label)
	StyleButton(button)
	button:SetScript("OnClick", onClick)
	return button
end

local function ShowTextDialog(title, text, acceptLabel, onAccept)
	if not HTT.textDialog then
		local frame = CreateFrame("Frame", "HoverToolTipTextDialogFrame", UIParent, "BasicFrameTemplateWithInset")
		frame:SetSize(720, 420)
		frame:SetPoint("CENTER")
		frame:SetFrameStrata("FULLSCREEN_DIALOG")
		frame:Hide()
		frame:SetMovable(true)
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", frame.StartMoving)
		frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

		frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 8, 0)

		local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 16, -36)
		scroll:SetPoint("BOTTOMRIGHT", -36, 54)
		frame.scroll = scroll

		local editBox = CreateFrame("EditBox", nil, scroll)
		editBox:SetMultiLine(true)
		editBox:SetAutoFocus(false)
		editBox:SetFontObject(ChatFontNormal)
		editBox:SetSize(650, 320)
		editBox:SetScript("OnEscapePressed", function(self)
			self:ClearFocus()
		end)
		scroll:SetScrollChild(editBox)
		frame.editBox = editBox

		frame.accept = CreateButton(frame, "Apply", 16, -372, 120, function()
			if frame.onAccept then
				frame.onAccept(frame.editBox:GetText() or "")
			end
			frame:Hide()
		end)
		frame.selectAll = CreateButton(frame, "Select All", 144, -372, 120, function()
			frame.editBox:SetFocus()
			frame.editBox:HighlightText()
		end)
		frame.close = CreateButton(frame, "Close", 592, -372, 90, function()
			frame:Hide()
		end)

		HTT.textDialog = frame
	end

	local frame = HTT.textDialog
	frame.title:SetText(title or "HoverToolTip")
	frame.accept:SetText(acceptLabel or "Apply")
	frame.onAccept = onAccept
	frame.editBox:SetText(text or "")
	frame.editBox:SetCursorPosition(0)
	frame.editBox:HighlightText(0, 0)
	frame:Show()
end

local function CreateProfileDropdown(parent, x, y, width, frame)
	if not UIDropDownMenu_Initialize or not UIDropDownMenu_CreateInfo or not UIDropDownMenu_AddButton then
		local names = HTT:GetProfileNames()
		local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
		SetPointSafe(button, "TOPLEFT", x + 14, y)
		button:SetSize(width, 24)
		button:SetText(HTT:GetCurrentProfileName())
		button:SetScript("OnClick", function()
			local current = HTT:GetCurrentProfileName()
			local index = GetValueIndex(names, current) + 1
			if index > #names then
				index = 1
			end

			if HTT:SetProfile(names[index]) then
				RebuildOptions(frame)
			end
		end)
		return
	end

	local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
	SetPointSafe(dropdown, "TOPLEFT", x - 20, y + 4)
	UIDropDownMenu_SetWidth(dropdown, width - 20)
	UIDropDownMenu_SetText(dropdown, HTT:GetCurrentProfileName())

	UIDropDownMenu_Initialize(dropdown, function()
		for _, name in ipairs(HTT:GetProfileNames()) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = name
			info.checked = false
			info.func = function()
				if HTT:SetProfile(name) then
					RebuildOptions(frame)
				end
			end
			UIDropDownMenu_AddButton(info)
		end
	end)

	dropdown:SetScript("OnShow", function(self)
		UIDropDownMenu_SetText(self, HTT:GetCurrentProfileName())
	end)
end

local function AddProfileControls(parent, y, layout, frame)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	SetPointSafe(label, "TOPLEFT", 24, y - 6)
	label:SetText("Active profile")
	label:SetWidth(130)
	label:SetJustifyH("LEFT")

	CreateProfileDropdown(parent, 170, y, min(layout.contentWidth - 210, 320), frame)

	local compact = layout.contentWidth < 680
	local inputWidth = compact and (layout.contentWidth - 48) or min(layout.contentWidth - 48, 300)
	local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	SetPointSafe(input, "TOPLEFT", 24, y - 40)
	input:SetSize(inputWidth, 24)
	input:SetAutoFocus(false)
	input:SetText("")
	input:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)

	local buttonY = compact and (y - 72) or (y - 40)
	local buttonX = compact and 24 or (24 + inputWidth + 16)
	local buttonWidth = compact and floor((layout.contentWidth - 58) / 2) or 116
	CreateButton(parent, "New", buttonX, buttonY, buttonWidth, function()
		if HTT:CreateProfile(input:GetText(), false) then
			input:SetText("")
			RebuildOptions(frame)
		end
	end)
	CreateButton(parent, "Copy", buttonX + buttonWidth + 10, buttonY, buttonWidth, function()
		if HTT:CreateProfile(input:GetText(), true) then
			input:SetText("")
			RebuildOptions(frame)
		end
	end)
	CreateButton(parent, "Reset", buttonX, buttonY - 30, buttonWidth, function()
		HTT:ResetCurrentProfile()
		RebuildOptions(frame)
	end)
	CreateButton(parent, "Delete Named", buttonX + buttonWidth + 10, buttonY - 30, buttonWidth, function()
		if HTT:DeleteProfile(input:GetText()) then
			input:SetText("")
			RebuildOptions(frame)
		end
	end)

	local hint = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	SetPointSafe(hint, "TOPLEFT", 26, compact and (y - 132) or (y - 98))
	hint:SetWidth(layout.contentWidth - 52)
	hint:SetJustifyH("LEFT")
	hint:SetText("Type a name, then use New, Copy, or Delete Named. Reset affects the active profile. Default and active profiles cannot be deleted.")

	return compact and (y - 158) or (y - 124)
end

local function ApplyPreset(preset, frame)
	local db = HTT:GetDB()
	for key, value in pairs(preset.settings) do
		db[key] = value
	end

	HTT.db = db
	RebuildOptions(frame)
end

local function AddPresetControls(parent, y, layout, frame)
	local columns = layout.contentWidth >= 760 and 4 or 2
	local width = floor((layout.contentWidth - 48 - ((columns - 1) * 10)) / columns)

	for index, preset in ipairs(PRESETS) do
		local row = floor((index - 1) / columns)
		local column = (index - 1) % columns
		CreateButton(parent, preset.name, 24 + (column * (width + 10)), y - (row * 30), width, function()
			ApplyPreset(preset, frame)
		end)
	end

	return y - (ceil(#PRESETS / columns) * 30) - 8
end

local function AddImportExportControls(parent, y, layout, frame)
	local width = min(150, floor((layout.contentWidth - 58) / 2))
	CreateButton(parent, "Export Profile", 24, y, width, function()
		ShowTextDialog("Export HoverToolTip Profile", HTT:ExportCurrentProfile(), "Close", nil)
	end)
	CreateButton(parent, "Import Profile", 34 + width, y, width, function()
		ShowTextDialog("Import HoverToolTip Profile", "", "Import", function(text)
			local ok, message = HTT:ImportProfile(text)
			if ok then
				RebuildOptions(frame)
				print("HoverToolTip profile imported into " .. HTT:GetCurrentProfileName() .. ".")
			else
				print("HoverToolTip import failed: " .. tostring(message or "Invalid profile."))
			end
		end)
	end)

	local hint = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	SetPointSafe(hint, "TOPLEFT", 26, y - 34)
	hint:SetWidth(layout.contentWidth - 52)
	hint:SetJustifyH("LEFT")
	hint:SetText("Export copies the active profile. Import replaces the active profile and keeps missing values at defaults.")

	return y - 58
end

local function AddCustomGroup(parent, group, y, layout, frame)
	if group.custom == "profiles" then
		return AddProfileControls(parent, y, layout, frame)
	elseif group.custom == "presets" then
		return AddPresetControls(parent, y, layout, frame)
	elseif group.custom == "importExport" then
		return AddImportExportControls(parent, y, layout, frame)
	end

	return y
end

local function IsValidTab(tabKey)
	for _, tab in ipairs(TABS) do
		if tab.key == tabKey then
			return true
		end
	end
	return false
end

local function GetActiveTab()
	local db = HTT:GetDB()
	if not IsValidTab(db.optionsTab) then
		db.optionsTab = TABS[1].key
	end
	return db.optionsTab
end

local function RefreshTabButtons(frame)
	if not frame or not frame.tabs then
		return
	end

	local activeTab = GetActiveTab()
	for _, button in ipairs(frame.tabs) do
		local selected = button.tabKey == activeTab
		button:SetEnabled(not selected)
		StyleButton(button, selected)
		if selected then
			button:LockHighlight()
		else
			button:UnlockHighlight()
		end
	end
end

local function CreateTabButtons(frame)
	frame.tabs = {}
	local tabWidth = 94
	for index, tab in ipairs(TABS) do
		local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		button:SetSize(tabWidth, 24)
		button:SetPoint("TOPLEFT", 14 + ((index - 1) * (tabWidth + 6)), -30)
		button:SetText(tab.label)
		StyleButton(button)
		button.tabKey = tab.key
		button:SetScript("OnClick", function(self)
			local db = HTT:GetDB()
			db.optionsTab = self.tabKey
			BuildOptionsContent(frame)
		end)
		frame.tabs[index] = button
	end

	RefreshTabButtons(frame)
end

local function AddChecks(parent, checks, y, layout)
	if not checks then
		return y
	end

	for index, option in ipairs(checks) do
		local row = floor((index - 1) / layout.columns)
		local column = (index - 1) % layout.columns
		CreateCheck(parent, option[1], option[2], layout.checkX[column + 1], y - (row * 28), layout)
	end

	return y - (ceil(#checks / layout.columns) * 28) - 6
end

local function AddSelects(parent, selects, y, layout)
	if not selects then
		return y
	end

	for index, option in ipairs(selects) do
		local row = floor((index - 1) / layout.selectColumns)
		local column = (index - 1) % layout.selectColumns
		CreateSelect(parent, option[1], option[2], option[3], layout.selectX[column + 1], y - (row * 34), layout)
	end

	return y - (ceil(#selects / layout.selectColumns) * 34) - 4
end

local function AddSliders(parent, sliders, y, layout)
	if not sliders then
		return y
	end

	for _, option in ipairs(sliders) do
		if type(option[1]) == "table" then
			local left = option[1]
			local right = option[2]
			local rowY = y
			CreateSlider(parent, left[1], left[2], left[3], left[4], left[5], left[6], rowY, layout, 24, layout.halfSliderWidth)
			if right then
				CreateSlider(parent, right[1], right[2], right[3], right[4], right[5], right[6], rowY, layout, layout.halfSliderX, layout.halfSliderWidth)
			end
			y = rowY - 68
		else
			y = CreateSlider(parent, option[1], option[2], option[3], option[4], option[5], option[6], y, layout)
		end
	end

	return y
end

local function GetLayout(width)
	local contentWidth = max(width - 60, 360)
	local columns
	if contentWidth >= 1100 then
		columns = 5
	elseif contentWidth >= 860 then
		columns = 4
	elseif contentWidth >= 600 then
		columns = 3
	else
		columns = 2
	end

	local selectColumns = contentWidth >= 760 and 2 or 1
	local checkColumnWidth = floor((contentWidth - 24) / columns)
	local selectColumnWidth = floor((contentWidth - 24) / selectColumns)
	local checkX = {}
	for index = 1, columns do
		checkX[index] = 18 + ((index - 1) * checkColumnWidth)
	end
	local selectX = {}
	for index = 1, selectColumns do
		selectX[index] = 24 + ((index - 1) * selectColumnWidth)
	end

	local sliderWidth = min(max(contentWidth - 110, 280), 760)
	local halfSliderGap = 40
	local halfSliderWidth = max(floor((sliderWidth - halfSliderGap) / 2), 180)

	return {
		contentWidth = contentWidth,
		columns = columns,
		selectColumns = selectColumns,
		checkX = checkX,
		selectX = selectX,
		checkTextWidth = max(checkColumnWidth - 48, 120),
		selectLabelWidth = selectColumns > 1 and 130 or 160,
		selectControlWidth = min(max(selectColumnWidth - (selectColumns > 1 and 170 or 220), 190), 280),
		sliderWidth = sliderWidth,
		halfSliderWidth = halfSliderWidth,
		halfSliderX = 24 + halfSliderWidth + halfSliderGap,
	}
end

BuildOptionsContent = function(frame)
	if frame.content then
		frame.content:Hide()
		frame.content:SetParent(nil)
		frame.content = nil
	end

	local width = frame:GetWidth()
	local layout = GetLayout(width)
	local activeTab = GetActiveTab()
	local child = CreateFrame("Frame", nil, frame.scroll)
	child:SetSize(layout.contentWidth, 1)
	frame.scroll:SetScrollChild(child)
	frame.scroll:SetVerticalScroll(0)
	frame.content = child
	RefreshTabButtons(frame)

	local y = -14
	for _, group in ipairs(GROUPS) do
		if group.tab == activeTab then
			y = CreateSection(child, group.title, y, layout)
			y = AddCustomGroup(child, group, y, layout, frame)
			if group.checksFirst then
				y = AddChecks(child, group.checks, y, layout)
				y = AddSelects(child, group.selects, y, layout)
				y = AddSliders(child, group.sliders, y, layout)
			else
				y = AddSelects(child, group.selects, y, layout)
				y = AddSliders(child, group.sliders, y, layout)
				y = AddChecks(child, group.checks, y, layout)
			end
			y = y - 12
		end
	end

	child:SetHeight(-y + 24)
end

local function CreateOptionsPanel()
	local db = HTT:GetDB()
	local frame = CreateFrame("Frame", "HoverToolTipOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(Clamp(db.optionsWidth, 460, 1440), Clamp(db.optionsHeight, 460, 900))
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:Hide()
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetResizeBounds(460, 460, 1440, 900)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
	frame:SetScript("OnShow", function(self)
		ApplyOptionsFrameBackdrop(self)
	end)

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 8, 0)
	frame.title:SetText("HoverToolTip")

	CreateTabButtons(frame)

	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 8, -60)
	scroll:SetPoint("BOTTOMRIGHT", -34, 30)
	frame.scroll = scroll

	local resize = CreateFrame("Button", nil, frame)
	resize:SetSize(18, 18)
	resize:SetPoint("BOTTOMRIGHT", -8, 8)
	resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	resize:SetScript("OnMouseDown", function()
		frame:StartSizing("BOTTOMRIGHT")
	end)
	resize:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
		local panelDB = HTT:GetDB()
		panelDB.optionsWidth = floor(frame:GetWidth() + 0.5)
		panelDB.optionsHeight = floor(frame:GetHeight() + 0.5)
		BuildOptionsContent(frame)
	end)
	frame.resize = resize

	frame:SetScript("OnSizeChanged", function(self, width, height)
		local panelDB = HTT:GetDB()
		panelDB.optionsWidth = floor(width + 0.5)
		panelDB.optionsHeight = floor(height + 0.5)
	end)

	ApplyOptionsFrameBackdrop(frame)
	BuildOptionsContent(frame)
	return frame
end

function HTT:RegisterOptions()
	if self.optionsRegistered then
		return
	end

	self.optionsPanel = self.optionsPanel or CreateOptionsPanel()
	self.optionsRegistered = true
end

function HTT:ToggleOptionsPanel()
	self.optionsPanel = self.optionsPanel or CreateOptionsPanel()
	if self.optionsPanel:IsShown() then
		self.optionsPanel:Hide()
	else
		self.optionsPanel:Show()
	end
end

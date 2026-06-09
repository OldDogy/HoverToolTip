local addon = _G.HoverToolTip
if not addon then return end

addon.fontChoices = {
	{ key = "DEFAULT", label = "Default", regular = nil },
	{ key = "LATO", label = "Lato", regular = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\Lato-Regular.ttf", bold = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\Lato-Bold.ttf", italic = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\Lato-Italic.ttf", boldItalic = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\Lato-BoldItalic.ttf" },
	{ key = "FIRA_SANS", label = "Fira Sans", regular = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\FiraSans-Regular.ttf", bold = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\FiraSans-Bold.ttf", italic = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\FiraSans-Italic.ttf", boldItalic = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\FiraSans-BoldItalic.ttf" },
	{ key = "POPPINS", label = "Poppins", regular = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\Poppins-Regular.ttf", bold = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\Poppins-Bold.ttf", italic = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\Poppins-Italic.ttf", boldItalic = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\Poppins-BoldItalic.ttf" },
	{ key = "RAJDHANI", label = "Rajdhani", regular = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\Rajdhani-Regular.ttf", bold = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\Rajdhani-Bold.ttf" },
	{ key = "ANTON", label = "Anton", regular = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\Anton-Regular.ttf", bold = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\Anton-Regular.ttf" },
	{ key = "BEBAS_NEUE", label = "Bebas Neue", regular = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\BebasNeue-Regular.ttf", bold = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\BebasNeue-Regular.ttf" },
	{ key = "ARCHIVO_BLACK", label = "Archivo Black", regular = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\ArchivoBlack-Regular.ttf", bold = "Interface\\AddOns\\HoverToolTip\\Media\\Fonts\\ArchivoBlack-Regular.ttf" },
}

addon.fontStyleChoices = {
	{ key = "REGULAR", label = "Regular", field = "regular" },
	{ key = "BOLD", label = "Bold", field = "bold" },
	{ key = "ITALIC", label = "Italic", field = "italic" },
	{ key = "BOLD_ITALIC", label = "Bold Italic", field = "boldItalic" },
}

addon.tooltipBackdropStyles = {
	{ key = "BURNED_PAPER", label = "Burned Paper", texture = "Interface\\AddOns\\HoverToolTip\\Media\\Backdrops\\BurnedPaper.tga" },
	{ key = "INK_WASH", label = "Ink Wash", texture = "Interface\\AddOns\\HoverToolTip\\Media\\Backdrops\\InkWash.tga" },
	{ key = "PAINT_SPLASH", label = "Paint Splash", texture = "Interface\\AddOns\\HoverToolTip\\Media\\Backdrops\\PaintSplash.tga" },
	{ key = "CHARCOAL", label = "Charcoal", texture = "Interface\\AddOns\\HoverToolTip\\Media\\Backdrops\\Charcoal.tga" },
	{ key = "SOFT_PAPER", label = "Soft Paper", texture = "Interface\\AddOns\\HoverToolTip\\Media\\Backdrops\\SoftPaper.tga" },
}

addon.defaults = {
	enable = true,
	alpha = 1,
	titleTextAlpha = 1,
	textAlpha = 1,
	scale = 1,
	hideBackdrop = true,
	optionsBackdropAlpha = 0.85,
	statusBar = true,
	cursorAnchorType = "ANCHOR_CURSOR_LEFT",
	optionsWidth = 640,
	optionsHeight = 680,
	optionsTab = "setup",

	fontFace = "DEFAULT",
	fontStyle = "REGULAR",
	titleTextSize = 14,
	titleTextOutline = "SHADOWOUTLINE",
	bodyTextSize = 11,
	bodyTextOutline = "SHADOWOUTLINE",
	objectTitleTextSize = 14,
	objectBodyTextSize = 11,
	customTooltipBackdrop = false,
	tooltipBackdropStyle = "CHARCOAL",
	customTooltipBackdropAlpha = 0.85,
	customTooltipBackdropScale = 1.15,
	unitInfoAboveName = false,
	secureInstanceStyling = false,

	detailsKey = "NONE",
	detailsOnUnitFrames = false,
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
}

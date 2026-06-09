local addonName, addon = ...
_G.HoverToolTip = addon

addon.name = addonName
addon.defaults = addon.defaults or {}
addon.dbVersion = 2

local PROFILE_DEFAULT = "Default"
local EXPORT_PREFIX = "HTT:1"

local function GetElvUIEngine()
	if type(_G.ElvUI) ~= "table" or type(unpack) ~= "function" then
		return nil
	end

	local ok, E = pcall(function()
		return unpack(_G.ElvUI)
	end)

	return ok and E or nil
end

function addon:IsMerathilisModuleEnabled(key)
	if type(_G.ElvUI_MerathilisUI) ~= "table" then
		return false
	end

	local E = GetElvUIEngine()
	local db = E and E.db and E.db.mui and E.db.mui[key]
	if type(db) == "table" then
		return db.enable ~= false
	end

	return false
end

function addon:IsMerathilisHoverToolTipEnabled()
	return self:IsMerathilisModuleEnabled("hoverToolTip")
end

function addon:IsMerathilisNameHoverEnabled()
	return self:IsMerathilisModuleEnabled("nameHover")
end

function addon:ShouldStandDownForMerathilis()
	return self:IsMerathilisHoverToolTipEnabled() or self:IsMerathilisNameHoverEnabled()
end

function addon:CopyDefaults(defaults, target)
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end

			self:CopyDefaults(value, target[key])
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

function addon:CopyTable(source, target)
	target = target or {}
	for key, value in pairs(source or {}) do
		if type(value) == "table" then
			target[key] = self:CopyTable(value, type(target[key]) == "table" and target[key] or {})
		else
			target[key] = value
		end
	end
	return target
end

function addon:ReplaceTable(target, source)
	if wipe then
		wipe(target)
	else
		for key in pairs(target) do
			target[key] = nil
		end
	end

	return self:CopyTable(source, target)
end

function addon:GetCharacterKey()
	local name = UnitName and UnitName("player") or nil
	local realm = GetRealmName and GetRealmName() or nil

	if name and name ~= "" and realm and realm ~= "" then
		return name .. " - " .. realm
	elseif name and name ~= "" then
		return name
	end

	return "Default"
end

function addon:NormalizeDB()
	_G.HoverToolTipDB = _G.HoverToolTipDB or _G.HoverToolTipTestDB or {}
	_G.HoverToolTipTestDB = nil
	local root = _G.HoverToolTipDB

	if type(root.profiles) ~= "table" then
		local migrated = type(root.profile) == "table" and root.profile or {}
		root.profiles = {
			[PROFILE_DEFAULT] = migrated,
		}
	end

	root.profile = nil
	root.profileKeys = type(root.profileKeys) == "table" and root.profileKeys or {}
	root.version = self.dbVersion
	root.profiles[PROFILE_DEFAULT] = type(root.profiles[PROFILE_DEFAULT]) == "table" and root.profiles[PROFILE_DEFAULT] or {}

	local active = root.profileKeys[self:GetCharacterKey()]
	if type(active) ~= "string" or active == "" or type(root.profiles[active]) ~= "table" then
		root.profileKeys[self:GetCharacterKey()] = PROFILE_DEFAULT
		active = PROFILE_DEFAULT
	end

	self:CopyDefaults(self.defaults, root.profiles[active])
	return root
end

function addon:GetDB()
	local root = self:NormalizeDB()
	local profileName = root.profileKeys[self:GetCharacterKey()] or PROFILE_DEFAULT
	root.profiles[profileName] = root.profiles[profileName] or {}
	self:CopyDefaults(self.defaults, root.profiles[profileName])
	return root.profiles[profileName]
end

function addon:GetCurrentProfileName()
	local root = self:NormalizeDB()
	return root.profileKeys[self:GetCharacterKey()] or PROFILE_DEFAULT
end

function addon:GetProfileNames()
	local root = self:NormalizeDB()
	local names = {}
	for name in pairs(root.profiles) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

function addon:SetProfile(name)
	name = tostring(name or ""):match("^%s*(.-)%s*$")
	if name == "" then
		return false
	end

	local root = self:NormalizeDB()
	root.profiles[name] = root.profiles[name] or {}
	self:CopyDefaults(self.defaults, root.profiles[name])
	root.profileKeys[self:GetCharacterKey()] = name
	self.db = root.profiles[name]
	return true
end

function addon:CreateProfile(name, copyCurrent)
	name = tostring(name or ""):match("^%s*(.-)%s*$")
	if name == "" then
		return false
	end

	local root = self:NormalizeDB()
	if type(root.profiles[name]) ~= "table" then
		root.profiles[name] = {}
	end

	if copyCurrent then
		self:ReplaceTable(root.profiles[name], self:GetDB())
	end

	self:CopyDefaults(self.defaults, root.profiles[name])
	return self:SetProfile(name)
end

function addon:ResetCurrentProfile()
	local root = self:NormalizeDB()
	local profileName = self:GetCurrentProfileName()
	root.profiles[profileName] = {}
	self:CopyDefaults(self.defaults, root.profiles[profileName])
	self.db = root.profiles[profileName]
end

function addon:DeleteProfile(name)
	local root = self:NormalizeDB()
	name = tostring(name or ""):match("^%s*(.-)%s*$")

	if name == PROFILE_DEFAULT or name == self:GetCurrentProfileName() or type(root.profiles[name]) ~= "table" then
		return false
	end

	root.profiles[name] = nil
	for characterKey, profileName in pairs(root.profileKeys) do
		if profileName == name then
			root.profileKeys[characterKey] = PROFILE_DEFAULT
		end
	end

	return true
end

local function EscapeValue(value)
	return tostring(value):gsub("%%", "%%25"):gsub(";", "%%3B"):gsub("=", "%%3D")
end

local function UnescapeValue(value)
	return tostring(value):gsub("%%3D", "="):gsub("%%3B", ";"):gsub("%%25", "%%")
end

function addon:ExportCurrentProfile()
	local db = self:GetDB()
	local parts = { EXPORT_PREFIX }
	local keys = {}

	for key in pairs(self.defaults) do
		keys[#keys + 1] = key
	end
	table.sort(keys)

	for _, key in ipairs(keys) do
		local value = db[key]
		if type(value) == "boolean" then
			parts[#parts + 1] = key .. "=b:" .. (value and "1" or "0")
		elseif type(value) == "number" then
			parts[#parts + 1] = key .. "=n:" .. tostring(value)
		elseif type(value) == "string" then
			parts[#parts + 1] = key .. "=s:" .. EscapeValue(value)
		end
	end

	return table.concat(parts, ";")
end

function addon:ImportProfile(text)
	text = type(text) == "string" and text:match("^%s*(.-)%s*$") or text
	if type(text) ~= "string" or (text ~= EXPORT_PREFIX and text:sub(1, #EXPORT_PREFIX + 1) ~= EXPORT_PREFIX .. ";") then
		return false, "Import text is not a HoverToolTip profile."
	end

	local imported = self:CopyTable(self.defaults, {})
	local importedCount = 0
	for entry in text:gmatch("[^;]+") do
		entry = entry:match("^%s*(.-)%s*$")
		if entry ~= EXPORT_PREFIX then
			local key, encoded = entry:match("^([^=]+)=(.+)$")
			key = key and key:match("^%s*(.-)%s*$")
			encoded = encoded and encoded:match("^%s*(.-)%s*$")
			local valueType, value
			if encoded then
				valueType, value = encoded:match("^([bns]):(.*)$")
			end
			if key and self.defaults[key] ~= nil and valueType then
				local importedValue
				if valueType == "b" then
					importedValue = value == "1"
				elseif valueType == "n" then
					importedValue = tonumber(value)
				elseif valueType == "s" then
					importedValue = UnescapeValue(value)
				end

				if type(importedValue) == type(self.defaults[key]) then
					imported[key] = importedValue
					importedCount = importedCount + 1
				end
			end
		end
	end

	if importedCount == 0 then
		return false, "Import text did not contain usable HoverToolTip settings."
	end

	local root = self:NormalizeDB()
	local profileName = self:GetCurrentProfileName()
	root.profiles[profileName] = imported
	self.db = imported
	return true
end

function addon:OnInitialize()
	if self:ShouldStandDownForMerathilis() then
		self.disabledByMerathilisHoverToolTip = true
		print("HoverToolTip disabled: MerathilisUI HoverToolTip or Name Hover is enabled.")
		return
	end

	self.db = self:GetDB()

	if type(self.Initialize) == "function" then
		self:Initialize()
	end

	if self.disabledByMerathilisHoverToolTip then
		return
	end

	if type(self.RegisterOptions) == "function" then
		self:RegisterOptions()
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, loadedAddon)
	if loadedAddon == addonName then
		addon:OnInitialize()
	end
end)

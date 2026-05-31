local E, L, V, P, G = unpack(ElvUI)
local AceAddon = E.Libs.AceAddon

local addon = AceAddon:NewAddon("HoverToolTip", "AceEvent-3.0")
_G.HoverToolTip = addon

addon.E = E
addon.L = L
addon.defaults = addon.defaults or {}

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

function addon:GetDB()
	_G.HoverToolTipDB = _G.HoverToolTipDB or {}
	_G.HoverToolTipDB.profile = _G.HoverToolTipDB.profile or {}
	self:CopyDefaults(self.defaults, _G.HoverToolTipDB.profile)
	return _G.HoverToolTipDB.profile
end

function addon:OnInitialize()
	self.db = self:GetDB()

	if type(self.Initialize) == "function" then
		self:Initialize()
	end

	if type(self.RegisterOptions) == "function" then
		self:RegisterOptions()
	end
end

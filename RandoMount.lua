RM = LibStub("AceAddon-3.0"):NewAddon("RandoMount", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0", "AceComm-3.0")

--set options
local options = {
	name = "RandoMount",
	handler = RM,
	type = "group",
	args = {
		mount = {
			type = "execute",
			name = "Random Mount",
			desc = "Summon random mount.",
			func = "ExecuteMount",
			guiHidden = true
		},
		config = {
			type = "execute",
			name = "Configuration",
			desc = "Configure RandoMount",
			func = "ExecuteConfig",
			guiHidden = true
		},
		desc = {
			type = "description",
			name = "RanoMount options.",
			order = 100
		},
		ground = {
			type = "group",
			name = "Ground Mount Options",
			desc = "Options for randmozing ground mounts.",
			order = 200,
			inline = true,
			args = {
				speed = {
					type = "select",
					name = "Ground Mount Speed",
					desc = "Select between all ground mount speeds (60% and 100%) or fast only (100%).",
					values = {
						"All",
						"Fast Only"
					},
					get = "GetOptionGroundSpeed",
					set = "SetOptionGroundSpeed",
					style = "radio",
					order = 210,
					width = "full"
				}
			}
		},
		flying = {
			type = "group",
			name = "Flying Mount Options",
			desc = "Options for randmozing flying mounts.",
			order = 300,
			inline = true,
			args = {
				speed = {
					type = "select",
					name = "Flying Mount Speed",
					desc = "Select between all flying mount speeds, fast only (280% and 310%), and ultra fast only (310%).",
					values = {
						"All",
						"Fast Only",
						"Ultra Only"
					},
					get = "GetOptionFlyingSpeed",
					set = "SetOptionFlyingSpeed",
					style = "radio",
					order = 310,
					width = "full"
				},
				dismount = {
					type = "toggle",
					name = "Dismount While Flying",
					desc = "Allow RandoMount to dismout your character while flying. (Caution: fall damage is still a thing...)",
					get = "GetOptionFlyingDismount",
					set = "SetOptionFlyingDismount",
					order = 320,
					width = "full"
				}
			}
		}
	}
}

local defaults = {
	profile = {
		Ground_Valid_Speeds = 2,
		Flying_Valid_Speeds = 2,
		Flying_Allow_Dismount = false
	},
	char = {
		Riding_Skill = nil
	}
}

function RM:OnEnable()
	--Enabled message
	self:Print("|cff7702bfRandoMount:|r version " .. GetAddOnMetadata("RandoMount", "Version") .. " by " .. GetAddOnMetadata("RandoMount", "Author") .. " loaded.")
end

function RM:OnDisable()
	--Disabled message
	self:Print("RandoMount disabled.")
end

function RM:OnInitialize()
	-- Chat commands
	local chatCommands = {
		rm="ChatCommand",
		randomount="ChatCommand"
	}
	for k,v in pairs(chatCommands) do
		self:RegisterChatCommand(k, v)
	end
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("RandoMount", options)
	-- Options DB
	self.db = LibStub("AceDB-3.0"):New("RandoMountOptionsDB", defaults, true)
	local dbActions = {
		OnNewProfile="RefreshConfig",
		OnProfileChanged="RefreshConfig",
		OnProfileCopied="RefreshConfig",
		OnProfileReset="RefreshConfig"
	}
	for k,v in pairs(dbActions) do
		self.db.RegisterCallback(self, k, v)
	end
	-- Options frames
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("RandoMount", options)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("RandoMount", "RandoMount")
	-- Profile
	local optionsProfile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("RandoMount" .. "-Profiles", optionsProfile)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("RandoMount-Profiles", "Profiles", "RandoMount")
	-- Clear riding skill
	self.db.char.Riding_Skill = nil
end

function RM:ChatCommand(input)
	if not input or input:trim() == "" then
		self:ExecuteHelp()
	else
		LibStub("AceConfigCmd-3.0"):HandleCommand("rm", "RandoMount", input)
	end
end

function RM:ExecuteMount()
	if (IsMounted()) then
		if ((not IsFlying()) or (IsFlying() and RM:GetOptionFlyingDismount())) then
			Dismount()
		end
	else
		local index = RM:RandomMount()
		CallCompanion("MOUNT", index)
	end
end

function RM:RandomMount()
	if (self.db.char.Riding_Skill == nil) then
		for i=1, GetNumSkillLines() do
			local skill_name,_,_,skill_value = GetSkillLineInfo(i)
			if string.match(skill_name, "Riding") then
				self.db.char.Riding_Skill = skill_value
				break
			end
		end
	end
	local zone, subzone = GetZoneText(), GetSubZoneText()
	local ground_slow, ground_fast, flying_slow, flying_fast, flying_ultra = RM:GetMountGroups()
	local mountTable = nil
	local conditions = {
		ctrl = (IsControlKeyDown()),
		dalaran = (string.match(zone, "Dalaran") and not string.match(subzone, "Krasus' Landing")),
		wintergrasp = (string.match(zone, "Wintergrasp")),
		skill = (self.db.char.Riding_Skill <= 150),
		no_flying = (not IsFlyableArea())
	}
	local use_ground = false
	for i,v in pairs(conditions) do
		if (v) then
			use_ground = true
			break
		end
	end
	if (use_ground) then
		if (self.db.char.Riding_Skill == 75) then
			mountTable = ground_slow
		else
			mountTable = ground_fast
			if (RM:GetOptionGroundSpeed() == 1) then
				for _,v in ipairs(ground_slow) do
					table.insert(mountTable, v)
				end
			end
		end
	else
		if (self.db.char.Riding_Skill == 225) then
			mountTable = flying_slow
		else
			if (RM:GetOptionFlyingSpeed() == 3) then
				mountTable = flying_ultra
			elseif (RM:GetOptionFlyingSpeed() == 2) then
				mountTable = flying_fast
				for _,v in ipairs(flying_ultra) do
					table.insert(mountTable, v)
				end
			else
				mountTable = flying_slow
				for _,v in ipairs(flying_fast) do
					table.insert(mountTable, v)
				end
				for _,v in ipairs(flying_ultra) do
					table.insert(mountTable, v)
				end
			end
		end
	end
	local randomIndex = math.random(1, #mountTable)
	return mountTable[randomIndex]
end

function RM:GetMountGroups()
	local ground_slow, ground_fast, flying_slow, flying_fast, flying_ultra = {}, {}, {}, {}, {}
	for i=1,GetNumCompanions("MOUNT") do
		local desc = RM:GetMountDescription(i)
		if (string.match(desc, "Outland") or string.match(desc, "Northrend")) then
			if string.match(desc, "very") then
				table.insert(flying_fast, i)
			elseif string.match(desc, "extremely fast") then
				table.insert(flying_ultra, i)
			elseif string.match(desc, "changes speed") then
				table.insert(flying_fast, i)
				table.insert(flying_slow, i)
			else
				table.insert(flying_slow, i)
			end
		else
			if string.match(desc, "very") then
				table.insert(ground_fast, i)
			else
				table.insert(ground_slow, i)
			end
		end
	end
	return ground_slow, ground_fast, flying_slow, flying_fast, flying_ultra
end

function RM:GetMountDescription(idx)
	local _,_,sid = GetCompanionInfo("MOUNT", idx)
	return GetSpellDescription(sid)
end

function RM:GetOptionGroundSpeed(info)
	return self.db.profile.Ground_Valid_Speeds
end

function RM:SetOptionGroundSpeed(info, value)
	self.db.profile.Ground_Valid_Speeds = value
	local speeds = {
		"All",
		"Fast Only"
	}
	local speed = speeds[value]
	print("|cff7702bfRandoMount:|r Option |cff12ad0cupdated|r: Ground Mount Speed - " .. speed)
end

function RM:GetOptionFlyingSpeed(info)
	return self.db.profile.Flying_Valid_Speeds
end

function RM:SetOptionFlyingSpeed(info, value)
	self.db.profile.Flying_Valid_Speeds = value
	local speeds = {
		"All",
		"Fast Only",
		"Ultra Only"
	}
	local speed = speeds[value]
	print("|cff7702bfRandoMount:|r Option |cff12ad0cupdated|r: FLying Mount Speed - " .. speed)
end

function RM:GetOptionFlyingDismount(info)
	return self.db.profile.Flying_Valid_Speeds
end

function RM:SetOptionFlyingDismount(info, value)
	self.db.profile.Flying_Valid_Speeds = value
	if (value) then
		print "|cff7702bfRandoMount:|r Option |cff12ad0cenabled|r: Flying Dismount"
	else
		print "|cff7702bfRandoMount:|r Option |cff9c0909disabled|r: Flying Dismount"
	end
end

--Ace3 Comm
function RM:OnCommReceived(prefix, message, distribution, sender)
end

function RM:ExecuteHelp()
	print("RandoMount: Unknown command.")
end

function RM:ExecuteConfig()
	--Blizzard UI bug, execute 2x
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
end

function RM:RefreshConfig()
end
--
-- GlobalCompany - utils - GC_DebugUtils
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 27.01.2019
-- @Version: 1.2.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
-- 	v1.2.0.0 (09.03.2019): aPuehri
--		- added new Level "DevDebug"
--		- for usage of Level "DevDebug" see Console Command
--
-- 	v1.1.0.0 (27.01.2019):
--		- update to GC_DebugUtils for fs19.
--
-- 	v1.0.0.0 (17.12.2017):
-- 		- initial fs17 [Debug] (kevink98)
--
-- Notes:
--		- Loaded before all scripts from 'GlobalCompany.lua'
--		- Global instance is 'g_company.debug'
--
-- ToDo:
--

GC_DebugUtils = {};
local GC_DebugUtils_mt = Class(GC_DebugUtils);

-- GC_DebugUtils.setDevLevelMax = false;

GC_DebugUtils.defaultLevel = 1;

GC_DebugUtils.numLevels = 7;
GC_DebugUtils.maxLevels = 20;

GC_DebugUtils.BLANK = -3;
GC_DebugUtils.MODDING = -2;
GC_DebugUtils.ERROR = -1;
GC_DebugUtils.WARNING = 0;
GC_DebugUtils.INFORMATIONS = 1; -- Default max. Increase using 'gcSetDebugLevelState'
GC_DebugUtils.LOAD = 2;
GC_DebugUtils.ONCREATE = 3;
GC_DebugUtils.TABLET = 4;
GC_DebugUtils.DEV = 5;
GC_DebugUtils.DEVDEBUG = 6;
GC_DebugUtils.NETWORK = 7;

function GC_DebugUtils:new(customMt)
	if g_company.debug ~= nil then
		local text = "  [LSMC - GlobalCompany > GC_DebugUtils] - Class already registered! Use 'g_company.debug' to access debug manager.";
		print(text);
		table.insert(self.savedErrors, text);
		return;
	end;

	local self = {};
	setmetatable(self, customMt or GC_DebugUtils_mt);

	self.isDev = GC_DebugUtils:getIsDev();
	-- local setMax = self.isDev and GC_DebugUtils.setDevLevelMax;

	self.registeredScriptNames = {};

	self.registeredScripts = {};
	self.registeredScriptsCount = 0;

	self.registeredMods = {};
	self.registeredModsCount = 0;

	self.printLevel = {};
	self.printLevelPrefix = {};

	for i = -3, GC_DebugUtils.numLevels + 4 do
		-- if i <= GC_DebugUtils.defaultLevel or (setMax and (i < GC_DebugUtils.DEVDEBUG)) then
		if i <= GC_DebugUtils.defaultLevel or (self.isDev and (i < GC_DebugUtils.DEVDEBUG)) then
			self.printLevel[i] = true;
		else
			self.printLevel[i] = false;
		end;

		self.printLevelPrefix[i] = "";
	end;

	self.printLevelPrefix[GC_DebugUtils.BLANK] = "";
	self.printLevelPrefix[GC_DebugUtils.MODDING] = "MODDING: ";
	self.printLevelPrefix[GC_DebugUtils.ERROR] = "ERROR: ";
	self.printLevelPrefix[GC_DebugUtils.WARNING] = "WARNING: ";
	self.printLevelPrefix[GC_DebugUtils.INFORMATIONS] = "INFORMATION: ";
	self.printLevelPrefix[GC_DebugUtils.LOAD] = "LOAD: ";
	self.printLevelPrefix[GC_DebugUtils.ONCREATE] = "ONCREATE: ";
	self.printLevelPrefix[GC_DebugUtils.TABLET] = "TABLET: ";
	self.printLevelPrefix[GC_DebugUtils.DEV] = "DEVELOPMENT: ";
	self.printLevelPrefix[GC_DebugUtils.DEVDEBUG] = "DEVELOPMENT DEBUG: ";
	self.printLevelPrefix[GC_DebugUtils.NETWORK] = "NETWORK DEBUG: ";
	
	self.savedErrors = {};

	return self;
end;

-------------------
-- Print Options --
-------------------

function GC_DebugUtils:print(message, ...)
	local text = string.format(message, ...);
	print(text);
	table.insert(self.savedErrors, text);
end;

-- Standard formatted printing for 'unregistered' scripts. This has no 'level' or 'data' requirement.
function GC_DebugUtils:printToLog(prefix, message, ...)
	if prefix ~= nil then
		prefix = string.format("%s:  ", prefix:upper());
	else
		prefix = "WARNING:  ";
	end;

	local text = "  [LSMC - GlobalCompany] - " .. prefix .. string.format(message, ...);
	print(text);
	table.insert(self.savedErrors, text);
end;

-- Print only the 'mods' header.
function GC_DebugUtils:printHeader(data)
	local header = "  [LSMC - GlobalCompany]";
	
	if data ~= nil then
		if type(data) == "table" then
			if data.header ~= nil then
				header = data.header;
			end;
		else
			registeredScriptName = self.registeredScripts[data];
			header = "  [LSMC - GlobalCompany] - [" .. registeredScriptName .. "]";
		end;
	end;

	print(header);
	table.insert(self.savedErrors, header);
end;

-- Print to log without header.
function GC_DebugUtils:singleLogWrite(level, message, ...)
	if self.printLevel[level] == true then
		local text = "  [LSMC - GlobalCompany] - " .. self.printLevelPrefix[level] .. string.format(message, ...);
	-- else
		-- text = "  [LSMC - GlobalCompany] - " .. self.printLevelPrefix[GC_DebugUtils.ERROR] .. string.format(message, ...);
		
		print(text);
		table.insert(self.savedErrors, text);
	end;
end;

-- Print to log with header.
function GC_DebugUtils:logWrite(data, level, message, ...)
	if self.printLevel[level] == true then
		if data ~= nil then
			local registeredScriptName, header;

			if type(data) == "table" then
				registeredScriptName = self.registeredScripts[data.scriptId];
				header = data.header;
			else
				registeredScriptName = self.registeredScripts[data];
				header = "  [LSMC - GlobalCompany] - [" .. registeredScriptName .. "]";
			end;

			local text = "";
			if registeredScriptName ~= nil then
				if header ~= nil then
					print(header);
					table.insert(self.savedErrors, header);
					text = "    " .. self.printLevelPrefix[level] .. string.format(message, ...);
				else
					text = "  [LSMC - GlobalCompany] - " .. self.printLevelPrefix[level] .. string.format(message, ...);
				end;
			else
				text = "  [LSMC - GlobalCompany > GC_DebugUtils] - Illegal mod!";
			end;
			
			print(text);
			table.insert(self.savedErrors, text);
		end;
	end;
end;

-- Direct print functions (With Header Only).
function GC_DebugUtils:writeBlank(data, message, ...)
	self:logWrite(data, -3, message, ...);
end;

function GC_DebugUtils:writeModding(data, message, ...)
	self:logWrite(data, -2, message, ...);
end;

function GC_DebugUtils:writeError(data, message, ...)
	self:logWrite(data, -1, message, ...);
end;

function GC_DebugUtils:writeWarning(data, message, ...)
	self:logWrite(data, 0, message, ...);
end;

function GC_DebugUtils:writeInformations(data, message, ...)
	self:logWrite(data, 1, message, ...);
end;

function GC_DebugUtils:writeLoad(data, message, ...)
	self:logWrite(data, 2, message, ...);
end;

function GC_DebugUtils:writeOnCreate(data, message, ...)
	self:logWrite(data, 3, message, ...);
end;

function GC_DebugUtils:writeTablet(data, message, ...)
	self:logWrite(data, 4, message, ...);
end;

function GC_DebugUtils:writeDev(data, message, ...)
	self:logWrite(data, 5, message, ...);
end;

function GC_DebugUtils:writeDevDebug(data, message, ...)
	self:logWrite(data, 6, message, ...);
end;

function GC_DebugUtils:writeNetworkDebug(data, message, ...)
	self:logWrite(data, 7, message, ...);
end;

---------------------
-- Other Functions --
---------------------

function GC_DebugUtils:getLevelFromName(levelName, printError)
	local level = GC_DebugUtils[levelName:upper()];

	if printError == true and level == nil then
		local text = "  [LSMC - GlobalCompany > GC_DebugUtils] - 'printLevel' with name '" .. levelName:upper() .. "' does not exist!";
		print(text);
		table.insert(self.savedErrors, text);
	end;

	return level;
end;

function GC_DebugUtils:setLevel(level, value)
	if value == nil or type(value) ~= "boolean" then
		value = false;
	end;

	if level ~= nil and level > 0 and level < GC_DebugUtils.maxLevels then
		self.printLevel[level] = value;
		return true;
	end;

	return false;
end;

function GC_DebugUtils:setAllLevels(value)
	if value == nil or type(value) ~= "boolean" then
		value = false;
	end;

	local count = 0
	for i = -1, GC_DebugUtils.maxLevels do
		if i > 0 then
			self.printLevel[i] = value;
			count = count + 1;
		end;
	end;

	return count;
end;

function GC_DebugUtils:registerScriptName(scriptName, isSpec)
	if type(scriptName) ~= "string" then
		local text = "  [LSMC - GlobalCompany > GC_DebugUtils] - 'registerScriptName' failed! '" .. tostring(scriptName) .. "' is not a string value.";
		print(text);
		table.insert(self.savedErrors, text);
		return;
	end;

	if self.registeredScriptNames[scriptName] == nil then
		self.registeredScriptsCount = self.registeredScriptsCount + 1;

		self.registeredScripts[self.registeredScriptsCount] = scriptName;
		self.registeredScriptNames[scriptName] = self.registeredScriptsCount;

		return self.registeredScriptsCount;
	elseif not isSpec then --i'm not sure, if that is good... but if the script is a spec, and i register it in multiple mod-environments,
		-- then will the function ``g_specializationManager:addSpecialization`` call every times ``source`` and so this function here also multiple times.
		local text = string.format("  [LSMC - GlobalCompany > GC_DebugUtils] - Script name %s is already registered! Registered Script Id = %d", scriptName, self.registeredScriptNames[scriptName]);
		print(text);
		table.insert(self.savedErrors, text);
	end;
end;

function GC_DebugUtils:getDebugData(scriptId, target, customEnvironment)
	local parentScriptId, modName = nil, "";

	if target ~= nil then
		parentScriptId = target.debugIndex;

		if customEnvironment ~= nil then
			modName = " - [" .. tostring(customEnvironment) .. "]"; -- Optional to overwrite modName.
		elseif target.debugModName ~= nil then
			modName = " - [" .. tostring(target.debugModName) .. "]"; -- Optional value for any script to store 'loading mod name'.
		elseif target.customEnvironment ~= nil then
			modName = " - [" .. tostring(target.customEnvironment) .. "]"; -- As given by any 'Object' Class script.
		end;
	else
		if customEnvironment ~= nil then
			modName = " - [" .. tostring(customEnvironment) .. "]";  -- Optional to show modName in header if no target is given.
		end;
	end;

	local scriptName = self:getScriptNameFromIndex(scriptId);
	if scriptName ~= "" then
		local parentScriptName = self:getScriptNameFromIndex(parentScriptId);
		if parentScriptName ~= "" then
			scriptName =  parentScriptName .. " > " .. scriptName;
		end;

		local header = "  [LSMC - GlobalCompany] - [" .. scriptName .. "]" .. modName;

		return {scriptId = scriptId,
				header = header,
				modName = modName,
				BLANK = -3,
				MODDING = -2,
				ERROR = -1,
				WARNING = 0,
				INFORMATIONS = 1,
				LOAD = 2,
				ONCREATE = 3,
				TABLET = 4,
				DEV = 5,
				DEVDEBUG = 6,
				NETWORK = 7};
	end;

	return nil;
end;

function GC_DebugUtils:getScriptNameFromIndex(index)
	local name = "";

	if index ~= nil and self.registeredScripts[index] ~= nil then
		name = self.registeredScripts[index];
	end;

	return name;
end;

function GC_DebugUtils:getScriptIndexFromName(name)
	return self.registeredScriptNames[name];
end;

function GC_DebugUtils:getIsDev(getName)
	local isDev, name = false, "";
	local devNames = {"kevink98", "LSMC", "DEV", "aPuehri"};
	if g_mpLoadingScreen ~= nil and g_mpLoadingScreen.missionInfo ~= nil then
		if g_mpLoadingScreen.missionInfo.playerStyle ~= nil and g_mpLoadingScreen.missionInfo.playerStyle.playerName ~= nil then
			for i = 1, #devNames do
				if g_mpLoadingScreen.missionInfo.playerStyle.playerName == devNames[i] then
					name = devNames[i];
					isDev = true;
					break;
				end;
			end;
		end;
	end;

	if getName == true then
		return isDev, name;
	end;
	
	return isDev;
end;


------------------------------
--| Debug Console Commands |--
------------------------------
function GC_DebugUtils:loadConsoleCommands()
	if self.consoleCommandsLoaded == true then
		return;
	end;

	if self.isDev then
		-- Load dev only debug commands when added.
		addConsoleCommand("gcSetAllDebugLevelsState", "Set the state of all debug levels. [state]", "consoleCommandSetAllDebugLevels", self);
	end;

	addConsoleCommand("gcSetDebugLevelState", "Set the state of the given debug level. [level] [state]", "consoleCommandSetDebugLevel", self);

	self.consoleCommandsLoaded = true;
end;

function GC_DebugUtils:deleteConsoleCommands()
	if self.isDev then
		-- Load dev only debug commands when added
		removeConsoleCommand("gcSetAllDebugLevelsState");
	end;

	removeConsoleCommand("gcSetDebugLevelState");
end;

function GC_DebugUtils:consoleCommandSetDebugLevel(level, state)
	if level == nil then
		return "'GlobalCompany' Debug printLevel failed to update!  gcSetDebugLevelState [level] [state]";
	end;

	local newLevel;
	if GC_DebugUtils[level:upper()] ~= nil then
		newLevel = GC_DebugUtils[level:upper()];
	else
		newLevel = tonumber(level);
	end;

	local value = Utils.stringToBoolean(state);
	local success = self:setLevel(newLevel, value);

	if success then
		return "'GlobalCompany' Debug printLevel " .. tostring(newLevel) .. " = " .. tostring(value);
	else
		return "'GlobalCompany' Debug printLevel failed to update!";
	end;
end;

function GC_DebugUtils:consoleCommandSetAllDebugLevels(state)
	local value = Utils.stringToBoolean(state);
	local updated = self:setAllLevels(value);

	return "'GlobalCompany' Updated (" .. tostring(updated) .. ") Debug printLevels to '" .. tostring(value) .. "'.";
end;

------------------------------------
-- Print Debug (For Testing Only) --
------------------------------------

function debugPrint(name, text, depth, referenceText, isExtraPrintText)
	if isExtraPrintText == true then
		if text ~= nil then	
			g_currentMission:addExtraPrintText(tostring(name) .. " = " .. tostring(text));
		else	
			g_currentMission:addExtraPrintText(tostring(name));
		end;
	else
		local refName = "debugPrint";
		if referenceText ~= nil then
			refName = tostring(referenceText);
		end;
	
		if name ~= nil then
			if text == nil then
				if type(name) == "table" then
					print("", "(" .. refName .. ")")
					if depth == nil then
						depth = 2;
					end;
					DebugUtil.printTableRecursively(name, ":", 1, depth);
					print("");
				else
					print("    " .. refName .. " = " .. tostring(name));
				end;
			else
				if type(text) == "table" then
					print("", "(" .. refName .. ")")
					if depth == nil then
						depth = 2;
					end;
					DebugUtil.printTableRecursively(text, name .. " ", 1, depth);
					print("");
				else
					print("    (" .. refName .. ") " .. tostring(name) .. " = " .. tostring(text));
				end;
			end;
		else
			print("    " .. refName .. " = " .. tostring(name));
		end;
	end;
end;

-- if GC_DebugUtils.setDevLevelMax then
if GC_DebugUtils:getIsDev() then
	getfenv(0)["gc_debugPrint"] = debugPrint;
end
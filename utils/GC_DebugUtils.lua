--
-- GlobalCompany - utils - GC_DebugUtils
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98 / GtX
-- @Date: 27.01.2019
-- @Version: 1.1.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
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

GC_DebugUtils.setDevLevelMax = true; -- Override isDev maxLevel loading to 'false' if needed. (LSMC DEV ONLY)

GC_DebugUtils.defaultLevel = 4; -- Default level used on load.

GC_DebugUtils.numLevels = 6; -- This is starting at `GC_DebugUtils.INFORMATIONS` as we do not disable 'ERROR' or 'WARNING'.
GC_DebugUtils.maxLevels = 20;

GC_DebugUtils.BLANK = -2; -- No 'PREFIX' and can not be disabled in console. (Used for main loading)
GC_DebugUtils.ERROR = -1;
GC_DebugUtils.WARNING = 0;
GC_DebugUtils.INFORMATIONS = 1;
GC_DebugUtils.LOAD = 2;
GC_DebugUtils.ONCREATE = 3;
GC_DebugUtils.TABLET = 4;
GC_DebugUtils.MODDING = 5;
GC_DebugUtils.DEV = 6;

function GC_DebugUtils:new(customMt)
	if g_company.debug ~= nil then
		print("[LSMC - GC_DebugUtils] Class already registered! Use 'g_company.debug' to access debug manager.")
		return;
	end;

	if customMt == nil then
		customMt = GC_DebugUtils_mt;
	end;

	local self = {};
	setmetatable(self, customMt);

	self.isDev = GC_DebugUtils:getIsDev();
	local setMax = self.isDev and GC_DebugUtils.setDevLevelMax;

	self.registeredScriptNames = {};
	
	self.registeredScripts = {};
	self.registeredScriptsCount = 0;

	self.registeredMods = {};
	self.registeredModsCount = 0;

	self.printLevel = {};
	self.printLevelPrefix = {};

	-- Set print levels.
	for i = -2, GC_DebugUtils.numLevels + 3 do
		if i <= GC_DebugUtils.defaultLevel or setMax then
			self.printLevel[i] = true;
		else
			self.printLevel[i] = false;
		end;

		self.printLevelPrefix[i] = "";
	end;

	-- Set print levels prefix.
	self.printLevelPrefix[GC_DebugUtils.BLANK] = "";
	self.printLevelPrefix[GC_DebugUtils.ERROR] = "ERROR: ";
	self.printLevelPrefix[GC_DebugUtils.WARNING] = "WARNING: ";
	self.printLevelPrefix[GC_DebugUtils.INFORMATIONS] = "INFORMATIONS: ";
	self.printLevelPrefix[GC_DebugUtils.LOAD] = "LOAD: ";
	self.printLevelPrefix[GC_DebugUtils.ONCREATE] = "ONCREATE: ";
	self.printLevelPrefix[GC_DebugUtils.TABLET] = "TABLET: ";
	self.printLevelPrefix[GC_DebugUtils.MODDING] = "MODDING: ";
	self.printLevelPrefix[GC_DebugUtils.DEV] = "DEVELOPMENT: ";

	return self;
end;

function GC_DebugUtils:setLevel(level, value)
	if value == nil or type(value) ~= "boolean" then
		value = false;
	end;

	if level ~= nil and level > 0 then
		self.printLevel[level] = value;
	end;
end;

function GC_DebugUtils:setAllLevels(value)
	if value == nil or type(value) ~= "boolean" then
		value = false;
	end;

	for i = -1, GC_DebugUtils.maxLevels do
		if i > 0 then
			self.printLevel[i] = value;
		end;
	end;
end;

-- This is done when game loads.
-- EXAMPLE: GC_PlayerTrigger.debugIndex = g_company.debug:registerScriptName("PlayerTrigger");

-- @param string scriptName = name of the script to register.
-- @return integer = index of the script.
function GC_DebugUtils:registerScriptName(scriptName)
	if self.registeredScriptNames[scriptName] == nil then	
		self.registeredScriptsCount = self.registeredScriptsCount + 1;
		
		self.registeredScripts[self.registeredScriptsCount] = scriptName;
		self.registeredScriptNames[scriptName] = self.registeredScriptsCount;
	
		return self.registeredScriptsCount;
	end;
end;

-- This is called when the script is loaded.
-- EXAMPLE: self.debugData = g_company.debug:getDebugData(GC_PlayerTrigger.debugIndex, target.debugIndex, target.customEnvironment);

-- @param integer scriptId = registered script index.
-- @param integer parentScriptId = registered parent script index. (OPTIONAL)
-- @param string modName = name of the mod loading the scripts. (OPTIONAL) e.g customEnvironment
-- @return table = scriptId, header, (all prefix levels).
function GC_DebugUtils:getDebugData(scriptId, target)
	local parentScriptId = target.debugIndex;
	local modName = target.customEnvironment;
	if modName ~= nil then
		modName = " - [" .. tostring(modName) .. "]";
	else
		modName = "";
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
				BLANK = -2,
				ERROR = -1,
				WARNING = 0,
				INFORMATIONS = 1,
				LOAD = 2,
				ONCREATE = 3,
				TABLET = 4,
				MODDING = 5,
				DEV = 6};
	end;	

	return nil;
end;

-- Print only with a single line and no header.

-- EXAMPLE: g_company.debug:logWrite(self.debugData, self.debugData.MODDING, "Error loading 'playerTriggerNode' %s!", playerTriggerNode);
--
-- [LSMC - GlobalCompany] - Loaded Version: 1.0.0.0 (04.05.2018)


-- EXAMPLE: g_company.debug:logWrite(GC_PlayerTrigger.debugIndex, GC_DebugUtils.MODDING, "Error loading 'playerTriggerNode' %s!", playerTriggerNode);
--
-- [LSMC - GlobalCompany] - Loaded Version: 1.0.0.0 (04.05.2018)

-- @param integer data = registered script index.
-- or
-- @param table data = self.debugData = GC_DebugUtils:getDebugData(scriptId, parentScriptId, modName)

-- @param integer level = print level to be used. (-2 > 6)
-- @param string message = text to be printed. Can contain string-format placeholders
-- @param ... = values to add to given placeholders (OPTIONAL)
function GC_DebugUtils:singleLogWrite(data, level, message, ...)
	if self.printLevel[level] == true then
		if data ~= nil then
			local registeredScriptName, header;
		
			if type(data) == "table" then
				registeredScriptName = self.registeredScripts[data.scriptId];
			else
				registeredScriptName = self.registeredScripts[data];
			end;
		
			if registeredScriptName ~= nil then
				print("  [LSMC - GlobalCompany] - " .. self.printLevelPrefix[level] .. string.format(message, ...));
			else
				print("  [LSMC - GlobalCompany > GC_DebugUtils] - Illegal mod!");
			end;
		end;
	end;
end;

-- Print header and given message.

-- EXAMPLE: g_company.debug:logWrite(self.debugData, self.debugData.MODDING, "Error loading 'playerTriggerNode' %s!", playerTriggerNode);
--
-- [LSMC - GlobalCompany] - [ProductionFactory > GC_PlayerTrigger] - [FS19_TestMap]
--   MODDING: Error loading 'playerTriggerNode' woodSellStartTrigger!


-- EXAMPLE: g_company.debug:logWrite(GC_PlayerTrigger.debugIndex, GC_DebugUtils.MODDING, "Error loading 'playerTriggerNode' %s!", playerTriggerNode);
--
-- [LSMC - GlobalCompany] - [GC_PlayerTrigger]
--   MODDING: Error loading 'playerTriggerNode' woodSellStartTrigger!


-- @param integer data = registered script index.
-- or
-- @param table data = self.debugData = GC_DebugUtils:getDebugData(scriptId, parentScriptId, modName)

-- @param integer level = print level to be used. (-2 > 6)
-- @param string message = text to be printed. Can contain string-format placeholders
-- @param ... = values to add to given placeholders (OPTIONAL)
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
		
			if registeredScriptName ~= nil then
				if header ~= nil then				
					print(header, "    " .. self.printLevelPrefix[level] .. string.format(message, ...));
				else
					print("  [LSMC - GlobalCompany] - " .. self.printLevelPrefix[level] .. string.format(message, ...));
				end;
			else
				print("  [LSMC - GlobalCompany > GC_DebugUtils] - Illegal mod!");
			end;
		end;
	end;
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

function GC_DebugUtils:getIsDev()
	local isDev = false;
	local devNames = {"kevink98", "GtX", "LSMC", "DEV"};
	if g_mpLoadingScreen ~= nil and g_mpLoadingScreen.missionInfo ~= nil then
		if g_mpLoadingScreen.missionInfo.playerStyle ~= nil and g_mpLoadingScreen.missionInfo.playerStyle.playerName ~= nil then
			for i = 1, #devNames do
				if g_mpLoadingScreen.missionInfo.playerStyle.playerName == devNames[i] then
					isDev = true;
					break;
				end;
			end;
		end;
	end;

	return isDev;
end;


------------------------------
--| Debug Console Commands |--
------------------------------
function GC_DebugUtils:loadConsoleCommands()
	if self.isDev then
	
	end;
	
	addConsoleCommand("gc_setDebugLevelState", "Set the state of the given debug level. [level] [state]", "consoleCommandSetDebugLevel", self);
end;

function GC_DebugUtils:deleteConsoleCommands()
	if self.isDev then
	
	end;
	
	removeConsoleCommand("gc_setDebugLevelState");
end;

function GC_DebugUtils:consoleCommandSetDebugLevel(level, state)
	local newLevel = Utils.stringToBoolean(level);
	local value = Utils.stringToBoolean(state);
	self:setLevel(level, value);
	
	return "GC Debug print level " .. level .. " = " .. value;
end;

------------------------------------
-- Print Debug (For Testing Only) --
------------------------------------
function debugPrint(name, text, depth, referenceText)
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
getfenv(0)["gc_debugPrint"] = debugPrint; -- Maybe to make global?

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
	self.printLevelPrefix[GC_DebugUtils.ERROR] = "ERROR:  ";
	self.printLevelPrefix[GC_DebugUtils.WARNING] = "WARNING:  ";
	self.printLevelPrefix[GC_DebugUtils.INFORMATIONS] = "INFORMATIONS:  ";
	self.printLevelPrefix[GC_DebugUtils.LOAD] = "LOAD:  ";
	self.printLevelPrefix[GC_DebugUtils.ONCREATE] = "ONCREATE:  ";
	self.printLevelPrefix[GC_DebugUtils.TABLET] = "TABLET:  ";
	self.printLevelPrefix[GC_DebugUtils.MODDING] = "MODDING:  ";
	self.printLevelPrefix[GC_DebugUtils.DEV] = "DEVELOPMENT:  ";

	return self;
end;

function GC_DebugUtils:addNewLevel(key, prefix)
	if type(key) == "string" then
		if GC_DebugUtils.numLevels + 1 <= GC_DebugUtils.maxLevels then
			local newLevelKey = string.upper(key);
			if GC_DebugUtils[newLevelKey] == nil then
				GC_DebugUtils.numLevels = GC_DebugUtils.numLevels + 1;
				GC_DebugUtils[newLevelKey] = GC_DebugUtils.numLevels;
	
				if prefix == nil then
					prefix = "";
				end;
				self.printLevelPrefix[GC_DebugUtils.numLevels] = tostring(prefix) .. ":  ";
			end;
	
			if self.isDev and GC_DebugUtils.setDevLevelMax then
				self:setLevel(GC_DebugUtils[newLevelKey], true);
			end;
	
			return GC_DebugUtils[newLevelKey];
		end;
	end;
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

-- This is done in the 'new' or 'load' functions of the script.
-- EXAMPLE: self.debugIndex = g_company.debug:registerMod(scriptName, parentScript);
function GC_DebugUtils:registerMod(scriptName, parentScript, modName)
	local registeredMod = {};
	registeredMod.scriptName = scriptName;
	registeredMod.parentScriptName = self:getSplitClassName(parentScript);

	if modName == nil then
		modName = self:getModNameTextFromObject(parentScript);
	end;
	registeredMod.modName = modName;

	local parentScriptName = registeredMod.parentScriptName;
	if parentScriptName ~= "" then
		parentScriptName = parentScriptName .. " > ";
	end;

	registeredMod.header = "    [LSMC - GlobalCompany] - [" .. parentScriptName .. scriptName .. "] -" .. modName;

	self.registeredModsCount = self.registeredModsCount + 1;
	self.registeredMods[self.registeredModsCount] = registeredMod;

	return self.registeredModsCount;
end;

-- EXAMPLE:
--     [LSMC - GlobalCompany] - [GC_ProductionFactory > GC_PlayerTrigger] - [Mod Name: FS19_SawMill];
--     DEV ERROR:  function 'playerTriggerActivated' does not exist! 'isActivatable' is not an option!
function GC_DebugUtils:logWrite(modIndex, level, message, ...)
	if self.printLevel[level] then
		if modIndex ~= nil and self.registeredMods[modIndex] ~= nil then
			local registeredMod = self.registeredMods[modIndex];
			local debugText = "    " .. self.printLevelPrefix[level] .. string.format(message, ...);
			print(registeredMod.header, debugText);
		else
			print("    [LSMC - GC_DebugUtils] illegal mod!");
		end;
	end;
end;

-- EXAMPLE:
--     [LSMC - GlobalCompany > GC_ProductionFactory] - ERROR: function 'playerTriggerActivated' does not exist! 'isActivatable' is not an option!
function GC_DebugUtils:singleWrite(modIndex, level, message, ...)
	if self.printLevel[level] then
		if modIndex ~= nil and self.registeredMods[modIndex] ~= nil then
			local scriptName = self.registeredMods[modIndex].scriptName;
			local scriptString = " > " .. scriptName;
			if scriptName == nil or scriptName == "GlobalCompany" then
				scriptString = "";
			end;
			print("    [LSMC - GlobalCompany" .. scriptString .. "] - " .. self.printLevelPrefix[level] .. string.format(message, ...));
		else
			print("    [LSMC - GC_DebugUtils] illegal mod!");
		end;
	end;
end;

function GC_DebugUtils:getSplitClassName(object)
	local splitClassName = "";

	if object ~= nil and type(object) == "table" then
		local fullClassName = object.className;
		if fullClassName ~= nil then
			local start, _ = string.find(fullClassName, ".", 1, true);
			if start ~= nil then
				splitClassName = string.sub(fullClassName, start + 1);
			end;
		end;
	end;

	return splitClassName;
end;

function GC_DebugUtils:getModNameTextFromObject(object)
	local text = "";

	if object ~= nil and object.customEnvironment ~= nil then
		local modName = object.customEnvironment;

		text = string.format(" [Mod Name: %s  Type: Placeable]", modName);

		if g_currentMission.loadingMapModName ~= nil then
			if modName == g_currentMission.loadingMapModName then
				text = string.format(" [Mod Name: %s  Type: OnCreate]", modName);
			end;
		end;
	end;

	return text;
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
	
	return "GC Debug print level " .. level .. " = " .. state;
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


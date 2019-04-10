--
-- GlobalCompany - Utils - GC_languageManager
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 17.12.2018
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 ():
-- 		- initial fs19 (kevink98)
--
-- Notes:
--
--
-- ToDo:
--
--

GC_languageManager = {};
GC_languageManager.debugIndex = g_company.debug:registerScriptName("LanguageManager");

g_company.languageManager = GC_languageManager;

local baseModNameToPrefix = {["GlobalCompany"] = "GC",
							 ["GlobalCompanyTablet"] = "GCT",
							 ["GlobalCompanySRS"] = "SRS"};

function GC_languageManager:load(loadingDirectory)
	GC_languageManager.debugData = g_company.debug:getDebugData(GC_languageManager.debugIndex, g_company);

	addConsoleCommand("gcCompareLanguageFiles", "Compare language files. For mods use [modName] [folder](optional)", "consoleCommandCompareLanguageFiles", GC_languageManager);

	if loadingDirectory ~= nil then
		local baseLanguageFullPath = g_company.languageManager:getLanguagesFullPath(loadingDirectory);
		GC_languageManager:loadEntries(g_currentModName, baseLanguageFullPath, "l10n.elements.e(%d)");

		g_company.debug:writeDev(GC_languageManager.debugData, "Standard language XML file has been loaded successfully."); -- Only print in development mode.
	end;
end;

function GC_languageManager:delete()
	removeConsoleCommand("gcCompareLanguageFiles");
end;

function GC_languageManager:loadModLanguageFiles(modLanguageFiles)
	local fullPathCount = 0;

	if modLanguageFiles ~= nil then
		for modName, fullPath in pairs(modLanguageFiles) do
			GC_languageManager:loadEntries(modName, fullPath, "l10n.elements.e(%d)");
			fullPathCount = fullPathCount + 1;
		end;
	end;

	if fullPathCount > 0 then
		g_company.debug:writeLoad(GC_languageManager.debugData, "'%d' mod language XML files have been loaded successfully.", fullPathCount);
	end;
end;

function GC_languageManager:loadEntries(modName, fullPath, baseKey)
	local globalTexts = getfenv(0).g_i18n.texts;
	
	local duplicateTable = {};
	local prefixErrorTable = {};
	local rootModName = g_company.utils.getRootModName(modName)

	local xmlFile = loadXMLFile("TempConfig", fullPath);

	local i = 0;
	while true do
		local key = string.format(baseKey, i);
		if not hasXMLProperty(xmlFile, key) then
			break;
		end;

		local k = getXMLString(xmlFile, key.."#k");
		local v = getXMLString(xmlFile, key.."#v");

		if k ~= nil and v ~= nil then
			if GC_languageManager:getCanUseText(k, rootModName) then -- Make sure the texts are mod specific.
				if globalTexts[k] == nil then -- Stop duplicates and print warning.
					globalTexts[k] = v;
				else
					table.insert(duplicateTable, k);
				end;
			else
				table.insert(prefixErrorTable, k);
			end;
		end;

		i = i + 1;
	end;

	delete(xmlFile);

	-- Group print all warning at the end.
	if #duplicateTable > 0 then
		local text = "The following duplicate text entries have been found in '%s' (%s)! Please remove these."
		g_company.debug:writeWarning(GC_languageManager.debugData, text, fullPath, modName);

		for i = 1, #duplicateTable do
			local name = duplicateTable[i];
			print(string.format("      %d: %s", i, name));
		end;

		duplicateTable = nil;
	end;

	if #prefixErrorTable > 0 then
		local text = "The following text entries loaded from '%s' do not have the required prefix or subPrefix '%s'! Please add this."
		local prefix = rootModName;
		if baseModNameToPrefix[rootModName] ~= nil then
			prefix = baseModNameToPrefix[rootModName];
		end;
		
		g_company.debug:writeWarning(GC_languageManager.debugData, text, fullPath, prefix);

		for i = 1, #prefixErrorTable do
			local name = prefixErrorTable[i];
			print(string.format("      %d: %s", i, name));
		end;

		prefixErrorTable = nil;
	end;
end

function GC_languageManager:getLanguagesFullPath(modPath)
	local languageSuffixs = {g_languageSuffix, "_en", "_de"};
	for i = 1, 3 do
		local fullPath = string.format("%sl10n%s.xml", modPath, languageSuffixs[i]);
		if fileExists(fullPath) then
			return fullPath;
		else
			fullPath = string.format("%slanguages/l10n%s.xml", modPath, languageSuffixs[i]);
			if fileExists(fullPath) then
				return fullPath;
			end;
		end;
	end;

	return;
end;

-- @kevink98 Should we force people to include 'English' if they have text files.
function GC_languageManager:checkEnglishBackupExists(fullPath, modName)
	local filename = string.format("l10n%s", g_languageSuffix);
	if filename == "l10n_en" then
		return true;
	else
		local path = fullPath:gsub(filename, "l10n_en")
		if fileExists(path) then
			return true;
		end;
	end;

	local text = "Failed to find 'l10n_en' language file for mod ' %s '! This is a minimum requirement when using language files.";
	g_company.debug:writeWarning(GC_languageManager.debugData, text, modName);

	return false;
end;

function GC_languageManager:getText(textName, endText)
	if textName ~= nil then
		local text = "";

		if textName:sub(1, 6) == "$l10n_" then
			local subText = textName:sub(7);
			if g_i18n:hasText(subText) then
				text = g_i18n:getText(subText);
			end;
		elseif g_i18n:hasText(textName) then
			text = g_i18n:getText(textName);
		end;

		if text ~= "" then
			if endText ~= nil then
				return text .. tostring(endText);
			end;

			return text;
		end;

		return textName;
	end;

	return "";
end;

-- Mods must use their filename as a prefix. Excluding 'FS19_' from start and / or '_update' from end.).
-- Mod Name: FS19_MyGreatFactory
-- Examples: 'MyGreatFactory_OpenGate' or 'input_MyGreatFactory_OpenGate' or 'gui_MyGreatFactory_Options'.
function GC_languageManager:getCanUseText(text, modName)
	if baseModNameToPrefix[modName] ~= nil then
		local stringStart, stringEnd = text:find("_", 1, true);
		if stringStart ~= nil then
			local subText = text:sub(1, stringStart - 1);
			if subText == "input" or subText == "gui"  then
				local newStart = stringEnd + 1;
				stringStart, stringEnd = text:find("_", newStart, true);
				if stringStart ~= nil then
					subText = text:sub(newStart, stringStart - 1);
					return subText == baseModNameToPrefix[modName];
				end;
			else
				return subText == baseModNameToPrefix[modName];
			end;
		end;
	end;
	
	local stringStart, stringEnd = text:find(modName, 1, true);
	if stringStart ~= nil then
		return true;
	end;

	return false;
end;

function GC_languageManager:consoleCommandCompareLanguageFiles(modName, folder)
	GC_languageManager:compareLanguageFiles(modName, folder);
	return "Comparing of language files completed."
end;

function GC_languageManager:compareLanguageFiles(modName, folder)
	local filesFound = false;
	local languages = {};
	local setNames = {};

	-- Default 'GC' path.
	local path = g_company.dir .. "languages";

	-- Allow modName to be given and location (folder) of mod text files for checking.
	if modName ~= nil then
		if g_modIsLoaded[modName] then
			if folder == nil then
				folder = "";
			end;
			path = g_modNameToDirectory[modName] .. folder
		else
			g_company.debug:singleLogWrite(GC_DebugUtils.WARNING, "Unable to find an active mode with a filename '%s'.", modName);
		end;
	end;

	-- This will check all available game languages.
	for i = 1, getNumOfLanguages() do
		local languageCode = getLanguageCode(i - 1);
		local fileName = string.format("l10n_%s.xml", languageCode);
		local fullPath = string.format("%s/%s", path, fileName);
		if fileExists(fullPath) then
			filesFound = true;
			languages[fileName] = {};
			local xmlFile = loadXMLFile("TempConfig", fullPath);

			local j = 0;
			while true do
				local key = string.format("l10n.elements.e(%d)", j);
				if not hasXMLProperty(xmlFile, key) then
					break;
				end;

				local k = getXMLString(xmlFile, key.."#k");
				local v = getXMLString(xmlFile, key.."#v");

				if k ~= nil and v ~= nil then
					languages[fileName][k] = true; -- Save names for each language.
					setNames[k] = true; -- Save complete list of names to compare with.
				end;

				j = j + 1;
			end;

			delete(xmlFile);
		end;
	end;

	if filesFound then
		for textName, _ in pairs(setNames) do
			for fileName, texts in pairs(languages) do
				if texts[textName] == nil then
					g_company.debug:singleLogWrite(GC_DebugUtils.WARNING, "Text '%s' is missing in %s", textName, fileName);
				end;
			end;
		end;
	else
		g_company.debug:singleLogWrite(GC_DebugUtils.WARNING, "Invalid file path '%s' given! No language files found.", path);
	end;
end;





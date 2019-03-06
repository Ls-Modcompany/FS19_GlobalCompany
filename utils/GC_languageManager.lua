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

function GC_languageManager:load(loadingDirectory)
	GC_languageManager.debugData = g_company.debug:getDebugData(GC_languageManager.debugIndex, g_company);
	
	if loadingDirectory ~= nil then
		local dir = loadingDirectory:sub(1, loadingDirectory:len() - 1); -- Remove  /  from end of file path (g_currentModDirectory).
		local baseLanguageFullPath = g_company.languageManager:getLanguagesFullPath(dir);
		GC_languageManager:loadEntries(g_currentModName, baseLanguageFullPath, "l10n.elements.e(%d)");
		
		g_company.debug:writeDev(GC_languageManager.debugData, "Standard language XML file has been loaded successfully."); -- Only print in development mode.
	end;
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
			if g_company.utils.getHasPrefix(k) then -- Stops texts being added that may change Giants texts.
				if globalTexts[k] == nil then -- Stops our base texts being changed.
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
		local text = "The following text entries loaded from '%s' (%s) do not have the required prefix! Entries must contain 'GC_' for ( GlobalCompany ) mods or 'SRS_' for ( SkiRegionSimulator ) mods."
		g_company.debug:writeWarning(GC_languageManager.debugData, text, fullPath, modName);
		
		for i = 1, #prefixErrorTable do
			local name = prefixErrorTable[i];
			print(string.format("      %d: %s", i, name));
		end;

		prefixErrorTable = nil;
	end;
end

function GC_languageManager:getLanguagesFullPath(modPath)
	local fullPath = string.format("%s/l10n%s.xml", modPath, g_languageSuffix);
	if fileExists(fullPath) then
		return fullPath;
	end;	

	fullPath = string.format("%s/languages/l10n%s.xml", modPath, g_languageSuffix);
	if fileExists(fullPath) then
		return fullPath;
	end;

	fullPath = string.format("%s/l10n_en.xml", modPath);
	if fileExists(fullPath) then
		return fullPath;
	end;	
	
	fullPath = string.format("%s/languages/l10n_en.xml", modPath);
	if fileExists(fullPath) then
		return fullPath;
	end;
	
	return;
end;

function GC_languageManager:getText(text)
	if text ~= nil then
		local addColon = false;
		local lenght = text:len();
		if text:sub(lenght, lenght+1) == ":" then
			text = text:sub(1, lenght-1);
			addColon = true;
		end;
		if text:sub(1,6) == "$l10n_" then
			text = g_i18n:getText(text:sub(7));
		elseif g_i18n:hasText(text) then
			text = g_i18n:getText(text);
		end;
		if addColon and text ~= "" then
			text = text .. ":";
		end;
		return text;
	end;
	return "";
end;



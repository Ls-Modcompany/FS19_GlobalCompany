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
local debugIndex = g_debug.registerMod("GlobalCompany-GC_languageManager");

GC_languageManager = {};
g_company.languageManager = GC_languageManager;

function GC_languageManager:load()	
	for modName, data in pairs(g_company.environments) do		
		local currentPath = string.format("%s%s/", g_modsDirectory, modName);
				
		local fullPath = string.format("%sl10n%s.xml", currentPath, g_languageSuffix);
		if not fileExists(fullPath) then
			fullPath = string.format("%slanguages/l10n%s.xml", currentPath, g_languageSuffix);
			print(fullPath)
			if not fileExists(fullPath) then
				fullPath = nil;
			end;
		end;		
		
		if fullPath ~= nil then
			local fullPath = string.format("%sl10n_en.xml", currentPath);
			if not fileExists(fullPath) then
				fullPath = string.format("%slanguages/l10n_en.xml", currentPath);
				print(fullPath)
				if not fileExists(fullPath) then
					fullPath = nil;
				end;
			end;	
		end;

		if fullPath ~= nil then
			local langXml = loadXMLFile("TempConfig", fullPath);
			g_i18n:loadEntriesFromXML(langXml, "l10n.elements.e(%d)", "Warning: Duplicate text in l10n %s",  g_i18n.texts);
		end;
	end;
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



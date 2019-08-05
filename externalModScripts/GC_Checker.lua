--
-- GC_Checker
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 24.04.2019
-- @Version: 1.1.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
-- 	v1.1.0.0 (24.04.2019):
-- 		- remove 'modEventListener' as in FS19 this is now a problem if more than one script in a mod is using it.
--		- This is done to support 'addonScripts' if needed.
--
--
-- 	v1.0.0.0 (07.03.2019):
-- 		- initial fs19 ()
--		- 'de' warning translation (aPuehri)
--
-- Notes:
--		- This script is added to individual mods or maps.
--		- If 'Global Company' is not loaded with game than a message will be displayed when game is started.
--
--		- English and German messages are hard coded by standard.
--		- New message languages can be added in each mod or maps modDesc l10n entries using [ GC_globalCompanyMissing ].
--		- NOTE: Correct formatting must be used for new messages to work without error.
--
-- ToDo:
--
--

GC_Checker = {}

function GC_Checker:init()
	if g_globalCompanyChecker == nil then
		GC_Checker.modsToCheck = {}
		GC_Checker.errorsToShow = {}		
		GC_Checker.startUpdateTime = 2000

		Mission00.onStartMission = Utils.appendedFunction(Mission00.onStartMission, GC_Checker.onStartMission);

		getfenv(0)["g_globalCompanyChecker"] = GC_Checker
	end
	
	g_globalCompanyChecker:addModToList(g_currentModName)
end

function GC_Checker:addModToList(modName)
	if g_globalCompanyChecker.modsToCheck[modName] == nil then
		g_globalCompanyChecker.modsToCheck[modName] = GC_Checker.getWarningText(g_languageShort)
	end
end

function GC_Checker:onStartMission()
	if g_company == nil then	
		local needUpdateable = false;
		
		for modName, warningText in pairs (g_globalCompanyChecker.modsToCheck) do
			local mod = g_modManager:getModByName(modName)
			local xmlFile = loadXMLFile("TempModDesc", mod.modFile)
			if xmlFile ~= nil and xmlFile ~= 0 then
				local versionString = getXMLString(xmlFile, "modDesc.globalCompany#minimumVersion")
				if versionString ~= nil then					
					needUpdateable = true;
					local data = {}
					data.modData = mod
					data.showWarning = true
					data.versionString = versionString
					data.okButtonText = g_i18n:getText("button_ok")
					data.downloadButtonText = g_i18n:getText("button_modHubDownload")
					data.warningText = warningText
					
					table.insert(g_globalCompanyChecker.errorsToShow, data)
				else
					g_logManager:error("Required version number was not given at 'modDesc.globalCompany#minimumVersion' in modDesc ( %s )!", mod.modFile)
				end
			
				delete(xmlFile)
			end
		end
		
		if needUpdateable then
			g_currentMission:addUpdateable(g_globalCompanyChecker);
		end;
	else	
		g_globalCompanyChecker:delete()
	end
end

function GC_Checker:delete()
	if g_globalCompanyChecker ~= nil then
		g_currentMission:removeUpdateable(g_globalCompanyChecker)
		getfenv(0)["g_globalCompanyChecker"] = nil;
	end;
end

function GC_Checker:update(dt)
	if g_globalCompanyChecker ~= nil then
		if g_globalCompanyChecker.startUpdateTime > 0 then		
			g_globalCompanyChecker.startUpdateTime = g_globalCompanyChecker.startUpdateTime - dt
		else
			for i = 1, #g_globalCompanyChecker.errorsToShow do
				local mod = g_globalCompanyChecker.errorsToShow[i]					
				if mod ~= nil and not g_gui:getIsGuiVisible() then
					if mod.showWarning then	
						mod.showWarning = false
						g_globalCompanyChecker:showModWarningGUI(mod)
					else
						g_globalCompanyChecker.errorsToShow[i] = nil
					end
				end
			end
			
			if next(g_globalCompanyChecker.errorsToShow) == nil then
				g_globalCompanyChecker:delete()
			end
		end
	end
end

function GC_Checker:showModWarningGUI(mod)
	local title = string.format("%s - %s", mod.modData.title, mod.modData.version)

	local url = " www.ls-modcompany.com "
	if g_languageShort == "de" then
		url = " www.ls-modcompany.de "
	end

	local text = string.format(mod.warningText, mod.versionString, url)

	g_gui:showYesNoDialog({
		title = title,
		text = text,
		dialogType = DialogElement.TYPE_WARNING,
		callback = g_globalCompanyChecker.openModHubLink,
		target = g_globalCompanyChecker,
		yesText = mod.okButtonText,
		noText = mod.downloadButtonText
	})
end

function GC_Checker:openModHubLink(isYes)
	if isYes == false then
		local language = g_languageShort
		local link = "mods.php?lang=en&title=fs2019&filter=org&org_id=65115&page=0#"
		if language == "de" or language == "fr" then
			link = "mods.php?lang=" .. language .. "&title=fs2019&filter=org&org_id=65115&page=0#"
		end

		openWebFile(link, "")
	else
		g_gui:showGui("")
	end
end

-- Do not add or change texts here. Each mod loads its own text in other languages if needed from the 'l10n' entries.
-- Any changes here will / can  break other 'Global Company' mods when loading!!!!!
function GC_Checker.getWarningText(language)
	local warnings = {
		["en"] = "Global Company Version %s or greater is required for this mod / map to operate. Please visit modHub download link for the latest official version or visit '%s' for Global Company support.",
		["de"] = "Für die Verwendung dieses Mods / dieser Map ist Global Company Version %s oder höher erforderlich. Bitte im ModHub die aktuelle offizielle Version downloaden, oder besuche '%s' für den Global Company Support."
	}

	if warnings[language] ~= nil then
		return warnings[language]
	else
		if g_i18n:hasText("GC_globalCompanyMissing") then
			return g_i18n:getText("GC_globalCompanyMissing")
		else
			return warnings["en"]
		end
	end
end

GC_Checker:init()






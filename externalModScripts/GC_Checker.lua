--
-- GC_Checker
--
-- @Interface: --
-- @Author: LS-Modcompany
-- @Date: 07.03.2018
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 ():
-- 		- initial fs19 (GtX)
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


GC_Checker = {};
GC_Checker.modName = g_currentModName;

addModEventListener(GC_Checker);

function GC_Checker:loadMap(i3dFilePath)
	self.showWarning = false;
	self.startUpdateTime = 2000;
	self.hasModEventListener = true;

	if g_company ~= nil then
		self:delete();
	else
		local mod = g_modManager:getModByName(GC_Checker.modName);
		local xmlFile = loadXMLFile("TempModDesc", mod.modFile);
		local versionString = getXMLString(xmlFile, "modDesc.globalCompany#minimumVersion");
		if versionString ~= nil then
			self.modData = mod;
			self.showWarning = true;
			self.versionString = versionString;
			self.okButtonText = g_i18n:getText("button_ok");
			self.downloadButtonText = g_i18n:getText("button_modHubDownload");
			self.warningText = self:getWarningText(g_languageShort);
		else
			g_logManager:error("Required version number was not given at 'modDesc.globalCompany#minimumVersion' in modDesc ( %s )!", mod.modFile);
			self:delete();
		end;

		delete(xmlFile);
	end;
end;

function GC_Checker:delete()
	if self.hasModEventListener then
		self.hasModEventListener = false;
		removeModEventListener(self);
	end;
end;

function GC_Checker:update(dt)
	if self.startUpdateTime > 0 then
		self.startUpdateTime = self.startUpdateTime - dt;
	else
		if self.showWarning and not g_gui:getIsGuiVisible() then
			self.showWarning = false;
			self:showModWarningGUI();
		end;
	end;
end;

function GC_Checker:showModWarningGUI()
	local title = string.format("%s - %s", self.modData.title, self.modData.version);

	local url = " www.ls-modcompany.com ";
	if g_languageShort == "de" then
		url = " www.ls-modcompany.de ";
	end;

	local text = string.format(self.warningText, self.versionString, url);

	g_gui:showYesNoDialog({title = title,
						   text = text,
						   dialogType = DialogElement.TYPE_WARNING,
						   callback = self.openModHubLink,
						   target = self,
						   yesText = self.okButtonText,
						   noText = self.downloadButtonText});
end;

function GC_Checker:openModHubLink(isYes)
	if isYes == false then
		local language = g_languageShort;
		local link = "mods.php?lang=en&title=fs2019&filter=org&org_id=65115&page=0#";
		if language == "de" or language == "fr" then
			link = "mods.php?lang=" .. language .. "&title=fs2019&filter=org&org_id=65115&page=0#";
		end;

		openWebFile(link, "");
	else
		g_gui:showGui("");
	end;

	self:delete();
end;

function GC_Checker:getWarningText(language)
	local warnings = {["en"] = "Global Company Version %s or greater is required for this mod / map to operate. Please visit modHub download link for the latest official version or visit '%s' for Global Company support.",
					  ["de"] = "Für die Verwendung dieses Mods / dieser Map ist Global Company Version %s oder höher erforderlich. Bitte im ModHub die aktuelle offizielle Version downloaden, oder besuche '%s' für den Global Company Support."};

	if warnings[language] ~= nil then
		return warnings[language];
	else
		if g_i18n:hasText("GC_globalCompanyMissing") then
			return g_i18n:getText("GC_globalCompanyMissing");
		else
			return warnings["en"];
		end;
	end;
end;
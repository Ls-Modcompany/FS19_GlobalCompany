--
-- GlobalCompany - Utils - GC_ModManager
--
-- @Interface: --
-- @Author: LS-Modcompany / GtX
-- @Date: 05.03.2018
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 ():
-- 		- initial fs19 (GtX)
--
-- Notes:
--
--
-- ToDo:
--
--

GC_ModManager = {};
local GC_ModManager_mt = Class(GC_ModManager);

GC_ModManager.debugIndex = g_company.debug:registerScriptName("ModManager");

function GC_ModManager:new()
	if g_company.modManager ~= nil then
		g_company.debug:print("  [LSMC - GlobalCompany > GC_ModManager] - Class already registered! Use 'g_company.modManager' to access mod manager.");
		return;
	end;

	local self = {};
	setmetatable(self, GC_ModManager_mt);

	self.isServer = g_server ~= nil;
	self.isClient = g_client ~= nil;

	self:initInvalidMods();

	self.startUpdateTime = 2000; -- Wait 2 sec to show any messages.

	self.canShowDevelopmentGUI = false;

	self.modVersionErrors = nil;
	self.numModVersionErrors = 0;

	self.modInvalidErrors = nil;
	self.numInvalidModsErrors = 0;

	self.modVersionCheck = false;
	self.updateableLoaded = false;

	local languageManager = g_company.languageManager;
	local titleText = string.format("GLOBAL COMPANY - VERSION %s", g_company.version);
	self.texts = {["guiTitle"] = titleText,
				  ["mapWarning"] = languageManager:getText("GC_mapVersionWarning"),
				  ["modWarning"] = languageManager:getText("GC_modVersionWarning"),
				  ["loadingError"] = languageManager:getText("GC_loadingError"),
				  ["duplicateError"] = languageManager:getText("GC_duplicateError"),
				  ["combinedError"] = languageManager:getText("GC_combinedError"),
				  ["namingError"] = languageManager:getText("GC_namingError"),
				  ["modHubLink"] = languageManager:getText("GC_gui_modHubLink"),
				  ["okButton"] = languageManager:getText("GC_gui_buttons_ok"),
				  ["invalidModWarning"] = languageManager:getText("GC_invalidModWarning"),
				  ["quitToMainMenu"] = languageManager:getText("GC_quitToMainMenu"),
				  ["nextWarning"] = languageManager:getText("GC_gui_buttons_nextWarning"),
				  ["nextConflict"] = languageManager:getText("GC_gui_buttons_nextConflict"),
				  ["betaVersionWarning"] = languageManager:getText("GC_betaVersionWarning"),
				  ["cancelGame"] = languageManager:getText("button_cancelGame")};

	self.debugData = g_company.debug:getDebugData(GC_ModManager.debugIndex, g_company);

	return self;
end;

function GC_ModManager:checkActiveModVersions()
	if self.isClient then
		self.modVersionCheck = true;

		local activeMods = g_modManager:getActiveMods();
		for i = 1, #activeMods do
			local mod = activeMods[i];

			-- Do not check GlobalCompany Mod. ;-)
			if mod.modName ~= "FS19_GlobalCompany" and mod.modName ~= "FS19_GlobalCompany_update" then
				local xmlFile = loadXMLFile("TempModDesc", mod.modFile);

				local versionString = getXMLString(xmlFile, "modDesc.globalCompany#minimumVersion");
				if versionString ~= nil then
					local modVersionId = self:getVersionId(versionString);
					if modVersionId ~= nil and modVersionId ~= "" then
						if modVersionId > self:getCurrentVersionId() then
							if self.modVersionErrors == nil then
								self.modVersionErrors = {};
								self:doAddUpdateable(true);
							end;

							local isModMap = g_modManager:isModMap(mod.modName);
							self.modVersionErrors[mod.modName] = {versionString = versionString, author = mod.author, isModMap = isModMap};
							self.numModVersionErrors = self.numModVersionErrors + 1;
						end;
					else
						g_company.debug:writeModding(self.debugData, "%s is not a valid version number at 'modDesc.globalCompany#minimumVersion' in modDesc %s!", versionString, mod.modFile);
					end;
				end;

				if self.invalidMods[mod.modName] or self.invalidMods[mod.title] then
					if self.modInvalidErrors == nil then
						self.modInvalidErrors = {};
						self:doAddUpdateable(true);
					end;

					self.modInvalidErrors[mod.modName] = {author = mod.author};
					self.numInvalidModsErrors = self.numInvalidModsErrors + 1;
				end;

				delete(xmlFile);
			end;
		end;
	end;
end;

function GC_ModManager:delete()
	if self.isClient then
		if self.updateableLoaded == true then
			self.updateableLoaded = false;
			g_company.removeUpdateable(self);

			self.modVersionErrors = nil;
			self.numModVersionErrors = 0;
		end;
	end;
end;

function GC_ModManager:update(dt)
	if self.startUpdateTime > 0 then
		self.startUpdateTime = self.startUpdateTime - dt;
	else
		-- Show Development / GitHub warning.
		if self.canShowDevelopmentGUI then
			self.canShowDevelopmentGUI = false;
			self:showDevelopmentGUI();
		else
			-- Check for invalid mods first.
			if self.modInvalidErrors ~= nil then
				for modName, data in pairs(self.modInvalidErrors) do
					if not g_gui:getIsGuiVisible() then
						self:showModConflictWarningGui(modName, data.author);
						self.modInvalidErrors[modName] = nil;
						self.numInvalidModsErrors = self.numInvalidModsErrors - 1;
					end;
				end;
			end;

			-- Check now for version errors.
			if self.numInvalidModsErrors <= 0 and self.modVersionErrors ~= nil then
				for modName, data in pairs (self.modVersionErrors) do
					if not g_gui:getIsGuiVisible() then
						self:showModWarningGUI(modName, data.versionString, data.author, data.isModMap);
						self.modVersionErrors[modName] = nil;
						self.numModVersionErrors = self.numModVersionErrors - 1;
					end;
				end;
			end;

			if self:getCanDelete() then
				self:delete(); -- Remove update listener and save resources as we do not need it anymore.
			end;
		end;
	end;
end;

function GC_ModManager:getCanDelete()
	if self.canShowDevelopmentGUI then
		return false;
	elseif self.modInvalidErrors ~= nil and self.numInvalidModsErrors > 0 then
		return false;
	elseif self.modVersionErrors ~= nil and self.numModVersionErrors > 0 then
		return false;
	end;

	return true;
end;

function GC_ModManager:showDevelopmentGUI()
	local url = " www.ls-modcompany.com ";
	if g_languageShort == "de" then
		url = " www.ls-modcompany.de ";
	end;

	local errorReportLink = " -- "; -- We need the public gitHub link or release link here.
	local text = string.format(self.texts.betaVersionWarning, errorReportLink, url);

	g_gui:showYesNoDialog({title = self.texts.guiTitle,
						   text = text,
						   dialogType = DialogElement.TYPE_INFO,
						   callback = self.openModHubLink,
						   target = self,
						   yesText = self.texts.okButton,
						   noText = self.texts.modHubLink});
end;

function GC_ModManager:showModWarningGUI(modName, version, author, isModMap)
	local url = " www.ls-modcompany.com ";
	if g_languageShort == "de" then
		url = " www.ls-modcompany.de ";
	end;

	local text = string.format(self.texts.modWarning, modName, author, version, url);
	if isModMap then
		text = string.format(self.texts.mapWarning, modName, author, version, url);
	end;

	local okButton = self.texts.okButton;
	if self.numModVersionErrors > 1 then
		okButton = self.texts.nextWarning;
	end;

	g_gui:showYesNoDialog({title = self.texts.guiTitle,
						   text = text,
						   dialogType = DialogElement.TYPE_WARNING,
						   callback = self.openModHubLink,
						   target = self,
						   yesText = okButton,
						   noText = self.texts.modHubLink});
end;

function GC_ModManager:showModConflictWarningGui(modName, author)
	local text = string.format(self.texts.invalidModWarning, modName, author);
	local okButton = self.texts.okButton;
	if self.numInvalidModsErrors > 1 then
		okButton = self.texts.nextConflict;
	end;

	g_gui:showYesNoDialog({title = self.texts.guiTitle,
						   text = text,
						   dialogType = DialogElement.TYPE_WARNING,
						   callback = self.invalidModChoiceCallback,
						   target = self,
						   yesText = okButton,
						   noText = self.texts.cancelGame});
end;

function GC_ModManager:showLoadWarningGUI(strg, warningType)
	local url = " www.ls-modcompany.com ";
	if g_languageShort == "de" then
		url = " www.ls-modcompany.de ";
	end;

	local text = "";
	if warningType == "standardError" then
		text = string.format(self.texts.loadingError, url);
	elseif warningType == "duplicateError" then
		text = string.format(self.texts.duplicateError, strg);
	elseif warningType == "combinedError" then
		text = string.format(self.texts.combinedError, strg, url);
	elseif warningType == "namingError" then
		text = string.format(self.texts.namingError, strg, url);
	end;

	if self.isClient then
		g_gui:closeAllDialogs(); -- Make sure we are on top when opened.
		g_gui:showYesNoDialog({title = self.texts.guiTitle,
							text = text,
							dialogType = DialogElement.TYPE_LOADING,
							callback = self.openModHubLink,
							target = self,
							yesText = self.texts.okButton,
							noText = self.texts.modHubLink});
	else
		g_company.debug:print(title .. "  " .. text); -- Only print a log error to the server.
	end;
end;

function GC_ModManager:invalidModChoiceCallback(continue)
	if continue == false then
		g_gui:showYesNoDialog({text = self.texts.quitToMainMenu, callback = self.leaveToMenuCallback, target = self});
	else
		g_gui:showGui("");
	end;
end;

function GC_ModManager:leaveToMenuCallback(isYes)
	if isYes then
		-- Using 'OnInGameMenuMenu()' is no good, this does not reset variables that are only generated on initial game load.
		-- As 'g_inGameMenu' has been removed in FS19 and Giants do not share 3/4 of the game scripts this is a work around. Needs MP testing. ;-)
		local inGameMenuTarget = g_gui.guis["InGameMenu"].target;
		InGameMenu.onYesNoEnd(inGameMenuTarget, isYes);
	else
		g_gui:showGui("");
	end;
end;

function GC_ModManager:openModHubLink(isYes)
	if isYes == false then
		local language = g_languageShort;
		local link = "mods.php?lang=en&title=fs2019&filter=org&org_id=65115&page=0#";
		if language == "de" or language == "fr" then
			link = "mods.php?lang=" .. language .. "&title=fs2019&filter=org&org_id=65115&page=0#";
		end;

		openWebFile(link, ""); -- Take user to LS-Modcompany modHub page.
	else
		if self.modVersionCheck then
			g_gui:showGui(""); -- Make sure gui is closed in-case we have more warnings.
		end;
	end;
end;

function GC_ModManager:doLoadCheck(strg, duplicateLoad, isDevVersion)
	if duplicateLoad == false then
		local check, strgL = {["FS19_GlobalCompany"] = 18, ["FS19_GlobalCompany_update"] = 25}, strg:len();
		if check[strg] ~= nil and check[strg] == strgL then
			--if string.len(g_modManager:getModByName(strg).author) == 0 then
				return true;
			--else
				--self:showLoadWarningGUI(strg, "standardError");
			--end;
		else
			if g_modManager:isModMap(strg) then
				self:showLoadWarningGUI(strg, "combinedError");
			else
				if isDevVersion then
					-- Make sure name is 'FS19_GlobalCompany' when using GitHub release so we have no issues with release version.
					self:showLoadWarningGUI(strg, "namingError");
				else
					self:showLoadWarningGUI(strg, "standardError");
				end;
			end;
		end;
	else
		self:showLoadWarningGUI(strg, "duplicateError");
	end;

	return false;
end;

function GC_ModManager:initDevelopmentWarning(isDevVersion)
	if g_company.debug.isDev == false then
		self.canShowDevelopmentGUI = isDevVersion;
		self:doAddUpdateable(isDevVersion);
	end;
end;

function GC_ModManager:doAddUpdateable(add)
	if add and not self.updateableLoaded then
		self.updateableLoaded = true;
		g_company.addUpdateable(self, self.update);
	end;
end;

function GC_ModManager:getVersionId(versionString)
	local versionId = "";

	local length = versionString:len();
	if length > 6 then
		local position, periodCount = 1, 0;

		for i = 1, length do
			local stringStart, stringEnd = versionString:find(".", position, true);
			if stringStart == nil then
				versionId = versionId .. versionString:sub(position);
				break;
			end;

			versionId = versionId .. versionString:sub(position, stringStart - 1);
			position = stringEnd + 1;
			periodCount = periodCount + 1;
		end;

		if periodCount == 3 then -- Only accept correct version format, 3 decimals. e.g (1.0.0.0 or 1.0.10.4)
			return tonumber(versionId); -- Letters will not be accepted and will result in a 'nil' value.
		end;
	end;

	return nil;
end;

function GC_ModManager:getCurrentVersionId()
	return g_company.currentVersionId;
end;

function GC_ModManager:initInvalidMods()
	self.invalidMods = {};
	self.invalidMods["PlaceAnywhere"] = true;
end;






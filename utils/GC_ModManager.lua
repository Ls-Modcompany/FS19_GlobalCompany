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
		print("  [LSMC - GlobalCompany > GC_ModManager] - Class already registered! Use 'g_company.modManager' to access mod manager.");
		return;
	end;

	local self = {};
	setmetatable(self, GC_ModManager_mt);

	self.isServer = g_server ~= nil;
	self.isClient = g_client ~= nil;

	self.modVersionErrors = nil;
	self.numModVersionErrors = 0;
	self.modVersionCheck = false;

	self.modInvalidErrors = nil;
	self.numInvalidModsErrors = 0;

	self.updateableLoaded = false;

	local languageManager = g_company.languageManager;
	self.mapWarningText = languageManager:getText("GC_mapVersionWarning");
	self.modWarningText = languageManager:getText("GC_modVersionWarning");
	self.loadingErrorText = languageManager:getText("GC_loadingError");
	self.duplicateErrorText = languageManager:getText("GC_duplicateError");
	self.combinedErrorText = languageManager:getText("GC_combinedError");
	self.modHubLinkText = languageManager:getText("GC_gui_modHubLink");
	self.okButtonText = languageManager:getText("GC_gui_buttons_ok");
	self.invalidModWarning = languageManager:getText("GC_invalidModWarning");

	self.debugData = g_company.debug:getDebugData(GC_ModManager.debugIndex, g_company);

	self:initInvalidMods();

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

								if self.updateableLoaded ~= true then
									self.updateableLoaded = true;
									g_company.addUpdateable(self, self.update);
								end;
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

						if self.updateableLoaded ~= true then
							self.updateableLoaded = true;
							g_company.addUpdateable(self, self.update);
						end;
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
	-- Check for invalid mods first.
	if self.modInvalidErrors ~= nil then
		for modName, data in pairs(self.modInvalidErrors) do
			if not g_gui:getIsGuiVisible() then
				self:showInvalidModWarningGui(modName, data.author);
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

	if (self.modVersionErrors == nil or self.numModVersionErrors <= 0) and (self.modInvalidErrors == nil or self.numInvalidModsErrors <= 0) then
		self:delete(); -- Remove update listener and save resources as we do not need it anymore.
	end;
end;

function GC_ModManager:showModWarningGUI(modName, version, author, isModMap)
	local title = string.format("GLOBAL COMPANY - VERSION %s", g_company.version);

	local url = " www.ls-modcompany.com ";
	if g_languageShort == "de" then
		url = " www.ls-modcompany.de ";
	end;

	local text = string.format(self.modWarningText, modName, author, version, url);
	if isModMap then
		text = string.format(self.mapWarningText, modName, author, version, url);
	end;

	g_gui:showYesNoDialog({title = title,
						   text = text,
						   dialogType = DialogElement.TYPE_WARNING,
						   callback = self.openModHubLink,
						   target = self,
						   yesText = self.okButtonText,
						   noText = self.modHubLinkText});
end;

function GC_ModManager:showInvalidModWarningGui(modName, author)
	local title = string.format("GLOBAL COMPANY - VERSION %s", g_company.version);
	local text = string.format(self.invalidModWarning, modName, author);

	local dialog = g_gui:showDialog("YesNoDialog");
	if dialog ~= nil then
		dialog.target:setText(text);
		dialog.target:setTitle(title);
		dialog.target:setDialogType(DialogElement.TYPE_WARNING);
		dialog.target:setCallback(self.invalidModChoiceCallback, self)
		dialog.target:setButtonTexts(self.okButtonText, g_i18n:getText("button_cancelGame"));

		-- Only this in SP or on hosting PC (server) only.
		if self.isServer == false then
			dialog.target.noButton:setDisabled(true);
		end;

		-- Option 2:
		-- Hide button and do not use 'self.invalidModChoiceCallback'?

		--dialog.target.noButton:setDisabled(true);
		--dialog.target.noButton:setVisible(false);
	end;
end;

function GC_ModManager:invalidModChoiceCallback(continue)
	if continue == false then
		InGameMenu:leaveCurrentGame(); -- Quit to main menu.
	else
		g_gui:showGui(""); -- Make sure gui is closed in-case we have more warnings.
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

function GC_ModManager:doLoadCheck(strg, duplicateLoad)
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
				self:showLoadWarningGUI(strg, "standardError");
			end;
		end;
	else
		self:showLoadWarningGUI(strg, "duplicateError");
	end;

	return false;
end;

function GC_ModManager:showLoadWarningGUI(strg, warningType)
	local title = string.format("GLOBAL COMPANY - VERSION %s", g_company.version);

	local url = " www.ls-modcompany.com ";
	if g_languageShort == "de" then
		url = " www.ls-modcompany.de ";
	end;

	local text = "";
	if warningType == "standardError" then
		text = string.format(self.loadingErrorText, url);
	elseif warningType == "duplicateError" then
		text = string.format(self.duplicateErrorText, strg);
	elseif warningType == "combinedError" then
		text = string.format(self.combinedErrorText, strg, url);
	end;

	if self.isClient then
		g_gui:showYesNoDialog({title = title,
							text = text,
							dialogType = DialogElement.TYPE_LOADING,
							callback = self.openModHubLink,
							target = self,
							yesText = self.okButtonText,
							noText = self.modHubLinkText});
	else
		print(title .. "  " .. text); -- Only print a log error to the server.
	end;
end;

function GC_ModManager:getVersionId(versionString) -- This is faster then old function.
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






--
-- GlobalCompany
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98 / GtX
-- @Date: 11.05.2018
-- @Version: 1.1.1.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (11.05.2018):
--
--
-- Notes:
--
--
-- ToDo:
--		- 'loadParameters' only for one environment! this is not good (kevink98)
--		- convert all scripts to use 'GC_DebugUtils' (kevink98 / GtX)
--
--

GlobalCompany = {};
GlobalCompany.dir = g_currentModDirectory;

GlobalCompany.version = "1.0.0.0"; -- Release Version.
GlobalCompany.versionDate = "04.05.2018"; -- Release Date ??
GlobalCompany.currentVersionId = 1000; -- Mod Manager ID. (Version number without periods.)
GlobalCompany.isDevelopmentVersion = true; -- This is for versions loaded from GIT. 

GlobalCompany.LOADTYP_XMLFILENAME = 1;

function GlobalCompany.initialLoad()
	if GlobalCompany.initialLoadComplete ~= nil then
		print("  [LSMC - GlobalCompany] - ERROR: 'initialLoad' failed! This function is only called on initial load.")
		return;
	end;

	-- Protect from duplicate loading.
	-- Load these critical source files first in case we fail.
	local duplicateLoad = false;
	if g_company == nil then
		getfenv(0)["g_company"] = GlobalCompany;	

		--| Load Utils |--
		source(GlobalCompany.dir .. "utils/GC_utils.lua");

		--| Load Debug |--
		source(GlobalCompany.dir .. "utils/GC_DebugUtils.lua");
		g_company.debug = GC_DebugUtils:new();
		GlobalCompany.debugIndex = g_company.debug:registerScriptName("GlobalCompany");

		--| Load Language Manager |--
		source(GlobalCompany.dir .. "utils/GC_languageManager.lua");
		g_company.languageManager:load(GlobalCompany.dir); -- We need to load Global Company texts first for 'modManager' to use.

		--| Load Mod Manager |--
		source(GlobalCompany.dir .. "utils/GC_ModManager.lua");
		g_company.modManager = GC_ModManager:new();
		
		--| Load Event Manager |--
		source(GlobalCompany.dir .. "utils/GC_EventManager.lua");		
		g_company.eventManager = GC_EventManager:new();		
	else
		duplicateLoad = true;
	end;

	-- Can we load?
	if g_company.modManager:doLoadCheck(g_currentModName, duplicateLoad, GlobalCompany.isDevelopmentVersion) then
		g_company.debug:singleLogWrite(GlobalCompany.debugIndex, GC_DebugUtils.BLANK, "Loading Version: %s (%s)", GlobalCompany.version, GlobalCompany.versionDate);
		addModEventListener(GlobalCompany);

		Mission00.onStartMission = Utils.appendedFunction(Mission00.onStartMission, GlobalCompany.init);

		GlobalCompany.inits = {};
		GlobalCompany.loadables = {};
		GlobalCompany.updateables = {};
		GlobalCompany.raisedUpdateables = {};
		GlobalCompany.environments = {};
		GlobalCompany.loadParameters = {};
		GlobalCompany.loadParametersToEnvironment = {};
		
		g_company.modManager:initDevelopmentWarning(GlobalCompany.isDevelopmentVersion);

		GlobalCompany.loadSourceFiles();
		GlobalCompany.loadPlaceables();

		local modLanguageFiles = {};

		local selectedMods = {};
		if g_server == nil then			
			selectedMods = g_mpLoadingScreen.missionDynamicInfo.mods;
		else
			selectedMods = g_modSelectionScreen.missionDynamicInfo.mods;
		end;

		for _, mod in pairs(selectedMods) do
			local path;
			local modName = mod.modName;

			if mod.modDir ~= nil then
				path = mod.modDir .. "globalCompany.xml";
				if not fileExists(path) then
					path = mod.modDir .. "xml/globalCompany.xml";
					if not fileExists(path) then
						path = nil;
					end;
				end;

				-- Ignore Global Company language files.
				if modName ~= g_currentModName then
					local langFullPath = g_company.languageManager:getLanguagesFullPath(mod.modDir);
					if langFullPath ~= nil then					
						--if g_company.languageManager:checkEnglishBackupExists(langFullPath, modName) then
							modLanguageFiles[modName] = langFullPath;
						--end;
					end;
				end;
			end;

			if path ~= nil then
				local xmlFile = loadXMLFile("globalCompany", path);

				GlobalCompany.environments[modName] = {};
				GlobalCompany.environments[modName].fullPath = path;
				GlobalCompany.environments[modName].xmlFile = xmlFile;
				GlobalCompany.environments[modName].specializations = getXMLString(xmlFile, "globalCompany.specializations#xmlFilename");
				GlobalCompany.environments[modName].shopManager = getXMLString(xmlFile, "globalCompany.shopManager#xmlFilename");
				GlobalCompany.environments[modName].densityMapHeight = getXMLString(xmlFile, "globalCompany.densityMapHeight#xmlFilename");
				GlobalCompany.environments[modName].densityMapHeightOverwriteOrginalFunction = getXMLBool(xmlFile, "globalCompany.densityMapHeight#overwriteOrginalFunction");
			end;
		end;

		for modName, values in pairs(GlobalCompany.environments) do
			if values.shopManager ~= nil and values.shopManager ~= "" then
				g_company.shopManager:loadFromXML(modName, g_company.utils.createModPath(modName, values.shopManager));
			end;
			
			if values.specializations ~= nil and values.specializations ~= "" then
				g_company.specializations:loadFromXML(modName, g_company.utils.createModPath(modName, values.specializations));
			end;
			
			if values.densityMapHeightOverwriteOrginalFunction then
				g_densityMapHeightManager.loadMapData = function() return true; end;
			end;
		end;

		g_company.languageManager:loadModLanguageFiles(modLanguageFiles);
	else
		getfenv(0)["g_company"] = nil; -- Clear if there is an error loading or a duplicate.
	end;

	GlobalCompany.initialLoadComplete = true;
end;

--|| Init ||--
function GlobalCompany.addInit(target, init)
	table.insert(GlobalCompany.inits, {init=init, target=target});
end;

--|| Load ||--
function GlobalCompany.addLoadable(target, loadF)
	table.insert(GlobalCompany.loadables, {loadF=loadF, target=target});
end;

--|| Raised Updateables ||--
function GlobalCompany.addRaisedUpdateable(target, raiseOnFirstRun)
	if target.update ~= nil then
		target.updateableCanUpdate = raiseOnFirstRun == true; -- If 'raiseOnFirstRun' then set update loop to do a single pass when first loaded.

		if target.raiseUpdate == nil then
			target.raiseUpdate = function() target.updateableCanUpdate = true; end; -- Add 'raiseUpdate' function if 'nil' in target.
		end;

		GlobalCompany.raisedUpdateables[target] = target;
	else
		local debugName = g_company.debug:getScriptNameFromIndex(target.debugIndex);
		print(string.format("  [LSMC - GlobalCompany > %s] - ERROR: 'addRaisedUpdateable' failed, function 'update(dt)' could not be found.", debugName));
	end;
end;

function GlobalCompany.removeRaisedUpdateable(target)
	if GlobalCompany.raisedUpdateables[target] ~= nil then
		target.updateableCanUpdate = false;
		GlobalCompany.raisedUpdateables[target] = nil;
	end;
end;

--|| Updateables ||--
function GlobalCompany.addUpdateable(target, update)
	table.insert(GlobalCompany.updateables, {update=update, target=target});
end;

function GlobalCompany.removeUpdateable(target, update)
	for key, u in pairs(GlobalCompany.updateables) do
		if u.target == target then
			table.remove(GlobalCompany.updateables, key);
			break;
		end;
	end;
end;

--|| Parameters ||--
function GlobalCompany.addLoadParameter(name, key, typ)
	GlobalCompany.loadParameters[name] = {key=key, typ=typ, value=nil, environment=nil};
end;

--| Load Source Files |--
function GlobalCompany.loadSourceFiles()
	if GlobalCompany.initialLoadComplete ~= nil then
		return;
	end;

	--|| Settings ||--
	source(GlobalCompany.dir .. "GlobalCompanySettings.lua");

	--|| Utils / Managers ||--
	source(GlobalCompany.dir .. "utils/GC_mathUtils.lua");
	source(GlobalCompany.dir .. "utils/GC_xmlUtils.lua");
	source(GlobalCompany.dir .. "utils/GC_i3dLoader.lua");
	source(GlobalCompany.dir .. "utils/GC_cameraUtil.lua");
	source(GlobalCompany.dir .. "utils/GC_shopManager.lua");
	source(GlobalCompany.dir .. "utils/GC_TriggerManager.lua");
	source(GlobalCompany.dir .. "utils/GC_specializations.lua");
	source(GlobalCompany.dir .. "utils/GC_densityMapHeight.lua");

	--|| Gui ||--
	source(GlobalCompany.dir .. "GlobalCompanyGui.lua");

	--|| Objects ||--
	source(GlobalCompany.dir .. "objects/GC_Clock.lua");
	source(GlobalCompany.dir .. "objects/GC_Sounds.lua");
	source(GlobalCompany.dir .. "objects/GC_Movers.lua");
	source(GlobalCompany.dir .. "objects/GC_Shaders.lua");
	source(GlobalCompany.dir .. "objects/GC_Effects.lua");
	source(GlobalCompany.dir .. "objects/GC_Lighting.lua");
	source(GlobalCompany.dir .. "objects/GC_Conveyor.lua");
	source(GlobalCompany.dir .. "objects/GC_MovingPart.lua");
	source(GlobalCompany.dir .. "objects/GC_Animations.lua");
	source(GlobalCompany.dir .. "objects/GC_FillVolume.lua");
	source(GlobalCompany.dir .. "objects/GC_DynamicHeap.lua");
	source(GlobalCompany.dir .. "objects/GC_PalletCreator.lua");
	source(GlobalCompany.dir .. "objects/GC_RotationNodes.lua");
	source(GlobalCompany.dir .. "objects/GC_ConveyorEffekt.lua");
	source(GlobalCompany.dir .. "objects/GC_DigitalDisplays.lua");
	source(GlobalCompany.dir .. "objects/GC_ActivableObject.lua");
	source(GlobalCompany.dir .. "objects/GC_VisibilityNodes.lua");
	source(GlobalCompany.dir .. "objects/GC_ProductionFactory.lua");
	--source(GlobalCompany.dir .. "objects/GC_DynamicPalletAreas.lua");
	source(GlobalCompany.dir .. "objects/GC_BaleShreader.lua");
	source(GlobalCompany.dir .. "objects/GC_DirtyObjects.lua");
	source(GlobalCompany.dir .. "objects/GC_Baler.lua");

	--|| Triggers ||--
	source(GlobalCompany.dir .. "triggers/GC_WoodTrigger.lua");
	source(GlobalCompany.dir .. "triggers/GC_PlayerTrigger.lua");
	source(GlobalCompany.dir .. "triggers/GC_UnloadingTrigger.lua");
	source(GlobalCompany.dir .. "triggers/GC_BaleTrigger.lua");

	--|| Placeables ||--
	source(GlobalCompany.dir .. "placeables/GC_ProductionFactoryPlaceable.lua");
	source(GlobalCompany.dir .. "placeables/GC_BaleShreaderPlaceable.lua");
	source(GlobalCompany.dir .. "placeables/GC_BalerPlaceable.lua");
	
	--|| Additionals ||--
	source(GlobalCompany.dir .. "additionals/GC_ExtendedPlaceable.lua");
	source(GlobalCompany.dir .. "additionals/GC_HorseHelper.lua");
	source(GlobalCompany.dir .. "additionals/GC_MoreTrees.lua");
	source(GlobalCompany.dir .. "additionals/GC_ObjectInfo.lua");
end;

--| Add Base GC Placeables |--
function GlobalCompany.loadPlaceables()
	if GlobalCompany.initialLoadComplete ~= nil then
		return;
	end;

	local placeablesDir = GlobalCompany.dir .. "placeables/";

	GlobalCompany:addPlaceableType("GC_ProductionFactoryPlaceable", "GC_ProductionFactoryPlaceable", placeablesDir .. "GC_ProductionFactoryPlaceable.lua");
	GlobalCompany:addPlaceableType("GC_BaleShreaderPlaceable", "GC_BaleShreaderPlaceable", placeablesDir .. "GC_BaleShreaderPlaceable.lua");
	GlobalCompany:addPlaceableType("GC_BalerPlaceable", "GC_BalerPlaceable", placeablesDir .. "GC_BalerPlaceable.lua");
end;

--| Main |--
function GlobalCompany:init()
	for _, init in pairs(GlobalCompany.inits) do
		init.init(init.target);
	end;
end;

function GlobalCompany:loadMap()
	g_company.debug:loadConsoleCommands();

	g_company.modManager:checkActiveModVersions(); -- Check active mods for version ID
	g_company.gui:load();

	for modName, e in pairs(GlobalCompany.environments) do
		for name, v in pairs(GlobalCompany.loadParameters) do
			if v.typ == GlobalCompany.LOADTYP_XMLFILENAME then
				local value = getXMLString(e.xmlFile, string.format("globalCompany%s#xmlFilename", v.key));
				if value ~= nil then
					GlobalCompany.loadParameters[name].value = value;
					GlobalCompany.loadParameters[name].environment = modName;
				end;
			end;
		end;

		-- if e.shopManager ~= nil and e.shopManager ~= "" then
			-- g_company.shopManager:loadFromXML(modName, g_company.utils.createModPath(modName, e.shopManager));
		-- end;

		if e.densityMapHeight ~= nil and e.densityMapHeight ~= "" then
			g_company.densityMapHeight:loadFromXML(modName, g_company.utils.createModPath(modName, e.densityMapHeight));
		end;

		delete(e.xmlFile);
	end;

	g_company.settings = GlobalCompanySettings:load();

	for _,loadable in pairs(GlobalCompany.loadables) do
		loadable.loadF(loadable.target);
	end;
end;

function GlobalCompany:update(dt)
	for _, updateable in pairs(GlobalCompany.updateables) do
		updateable.update(updateable.target, dt);
	end;

	--can enable for testing!
	--if g_currentMission.missionInfo.timeScale >= 120 then
	--	g_currentMission.missionInfo.timeScale = 900;
	--end;

	for _, raisedUpdateable in pairs(GlobalCompany.raisedUpdateables) do
		if raisedUpdateable.updateableCanUpdate then
			raisedUpdateable.updateableCanUpdate = false;
			raisedUpdateable:update(dt);
		end;
	end;
end;

function GlobalCompany:delete()
end;

function GlobalCompany:deleteMap()
	g_company.debug:deleteConsoleCommands();
	g_company.languageManager:delete();
	
	getfenv(0)["g_company"] = nil; -- Clean up so we have no conflicts.
end;

function GlobalCompany:getLoadParameterValue(name)
	if GlobalCompany.loadParameters[name] == nil or GlobalCompany.loadParameters[name].value == nil then
		return "";
	end;

	return GlobalCompany.loadParameters[name].value;
end;

function GlobalCompany:getLoadParameterEnvironment(name)
	if GlobalCompany.loadParameters[name] == nil or GlobalCompany.loadParameters[name].environment == nil then
		return "";
	end;

	return GlobalCompany.loadParameters[name].environment;
end;

function GlobalCompany:addPlaceableType(name, className, filename)
	-- Force all GlobalCompany Placeables to use a 'PREFIX' (GC_ or SRS_) so that it is clear these are not GIANTS Placeables.
	if g_company.utils.getHasPrefix(name) then
		g_placeableTypeManager.placeableTypes[name] = {name=name, className=className, filename=filename};
	else
		print(string.format("  [LSMC - GlobalCompany] - ERROR: Failed to add placeable type using name '%s'! Incorrect / No prefix found.", name));
		print("    Use prefix 'GC_' for ( GlobalCompany ) placeable mods.", "    Use prefix 'SRS_' for ( SkiRegionSimulator ) placeable mods.");
	end;
end;

GlobalCompany.initialLoad();
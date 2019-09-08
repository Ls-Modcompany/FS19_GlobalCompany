--
-- GlobalCompany
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 24.08.2018
-- @Version: 1.1.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.1.0.0 (24.08.2018):
--		- add language russian
--		- fix Shopmanager for actual patch
--		- Objectinfo: Add support for pallets of VertexDesign
--		- add registration of filltypes
--		- add registration of treetypes
--		- fix densityHeightManager
--		- Horsehelper: Change money when play with seasonsmod
--		- fix gui for large width
--		- adaption to autoDrive
--		- add dynamicStorage
--
-- 	v1.0.0.0 (11.05.2018):
--		- first Release
--
-- Notes:
--
--
-- ToDo:
--
--

GlobalCompany = {};
GlobalCompany.dir = g_currentModDirectory;

GlobalCompany.version = "1.1.0.0";
GlobalCompany.versionDate = "24.08.2019";
GlobalCompany.currentVersionId = 1100; -- Mod Manager ID. (Version number without periods.)
GlobalCompany.isDevelopmentVersion = false; -- This is for versions loaded from GIT.

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

		source(GlobalCompany.dir .. "utils/GC_utils.lua");

		source(GlobalCompany.dir .. "utils/GC_DebugUtils.lua");
		g_company.debug = GC_DebugUtils:new();
		GlobalCompany.debugIndex = g_company.debug:registerScriptName("GlobalCompany");

		source(GlobalCompany.dir .. "utils/GC_languageManager.lua");
		g_company.languageManager:load(GlobalCompany.dir);

		source(GlobalCompany.dir .. "utils/GC_ModManager.lua");
		g_company.modManager = GC_ModManager:new();

		source(GlobalCompany.dir .. "utils/GC_EventManager.lua");
		g_company.eventManager = GC_EventManager:new();
	else
		duplicateLoad = true;
	end;

	local modNameCurrent = g_currentModName;
	if g_company.modManager:doLoadCheck(modNameCurrent, duplicateLoad, GlobalCompany.isDevelopmentVersion) then
		g_company.debug:singleLogWrite(GC_DebugUtils.BLANK, "Loading Version: %s (%s)", GlobalCompany.version, GlobalCompany.versionDate);
		addModEventListener(GlobalCompany);
		
		GlobalCompany.loadedFactories = {}

		Mission00.load = Utils.prependedFunction(Mission00.load, GlobalCompany.initModClasses);
		Mission00.onStartMission = Utils.appendedFunction(Mission00.onStartMission, GlobalCompany.init);

		GlobalCompany.inits = {};
		GlobalCompany.loadables = {};
		GlobalCompany.updateables = {};
		GlobalCompany.raisedUpdateables = {};
		GlobalCompany.environments = {};
		GlobalCompany.xmlLoads = {};
		GlobalCompany.modClassNames = {};
		GlobalCompany.modLanguageFiles = {};

		g_company.modManager:initDevelopmentWarning(GlobalCompany.isDevelopmentVersion);

		GlobalCompany.loadBaseGameGuiFiles(GlobalCompany.dir .. "gui/baseGame/");
		
		GlobalCompany.loadSourceFiles();
		GlobalCompany.loadPlaceables();

		g_company.farmlandOwnerListener = GC_FarmlandOwnerListener:new();
		g_company.fillTypeManager = GC_FillTypeManager:new();
		g_company.densityMapHeightManager = GC_densityMapHeightManager:new();
		g_company.treeTypeManager = GC_TreeTypeManager:new();
		g_company.physicManager = GC_PhysicManager:new();

		GlobalCompany.loadEnviroment(modNameCurrent, GlobalCompany.dir .. "xml/globalCompany.xml", false);
		g_company.modManager:initSelectedMods();
		g_company.languageManager:loadModLanguageFiles(GlobalCompany.modLanguageFiles);

		local xmlFileCurrentMod = nil;
		for modName, xmlFile in pairs(GlobalCompany.environments) do
			g_company.shopManager:loadFromXML(modName, xmlFile);
			g_company.fillTypeManager:loadFromXML(modName, xmlFile);
			g_company.treeTypeManager:loadFromXML(modName, xmlFile);
			g_company.densityMapHeightManager:loadFromXML(modName, xmlFile);

			if modName == modNameCurrent then
				xmlFileCurrentMod = xmlFile;
			else
				g_company.specializations:loadFromXML(modName, xmlFile);	
			end;
		end;
		g_company.specializations:loadFromXML(modNameCurrent, xmlFileCurrentMod);	

	else
		getfenv(0)["g_company"] = nil;
	end;

	GlobalCompany.initialLoadComplete = true;
end;

function GlobalCompany.loadEnviroment(modName, path, isMod)
	local xmlFile = loadXMLFile("globalCompany", path);
	GlobalCompany.environments[modName] = xmlFile;

	if isMod then
		g_company.debug:singleLogWrite(g_company.debug.MODDING, "Initialising environments for mod '%s'", modName);
	end;
	g_company.modManager:loadInitInvalidModsByXml(xmlFile, "globalCompany");
end;

-- Using the following in a mod's 'modDesc' you can init GC functions or addModEventListeners after GC loads.
-- Script still needs to be loaded from modDesc using 'extraSourceFiles'.
-- <globalCompany minimumVersion="1.0.0.0"> <customClasses> <customClass name="MyAddonScript"/> </customClasses> </globalCompany>
-- function MyAddonScript:initGlobalCompany(customEnvironment, baseDirectory, xmlFile) end;
function GlobalCompany:initModClasses()
	if g_company.modClassNames ~= nil then
		for modName, modClasses in pairs (g_company.modClassNames) do
			local modEnv = getfenv(0)["_G"][modName];
			if modEnv ~= nil then
				local baseDirectory = g_modNameToDirectory[modName];
				for _, className in ipairs(modClasses) do
					if className ~= nil and modEnv[className] ~= nil and modEnv[className].initGlobalCompany ~= nil then
						modEnv[className].initGlobalCompany(modEnv[className], modName, baseDirectory, GlobalCompany.environments[modName]);
					end;
				end;
			end;

			if GlobalCompany.environments[modName] ~= nil then
				delete(GlobalCompany.environments[modName]);
				GlobalCompany.environments[modName] = nil;
			end;
		end;

		g_company.modClassNames = nil;
	end;
end;

function GlobalCompany.addFactory(factory)
	if factory ~= nil then
		table.insert(GlobalCompany.loadedFactories, factory);
		return #GlobalCompany.loadedFactories;
	end;
end;

function GlobalCompany.removeFactory(factory, index)
	if factory ~= nil then
		if index ~= nil and GlobalCompany.loadedFactories[index] == factory then
			table.remove(GlobalCompany.loadedFactories, index);
		else
			for i, globalFactory in pairs (GlobalCompany.loadedFactories) do
				if globalFactory == factory then
					table.remove(GlobalCompany.loadedFactories, i);
					break;
				end;
			end;
		end;
	end;
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
		g_company.debug:print("  [LSMC - GlobalCompany > %s] - ERROR: 'addRaisedUpdateable' failed, function 'update(dt)' could not be found.", debugName);
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

--| Load Source Files |--
function GlobalCompany.loadSourceFiles()
	if GlobalCompany.initialLoadComplete ~= nil then
		return;
	end;

	--|| Settings ||--
	source(GlobalCompany.dir .. "GlobalCompanySettings.lua");

	--|| Utils / Managers ||--
	source(GlobalCompany.dir .. "utils/GC_xmlUtils.lua");
	source(GlobalCompany.dir .. "utils/GC_i3dLoader.lua");
	source(GlobalCompany.dir .. "utils/GC_mathUtils.lua");
	source(GlobalCompany.dir .. "utils/GC_cameraUtil.lua");
	source(GlobalCompany.dir .. "utils/GC_shopManager.lua");
	source(GlobalCompany.dir .. "utils/GC_TriggerManager.lua");
	source(GlobalCompany.dir .. "utils/GC_specializations.lua");
	source(GlobalCompany.dir .. "utils/GC_densityMapHeight.lua"); --fixed with patch 1.3 --but in patch 1.4 we need it again... thanks! :)
	source(GlobalCompany.dir .. "utils/GC_FarmlandOwnerListener.lua");
	source(GlobalCompany.dir .. "utils/GC_FillTypeManager.lua");
	source(GlobalCompany.dir .. "utils/GC_TreeTypeManager.lua");
	source(GlobalCompany.dir .. "utils/GC_PhysicManager.lua");

	--|| Gui ||--
	source(GlobalCompany.dir .. "GlobalCompanyGui.lua");

	--|| Objects ||--
	-- source(GlobalCompany.dir .. "objects/GC_Baler.lua");
	source(GlobalCompany.dir .. "objects/GC_Sounds.lua");
	source(GlobalCompany.dir .. "objects/GC_Movers.lua");
	source(GlobalCompany.dir .. "objects/GC_Shaders.lua");
	source(GlobalCompany.dir .. "objects/GC_Effects.lua");
	source(GlobalCompany.dir .. "objects/GC_Lighting.lua");
	source(GlobalCompany.dir .. "objects/GC_Conveyor.lua");
	-- source(GlobalCompany.dir .. "objects/GC_MovingPart.lua");
	source(GlobalCompany.dir .. "objects/GC_FillVolume.lua");
	source(GlobalCompany.dir .. "objects/GC_DynamicHeap.lua");
	source(GlobalCompany.dir .. "objects/GC_DirtyObjects.lua");
	source(GlobalCompany.dir .. "objects/GC_PalletCreator.lua");
	source(GlobalCompany.dir .. "objects/GC_ObjectSpawner.lua");
	source(GlobalCompany.dir .. "objects/GC_AnimationNodes.lua");
	source(GlobalCompany.dir .. "objects/GC_ConveyorEffekt.lua");
	source(GlobalCompany.dir .. "objects/GC_AnimationClips.lua");
	source(GlobalCompany.dir .. "objects/GC_DigitalDisplays.lua");
	source(GlobalCompany.dir .. "objects/GC_ActivableObject.lua");
	source(GlobalCompany.dir .. "objects/GC_VisibilityNodes.lua");
	source(GlobalCompany.dir .. "objects/GC_AnimationManager.lua");
	source(GlobalCompany.dir .. "objects/GC_ProductionFactory.lua");
	source(GlobalCompany.dir .. "objects/GC_DynamicStorage.lua");

	--|| Triggers ||--
	source(GlobalCompany.dir .. "triggers/GC_WoodTrigger.lua");
	source(GlobalCompany.dir .. "triggers/GC_BaleTrigger.lua");
	source(GlobalCompany.dir .. "triggers/GC_PlayerTrigger.lua");
	source(GlobalCompany.dir .. "triggers/GC_LoadingTrigger.lua");
	source(GlobalCompany.dir .. "triggers/GC_UnloadingTrigger.lua");
	source(GlobalCompany.dir .. "triggers/GC_ShovelFillTrigger.lua");
	source(GlobalCompany.dir .. "triggers/GC_AnimalLoadingTrigger.lua");
	--source(GlobalCompany.dir .. "triggers/GC_PalletExtendedTrigger.lua");

	--|| Placeables ||--
	-- source(GlobalCompany.dir .. "placeables/GC_BalerPlaceable.lua");
	source(GlobalCompany.dir .. "placeables/GC_ProductionFactoryPlaceable.lua");
	source(GlobalCompany.dir .. "placeables/GC_DynamicStoragePlaceable.lua");

	--|| Additionals ||--
	source(GlobalCompany.dir .. "additionals/GC_BaleAddon.lua");
	source(GlobalCompany.dir .. "additionals/GC_MoreTrees.lua");
	source(GlobalCompany.dir .. "additionals/GC_ObjectInfo.lua");
	source(GlobalCompany.dir .. "additionals/GC_HorseHelper.lua");
	source(GlobalCompany.dir .. "additionals/GC_ExtendedPlaceable.lua");

	--|| Events ||--
	source(GlobalCompany.dir .. "events/GC_PalletCreatorWarningEvent.lua");
	source(GlobalCompany.dir .. "events/GC_AnimationManagerStopEvent.lua");
	source(GlobalCompany.dir .. "events/GC_AnimalLoadingTriggerEvent.lua");
	source(GlobalCompany.dir .. "events/GC_AnimationManagerStartEvent.lua");
	source(GlobalCompany.dir .. "events/GC_ProductionFactoryStateEvent.lua");
	source(GlobalCompany.dir .. "events/GC_ProductionFactoryCustomTitleEvent.lua");
	source(GlobalCompany.dir .. "events/GC_ProductionFactorySpawnPalletEvent.lua");
	source(GlobalCompany.dir .. "events/GC_ProductionFactoryProductPurchaseEvent.lua");
	

	--|| Specializations ||--
	--source(GlobalCompany.dir .. "specializations/PalletExtended.lua");
	
end;

--| Add Base GC Placeables |--
function GlobalCompany.loadPlaceables()
	if GlobalCompany.initialLoadComplete ~= nil then
		return;
	end;

	local placeablesDir = GlobalCompany.dir .. "placeables/";

	-- GlobalCompany:addPlaceableType("GC_BalerPlaceable", "GC_BalerPlaceable", placeablesDir .. "GC_BalerPlaceable.lua");
	GlobalCompany:addPlaceableType("GC_DynamicStoragePlaceable", "GC_DynamicStoragePlaceable", placeablesDir .. "GC_DynamicStoragePlaceable.lua");
	GlobalCompany:addPlaceableType("GC_ProductionFactoryPlaceable", "GC_ProductionFactoryPlaceable", placeablesDir .. "GC_ProductionFactoryPlaceable.lua");
end;

--| Main |--
function GlobalCompany:init()
	for _, init in pairs(GlobalCompany.inits) do
		init.init(init.target);
	end;
end;

function GlobalCompany:loadMap()
	g_company.debug:loadConsoleCommands();

	g_company.gui:load();

	local fillLevelsDisplay = GC_FillLevelsDisplay.new(g_baseHUDFilename)
	if fillLevelsDisplay ~= nil then
		if g_company.fillLevelsDisplay == nil then
			fillLevelsDisplay:setVisible(false, false)
			local uiScale = Utils.getNoNil(g_gameSettings:getValue("uiScale"), 1.0)
			fillLevelsDisplay:setScale(uiScale)
			g_company.fillLevelsDisplay = fillLevelsDisplay
		else
			fillLevelsDisplay:delete()
		end
	end	

	-- for modName, xmlFile in pairs(GlobalCompany.environments) do
		-- for xmlLoad, _ in pairs(GlobalCompany.xmlLoads) do
			-- if xmlLoads.loadXml ~= nil then
				-- xmlLoads.loadXml(xmlLoad, modName, xmlFile);
			-- else
				-- --error
			-- end;
		-- end;
	-- end;

	g_company.settings = GlobalCompanySettings:load();
	FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, g_company.settings.saveSettings);
    g_company.settings:loadSettings();

	for _,loadable in pairs(GlobalCompany.loadables) do
		loadable.loadF(loadable.target);
	end;
end;

function GlobalCompany:getIsServer()
	return g_server ~= nil
end

function GlobalCompany:getIsClient()
	return g_dedicatedServerInfo == nil
end

function GlobalCompany:update(dt)
	for _, updateable in pairs(GlobalCompany.updateables) do
		updateable.update(updateable.target, dt);
	end;

	for _, raisedUpdateable in pairs(GlobalCompany.raisedUpdateables) do
		if raisedUpdateable.updateableCanUpdate then
			raisedUpdateable.updateableCanUpdate = false;
			raisedUpdateable:update(dt);
		end;
	end;
	
	if g_dedicatedServerInfo == nil and g_company.fillLevelsDisplay ~= nil then
		if not g_gui:getIsGuiVisible() and g_currentMission.controlledVehicle == nil then
			g_company.fillLevelsDisplay:update(dt)
		end
	end
end;

function GlobalCompany:draw()
	if g_dedicatedServerInfo == nil and g_company.fillLevelsDisplay ~= nil then
		if not g_gui:getIsGuiVisible() and g_currentMission.controlledVehicle == nil then
			g_company.fillLevelsDisplay:draw()
		end
	end
end

function GlobalCompany:delete()
	if g_company.fillLevelsDisplay ~= nil then
		g_company.fillLevelsDisplay:setVisible(false, false)
		g_company.fillLevelsDisplay:delete()
		g_company.fillLevelsDisplay = nil
	end
	
	g_company.debug:deleteConsoleCommands();
	g_company.languageManager:delete();

	local environment = getfenv(0);
	if environment.g_company ~= nil then
		environment.g_company = nil;
	end;
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
		g_company.debug:print("  [LSMC - GlobalCompany] - ERROR: Failed to add placeable type using name '%s'! Incorrect / No prefix found.", name);
		g_company.debug:print("    Use prefix 'GC_' for ( GlobalCompany ) placeable mods.", "    Use prefix 'SRS_' for ( SkiRegionSimulator ) placeable mods.");
	end;
end;

function GlobalCompany.loadBaseGameGuiFiles(directory)
	source(directory .. "GC_FillLevelsDisplay.lua")
	
	g_gui:loadProfiles(directory .. "GC_GuiProfiles.xml")
	
	if g_gui ~= nil then
		if g_company.productionFactoryDialog == nil then
			source(directory .. "GC_ProductionFactoryGui.lua")
			
			local factoryDialog = GC_ProductionFactoryGui:new(g_i18n, g_messageCenter)
			g_gui:loadGui(directory .. "GC_ProductionFactoryGui.xml", "GC_ProductionFactoryDialog", factoryDialog)
			g_company.productionFactoryDialog = factoryDialog
		end
		
		if g_company.animalDeliveryDialog == nil then
			source(directory .. "GC_AnimalDeliveryDialog.lua")
			
			local animalDeliveryDialog = GC_AnimalDeliveryDialog:new()
			g_gui:loadGui(directory .. "GC_AnimalDeliveryDialog.xml", "GC_AnimalDeliveryDialog", animalDeliveryDialog)
			g_company.animalDeliveryDialog = animalDeliveryDialog
		end
	end
end

GlobalCompany.initialLoad();
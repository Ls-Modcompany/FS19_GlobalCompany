--
-- GlobalCompany
--
-- @Interface: 1.5.1.0 b6730
-- @Author: LS-Modcompany
-- @Date: 29.04.2020
-- @Version: 1.5.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
-- 	v1.5.0.0 (29.04.2020):
--		- Fix Baler
--
-- 	v1.4.4.0 (18.04.2020):
--		- Some Bugfixes
--
-- 	v1.4.3.0 (02.04.2020):
--		- FarmStart: Add 'boughtWithFarmland' attribute for items
--
-- 	v1.4.2.0 (02.04.2020):
--		- GlobalMarket: Add feature for create own server
--
-- 	v1.4.1.0 (30.03.2020):
--		- Add FarmStart
--
-- 	v1.4.0.0 (22.03.2020):
--		- Add support of manurehosesystem to factory
--		- Add programmflow to factory
-- 		- Some further improvements
--
-- 	v1.3.0.0 (18.02.2020):
--		- Fix synchro error
-- 		- Add GlobalMarket
-- 		- Add AnimalTrough
--		- Change Design
--
-- 	v1.2.1.0 (27.01.2020):
--		- Add new Mp-Synch and GC-Object System
-- 		- Fix PlaceableDisplay
--
-- 	v1.2.0.0 (12.01.2020):
--		- Release v1.2.0.0 on Modhub
--
-- 	v1.1.5.1 (05.01.2020):
--		- Update cs language
--		- Factory: Add old animalinput
--
-- 	v1.1.5.0 (02.01.2020):
--		- DynamicStorage: Fix effects on dediserver
--		- DynamicStorage: Add unloadtriggers at places
--		- Ingamemap: Add support for 4x maps
--
-- 	v1.1.4.2 (24.12.2019):
--		- DynamicStorage: Change key t to lctrl+t
--
-- 	v1.1.4.1 (23.12.2019):
--		- Factory: Add animaloutput
--
-- 	v1.1.4.0 (22.12.2019):
--		- Factory: Add Seasons support
--		- GC-Menu: Improve dynamic ingamemap
--		- Add languanges: pt, it, pl
-- 		- Update for green week berlin 2020
-- 		- Further improvements
--
-- 	v1.1.3.0 (03.11.2019):
--		- FIX: 'Error: Server:registerObjectInStream is only allowed in writeStream calls' Error on MP again
--
--
-- 	v1.1.2.0 (31.10.2019):
--		- FIX: 'Error: Server:registerObjectInStream is only allowed in writeStream calls' Error on MP
--		- FIX: language texts
--		- FIX: Objektinfo: Change position, now we can see the hand
--
--
-- 	v1.1.1.0 (30.10.2019):
--		- GC-Menu
--			- NEW: Overview for DynamicStorage
--			- NEW: Better overview for Factorys
--			- NEW: AddOns can now create Tabs
--		- Factory
--			- NEW: add 'refPoint' - Attribute
--			- FIX: Incomeprice can now be negative
--		- Add new Gui-elements
--		- VisibilityNodes: Collisions will check now also on Server
--		- Adaption to Courseplay
--		- many more things
--
-- 	v1.1.0.0 (24.08.2019):
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
-- 	v1.0.0.0 (11.05.2019):
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

GlobalCompany.version = "1.5.0.0";
GlobalCompany.versionDate = "29.04.2020";
GlobalCompany.currentVersionId = 1500; -- Mod Manager ID. (Version number without periods.)
GlobalCompany.isDevelopmentVersion = false; -- This is for versions loaded from GIT.
GlobalCompany.isGreenWeekVersion = false;

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
		source(GlobalCompany.dir .. "utils/GC_DataTypeConverter.lua");
		source(GlobalCompany.dir .. "class/GC_Class.lua");
		source(GlobalCompany.dir .. "class/GC_StaticClass.lua");

		source(GlobalCompany.dir .. "utils/GC_DebugUtils.lua");
		source(GlobalCompany.dir .. "utils/GC_DebugManager.lua");
		g_company.debug = GC_DebugUtils:new();
		g_company.debugManager = GC_DebugManager:new();
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
		local text = "Loading Version: %s (%s)"
		if GlobalCompany.isDevelopmentVersion then
			text = "Loading Developer-Version: %s (%s)"
		end
		g_company.debug:singleLogWrite(GC_DebugUtils.BLANK, text, GlobalCompany.version, GlobalCompany.versionDate);

		addModEventListener(GlobalCompany);
		
		GlobalCompany.loadedFactories = {}
		GlobalCompany.loadedDynamicStorages = {}
		GlobalCompany.loadedAnimalFeeders = {}

		Mission00.load = Utils.prependedFunction(Mission00.load, GlobalCompany.onMissionLoad);
		Mission00.onStartMission = Utils.appendedFunction(Mission00.onStartMission, GlobalCompany.init);
		FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, GlobalCompany.saveToXMLFile)

		GlobalCompany.inits = {};
		GlobalCompany.loadables = {};
		GlobalCompany.updateables = {};
		GlobalCompany.raisedUpdateables = {};
		GlobalCompany.environments = {};
		GlobalCompany.xmlLoads = {};
		GlobalCompany.modClassNames = {};
		GlobalCompany.modLanguageFiles = {};
		GlobalCompany.saveables = {};

		GlobalCompany.objects = {}
		GlobalCompany.objectId = 1
		GlobalCompany.staticObjects = {}

		g_company.modManager:initDevelopmentWarning(GlobalCompany.isDevelopmentVersion);

		GlobalCompany.loadBaseGameGuiFiles(GlobalCompany.dir .. "gui/baseGame/");
		
		GlobalCompany.loadSourceFiles();
		GlobalCompany.loadPlaceables();
		
		g_company.gui:preLoad()

		g_company.farmlandOwnerListener = GC_FarmlandOwnerListener:new()
		g_company.fillTypeManager = GC_FillTypeManager:new()
		g_company.densityMapHeightManager = GC_densityMapHeightManager:new()
		g_company.treeTypeManager = GC_TreeTypeManager:new()
		g_company.physicManager = GC_PhysicManager:new()
		g_company.bitmapManager = GC_BitmapManager:new()
		g_company.jobManager = GC_JobManager:new()
		g_company.globalMarket = GC_GlobalMarket:new()

		GlobalCompany.loadEnviroment(modNameCurrent, GlobalCompany.dir .. "xml/globalCompany.xml", false);
		
		g_company.modManager:initSelectedMods()	
		
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

function GlobalCompany:leaveToMenuCallback()
	local inGameMenuTarget = g_gui.guis["InGameMenu"].target;
	InGameMenu.onYesNoEnd(inGameMenuTarget, true);
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
function GlobalCompany.onMissionLoad(mission)

	g_company.bitmapManager.mission = mission;

	-- init mod classes
	if g_company.modClassNames ~= nil then
		for modName, modClasses in pairs (g_company.modClassNames) do
			local modEnv = getfenv(0)["_G"][modName];
			if modEnv ~= nil then
				local baseDirectory = g_modNameToDirectory[modName];
				for _, className in ipairs(modClasses) do
					if className ~= nil and modEnv[className] ~= nil and modEnv[className].initGlobalCompany ~= nil then
						modEnv[className].initGlobalCompany(modEnv[className], modName, baseDirectory, GlobalCompany.environments[modName], mission);
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

function GlobalCompany.addDynamicStorage(dynamicStorage)
	if dynamicStorage ~= nil then
		table.insert(GlobalCompany.loadedDynamicStorages, dynamicStorage);
		return #GlobalCompany.loadedDynamicStorages;
	end;
end;

function GlobalCompany.removeDynamicStorage(dynamicStorage, index)
	if dynamicStorage ~= nil then
		if index ~= nil and GlobalCompany.loadedDynamicStorages[index] == dynamicStorage then
			table.remove(GlobalCompany.loadedDynamicStorages, index);
		else
			for i, globalStorage in pairs (GlobalCompany.loadedDynamicStorages) do
				if globalStorage == dynamicStorage then
					table.remove(GlobalCompany.loadedDynamicStorages, i);
					break;
				end;
			end;
		end;
	end;
end;

function GlobalCompany.addAnimalFeeder(animalFeeder)
	if animalFeeder ~= nil then
		table.insert(GlobalCompany.loadedAnimalFeeders, animalFeeder);
		return #GlobalCompany.loadedAnimalFeeders;
	end;
end;

function GlobalCompany.removeAnimalFeeder(animalFeeder, index)
	if animalFeeder ~= nil then
		if index ~= nil and GlobalCompany.loadedAnimalFeeders[index] == animalFeeder then
			table.remove(GlobalCompany.loadedAnimalFeeders, index);
		else
			for i, globalFeeder in pairs (GlobalCompany.loadedAnimalFeeders) do
				if globalFeeder == animalFeeder then
					table.remove(GlobalCompany.loadedAnimalFeeders, i);
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

--|| Saveables ||--
function GlobalCompany.addSaveable(target, saveF)
	table.insert(GlobalCompany.saveables, {saveF=saveF, target=target});
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
	source(GlobalCompany.dir .. "utils/GC_BitmapManager.lua");
	source(GlobalCompany.dir .. "utils/GC_JobManager.lua");

	--|| Gui ||--
	source(GlobalCompany.dir .. "GlobalCompanyGui.lua");

	--|| Objects ||--
	source(GlobalCompany.dir .. "objects/GC_Baler.lua");
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
	source(GlobalCompany.dir .. "objects/GC_PlaceableDigitalDisplay.lua");
	source(GlobalCompany.dir .. "objects/GC_GlobalMarket.lua");
	source(GlobalCompany.dir .. "objects/GC_GlobalMarketObject.lua");
	source(GlobalCompany.dir .. "objects/GC_AnimalTrough.lua");
	source(GlobalCompany.dir .. "objects/GC_ProgrammFlow.lua");
	source(GlobalCompany.dir .. "objects/GC_ProgrammFlow_Globalfunctions.lua");
	source(GlobalCompany.dir .. "objects/GC_AnimalFeeder.lua");

	--|| Triggers ||--
	source(GlobalCompany.dir .. "triggers/GC_WoodTrigger.lua");
	source(GlobalCompany.dir .. "triggers/GC_BaleTrigger.lua");
	source(GlobalCompany.dir .. "triggers/GC_PlayerTrigger.lua");
	source(GlobalCompany.dir .. "triggers/GC_LoadingTrigger.lua");
	source(GlobalCompany.dir .. "triggers/GC_UnloadingTrigger.lua");
	source(GlobalCompany.dir .. "triggers/GC_ShovelFillTrigger.lua");
	source(GlobalCompany.dir .. "triggers/GC_AnimalLoadingTrigger.lua");
	source(GlobalCompany.dir .. "triggers/GC_VehicleTrigger.lua");
	--source(GlobalCompany.dir .. "triggers/GC_PalletExtendedTrigger.lua");

	--|| Placeables ||--
	source(GlobalCompany.dir .. "placeables/GC_BalerPlaceable.lua");
	source(GlobalCompany.dir .. "placeables/GC_ProductionFactoryPlaceable.lua");
	source(GlobalCompany.dir .. "placeables/GC_DynamicStoragePlaceable.lua");
	source(GlobalCompany.dir .. "placeables/GC_PlaceableDigitalDisplayPlaceable.lua");
	source(GlobalCompany.dir .. "placeables/GC_GlobalMarketPlaceable.lua");
	source(GlobalCompany.dir .. "placeables/GC_AnimalFeederPlaceable.lua");

	--|| Additionals ||--
	source(GlobalCompany.dir .. "additionals/GC_BaleAddon.lua");
	source(GlobalCompany.dir .. "additionals/GC_MoreTrees.lua");
	source(GlobalCompany.dir .. "additionals/GC_ObjectInfo.lua");
	source(GlobalCompany.dir .. "additionals/GC_HorseHelper.lua");
	source(GlobalCompany.dir .. "additionals/GC_ExtendedPlaceable.lua");
	source(GlobalCompany.dir .. "additionals/GC_FarmStarter.lua");

	--|| Events ||--
	source(GlobalCompany.dir .. "events/GC_SynchEvent.lua");
	source(GlobalCompany.dir .. "events/GC_PalletCreatorWarningEvent.lua");
	source(GlobalCompany.dir .. "events/GC_AnimationManagerStopEvent.lua");
	source(GlobalCompany.dir .. "events/GC_AnimalLoadingTriggerEvent.lua");
	source(GlobalCompany.dir .. "events/GC_AnimationManagerStartEvent.lua");
	source(GlobalCompany.dir .. "events/GC_ProductionFactoryStateEvent.lua");
	source(GlobalCompany.dir .. "events/GC_ProductionFactoryCustomTitleEvent.lua");
	source(GlobalCompany.dir .. "events/GC_ProductionFactorySpawnPalletEvent.lua");
	source(GlobalCompany.dir .. "events/GC_ProductionFactoryProductPurchaseEvent.lua");
	source(GlobalCompany.dir .. "events/GC_ProductionDynamicStorageCustomTitleEvent.lua");
	source(GlobalCompany.dir .. "events/GC_GmSendMoneyEvent.lua");
	

	--|| Specializations ||--
	--source(GlobalCompany.dir .. "specializations/PalletExtended.lua");
	
end;

--| Add Base GC Placeables |--
function GlobalCompany.loadPlaceables()
	if GlobalCompany.initialLoadComplete ~= nil then
		return;
	end;

	local placeablesDir = GlobalCompany.dir .. "placeables/";

	GlobalCompany:addPlaceableType("GC_BalerPlaceable", "GC_BalerPlaceable", placeablesDir .. "GC_BalerPlaceable.lua");
	GlobalCompany:addPlaceableType("GC_DynamicStoragePlaceable", "GC_DynamicStoragePlaceable", placeablesDir .. "GC_DynamicStoragePlaceable.lua");
	GlobalCompany:addPlaceableType("GC_ProductionFactoryPlaceable", "GC_ProductionFactoryPlaceable", placeablesDir .. "GC_ProductionFactoryPlaceable.lua");
	GlobalCompany:addPlaceableType("GC_PlaceableDigitalDisplayPlaceable", "GC_PlaceableDigitalDisplayPlaceable", placeablesDir .. "GC_PlaceableDigitalDisplayPlaceable.lua");
	GlobalCompany:addPlaceableType("GC_GlobalMarketPlaceable", "GC_GlobalMarketPlaceable", placeablesDir .. "GC_GlobalMarketPlaceable.lua");
	GlobalCompany:addPlaceableType("GC_AnimalFeederPlaceable", "GC_AnimalFeederPlaceable", placeablesDir .. "GC_AnimalFeederPlaceable.lua");
end;

function GlobalCompany:registerObject(object)
	--if GlobalCompany:getIsServer() then		
		object.gcId = GlobalCompany.objectId
		table.insert(GlobalCompany.objects, object)
		GlobalCompany.objectId = GlobalCompany.objectId + 1
	--end
end

function GlobalCompany:unregisterObject(objectToDelete)
	for id,object in pairs(GlobalCompany.objects) do
		if object == objectToDelete then
			table.remove(GlobalCompany.objects, id)
			break
		end
	end
end

function GlobalCompany:getObject(id)
	for _,object in pairs(GlobalCompany.objects) do
		if object.gcId == id then
			return object
		end
	end
end

function GlobalCompany:registerStaticObject(object, staticId)
	object.gcId = staticId
	table.insert(GlobalCompany.staticObjects, object)
end

function GlobalCompany:unregisterStaticObject(objectToDelete)
	for id,object in pairs(GlobalCompany.staticObjects) do
		if object == objectToDelete then
			table.remove(GlobalCompany.staticObjects, id)
			break
		end
	end
end

function GlobalCompany:getStaticObject(id)
	for _,object in pairs(GlobalCompany.staticObjects) do
		if object.gcId == id then
			return object
		end
	end
end

--| Main |--
function GlobalCompany:init()
	for _, init in pairs(GlobalCompany.inits) do
		init.init(init.target);
	end;
end;

function GlobalCompany:loadMap()
	g_company.debug:loadConsoleCommands();
	
	g_company.gui:load()

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

function GlobalCompany:saveToXMLFile()
	for _, save in pairs(GlobalCompany.saveables) do
		save.saveF(save.target);
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
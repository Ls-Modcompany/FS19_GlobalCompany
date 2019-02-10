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
GlobalCompany.version = "1.0.0.0 (04.05.2018)";

GlobalCompany.LOADTYP_XMLFILENAME = 1;

getfenv(0)["g_company"] = GlobalCompany;
addModEventListener(GlobalCompany);

source(GlobalCompany.dir .. "Debug.lua"); -- TEMP 'Need to convert all then scripts using this to remove it'

function GlobalCompany.initialLoad()
	if GlobalCompany.initialLoadComplete ~= nil then
		print("  [LSMC - GlobalCompany] - ERROR: 'initialLoad' failed! This function is only called on initial load.")
		return;
	end;

	Mission00.onStartMission = Utils.appendedFunction(Mission00.onStartMission, GlobalCompany.init);

	--| Debug |--
	source(GlobalCompany.dir .. "utils/GC_DebugUtils.lua");
	g_company.debug = GC_DebugUtils:new();
	--getfenv(0)["gc_debug "] = g_company.debug; --[[ This is in case we need a superGlobal version ]]--

	GlobalCompany.debugIndex = g_company.debug:registerScriptName("GlobalCompany");
	g_company.debug:singleLogWrite(GlobalCompany.debugIndex, GC_DebugUtils.BLANK, "Loading Version: %s", GlobalCompany.version);


	GlobalCompany.inits = {};
	GlobalCompany.loadables = {};
	GlobalCompany.updateables = {};
	GlobalCompany.raisedUpdateables = {};
	GlobalCompany.environments = {};
	GlobalCompany.loadParameters = {};
	GlobalCompany.loadParametersToEnvironment = {};

	GlobalCompany.loadSourceFiles();

	local modLanguageFiles = {}; -- Check for language file during this pass and send with 'g_company.languageManager:load(modLanguageFiles)'.
	local selectedMods = g_modSelectionScreen.missionDynamicInfo.mods;
	for _, mod in pairs(selectedMods) do
		local path = nil;
		local modName = mod.modName;

		if mod.modDir ~= nil then
			path = mod.modDir .. "globalCompany.xml";
			if not fileExists(path) then
				path = mod.modDir .. "xml/globalCompany.xml";
				if not fileExists(path) then
					path = nil;
				end;
			end;

			-- Also find language files now.
			local langFullPath = g_company.languageManager:getLanguagesFullPath(mod.modDir);
			if langFullPath ~= nil then
				modLanguageFiles[modName] = langFullPath;
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
		if values.specializations ~= nil and values.specializations ~= "" then
			g_company.specializations:loadFromXML(modName, g_company.utils.createModPath(modName, values.specializations));
		end;
		if values.densityMapHeightOverwriteOrginalFunction then
			g_densityMapHeightManager.loadMapData = function() return true; end;
		end;
	end;

	g_company.languageManager:load(modLanguageFiles); -- Load language manager.

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


	--|| Utils / Managers ||--
	source(GlobalCompany.dir .. "utils/GC_Utils.lua");
	source(GlobalCompany.dir .. "utils/GC_XmlUtils.lua");
	source(GlobalCompany.dir .. "utils/GC_i3dLoader.lua");
	source(GlobalCompany.dir .. "utils/GC_cameraUtil.lua");
	source(GlobalCompany.dir .. "utils/GC_shopManager.lua");
	source(GlobalCompany.dir .. "utils/GC_TriggerManager.lua");
	source(GlobalCompany.dir .. "utils/GC_specializations.lua");
	source(GlobalCompany.dir .. "utils/GC_languageManager.lua");
	source(GlobalCompany.dir .. "utils/GC_densityMapHeight.lua");


	--|| Gui ||--
	source(GlobalCompany.dir .. "GlobalCompanyGui.lua");


	--|| Objects ||--
	source(GlobalCompany.dir .. "objects/GC_Sounds.lua");
	source(GlobalCompany.dir .. "objects/GC_Movers.lua");
	source(GlobalCompany.dir .. "objects/GC_Shaders.lua");
	source(GlobalCompany.dir .. "objects/GC_Lighting.lua");
	source(GlobalCompany.dir .. "objects/GC_MovingPart.lua");
	source(GlobalCompany.dir .. "objects/GC_Animations.lua");
	source(GlobalCompany.dir .. "objects/GC_DynamicHeap.lua");
	source(GlobalCompany.dir .. "objects/GC_RotationNodes.lua");
	source(GlobalCompany.dir .. "objects/GC_ConveyorEffekt.lua");
	source(GlobalCompany.dir .. "objects/GC_ActivableObject.lua");
	source(GlobalCompany.dir .. "objects/GC_ParticleEffects.lua");
	source(GlobalCompany.dir .. "objects/GC_VisibilityNodes.lua");
	source(GlobalCompany.dir .. "objects/GC_ProductionFactory.lua");


	--|| Triggers ||--
	source(GlobalCompany.dir .. "triggers/GC_WoodTrigger.lua");
	source(GlobalCompany.dir .. "triggers/GC_PlayerTrigger.lua");
	source(GlobalCompany.dir .. "triggers/GC_UnloadingTrigger.lua");
end;

--| Main |--
function GlobalCompany:init()
	for _, init in pairs(GlobalCompany.inits) do
		init.init(init.target);
	end;
end;

function GlobalCompany:loadMap()
	-- Load Debug console commands.
	g_company.debug:loadConsoleCommands();

	-- Load parameters from environments table.
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

		if e.shopManager ~= nil and e.shopManager ~= "" then
			g_company.shopManager:loadFromXML(modName, g_company.utils.createModPath(modName, e.shopManager));
		end;

		if e.densityMapHeight ~= nil and e.densityMapHeight ~= "" then
			g_company.densityMapHeight:loadFromXML(modName, g_company.utils.createModPath(modName, e.densityMapHeight));
		end;

		delete(e.xmlFile);
	end;

	-- Update loadables
	for _,loadable in pairs(GlobalCompany.loadables) do
		loadable.loadF(loadable.target);
	end;
end;

function GlobalCompany:update(dt)
	for _,updateable in pairs(GlobalCompany.updateables) do
		updateable.update(updateable.target, dt);
	end;

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

function  GlobalCompany:addPlaceableType(name, className, filename)
	g_placeableTypeManager.placeableTypes[name] = {name=name, className=className, filename=filename};
end

GlobalCompany.initialLoad();

--convert ExtendedPlaceable.lua from ls17
PlacementScreenController.DISPLACEMENT_COST_PER_M3 = 1;
PlacementUtil.hasObjectOverlap = function() return false end;
PlacementUtil.isInsidePlacementPlaces = function() return false end;
PlacementUtil.isInsideRestrictedZone = function() return false end;
PlacementUtil.hasOverlapWithPoint = function() return false end;
TerrainDeformation.setBlockedAreaMap = function() return true end;
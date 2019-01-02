-- 
-- GlobalCompany 
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 11.05.2018
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
local version = "1.0.0.0 (04.05.2018)";

GlobalCompany = {};
getfenv(0)["g_company"] = GlobalCompany;

GlobalCompany.dir = g_currentModDirectory;
addModEventListener(GlobalCompany);

GlobalCompany.LOADTYP_XMLFILENAME = 1;

--|| Debug ||--
source(GlobalCompany.dir .. "Debug.lua");
local debugIndex = g_debug.registerMod("GlobalCompany");
g_debug.write(debugIndex, -2, "load GlobalCompany %s", version);

g_debug.setLevel(3, true);
	
--|| Load ||--
GlobalCompany.loadables = {};	
function GlobalCompany.addLoadable(target, loadF)
	table.insert(GlobalCompany.loadables, {loadF=loadF, target=target});
end;

--|| Init ||--
GlobalCompany.inits = {};	
function GlobalCompany.addInit(target, init)
	table.insert(GlobalCompany.inits, {init=init, target=target});
end;

--|| Updateables ||--
GlobalCompany.updateables = {};	
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

--|| Init ||--
GlobalCompany.loadParameters = {};	
GlobalCompany.loadParametersToEnvironment = {};	
function GlobalCompany.addLoadParameter(name, key, typ)
	GlobalCompany.loadParameters[name] = {key=key, typ=typ, value=nil, environment=nil};
end;

--|| UpdateablesTick ||--
--[[GlobalCompany.updateablesTick = {};	
function GlobalCompany.addUpdateableTick(target, update)
	table.insert(GlobalCompany.updateablesTick, {update=update, target=target});
end;
function GlobalCompany.removeUpdateableTick(target, update)
	for key, u in pairs(GlobalCompany.updateablesTick) do
		if u.target == target then
			table.remove(GlobalCompany.updateablesTick, key);
			break;
		end;
	end;
end; ]]--


source(GlobalCompany.dir .. "utils/GC_utils.lua");
source(GlobalCompany.dir .. "utils/GC_i3dLoader.lua");
source(GlobalCompany.dir .. "utils/GC_specializations.lua");
source(GlobalCompany.dir .. "utils/GC_shopManager.lua");
source(GlobalCompany.dir .. "utils/GC_languageManager.lua");





--source(GlobalCompany.dir .. "utils/TriggerUtil.lua");
--source(GlobalCompany.dir .. "utils/FactoryUtils.lua");
--source(GlobalCompany.dir .. "utils/TextDisplayUtil.lua");
--source(GlobalCompany.dir .. "utils/AlgorithUtils.lua");
--source(GlobalCompany.dir .. "utils/GcUtils.lua");
source(GlobalCompany.dir .. "GlobalCompanyGui.lua");

--FarmShop
--source(GlobalCompany.dir .. "shop/FarmShop.lua");
--source(GlobalCompany.dir .. "shop/FarmShopPlace.lua");

--Objects
--source(GlobalCompany.dir .. "objects/FarmShopPallet.lua");
--source(GlobalCompany.dir .. "objects/FeederSilo.lua");
--source(GlobalCompany.dir .. "objects/FeederRoboter.lua");
--source(GlobalCompany.dir .. "objects/NodeObjects.lua");
--source(GlobalCompany.dir .. "objects/ObjectNodeSpawner.lua");

-- Objects (onCreate)
--source(GlobalCompany.dir .. "objects/AnimalShop.lua");
--source(GlobalCompany.dir .. "objects/Construction.lua");
--source(GlobalCompany.dir .. "objects/Feeder.lua");
--source(GlobalCompany.dir .. "objects/Fermenter.lua");
--source(GlobalCompany.dir .. "objects/ProductFactory.lua");
--source(GlobalCompany.dir .. "objects/Scaffolding.lua");
--source(GlobalCompany.dir .. "objects/SiloStorage.lua");

-- Objects (Addon Scripts)
--source(GlobalCompany.dir .. "objects/GC_Movers.lua");
--source(GlobalCompany.dir .. "objects/GC_VisibilityNodes.lua");
source(GlobalCompany.dir .. "objects/GC_Animations.lua");
--source(GlobalCompany.dir .. "objects/GC_AnimationClips.lua");
source(GlobalCompany.dir .. "objects/GC_ConveyorEffekt.lua");
--source(GlobalCompany.dir .. "objects/GC_ExtendedHeap.lua");
--source(GlobalCompany.dir .. "objects/GC_FillVolume.lua");
source(GlobalCompany.dir .. "objects/GC_ParticleEffects.lua");
--source(GlobalCompany.dir .. "objects/GC_Lighting.lua");
--source(GlobalCompany.dir .. "objects/GC_Sounds.lua");
--source(GlobalCompany.dir .. "objects/GC_Shaders.lua");
--source(GlobalCompany.dir .. "objects/GC_RotationNodes.lua");
--source(GlobalCompany.dir .. "objects/GC_Displays.lua");

--Triggers
--source(GlobalCompany.dir .. "triggers/GC_AnimalShopTrigger.lua");
--source(GlobalCompany.dir .. "triggers/GC_TipTrigger.lua");
--source(GlobalCompany.dir .. "triggers/GC_WoodTrigger.lua");
--source(GlobalCompany.dir .. "triggers/GC_BaleTrigger.lua");
--source(GlobalCompany.dir .. "triggers/GC_ShovelTarget.lua");
--source(GlobalCompany.dir .. "triggers/GC_SiloTrigger.lua");
--source(GlobalCompany.dir .. "triggers/GC_PlayerTrigger.lua");

--Vehicles
--source(GlobalCompany.dir .. "vehicles/GC_reg_LivestockTrailer.lua");



GlobalCompany.environments = {}
local mods = Files:new(g_modsDirectory);
for _,v in pairs(mods.files) do
	local modName = nil;
	if v.isDirectory then
		modName = v.filename;
	else
		local l = v.filename:len();
		if l > 4 then
			local ext = v.filename:sub(len-3);
			if ext == ".zip" or ext == ".gar" then
				modName = v.filename:sub(1, len-4);
			end;
		end;
	end;
	local currentPath = string.format("%s%s/",g_modsDirectory, modName);
	local fullPath = currentPath .. "globalCompany.xml";
	if not fileExists(fullPath) then
		fullPath = currentPath .. "xml/globalCompany.xml";
		if not fileExists(fullPath) then
			fullPath = nil;
		end;
	end;
	
	if fullPath ~= nil then
		local xmlFile = loadXMLFile("globalCompany", fullPath);
		
		GlobalCompany.environments[modName] = {};
		GlobalCompany.environments[modName].fullPath = fullPath;
		GlobalCompany.environments[modName].xmlFile = xmlFile;
		GlobalCompany.environments[modName].specializations = getXMLString(xmlFile, "globalCompany.specializations#xmlFilename");
		GlobalCompany.environments[modName].shopManager = getXMLString(xmlFile, "globalCompany.shopManager#xmlFilename");
	end;
end;


for modName, values in pairs(GlobalCompany.environments) do
	if values.specializations ~= nil and values.specializations ~= "" then	
		g_company.specializations:loadFromXML(modName, g_company.utils.createModPath(modName, values.specializations));
	end;
end;



--[[
GlobalCompanyOnCreate = {};
getfenv(0)["GlobalCompany"] = GlobalCompanyOnCreate;
local globalCompanyOnCreate_mt = Class(GlobalCompanyOnCreate);

--GlobalCompany.onCreateObjects = {};
function GlobalCompanyOnCreate:onCreate(id)
	--table.insert(GlobalCompany.onCreateObjects, GlobalCompanyOnCreate:new(id));
	GlobalCompanyOnCreate:new(id);
end;

function GlobalCompanyOnCreate:new(id)
	local self = setmetatable({}, globalCompanyOnCreate_mt);	
    --self.id = id;	
		
		
	if getUserAttribute(id, "readL10n") then
		local langXml = loadXMLFile("TempConfig", GlobalCompanyUtils.createModPath(g_company.modFileName, "l10n" .. g_languageSuffix .. ".xml"));
		g_i18n:loadEntriesFromXML(langXml, "l10n.elements.e(%d)", "Warning: Duplicate text in l10n %s", g_i18n.texts);	
	end;
	local langXml = loadXMLFile("TempConfig", GlobalCompany.dir .. "l10n" .. g_languageSuffix .. ".xml");
	g_i18n:loadEntriesFromXML(langXml, "l10n.elements.e(%d)", "Warning: Duplicate text in l10n %s", g_i18n.texts);
	
	
	--g_currentMission:addNodeObject(self.id, self); --??
	
	return self;
end;

function GlobalCompanyOnCreate:delete()
end;
]]--

function GlobalCompany:init() 
	for _,init in pairs(GlobalCompany.inits) do
		init.init(init.target);
	end; 
end;
	

function GlobalCompany:loadMap()
	g_company.languageManager:load();
	
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
		
		delete(e.xmlFile);
	end;
	
	

	for _,loadF in pairs(GlobalCompany.loadables) do
		loadF.loadF(loadF.target, dt);
	end;
end;

function GlobalCompany:update(dt) 
	for _,update in pairs(GlobalCompany.updateables) do
		update.update(update.target, dt);
	end; 
end;

function GlobalCompany:delete()
	for _,updateable in pairs(GlobalCompany.updateables) do
        if updateable.delete ~= nil then
			updateable:delete();
		end;
    end;
end;

function GlobalCompany:mouseEvent(posX, posY, isDown, isUp, button) end;
function GlobalCompany:keyEvent(unicode, sym, modifier, isDown) end;
function GlobalCompany:draw() end;
function GlobalCompany:deleteMap() end;

function GlobalCompany:getLoadParameterValue(name) 
	if GlobalCompany.loadParameters[name] == nil or GlobalCompany.loadParameters[name].value == nil then return "" end;
	return GlobalCompany.loadParameters[name].value;
end;
function GlobalCompany:getLoadParameterEnvironment(name) 
	if GlobalCompany.loadParameters[name] == nil or GlobalCompany.loadParameters[name].environment == nil then return "" end;
	return GlobalCompany.loadParameters[name].environment;
end;

Mission00.onStartMission = Utils.appendedFunction(Mission00.onStartMission, GlobalCompany.init);


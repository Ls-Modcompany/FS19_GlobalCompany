--
-- GlobalCompany - Objects - GC_Greenhouse
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 22.03.2018
-- @Version: 1.1.1.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (26.04.2019):
-- 		- initial fs17 (GtX)
--
--
-- Notes:
--
--
-- ToDo:
--
--
--


GC_Greenhouse = {};
local GC_Greenhouse_mt = Class(GC_Greenhouse, Object);
InitObjectClass(GC_Greenhouse, "GC_Greenhouse");

GC_Greenhouse.debugIndex = g_company.debug:registerScriptName("GC_Greenhouse");

GC_Greenhouse.DOORTRIGGER = 0;
GC_Greenhouse.GREENHOUSETRIGGER = 1;
GC_Greenhouse.PALLETEXTENDEDUNLOADTRIGGER = 2;
GC_Greenhouse.VENTILATOR = 3;
GC_Greenhouse.SELECTFILLTYPE = 4;
GC_Greenhouse.PLANT = 5;
GC_Greenhouse.PALLETEXTENDEDLOADTRIGGER = 6;

GC_Greenhouse.STATE_PREPERATION = 1;
GC_Greenhouse.STATE_CANPLANT = 2;
GC_Greenhouse.STATE_GROW = 3;
GC_Greenhouse.STATE_HARVEST = 4;
GC_Greenhouse.STATE_DEATH = 5;
GC_Greenhouse.STATE_NEEDCLEAN = 6;

getfenv(0)["GC_Greenhouse"] = GC_Greenhouse;

function GC_Greenhouse:onCreate(transformId)
	local indexName = getUserAttribute(transformId, "indexName");
	local xmlFilename = getUserAttribute(transformId, "xmlFile");
	local farmlandId = getUserAttribute(transformId, "farmlandId");

	if indexName ~= nil and xmlFilename ~= nil and farmlandId ~= nil then
		local customEnvironment = g_currentMission.loadingMapModName;
		local baseDirectory = g_currentMission.loadingMapBaseDirectory;

		local object = GC_Greenhouse:new(g_server ~= nil, g_client ~= nil, nil, xmlFilename, baseDirectory, customEnvironment);
		local xmlFile, xmlKey = g_company.xmlUtils:getXMLFileAndKey(xmlFilename, baseDirectory, "globalCompany.greenhouses.greenhouse", indexName, "indexName")
		if xmlFile ~= nil and xmlKey ~= nil then
			if object:load(transformId, xmlFile, xmlKey, indexName, false) then
				local onCreateIndex = g_currentMission:addOnCreateLoadedObject(object);
				g_currentMission:addOnCreateLoadedObjectToSave(object);

				g_company.debug:writeOnCreate(object.debugData, "[GREENHOUSE - %s]  Loaded successfully from '%s'!  [onCreateIndex = %d]", indexName, xmlFilename, onCreateIndex);
				object:register(true);

				local warningText = string.format("[GREENHOUSE - %s]  Attribute 'farmlandId' is invalid! Greenhouse will not operate correctly. 'farmlandId' should match area object is located at.", indexName);
				g_company.farmlandOwnerListener:addListener(object, farmlandId, warningText);
			else
				g_company.debug:writeOnCreate(object.debugData, "[GREENHOUSE - %s]  Failed to load from '%s'!", indexName, xmlFilename);
				object:delete();
			end;

			delete(xmlFile);
		else
			if xmlFile == nil then
				g_company.debug:writeModding(object.debugData, "[GREENHOUSE - %s]  XML File '%s' could not be loaded!", indexName, xmlFilename);
			else
				g_company.debug:writeModding(object.debugData, "[GREENHOUSE - %s]  XML Key containing  indexName '%s' could not be found in XML File '%s'", indexName, indexName, xmlFilename);
			end;
		end;
	else
		g_company.debug:print("  [LSMC - GlobalCompany] - [GC_Greenhouse]");
		if indexName == nil then
			g_company.debug:print("    ONCREATE: Trying to load 'GREENHOUSE' with nodeId name %s, attribute 'indexName' could not be found.", getName(transformId));
		else
			if xmlFilename == nil then
				g_company.debug:print("    ONCREATE: [GREENHOUSE - %s]  Attribute 'xmlFilename' is missing!", indexName);
			end;

			if farmlandId == nil then
				g_company.debug:print("    ONCREATE: [GREENHOUSE - %s]  Attribute 'farmlandId' is missing!", indexName);
			end;
		end;
	end;
end;

function GC_Greenhouse:new(isServer, isClient, customMt, xmlFilename, baseDirectory, customEnvironment)
	local self = Object:new(isServer, isClient, customMt or GC_Greenhouse_mt);

	self.xmlFilename = xmlFilename;
	self.baseDirectory = baseDirectory;
	self.customEnvironment = customEnvironment;


	self.debugData = g_company.debug:getDebugData(GC_Greenhouse.debugIndex, nil, customEnvironment);

	return self;
end;

function GC_Greenhouse:load(nodeId, xmlFile, xmlKey, indexName, isPlaceable)
	local canLoad, addMinuteChange, addHourChange = true, false, false;

	self.rootNode = nodeId;
	self.indexName = indexName;
	self.isPlaceable = isPlaceable;

	self.saveId = getXMLString(xmlFile, xmlKey .. "#saveId");
	if self.saveId == nil then
		self.saveId = "GC_Greenhouse_mt_" .. indexName;
	end;

	self.triggerManager = GC_TriggerManager:new(self);
	self.i3dMappings = GC_i3dLoader:loadI3dMapping(xmlFile, xmlKey .. ".i3dMappings");

	local animationManager = GC_AnimationManager:new(self.isServer, self.isClient);
	if animationManager:load(self.rootNode, self, xmlFile, xmlKey, true) then
		animationManager:register(true);
		self.animationManager = animationManager;
	else
		animationManager:delete();
	end;

	local doorKey = string.format("%s.door", xmlKey);
	if hasXMLProperty(xmlFile, doorKey) then
		self.doorTrigger = self.triggerManager:addTrigger(GC_PlayerTrigger, self.rootNode, self, xmlFile, doorKey, GC_Greenhouse.DOORTRIGGER, true);
		self.doorAnimationName = getXMLString(xmlFile, doorKey .. "#animationName");
	end;

	local greenhouseTriggerKey = string.format("%s.greenhouseTrigger", xmlKey);
	if hasXMLProperty(xmlFile, greenhouseTriggerKey) then
		self.greenhouseTrigger = self.triggerManager:addTrigger(GC_PlayerTrigger, self.rootNode, self, xmlFile, greenhouseTriggerKey, GC_Greenhouse.GREENHOUSETRIGGER);
	end;
	
	self.activableObjects = {};
	self.activableObjects[GC_Greenhouse.VENTILATOR] = g_company.activableObject:new(self.isServer, self.isClient);
	self.activableObjects[GC_Greenhouse.VENTILATOR]:load(self, GC_Greenhouse.VENTILATOR);
	self.activableObjects[GC_Greenhouse.VENTILATOR]:loadFromXML(xmlFile, greenhouseTriggerKey .. ".ventilator");
	self.activableObjects[GC_Greenhouse.VENTILATOR].canActivable = function (g) return true; end
	
	self.activableObjects[GC_Greenhouse.SELECTFILLTYPE] = g_company.activableObject:new(self.isServer, self.isClient);
	self.activableObjects[GC_Greenhouse.SELECTFILLTYPE]:load(self, GC_Greenhouse.SELECTFILLTYPE);
	self.activableObjects[GC_Greenhouse.SELECTFILLTYPE]:loadFromXML(xmlFile, greenhouseTriggerKey .. ".selectFilltype");
	self.activableObjects[GC_Greenhouse.SELECTFILLTYPE].canActivable = function (g) return g.state == GC_Greenhouse.STATE_PREPERATION or g.state == GC_Greenhouse.STATE_CANPLANT end
	
	self.activableObjects[GC_Greenhouse.PLANT] = g_company.activableObject:new(self.isServer, self.isClient);
	self.activableObjects[GC_Greenhouse.PLANT]:load(self, GC_Greenhouse.PLANT);
	self.activableObjects[GC_Greenhouse.PLANT]:loadFromXML(xmlFile, greenhouseTriggerKey .. ".doPlant");
	self.activableObjects[GC_Greenhouse.PLANT].canActivable = function (g) return g.state == GC_Greenhouse.STATE_CANPLANT end
	
	self.fillTypes = {};
    local i = 0;
    while true do
        local key = string.format("%s.fillTypes.fillType(%d)", xmlKey, i);
        if not hasXMLProperty(xmlFile, key) then
            break;
        end;
        
		local name = getXMLString(xmlFile, key .. "#name");
		
		local fillType = {};
		fillType.fillType = g_company.fillTypeManager:getFillTypeByName(name);
		fillType.needSeed = Utils.getNoNil(getXMLInt(xmlFile, key .. "#needSeed"), 50);
		fillType.growTime = Utils.getNoNil(getXMLInt(xmlFile, key .. "#growHour"), 72) * 60;
		fillType.growTemperature = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#growTemperature"), 25);
		fillType.harvestTime = Utils.getNoNil(getXMLInt(xmlFile, key .. "#harvestHour"), 72) * 60;

		local plant = getXMLString(xmlFile, key .. "#plant");
		if plant ~= nil and plant ~= "" then
			fillType.growObject = I3DUtil.indexToObject(self.rootNode, plant, self.i3dMappings);
			setVisibility(fillType.growObject, false);
		end;
		
		local fruits = getXMLString(xmlFile, key .. "#fruits");
		if fruits ~= nil and fruits ~= "" then
			fillType.fruitsObject = I3DUtil.indexToObject(self.rootNode, fruits, self.i3dMappings);
			setVisibility(fillType.fruitsObject, false);
		end;

		local dead = getXMLString(xmlFile, key .. "#dead");
		if dead ~= nil and dead ~= "" then
			fillType.deadObject = I3DUtil.indexToObject(self.rootNode, dead, self.i3dMappings);
			setVisibility(fillType.deadObject, false);
		end;

		fillType.movers = GC_Movers:new(self.isServer, self.isClient);
		fillType.movers:load(self.rootNode, self, xmlFile, key, self.baseDirectory, fillType.growTime, true);

        table.insert(self.fillTypes, fillType);
        i = i + 1;
    end;

	self.activeFillType = self.fillTypes[1].fillType.id;
	self.activableObjects[GC_Greenhouse.SELECTFILLTYPE]:setActivateText(string.format(g_company.languageManager:getText("GlobalCompanyPlaceable_Greenhouses_selectSeed"), g_company.fillTypeManager:getFillTypeLangNameById(self.activeFillType)));
	
	local palletExtendedUnloadTriggerKey = string.format("%s.palletExtendedUnloadTrigger", xmlKey);
	if hasXMLProperty(xmlFile, palletExtendedUnloadTriggerKey) then
		self.PALLETEXTENDEDUNLOADTRIGGER = self.triggerManager:addTrigger(GC_PALLETEXTENDEDUNLOADTRIGGER, self.rootNode, self, xmlFile, palletExtendedUnloadTriggerKey, GC_Greenhouse.PALLETEXTENDEDUNLOADTRIGGER);
	end;	

	local palletExtendedLoadTriggerKey = string.format("%s.palletExtendedLoadTrigger", xmlKey);
	if hasXMLProperty(xmlFile, palletExtendedLoadTriggerKey) then
		self.PALLETEXTENDEDUNLOADTRIGGER = self.triggerManager:addTrigger(GC_PALLETEXTENDEDUNLOADTRIGGER, self.rootNode, self, xmlFile, palletExtendedLoadTriggerKey, GC_Greenhouse.PALLETEXTENDEDLOADTRIGGER);
	end;	

	local waterTriggerKey = string.format("%s.watertrigger", xmlKey);
	if hasXMLProperty(xmlFile, waterTriggerKey) then
		self.waterTrigger = self.triggerManager:addTrigger(GC_UnloadingTrigger, self.rootNode, self, xmlFile, waterTriggerKey);
	end;
	
	self.waterFillLevel = 0;
	self.waterCapacity = getXMLFloat(xmlFile, waterTriggerKey .. "#capacity");

	self.growTime = 0;
	self.growTimeTarget = 0;
	self.harvestTime = 0;
	self.harvestTimeTarget = 0;
	
	self.currentTemperature = 15;
	self.targetTemperature = 15;
	self.state_ventilator = false;
	self.ventilatorRunningMinutes = 0;
	self.ventilatorCostPerMinute = Utils.getNoNil(getXMLInt(xmlFile, xmlKey .. "#ventilatorCostPerMinute"), 1);

	self.state = GC_Greenhouse.STATE_PREPERATION;

	g_currentMission.environment:addMinuteChangeListener(self);
	g_currentMission.environment:addHourChangeListener(self);
	
	self.greenhouseDirtyFlag = self:getNextDirtyFlag();
	
	self:addFillLevel(nil,5000); --only for test!

	return true;
end;

function GC_Greenhouse:delete()
	if not self.isPlaceable then
		g_currentMission:removeOnCreateLoadedObjectToSave(self);
	end;

	if self.isServer then
		g_currentMission.environment:removeMinuteChangeListener(self);
		g_currentMission.environment:removeHourChangeListener(self);
	end;

	if self.triggerManager ~= nil then
		self.triggerManager:removeAllTriggers();
	end;

	if self.animationManager ~= nil then
		self.animationManager:delete();
	end;

	if self.isClient then
	
		
	end;

	GC_Greenhouse:superClass().delete(self);
end;


function GC_Greenhouse:readStream(streamId, connection)
	GC_Greenhouse:superClass().readStream(self, streamId, connection);

	if connection:getIsServer() then
		if self.animationManager ~= nil then
			local animationManagerId = NetworkUtil.readNodeObjectId(streamId);
            self.animationManager:readStream(streamId, connection);
            g_client:finishRegisterObject(self.animationManager, animationManagerId);
		end;
		
		
	end;
end;

function GC_Greenhouse:writeStream(streamId, connection)
	GC_Greenhouse:superClass().writeStream(self, streamId, connection);

	if not connection:getIsServer() then
		if self.animationManager ~= nil then
			NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.animationManager));
            self.animationManager:writeStream(streamId, connection);
            g_server:registerObjectInStream(connection, self.animationManager);
		end;
		
		
	end;
end;

function GC_Greenhouse:loadFromXMLFile(xmlFile, key)
	

	return true;
end;

function GC_Greenhouse:saveToXMLFile(xmlFile, key, usedModNames)
	
	
end;

function GC_Greenhouse:update(dt)

end;

function GC_Greenhouse:onActivableObject(ref, isOn)
	if GC_Greenhouse.VENTILATOR == ref then
		self.state_ventilator = not self.state_ventilator;
	elseif GC_Greenhouse.SELECTFILLTYPE == ref then		
		local takeNext = false;
		for key, fillType in pairs(self.fillTypes) do
			if takeNext then
				self.activeFillType = fillType.fillType.id;
				takeNext = false;
				break;
			elseif fillType.fillType.id == self.activeFillType then
				takeNext = true;
			end;
		end;
		if takeNext then
			self.activeFillType = self.fillTypes[1].fillType.id;
		end;
		self.activableObjects[GC_Greenhouse.SELECTFILLTYPE]:setActivateText(string.format(g_company.languageManager:getText("GlobalCompanyPlaceable_Greenhouses_selectSeed"), g_company.fillTypeManager:getFillTypeLangNameById(self.activeFillType)));
		self:controlState();
	elseif GC_Greenhouse.PLANT == ref then	
		self:startGrow();
	end;
end;

function GC_Greenhouse:playerTriggerActivated(ref)
	if GC_Greenhouse.DOORTRIGGER == ref then
		if self.animationManager:getAnimationTime(self.doorAnimationName) > 0 then
			self.animationManager:setAnimationByState(self.doorAnimationName, false);
		else
			self.animationManager:setAnimationByState(self.doorAnimationName, true);
		end;
	end;
end;

function GC_Greenhouse:playerTriggerGetActivateText(ref)
	if GC_Greenhouse.DOORTRIGGER == ref then
		if self.animationManager:getAnimationTime(self.doorAnimationName) > 0 then
			return g_company.languageManager:getText("GlobalCompanyPlaceable_Greenhouses_closeDoor");
		else
			return g_company.languageManager:getText("GlobalCompanyPlaceable_Greenhouses_openDoor");
		end;
	end;
end;

function GC_Greenhouse:playerTriggerOnEnter(ref)
	if ref == GC_Greenhouse.GREENHOUSETRIGGER then
		self:updateControlls();
	end;
end;

function GC_Greenhouse:playerTriggerOnLeave(ref)
	if ref == GC_Greenhouse.GREENHOUSETRIGGER then
		for _, activableObject in pairs(self.activableObjects) do
			activableObject:removeActivatableObject();
		end;
	end;
end;

function GC_Greenhouse:onEnterPALLETEXTENDEDUNLOADTRIGGER(ref)
	if ref == GC_Greenhouse.PALLETEXTENDEDUNLOADTRIGGER then
		self:controlState();
	end;
end;

function GC_Greenhouse:onLeavePALLETEXTENDEDUNLOADTRIGGER(ref)
	if ref == GC_Greenhouse.PALLETEXTENDEDUNLOADTRIGGER then
		self:controlState();
	end;
end;

function GC_Greenhouse:addFillLevel(farmId, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, extraParamater)
	self.waterFillLevel = self.waterFillLevel + fillLevelDelta;
	self:controlState();
	self:updateControlls();
end;

function GC_Greenhouse:getFreeCapacity(fillTypeIndex, farmId, extraParamater)
	return self.waterCapacity - self.waterFillLevel;
end;

function GC_Greenhouse:minuteChanged()
	if self.isServer then
		local nightTemp, dayTemp = g_currentMission.environment.weather:getCurrentMinMaxTemperatures();
		local currentHour = g_currentMission.environment.currentHour;

		local startDayHour = 8;
		local startNightHour = 19;

		local factor = 0;
		if currentHour >= startDayHour and currentHour < startNightHour then
			if self.state_ventilator then
				factor = self:getVentilatorTempChange();
			else
				factor = 0.03;
			end;
		else
			if self.state_ventilator then
				factor = self:getVentilatorTempChange();
			else
				factor = -0.02;
			end;
		end;
		self.currentTemperature = self.currentTemperature + factor;

		if self.state_ventilator then
			self.ventilatorRunningMinutes = self.ventilatorRunningMinutes + 1;
		end;

		local fillType = self:getActiveFillType();
		if self.growTimeTarget > 0 then
			local factor, shouldDead = self:getTemperatureFactorGrow(fillType);
			if shouldDead then
				self.harvestTime = 0;
				self.harvestTimeTarget = 0;
				self:stopHarvest();
			else
				self.growTime = self.growTime + factor;
				fillType.movers:updateMovers(self.growTime);
				if self.growTime >= self.growTimeTarget then
					self.growTime = 0;
					self.growTimeTarget = 0;
					self:stopGrow();
				end;
			end;
		end;

		if self.harvestTimeTarget > 0 then
			local factor, shouldDead = self:getTemperatureFactorGrow(fillType);
			if shouldDead then
				self.harvestTime = 0;
				self.harvestTimeTarget = 0;
				self:stopHarvest();
			else
				self.harvestTime = self.harvestTime + factor;
				if self.harvestTime >= self.harvestTimeTarget then
					self.harvestTime = 0;
					self.harvestTimeTarget = 0;
					self:stopHarvest();
				end;
			end;
		end;
	end;
end

function GC_Greenhouse:getVentilatorTempChange()
	if self.targetTemperature > self.currentTemperature then
		return math.min(self.targetTemperature-self.currentTemperature, 0.01);
	elseif self.targetTemperature < self.currentTemperature then
		return math.min(self.currentTemperature-self.targetTemperature, 0.01) * -1;
	else
		return 0;
	end;
end

function GC_Greenhouse:getTemperatureFactorGrow(fillType)	
	local diff = self.currentTemperature - fillType.growTemperature;
	local f = 0;
	if math.abs(diff) > 4 then
		f = 0.2;
	elseif math.abs(diff) > 7 then
		f = 0.5;
	end;
	if diff >= 0 then
		return 1 + f;
	else
		return 1 - f;
	end;
end

function GC_Greenhouse:hourChanged()
	if self.ventilatorRunningMinutes > 0 then
		g_currentMission:addMoney(self.ventilatorRunningMinutes * self.ventilatorCostPerMinute * -1, self:getOwnerFarmId(), MoneyType.OTHER, true, false);
		self.ventilatorRunningMinutes = 0;
		
		
	end;
end;

function GC_Greenhouse:setState(newState, noEventSend)
	if self.state ~= newState then
		--event
		self.state = newState;
		self:updateControlls();
	end;
end

function GC_Greenhouse:controlState()
	if self.isServer then
		if self.state == GC_Greenhouse.STATE_PREPERATION then
			if self.waterFillLevel > 0 and self.PALLETEXTENDEDUNLOADTRIGGER:getFullFillLevelByFillType(self.activeFillType) >= self:getNeedSeedFromActiveFillType() then
				self:setState(GC_Greenhouse.STATE_CANPLANT);
			end;
		elseif self.state == GC_Greenhouse.STATE_CANPLANT then
			if self.PALLETEXTENDEDUNLOADTRIGGER:getFullFillLevelByFillType(self.activeFillType) < self:getNeedSeedFromActiveFillType() then
				self:setState(GC_Greenhouse.STATE_PREPERATION);
			end;
		elseif self.state == GC_Greenhouse.STATE_GROW then

		elseif self.state == GC_Greenhouse.STATE_HARVEST then

		elseif self.state == GC_Greenhouse.STATE_DEATH then

		elseif self.state == GC_Greenhouse.STATE_NEEDCLEAN then

		end;
	end;
end;

function GC_Greenhouse:updateControlls()
	if self.isClient and self.greenhouseTrigger:getPlayerInTrigger() then
		for _, activableObject in pairs(self.activableObjects) do
			if activableObject:isAdded() and not activableObject.canActivable(self) then
				activableObject:removeActivatableObject();   
			elseif not activableObject:isAdded() and activableObject.canActivable(self) then			
				activableObject:addActivatableObject();   
			end;
		end;
	end;
end

function GC_Greenhouse:startGrow(noEventSend)
	-- event
	local fillType = self:getActiveFillType();
	if self.isServer then
		local delta = fillType.needSeed;
		while delta > 0 do
			local _,object = next(self.PALLETEXTENDEDUNLOADTRIGGER:getObjectsByFillType(self.activeFillType));
			local neddLevel = math.min(object:getFillLevel(), delta);
			object:addFillLevel(neddLevel * -1);
			delta = delta - neddLevel;
		end;
		self.growTimeTarget = fillType.growTime;		
		setVisibility(fillType.growObject, true);
	end;
	self:setState(GC_Greenhouse.STATE_GROW, true);
end

function GC_Greenhouse:stopGrow(noEventSend)
	-- event
	local fillType = self:getActiveFillType();
	if self.isServer then
		self.harvestTimeTarget = fillType.harvestTime;
	end;

	if g_dedicatedServerInfo == nil then
		if fillType.fruitsObject ~= nil then
			setVisibility(fillType.growObject, false);
			setVisibility(fillType.fruitsObject, true);
		end;
	end;

	self:setState(GC_Greenhouse.STATE_HARVEST, true);
end

function GC_Greenhouse:stopHarvest(noEventSend)
	-- event
	if self.isServer then

	end;

	if g_dedicatedServerInfo == nil then
		local fillType = self:getActiveFillType();

		if fillType.fruitsObject ~= nil then
			setVisibility(fillType.fruitsObject, false);
		end;
		if fillType.deadObject ~= nil then
			setVisibility(fillType.growObject, false);
			setVisibility(fillType.deadObject, true);
		end;
	end;

	self:setState(GC_Greenhouse.STATE_DEATH, true);
end

function GC_Greenhouse:getActiveFillType()
	for _, fillType in pairs(self.fillTypes) do
		if fillType.fillType.id == self.activeFillType then
			return fillType;
		end;
	end;
end

function GC_Greenhouse:getNeedSeedFromActiveFillType()
	for _, fillType in pairs(self.fillTypes) do
		if fillType.fillType.id == self.activeFillType then
			return fillType.needSeed;
		end;
	end;
end


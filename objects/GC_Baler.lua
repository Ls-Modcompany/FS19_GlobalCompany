--
-- GlobalCompany - Objects - GC_Baler
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 26.02.2019
-- @Version: 1.0.1.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (26.02.2019):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--
--
-- ToDo:
--
--
--

Baler = {};
Baler_mt = Class(Baler, Object);
InitObjectClass(Baler, "Baler");

Baler.debugIndex = g_company.debug:registerScriptName("Baler");

Baler.PLAYERTRIGGER_MAIN = 0;
Baler.PLAYERTRIGGER_CLEAN = 1;

getfenv(0)["GC_Baler"] = Baler;

function Baler:onCreate(transformId)
	local indexName = getUserAttribute(transformId, "indexName");
	local xmlFilename = getUserAttribute(transformId, "xmlFile");
	if indexName ~= nil and xmlFilename ~= nil then
		local customEnvironment = g_currentMission.loadingMapModName;
		local baseDirectory = g_currentMission.loadingMapBaseDirectory;
		local object = Baler:new(g_server ~= nil, g_client ~= nil, nil, xmlFilename, baseDirectory, customEnvironment);
		local xmlFile, xmlKey = g_company.xmlUtils:getXMLFileAndKey(xmlFilename, baseDirectory, "globalCompany.balers.baler", indexName, "indexName")
		if xmlFile ~= nil and xmlKey ~= nil then
			if object:load(transformId, xmlFile, xmlKey, indexName, false) then
				local onCreateIndex = g_currentMission:addOnCreateLoadedObject(object);
				g_currentMission:addOnCreateLoadedObjectToSave(object);
				g_company.debug:writeOnCreate(object.debugData, "[Baler - %s]  Loaded successfully from '%s'!  [onCreateIndex = %d]", indexName, xmlFilename, onCreateIndex);
				object:register(true);
			else
				g_company.debug:writeOnCreate(object.debugData, "[Baler - %s]  Failed to load from '%s'!", indexName, xmlFilename);
				object:delete();
			end;
			delete(xmlFile);
		else
			if xmlFile == nil then
				g_company.debug:writeModding(object.debugData, "[Baler - %s]  XML File '%s' could not be loaded!", indexName, xmlFilename);
			else
				g_company.debug:writeModding(object.debugData, "[Baler - %s]  XML Key containing  indexName '%s' could not be found in XML File '%s'", indexName, indexName, xmlFilename);
			end;
		end;
	end;
end;

function Baler:new(isServer, isClient, customMt, xmlFilename, baseDirectory, customEnvironment)
	local self = Object:new(isServer, isClient, customMt or Baler_mt);

	self.xmlFilename = xmlFilename;
	self.baseDirectory = baseDirectory;
	self.customEnvironment = customEnvironment;

	self.debugData = g_company.debug:getDebugData(Baler.debugIndex, nil, customEnvironment);

	return self;
end;

function Baler:load(nodeId, xmlFile, xmlKey, indexName, isPlaceable)
	self.nodeId  = nodeId;
	self.indexName = indexName;
	self.isPlaceable = isPlaceable;

	self.triggerManager = GC_TriggerManager:new(self);
	self.i3dMappings = GC_i3dLoader:loadI3dMapping(xmlFile, xmlKey .. ".i3dMappings");

	self.saveId = getXMLString(xmlFile, xmlKey .. "#saveId");
	if self.saveId == nil then
		self.saveId = "baler_" .. indexName;
	end;
    
    local fillTypesKey = string.format("%s.fillTypes", xmlKey);
	if not hasXMLProperty(xmlFile, fillTypesKey) then
		--debug
		return false;
    end;
    
    self.fillLevel = 0;    
    self.capacity = Utils.getNoNil(getXMLInt(xmlFile, xmlKey .. "#capacity"), 50000);
    
    local capacities = {};
    self.fillTypes = {};
	local i = 0;
	while true do
		local fillTypeKey = string.format("%s.fillType(%d)", fillTypesKey, i);
		if not hasXMLProperty(xmlFile, fillTypeKey) then
			break;
        end;

        local fillTypeName = getXMLString(xmlFile, fillTypeKey .. "#name");
		if fillTypeName ~= nil then
			local fillType = g_fillTypeManager:getFillTypeByName(fillTypeName);
			if fillType ~= nil then
                self.fillTypes[fillType.index] = fillType;
                capacities[fillType.index] = self.capacity;
                if self.activeFillTypeIndex == nil then
                    self:setFillTyp(fillType.index);
                end;
			else
				if fillType == nil then
					g_company.debug:writeModding(self.debugData, "[BALER - %s] Unknown fillType ( %s ) found", indexName, fillTypeName);
				end;
			end;
		end;
		i = i + 1;
    end;

    self.unloadTrigger = self.triggerManager:loadTrigger(GC_UnloadingTrigger, self.nodeId , xmlFile, string.format("%s.unloadTrigger", xmlKey), {[1] = self.fillTypes[self.activeFillTypeIndex].index}, {[1] = "DISCHARGEABLE"});
    self.cleanHeap = self.triggerManager:loadTrigger(GC_DynamicHeap, self.nodeId , xmlFile, string.format("%s.cleanHeap", xmlKey), self.fillTypes[self.activeFillTypeIndex].name, nil, false);
    
	self.playerTriggerClean = self.triggerManager:loadTrigger(GC_PlayerTrigger, self.nodeId , xmlFile, string.format("%s.playerTriggerClean", xmlKey), Baler.PLAYERTRIGGER_CLEAN, true, g_company.languageManager:getText("GC_baler_cleaner"), true);
    
    self.movers = GC_Movers:new(self.isServer, self.isClient);
	self.movers:load(self.nodeId , self, xmlFile, xmlKey, self.baseDirectory, capacities);

	self.balerDirtyFlag = self:getNextDirtyFlag();

	return true;
end;

function Baler:delete()
	g_currentMission:removeOnCreateLoadedObjectToSave(self)

	if self.triggerManager ~= nil then
		self.triggerManager:unregisterAllTriggers();
	end;
	
	Baler:superClass().delete(self)
end;


function Baler:readStream(streamId, connection)
	Baler:superClass().readStream(self, streamId, connection);

    if connection:getIsServer() then
    
	end;
end;

function Baler:writeStream(streamId, connection)
	Baler:superClass().writeStream(self, streamId, connection);

    if not connection:getIsServer() then
    
	end;
end;

function Baler:readUpdateStream(streamId, timestamp, connection)
	Baler:superClass().readUpdateStream(self, streamId, timestamp, connection);

	if connection:getIsServer() then
        if streamReadBool(streamId) then
        
		end;
	end;
end;

function Baler:writeUpdateStream(streamId, connection, dirtyMask)
	Baler:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);

	if not connection:getIsServer() then
        if streamWriteBool(streamId, bitAND(dirtyMask, self.BalerDirtyFlag) ~= 0) then
        
		end;
	end;
end;

function Baler:loadFromXMLFile(xmlFile, key)

	return true;
end;

function Baler:saveToXMLFile(xmlFile, key, usedModNames)
	
end;

function Baler:update(dt)
	
end;

function Baler:addFillLevel(farmId, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, triggerId)
	self:setFillLevel(self.fillLevel + fillLevelDelta);
end;

function Baler:getFreeCapacity(dt)
	return self.capacity - self.fillLevel;
end;

function Baler:playerTriggerCanActivable(ref)
    if ref == Baler.PLAYERTRIGGER_CLEAN then
        if self.fillLevel >= 4000 or self.fillLevel == 0 then
            return false;
        end;
    end;
    return true;
end;

function Baler:playerTriggerActivated(ref)
    if ref == Baler.PLAYERTRIGGER_MAIN then

    elseif ref == Baler.PLAYERTRIGGER_CLEAN then
        if self.cleanHeap:getIsHeapEmpty() then
            if self.fillLevel < 4000 then
                self.cleanHeap.fillTypeIndex = self.activeFillTypeIndex;                    
                self.cleanHeap:updateDynamicHeap(self.fillLevel, false);
                self:setFillLevel(0);
            end;
        else
            -- heap is not empty
        end;
    end;
end;

function Baler:setFillLevel(level)    
    self.fillLevel = level;
    self.movers:updateMovers(level, self.activeFillTypeIndex);    
end;

function Baler:setFillTyp(fillTypeIndex)    
    self.activeFillTypeIndex = fillTypeIndex; 
end;
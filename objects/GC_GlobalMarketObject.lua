--
-- GlobalCompany - Objects - GC_GlobalMarketObject
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 25.01.2020
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (25.01.2020):
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

GC_GlobalMarketObject = {};
GC_GlobalMarketObject._mt = Class(GC_GlobalMarketObject, g_company.gc_class);
InitObjectClass(GC_GlobalMarketObject, "GC_GlobalMarketObject");

function GC_GlobalMarketObject:onCreate(transformId)
	local indexName = getUserAttribute(transformId, "indexName");
	local xmlFilename = getUserAttribute(transformId, "xmlFile");
	local farmlandId = getUserAttribute(transformId, "farmlandId");

	if indexName ~= nil and xmlFilename ~= nil and farmlandId ~= nil then
		local customEnvironment = g_currentMission.loadingMapModName;
		local baseDirectory = g_currentMission.loadingMapBaseDirectory;

		local object = GC_GlobalMarketObject:new(g_server ~= nil, g_client ~= nil, nil, xmlFilename, baseDirectory, customEnvironment);
		local xmlFile, xmlKey = g_company.xmlUtils:getXMLFileAndKey(xmlFilename, baseDirectory, "globalCompany.globalMarkets.globalMarket", indexName, "indexName")
		if xmlFile ~= nil and xmlKey ~= nil then
			if object:load(transformId, xmlFile, xmlKey, indexName, false) then
				local onCreateIndex = g_currentMission:addOnCreateLoadedObject(object);
				g_currentMission:addOnCreateLoadedObjectToSave(object);

				g_company.debug:writeOnCreate(object.debugData, "[GLOBALMARKETOBJECT - %s]  Loaded successfully from '%s'!  [onCreateIndex = %d]", indexName, xmlFilename, onCreateIndex);
				object:register(true);

				local warningText = string.format("[GLOBALMARKETOBJECT - %s]  Attribute 'farmlandId' is invalid! GLOBALMARKETOBJECT will not operate correctly. 'farmlandId' should match area object is located at.", indexName);
				g_company.farmlandOwnerListener:addListener(object, farmlandId, warningText);
			else
				g_company.debug:writeOnCreate(object.debugData, "[GLOBALMARKETOBJECT - %s]  Failed to load from '%s'!", indexName, xmlFilename);
				object:delete();
			end;

			delete(xmlFile);
		else
			if xmlFile == nil then
				g_company.debug:writeModding(object.debugData, "[GLOBALMARKETOBJECT - %s]  XML File '%s' could not be loaded!", indexName, xmlFilename);
			else
				g_company.debug:writeModding(object.debugData, "[GLOBALMARKETOBJECT - %s]  XML Key containing  indexName '%s' could not be found in XML File '%s'", indexName, indexName, xmlFilename);
			end;
		end;
	else
		g_company.debug:print("  [LSMC - GlobalCompany] - [GC_GlobalMarketObject]");
		if indexName == nil then
			g_company.debug:print("    ONCREATE: Trying to load 'GLOBALMARKETOBJECT' with nodeId name %s, attribute 'indexName' could not be found.", getName(transformId));
		else
			if xmlFilename == nil then
				g_company.debug:print("    ONCREATE: [GLOBALMARKETOBJECT - %s]  Attribute 'xmlFilename' is missing!", indexName);
			end;

			if farmlandId == nil then
				g_company.debug:print("    ONCREATE: [GLOBALMARKETOBJECT - %s]  Attribute 'farmlandId' is missing!", indexName);
			end;
		end;
	end;
end;

function GC_GlobalMarketObject:new(isServer, isClient, customMt, xmlFilename, baseDirectory, customEnvironment)    
    return GC_GlobalMarketObject:superClass():new(GC_GlobalMarketObject._mt, isServer, isClient, scriptDebugInfo, xmlFilename, baseDirectory, customEnvironment);
end;

function GC_GlobalMarketObject:load(nodeId, xmlFile, xmlKey, indexName, isPlaceable)
	GC_GlobalMarketObject:superClass().load(self)

	self.rootNode = nodeId;
	self.indexName = indexName;
	self.isPlaceable = isPlaceable;

	self.triggerManager = GC_TriggerManager:new(self);
    self.i3dMappings = GC_i3dLoader:loadI3dMapping(xmlFile, xmlKey .. ".i3dMappings");
        
	self.saveId = getXMLString(xmlFile, xmlKey .. "#saveId");
	if self.saveId == nil then
		self.saveId = "DynamicStorage_" .. indexName;
    end;
    
   
    local unloadingTriggerKey = string.format("%s.unloadingTrigger", xmlKey);    
    local unloadingTrigger = self.triggerManager:addTrigger(GC_UnloadingTrigger, self.rootNode, self, xmlFile, unloadingTriggerKey);
    if unloadingTrigger ~= nil then
		unloadingTrigger.allowEverybodyAccess = true
        self.unloadingTrigger = unloadingTrigger
	end
	
    local unloadingTriggerLiquidKey = string.format("%s.unloadingTriggerLiquid", xmlKey);    
    local unloadingTriggerLiquid = self.triggerManager:addTrigger(GC_UnloadingTrigger, self.rootNode, self, xmlFile, unloadingTriggerLiquidKey);
    if unloadingTriggerLiquid ~= nil then
		unloadingTriggerLiquid.allowEverybodyAccess = true
        self.unloadingTriggerLiquid = unloadingTriggerLiquid
	end
	
    local unloadingTriggerPalletBaleKey = string.format("%s.unloadingTriggerPalletBale", xmlKey);    
    local unloadingTriggerPalletBale = self.triggerManager:addTrigger(GC_UnloadingTrigger, self.rootNode, self, xmlFile, unloadingTriggerPalletBaleKey);
    if unloadingTriggerPalletBale ~= nil then
		unloadingTriggerPalletBale.allowEverybodyAccess = true
        self.unloadingTriggerPalletBale = unloadingTriggerPalletBale
	end	

    local loadingTriggerKey = string.format("%s.loadingTrigger", xmlKey)
    local loadingTrigger = self.triggerManager:addTrigger(GC_LoadingTrigger, self.rootNode, self, xmlFile, loadingTriggerKey, {}, false, true);
    if loadingTrigger ~= nil then        
		loadingTrigger.onActivateObject = function() self:onActivateObjectLoadingTrigger(loadingTrigger) end
		loadingTrigger.extraParamater = {g_company.globalMarket.fillTypeTypes.SILO}
		loadingTrigger.getIsActivatable = g_company.utils.appendedFunction(loadingTrigger.getIsActivatable, self.loadingTriggerGetIsActivatable, self)
		loadingTrigger.allowEverybodyAccess = true
		self.loadingTrigger = loadingTrigger
	end

    local loadingTrigger2Key = string.format("%s.loadingTrigger2", xmlKey)
    local loadingTrigger2 = self.triggerManager:addTrigger(GC_LoadingTrigger, self.rootNode, self, xmlFile, loadingTrigger2Key, {}, false, true);
    if loadingTrigger2 ~= nil then        
		loadingTrigger2.onActivateObject = function() self:onActivateObjectLoadingTrigger(loadingTrigger2) end
		loadingTrigger2.extraParamater = {g_company.globalMarket.fillTypeTypes.CONVEYOR, g_company.globalMarket.fillTypeTypes.CONVEYORANDBALE}
		loadingTrigger2.getIsActivatable = g_company.utils.appendedFunction(loadingTrigger2.getIsActivatable, self.loadingTriggerGetIsActivatable, self)
		loadingTrigger2.allowEverybodyAccess = true
		self.loadingTrigger2 = loadingTrigger2
	end
	
    local loadingTriggerLiquidKey = string.format("%s.loadingTriggerLiquid", xmlKey)
    local loadingTriggerLiquid = self.triggerManager:addTrigger(GC_LoadingTrigger, self.rootNode, self, xmlFile, loadingTriggerLiquidKey, {}, false, true);
    if loadingTriggerLiquid ~= nil then        
		loadingTriggerLiquid.onActivateObject = function() self:onActivateObjectLoadingTrigger(loadingTriggerLiquid) end
		loadingTriggerLiquid.extraParamater = {g_company.globalMarket.fillTypeTypes.LIQUID}
		loadingTriggerLiquid.getIsActivatable = g_company.utils.appendedFunction(loadingTriggerLiquid.getIsActivatable, self.loadingTriggerGetIsActivatable, self)
		loadingTriggerLiquid.allowEverybodyAccess = true
		self.loadingTriggerLiquid = loadingTriggerLiquid
	end
	
    --local vehicleTriggerKey = string.format("%s.vehicleTrigger", xmlKey)
    --local vehicleTrigger = self.triggerManager:addTrigger(GC_VehicleTrigger, self.rootNode, self, xmlFile, vehicleTriggerKey);
    --if vehicleTrigger ~= nil then        
	--	self.vehicleTrigger = vehicleTrigger
	--end
	
	local palletOutput = self.triggerManager:addTrigger(GC_ObjectSpawner, self.rootNode, self, xmlFile, xmlKey)
	if palletOutput ~= nil then   
		self.palletOutput = palletOutput
	end
  
	self.playerTrigger = self.triggerManager:addTrigger(GC_PlayerTrigger, self.rootNode, self , xmlFile, string.format("%s.playerTrigger", xmlKey), nil, true, g_company.languageManager:getText("GC_globalMarket_openGui"))
	self.playerTrigger.allowEverybodyAccess = true

	local dataKey = xmlKey .. ".data"
	self.data = {}
	self.data.capacityPerFillType = getXMLInt(xmlFile, dataKey .. ".capacityPerFillType")

	self.fillLevels = {}   
    

    self.globalMarketDirtyFlag = self:getNextDirtyFlag();
        
    g_company.addRaisedUpdateable(self);

	return true;
end;

function GC_GlobalMarketObject:finalizePlacement()
    GC_GlobalMarketObject:superClass().finalizePlacement(self)	
	
	self.marketId = g_company.globalMarket:registerMarket(self)
	g_company.globalMarket:addOnChangeFillTypes(self, self.onChangeFillTypesEvent)
	
    self.eventId_onChangeFillTypes = self:registerEvent(self, self.onChangeFillTypesEvent, true, true)
    self.eventId_sellBuyOnMarket = self:registerEvent(self, self.sellBuyOnMarketEvent, false, true)
    self.eventId_spawnPallets = self:registerEvent(self, self.spawnPalletsEvent, false, true)
    self.eventId_sendFillLevel = self:registerEvent(self, self.sendFillLevelEvent, false, true)
end

function GC_GlobalMarketObject:delete()    
	if not self.isPlaceable then
		g_currentMission:removeOnCreateLoadedObjectToSave(self);
	end;
	if self.triggerManager ~= nil then
		self.triggerManager:removeAllTriggers();
	end;
	
	if self.marketId ~= nil then
		g_company.globalMarket:unregisterMarket(self.marketId)
	end
	
	g_company.removeRaisedUpdateable(self)
        
	GC_GlobalMarketObject:superClass().delete(self);
end;

function GC_GlobalMarketObject:readStream(streamId, connection)
	GC_GlobalMarketObject:superClass().readStream(self, streamId, connection);

	if connection:getIsServer() then
		if self.triggerManager ~= nil then
			self.triggerManager:readStream(streamId, connection)
		end
		
		self.fillLevels = {}
		local num = streamReadInt8(streamId)
		for i=1, num do
			local fillTypeIndex = streamReadInt16(streamId)			
			self.fillLevels[fillTypeIndex] = {}
			local numFarms = streamReadInt8(streamId)
			for j=1, numFarms do
				local farmId = streamReadInt8(streamId)
				local level = streamReadInt32(streamId)
				self.fillLevels[fillTypeIndex][farmId] = level	
			end
		end
    end
end

function GC_GlobalMarketObject:writeStream(streamId, connection)
	GC_GlobalMarketObject:superClass().writeStream(self, streamId, connection);

	if not connection:getIsServer() then
		if self.triggerManager ~= nil then
			self.triggerManager:writeStream(streamId, connection)
		end

		streamWriteInt8(streamId, g_company.utils.getTableLength(self.fillLevels))
		for fillTypeIndex, farms in pairs(self.fillLevels) do
			streamWriteInt16(streamId, fillTypeIndex)
			streamWriteInt8(streamId, g_company.utils.getTableLength(farms))
			for farmId, level in pairs(farms) do
				streamWriteInt8(streamId, farmId)
				streamWriteInt32(streamId, level)
			end
		end
	end
end

function GC_GlobalMarketObject:readUpdateStream(streamId, timestamp, connection)
	GC_GlobalMarketObject:superClass().readUpdateStream(self, streamId, timestamp, connection);

	if connection:getIsServer() then
        if streamReadBool(streamId) then
			self.fillLevels = {}
            local num = streamReadInt8(streamId)
			for i=1, num do
				local fillTypeIndex = streamReadInt16(streamId)			
				self.fillLevels[fillTypeIndex] = {}
				local numFarms = streamReadInt8(streamId)
				for j=1, numFarms do
					local farmId = streamReadInt8(streamId)
					local level = streamReadInt32(streamId)
					self.fillLevels[fillTypeIndex][farmId] = level	
				end
			end            
        end		
	end
end

function GC_GlobalMarketObject:writeUpdateStream(streamId, connection, dirtyMask)
	GC_GlobalMarketObject:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);

	if not connection:getIsServer() then
		if streamWriteBool(streamId, bitAND(dirtyMask, self.globalMarketDirtyFlag) ~= 0) then
            streamWriteInt8(streamId, g_company.utils.getTableLength(self.fillLevels))
			for fillTypeIndex, farms in pairs(self.fillLevels) do
				streamWriteInt16(streamId, fillTypeIndex)
				streamWriteInt8(streamId, g_company.utils.getTableLength(farms))
				for farmId, level in pairs(farms) do
					streamWriteInt8(streamId, farmId)
					streamWriteInt32(streamId, level)
				end
			end
        end
	end
end

function GC_GlobalMarketObject:loadFromXMLFile(xmlFile, key)
	GC_GlobalMarketObject:superClass().loadFromXMLFile(self, xmlFile, key)
    if not self.isPlaceable then
		key = string.format("%s.globalMarket", key);
    end

    local index = 0;
	while true do
		local levelKey = string.format(key .. ".levels.level(%d)", index)
		if not hasXMLProperty(xmlFile, levelKey) then
			break
		end

        local fillTypeIndex = getXMLInt(xmlFile, levelKey .. "#fillTypeIndex")
		local fillType = getXMLString(xmlFile, levelKey .. "#fillType")
		if fillType ~= nil then
			fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillType)
		end
		if fillTypeIndex ~= nil then
			local farmId = getXMLInt(xmlFile, levelKey .. "#farmId")
			local level = getXMLInt(xmlFile, levelKey .. "#level")

			if self.fillLevels[fillTypeIndex] == nil then
				self.fillLevels[fillTypeIndex] = {}
			end
			self.fillLevels[fillTypeIndex][farmId] = level
		end		
		
        index = index + 1
	end  

	return true;
end;

function GC_GlobalMarketObject:saveToXMLFile(xmlFile, key, usedModNames)
	GC_GlobalMarketObject:superClass().saveToXMLFile(self, xmlFile, key, usedModNames)
	if not self.isPlaceable then
		key = string.format("%s.globalMarket", key);
		setXMLInt(xmlFile, key .. "#farmId", self:getOwnerFarmId());
	end
	
	local index = 0
	for fillTypeIndex, tab in pairs(self.fillLevels) do
		for farmId, level in pairs(tab) do
			local levelKey = string.format("%s.levels.level(%d)", key, index);
			setXMLString(xmlFile, levelKey .. "#fillType", g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex))
			setXMLInt(xmlFile, levelKey .. "#farmId", farmId);
			setXMLInt(xmlFile, levelKey .. "#level", level);
			index = index + 1;
		end
	end
end

function GC_GlobalMarketObject:update(dt)     
	GC_GlobalMarketObject:superClass().update(self, dt)
end;

function GC_GlobalMarketObject:playerTriggerCanAddActivatable()
    return true
end

function GC_GlobalMarketObject:playerTriggerActivated()
	if g_company.globalMarket:getIsOnline() then
		g_company.gui:openGuiWithData("gc_globalMarket", false, self)
	else
		if g_company.globalMarket.haveFile then
			g_gui:showInfoDialog({text = g_company.languageManager:getText("GC_globalMarket_externIsFalseVersion")})
		else
			g_gui:showInfoDialog({text = g_company.languageManager:getText("GC_globalMarket_externIsOffline")})
		end
	end
end

function GC_GlobalMarketObject:onChangeFillTypesEvent(fillTypes, noEventSend)	
	if not self.isServer and not g_company.globalMarket:getIsOnline() then
		return
	end

    self:raiseEvent(self.eventId_onChangeFillTypes, fillTypes, noEventSend)
	for fillTypeIndex,_ in pairs(fillTypes[g_company.globalMarket.fillTypeTypes.SILO]) do
		self.unloadingTrigger:setAcceptedFillTypeState(fillTypeIndex, true)
		self.unloadingTriggerPalletBale:setAcceptedFillTypeState(fillTypeIndex, true)
	end
	for fillTypeIndex,_ in pairs(fillTypes[g_company.globalMarket.fillTypeTypes.LIQUID]) do
		self.unloadingTriggerLiquid:setAcceptedFillTypeState(fillTypeIndex, true)
		self.unloadingTriggerPalletBale:setAcceptedFillTypeState(fillTypeIndex, true)
	end	
	for fillTypeIndex,_ in pairs(fillTypes[g_company.globalMarket.fillTypeTypes.CONVEYOR]) do
		self.unloadingTrigger:setAcceptedFillTypeState(fillTypeIndex, true)
		self.unloadingTriggerPalletBale:setAcceptedFillTypeState(fillTypeIndex, true)
	end
	for fillTypeIndex,_ in pairs(fillTypes[g_company.globalMarket.fillTypeTypes.PALLET]) do
		self.unloadingTriggerPalletBale:setAcceptedFillTypeState(fillTypeIndex, true)
	end
	for fillTypeIndex,_ in pairs(fillTypes[g_company.globalMarket.fillTypeTypes.BALE]) do
		self.unloadingTriggerPalletBale:setAcceptedFillTypeState(fillTypeIndex, true)
	end
	for fillTypeIndex,_ in pairs(fillTypes[g_company.globalMarket.fillTypeTypes.CONVEYORANDBALE]) do
		self.unloadingTrigger:setAcceptedFillTypeState(fillTypeIndex, true)
		self.unloadingTriggerPalletBale:setAcceptedFillTypeState(fillTypeIndex, true)
	end

	if self.isServer and not self.isClient then
		g_company.globalMarket:setFillTypesForServer(fillTypes)
	end
end

function GC_GlobalMarketObject:getIsFillTypeAllowed(fillTypeIndex, triggerId, trigger) 
	local fillTypeName = string.upper(g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex))
	if g_company.globalMarket.fillTypeMapping[fillTypeName] ~= nil then
		fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(g_company.globalMarket.fillTypeMapping[fillTypeName])
	end  
	return trigger.fillTypes[fillTypeIndex]
end

--call from unloading trigger
function GC_GlobalMarketObject:getFreeCapacity(fillTypeIndex, farmId, triggerId)    
	local fillTypeName = string.upper(g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex))
	if g_company.globalMarket.fillTypeMapping[fillTypeName] ~= nil then
		fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(g_company.globalMarket.fillTypeMapping[fillTypeName])
	end    
	if self.fillLevels[fillTypeIndex] == nil then
		return self.data.capacityPerFillType
	end

	local completeLevel = 0
	for _,level in pairs(self.fillLevels[fillTypeIndex]) do
		completeLevel = completeLevel + level
	end
	return self.data.capacityPerFillType - completeLevel
end

function GC_GlobalMarketObject:addFillLevelFromClient(farmId, fillLevel, fillTypeIndex)
	self:sendFillLevelEvent({farmId, fillLevel, fillTypeIndex})	
end

function GC_GlobalMarketObject:sendFillLevelEvent(data, noEventSend)
    self:raiseEvent(self.eventId_sendFillLevel, data, noEventSend)
	if self.isServer then
		self:addFillLevel(data[1], data[2], data[3])	
	end	
end

--call from unloading trigger
function GC_GlobalMarketObject:addFillLevel(farmId, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, triggerId)	
	if self.isServer then
		local fillTypeName = string.upper(g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex))
		if g_company.globalMarket.fillTypeMapping[fillTypeName] ~= nil then
			fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(g_company.globalMarket.fillTypeMapping[fillTypeName])
		end
		if self.fillLevels[fillTypeIndex] == nil then
			self.fillLevels[fillTypeIndex] = {}
		end
		if self.fillLevels[fillTypeIndex][farmId] == nil then
			self.fillLevels[fillTypeIndex][farmId] = 0
		end
		self.fillLevels[fillTypeIndex][farmId] = self.fillLevels[fillTypeIndex][farmId] + fillLevelDelta  	

		self:raiseDirtyFlags(self.globalMarketDirtyFlag)
	end
end

--call from load trigger
function GC_GlobalMarketObject:removeFillLevel(farmId, fillLevelDelta, fillTypeIndex, extraParamater)
	self.fillLevels[fillTypeIndex][farmId] = self.fillLevels[fillTypeIndex][farmId] - fillLevelDelta  
	if self.isServer then
		self:raiseDirtyFlags(self.globalMarketDirtyFlag)
	end	
	return self.fillLevels[fillTypeIndex][farmId]
end

--call from load trigger
function GC_GlobalMarketObject:getProvidedFillTypes(triggerId)
	return g_company.globalMarket:getProvidedFillTypes(triggerId)
end

--call from load trigger
function GC_GlobalMarketObject:getAllProvidedFillLevels(farmId)
	return {}, 0
end

--call from load trigger
function GC_GlobalMarketObject:getProvidedFillLevel(fillTypeIndex, farmId, extraParamater)
	if self.fillLevels[fillTypeIndex] ~= nil and self.fillLevels[fillTypeIndex][farmId] ~= nil then
		return self.fillLevels[fillTypeIndex][farmId]
	end
	return 0
end

function GC_GlobalMarketObject:loadingTriggerGetIsActivatable(trigger, val)
	if val then
		local items = {}

		local farmId = g_currentMission:getFarmId()

		for fillTypeIndex, levels in pairs(self.fillLevels) do
			
			local triggerAllow = trigger.validFillableObject:getFillUnitAllowsFillType(trigger.validFillableFillUnitIndex, fillTypeIndex)         
			local isForTriggerAvailable = g_company.globalMarket:getIsFillTypeFromType(fillTypeIndex, trigger.extraParamater)   
			if levels[farmId] ~= nil and levels[farmId] > 0 and triggerAllow and isForTriggerAvailable then
				table.insert(items, fillTypeIndex)
			end
		end

		local len = g_company.utils.getTableLength(items)
		if len == 0 then
			trigger.gcgm_guiData = {openGui = false}
			val = false
		elseif len == 1 then
			trigger.gcgm_guiData = {openGui = false, fillTypeIndex = items[1]}
		else
			trigger.gcgm_guiData = {openGui = true}
		end
	end
	return val
end

function GC_GlobalMarketObject:onActivateObjectLoadingTrigger(trigger)
	g_currentMission:addActivatableObject(trigger)
	if not trigger.isLoading and trigger.gcgm_guiData ~= nil then
		if trigger.gcgm_guiData.openGui then
			local gui = g_company.gui:openGuiWithData("gc_globalMarketLoading", false, self, trigger)
			gui.classGui:setCloseCallback(self, self.loadingTriggerOnActivateObjectCallback)
		else
			self:onSetSelectedFillTypeIndex(trigger, trigger.gcgm_guiData.fillTypeIndex)
			self:loadingTriggerOnActivateObjectCallback(trigger)
		end
    else
        trigger:setIsLoading(false)
	end
end

function GC_GlobalMarketObject:onSetSelectedFillTypeIndex(trigger, fillTypeIndex)        
    trigger.selectedFillTypeIndex = fillTypeIndex
end

function GC_GlobalMarketObject:loadingTriggerOnActivateObjectCallback(trigger)
	trigger:onFillTypeSelection(trigger.selectedFillTypeIndex)
end

function GC_GlobalMarketObject:sellBuyOnMarket(fillTypeIndex, fillLevelDelta, farmId, sell)
    self:sellBuyOnMarketEvent({fillTypeIndex, fillLevelDelta, farmId, sell})
end

function GC_GlobalMarketObject:sellBuyOnMarketEvent(data, noEventSend)
    self:raiseEvent(self.eventId_sellBuyOnMarket, data, noEventSend)
	if self.isServer then
		--local delta = 0
		if data[4] then
			--delta = math.min(self.fillLevels[data[1]][data[3]], data[2])
			self.fillLevels[data[1]][data[3]] = self.fillLevels[data[1]][data[3]] - data[2]
			self:raiseDirtyFlags(self.globalMarketDirtyFlag)
		--else
		--	delta = data[2]
		end
	end

	if self.isClient then
		g_company.globalMarket:sellBuyOnMarket(data[1], math.ceil(data[2]), data[4], self.marketId)
	end
end

function GC_GlobalMarketObject:onSetFarmlandStateChanged(farmId)
	self:setOwnerFarmId(farmId, false)
end

function GC_GlobalMarketObject:setOwnerFarmId(ownerFarmId, noEventSend)
	GC_GlobalMarketObject:superClass().setOwnerFarmId(self, ownerFarmId, noEventSend);
	if self.triggerManager ~= nil then
		self.triggerManager:setAllOwnerFarmIds(ownerFarmId, noEventSend)
	end;
end;

function GC_GlobalMarketObject:spawnPallets(fillTypeIndex, numPallets, farmId, capacityPerPallet, maxNumBales, asRoundBale)
	--local farmId = g_currentMission:getFarmId()
    self:spawnPalletsEvent({fillTypeIndex, numPallets, farmId, capacityPerPallet, maxNumBales, asRoundBale})	
end

function GC_GlobalMarketObject:spawnPalletsEvent(data, noEventSend)
    self:raiseEvent(self.eventId_spawnPallets, data, noEventSend)
	if self.isServer then
		local fillTypeIndex = data[1]
		local numPallets = data[2] 
		local farmId = data[3] 
		local capacityPerPallet = data[4]
		local maxNumBales = data[5] 
		local asRoundBale = data[6]

		local palletFilename = g_company.globalMarket:getPalletFilenameFromFillTypeIndex(fillTypeIndex) 

		local isPallet = true
		if palletFilename == nil then
			palletFilename = g_company.globalMarket.baleToFilename[string.upper(g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex))]
			if asRoundBale then
                palletFilename = palletFilename[1]
            else
                palletFilename = palletFilename[2]
            end
			isPallet = false
		end
		local width, length, _, _ = StoreItemUtil.getSizeValues(palletFilename, "vehicle", 0, {})
		
		local numberSpawned = 0
		local spawnedFillLevel = 0
		if isPallet then
			local fullSpawn = math.min(math.floor(self.fillLevels[fillTypeIndex][farmId] / capacityPerPallet), numPallets)
			
			local object = {
				filename = palletFilename,
				fillUnitIndex = 1,
				fillLevel = capacityPerPallet,
				fillTypeIndex = fillTypeIndex,
				width = width,
				length = length,
				offset = 0.5,
				farmId = farmId
			}

			numberSpawned = self.palletOutput:spawnByObjectInfo(object, fullSpawn)
			spawnedFillLevel = capacityPerPallet * numberSpawned

			if fullSpawn < numPallets and isPallet then
				object.fillLevel = self.fillLevels[fillTypeIndex][farmId] - (numberSpawned * capacityPerPallet)
				numberSpawned = numberSpawned + self.palletOutput:spawnByObjectInfo(object, 1)
				spawnedFillLevel = spawnedFillLevel + object.fillLevel
			end
		else
			local fullSpawn = math.min(math.floor(self.fillLevels[fillTypeIndex][farmId] / capacityPerPallet), numPallets)
			local fullSpawnBales = math.floor(fullSpawn/maxNumBales)
			local baleAmount = math.min(fullSpawn, maxNumBales)
			
			local ownFillLevel = nil
			if capacityPerPallet ~= 4000 then --4000 is the default for bales
				ownFillLevel = capacityPerPallet
			end

			local object = {
				filename = palletFilename,
				fillUnitIndex = 1,
				fillLevel = nil,
				fillTypeIndex = fillTypeIndex,
				width = width,
				length = length,
				offset = 0.5,
				farmId = farmId
			}

			object.configurations = {}
			object.configurations["buyableBaleAmount"] = baleAmount

			local object2 = nil
			if fullSpawn > fullSpawnBales * baleAmount then
				object2 = {
					filename = palletFilename,
					fillUnitIndex = 1,
					fillLevel = nil,
					fillTypeIndex = fillTypeIndex,
					width = width,
					length = length,
					offset = 0.5
				}
	
				object2.configurations = {}
				object2.configurations["buyableBaleAmount"] = fullSpawn - fullSpawnBales * baleAmount
			end

			if object2 ~= nil then
				numberSpawned = self.palletOutput:spawnByObjectInfo(object, fullSpawnBales, false, object2, 1, ownFillLevel)
				spawnedFillLevel = capacityPerPallet * fullSpawnBales * baleAmount
			else
				numberSpawned = self.palletOutput:spawnByObjectInfo(object, fullSpawnBales, false, nil, nil, ownFillLevel)
				spawnedFillLevel = capacityPerPallet * (fullSpawn - fullSpawnBales * baleAmount)
			end
			spawnedFillLevel = spawnedFillLevel + capacityPerPallet * numberSpawned * baleAmount

		end

		self:removeFillLevel(farmId, spawnedFillLevel, fillTypeIndex)
	end
end

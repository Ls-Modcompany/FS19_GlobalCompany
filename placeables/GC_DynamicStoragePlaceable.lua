--
-- GlobalCompany - Placeables - GC_DynamicStoragePlaceable
--
-- @Interface: --
-- @Author: LS-Modcompany / GtX / kevink98
-- @Date: 02.06.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (02.06.2019):
-- 		- initial fs19 (GtX / kevink98)
--
--
-- Notes:
--	
--
-- ToDo:
--
--

GC_DynamicStoragePlaceable = {};

local GC_DynamicStoragePlaceable_mt = Class(GC_DynamicStoragePlaceable, Placeable);
InitObjectClass(GC_DynamicStoragePlaceable, "GC_DynamicStoragePlaceable");

GC_DynamicStoragePlaceable.debugIndex = g_company.debug:registerScriptName("DynamicStoragePlaceable");

getfenv(0)["GC_DynamicStoragePlaceable"] = GC_DynamicStoragePlaceable;

function GC_DynamicStoragePlaceable:new(isServer, isClient, customMt)
	local self = Placeable:new(isServer, isClient, customMt or GC_DynamicStoragePlaceable_mt);
	
	self.debugData = nil;
	self.dynamicStorages = {};

	registerObjectClassName(self, "GC_DynamicStoragePlaceable");	
	return self;
end;

function GC_DynamicStoragePlaceable:load(xmlFilename, x,y,z, rx,ry,rz, initRandom)
	if not GC_DynamicStoragePlaceable:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, initRandom) then
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_DynamicStoragePlaceable.debugIndex, nil, self.customEnvironment);

	local filenameToUse = xmlFilename;
	local xmlFile = loadXMLFile("TempPlaceableXML", xmlFilename);
	local canLoad = xmlFile ~= nil and xmlFile ~= 0;
	
	if canLoad then
		local placeableKey = "placeable.dynamicStorages";
		local externalXML = getXMLString(xmlFile, placeableKey .. "#xmlFilename");
		if externalXML ~= nil then
			externalXML = Utils.getFilename(externalXML, self.baseDirectory);
			filenameToUse = externalXML;
			if fileExists(filenameToUse) then
				delete(xmlFile);
				
				placeableKey = "globalCompany.dynamicStorages";
				xmlFile = loadXMLFile("TempExternalXML", filenameToUse);
				canLoad = xmlFile ~= nil and xmlFile ~= 0;
			else
				canLoad = false;
			end;
		end;

		if canLoad then
			local usedIndexNames = {};
			
			local i = 0;
			while true do
				local key = string.format("%s.dynamicStorage(%d)", placeableKey, i);
				if not hasXMLProperty(xmlFile, key) then
					break;
				end;

				local indexName = getXMLString(xmlFile, key .. "#indexName");
				if indexName ~= nil and usedIndexNames[indexName] == nil then
					usedIndexNames[indexName] = key;
					local storage = GC_DynamicStorage:new(self.isServer, self.isClient, nil, filenameToUse, self.baseDirectory, self.customEnvironment);
					if storage:load(self.nodeId, xmlFile, key, indexName, true) then
						storage:setOwnerFarmId(self:getOwnerFarmId(), false);
						table.insert(self.dynamicStorages, storage);
					else
						storage:delete();
						storage = nil;
						canLoad = false;

						g_company.debug:writeError(self.debugData, "Can not load storage '%s' from XML file '%s'!", indexName, filenameToUse);
						break;
					end;
				else
					if indexName == nil then
						g_company.debug:writeError(self.debugData, "Can not load storage. 'indexName' is missing. From XML file '%s'!", filenameToUse);
					else
						local usedKey = usedIndexNames[indexName];
						g_company.debug:writeError(self.debugData, "Duplicate indexName '%s' found! indexName is used at '%s' in XML file '%s'!", indexName, usedKey, filenameToUse);
					end;
				end;

				i = i + 1;
			end;
		else
			g_company.debug:writeError(self.debugData, "Cannot load placeable type [GC_DynamicStoragePlaceable]! Unable to load XML file '%s'.", filenameToUse);
		end;

		delete(xmlFile);
	else
		g_company.debug:writeError(self.debugData, "Cannot load placeable type [GC_DynamicStoragePlaceable]! Unable to load XML file '%s'.", filenameToUse);
	end;

	return canLoad;
end;

function GC_DynamicStoragePlaceable:finalizePlacement()
	GC_DynamicStoragePlaceable:superClass().finalizePlacement(self)

	for _, storage in ipairs(self.dynamicStorages) do
		storage:register(true);
	end;
end;

function GC_DynamicStoragePlaceable:delete()
	for id, storage in ipairs(self.dynamicStorages) do
		storage:delete();
	end;

	unregisterObjectClassName(self);
	GC_DynamicStoragePlaceable:superClass().delete(self);
end;

function GC_DynamicStoragePlaceable:readStream(streamId, connection)
    GC_DynamicStoragePlaceable:superClass().readStream(self, streamId, connection);
    
	if connection:getIsServer() then
        for _, storage in ipairs(self.dynamicStorages) do
            local factoryId = NetworkUtil.readNodeObjectId(streamId);
            storage:readStream(streamId, connection);
            g_client:finishRegisterObject(storage, factoryId);
        end;
    end;
end;

function GC_DynamicStoragePlaceable:writeStream(streamId, connection)
    GC_DynamicStoragePlaceable:superClass().writeStream(self, streamId, connection);
    
	if not connection:getIsServer() then
        for _, storage in ipairs(self.dynamicStorages) do
            NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(storage));
            storage:writeStream(streamId, connection);
            g_server:registerObjectInStream(connection, storage);
        end;
    end;
end;

function GC_DynamicStoragePlaceable:collectPickObjects(node)
	if g_currentMission.nodeToObject[node] == nil then
		GC_DynamicStoragePlaceable:superClass().collectPickObjects(self, node);
	end;
end;

function GC_DynamicStoragePlaceable:loadFromXMLFile(xmlFile, key, resetVehicles)
	if not GC_DynamicStoragePlaceable:superClass().loadFromXMLFile(self, xmlFile, key, resetVehicles) then
		return false;
	end;

	local i = 0;
	while true do
		local factoryKey = string.format("%s.dynamicStorage(%d)", key, i);
		if not hasXMLProperty(xmlFile, factoryKey) then
			break;
		end;

		local index = getXMLInt(xmlFile, factoryKey .. "#index");
		local indexName = Utils.getNoNil(getXMLString(xmlFile, factoryKey .. "#indexName"), "");
		if index ~= nil then
			if self.dynamicStorages[index] ~= nil then
				if not self.dynamicStorages[index]:loadFromXMLFile(xmlFile, factoryKey) then
					return false;
				end;
			else
				g_company.debug:writeWarning(self.debugData, "Could not load DynamicStorage '%s'. Given 'index' '%d' is not defined!", indexName, index);
			end;
		end;
		
		i = i + 1;
	end;

	return true;
end;

function GC_DynamicStoragePlaceable:saveToXMLFile(xmlFile, key, usedModNames)
	GC_DynamicStoragePlaceable:superClass().saveToXMLFile(self, xmlFile, key, usedModNames);

	for index, storage in ipairs(self.dynamicStorages) do
		local keyId = index - 1;
		local factoryKey = string.format("%s.dynamicStorage(%d)", key, keyId);
		setXMLInt(xmlFile, factoryKey .. "#index", index);
		setXMLString(xmlFile, factoryKey .. "#saveId", storage.saveId);
		storage:saveToXMLFile(xmlFile, factoryKey, usedModNames);
	end;
end;

-- We need to update the 'OwnerFarmId' here so that sub-objects can also be updated and for land sales.
function GC_DynamicStoragePlaceable:setOwnerFarmId(ownerFarmId, noEventSend)
    GC_DynamicStoragePlaceable:superClass().setOwnerFarmId(self, ownerFarmId, noEventSend);

	for index, storage in ipairs(self.dynamicStorages) do
		storage:setOwnerFarmId(ownerFarmId, noEventSend);
	end;
end;
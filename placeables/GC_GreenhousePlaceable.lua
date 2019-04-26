--
-- GlobalCompany - Placeables - GC_GreenhousePlaceable
--
-- @Interface: --
-- @Author: LS-Modcompany / GtX / kevink98
-- @Date: 21.02.2019
-- @Version: 1.1.1.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (26.04.2019):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--	Registration is completed in the GlobalCompany.lua as part of 'loadPlaceables' function.
--	
--
-- ToDo:
--
--

GC_GreenhousePlaceable = {};

local GC_GreenhousePlaceable_mt = Class(GC_GreenhousePlaceable, Placeable);
InitObjectClass(GC_GreenhousePlaceable, "GC_GreenhousePlaceable");

GC_GreenhousePlaceable.debugIndex = g_company.debug:registerScriptName("GreenhousePlaceable");

getfenv(0)["GC_GreenhousePlaceable"] = GC_GreenhousePlaceable;

function GC_GreenhousePlaceable:new(isServer, isClient, customMt)
	local self = Placeable:new(isServer, isClient, customMt or GC_GreenhousePlaceable_mt);
	
	self.debugData = nil;
	self.greenhouses = {};

	registerObjectClassName(self, "GC_GreenhousePlaceable");	
	return self;
end;

function GC_GreenhousePlaceable:load(xmlFilename, x,y,z, rx,ry,rz, initRandom)
	if not GC_GreenhousePlaceable:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, initRandom) then
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_GreenhousePlaceable.debugIndex, nil, self.customEnvironment);

	local filenameToUse = xmlFilename;
	local xmlFile = loadXMLFile("TempPlaceableXML", xmlFilename);
	local canLoad = xmlFile ~= nil and xmlFile ~= 0;
	
	if canLoad then
		local placeableKey = "placeable.greenhouses";
		local externalXML = getXMLString(xmlFile, placeableKey .. "#xmlFilename");
		if externalXML ~= nil then
			externalXML = Utils.getFilename(externalXML, self.baseDirectory);
			filenameToUse = externalXML;
			if fileExists(filenameToUse) then
				delete(xmlFile); -- delete the 'Placeable.xml' first as we no longer needed it. ;-)
				
				placeableKey = "globalCompany.greenhouses";
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
				local key = string.format("%s.greenhouse(%d)", placeableKey, i);
				if not hasXMLProperty(xmlFile, key) then
					break;
				end;

				local indexName = getXMLString(xmlFile, key .. "#indexName");
				if indexName ~= nil and usedIndexNames[indexName] == nil then
					usedIndexNames[indexName] = key;
					local greenhouse = GC_Greenhouse:new(self.isServer, self.isClient, nil, filenameToUse, self.baseDirectory, self.customEnvironment);
					if greenhouse:load(self.nodeId, xmlFile, key, indexName, true) then
						greenhouse:setOwnerFarmId(self:getOwnerFarmId(), false);
						table.insert(self.greenhouses, greenhouse);
					else
						greenhouse:delete();
						greenhouse = nil;
						canLoad = false;

						g_company.debug:writeError(self.debugData, "Can not load greenhouse '%s' from XML file '%s'!", indexName, filenameToUse);
						break;
					end;
				else
					if indexName == nil then
						g_company.debug:writeError(self.debugData, "Can not load greenhouse. 'indexName' is missing. From XML file '%s'!", filenameToUse);
					else
						local usedKey = usedIndexNames[indexName];
						g_company.debug:writeError(self.debugData, "Duplicate indexName '%s' found! indexName is used at '%s' in XML file '%s'!", indexName, usedKey, filenameToUse);
					end;
				end;

				i = i + 1;
			end;
		else
			g_company.debug:writeError(self.debugData, "Cannot load placeable type [GC_GreenhousePlaceable]! Unable to load XML file '%s'.", filenameToUse);
		end;

		delete(xmlFile);
	else
		g_company.debug:writeError(self.debugData, "Cannot load placeable type [GC_GreenhousePlaceable]! Unable to load XML file '%s'.", filenameToUse);
	end;

	return canLoad;
end;

function GC_GreenhousePlaceable:finalizePlacement()
	GC_GreenhousePlaceable:superClass().finalizePlacement(self)

	for _, greenhouse in ipairs(self.greenhouses) do
		greenhouse:register(true);
	end;
end;

function GC_GreenhousePlaceable:delete()
	for id, greenhouse in ipairs(self.greenhouses) do
		greenhouse:delete();
	end;

	unregisterObjectClassName(self);
	GC_GreenhousePlaceable:superClass().delete(self);
end;

function GC_GreenhousePlaceable:readStream(streamId, connection)
    GC_GreenhousePlaceable:superClass().readStream(self, streamId, connection);
    
	if connection:getIsServer() then
        for _, greenhouse in ipairs(self.greenhouses) do
            local greenhouseId = NetworkUtil.readNodeObjectId(streamId);
            greenhouse:readStream(streamId, connection);
            g_client:finishRegisterObject(greenhouse, greenhouseId);
        end;
    end;
end;

function GC_GreenhousePlaceable:writeStream(streamId, connection)
    GC_GreenhousePlaceable:superClass().writeStream(self, streamId, connection);
    
	if not connection:getIsServer() then
        for _, greenhouse in ipairs(self.greenhouses) do
            NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(greenhouse));
            greenhouse:writeStream(streamId, connection);
            g_server:registerObjectInStream(connection, greenhouse);
        end;
    end;
end;

function GC_GreenhousePlaceable:collectPickObjects(node)
	-- We only want to add node once. This should be a simple check in the Placeable.lua be standard I think. ;-)
	if g_currentMission.nodeToObject[node] == nil then
		GC_GreenhousePlaceable:superClass().collectPickObjects(self, node);
	end;
end;

function GC_GreenhousePlaceable:loadFromXMLFile(xmlFile, key, resetVehicles)
	if not GC_GreenhousePlaceable:superClass().loadFromXMLFile(self, xmlFile, key, resetVehicles) then
		return false;
	end;

	local i = 0;
	while true do
		local greenhouseKey = string.format("%s.greenhouse(%d)", key, i);
		if not hasXMLProperty(xmlFile, greenhouseKey) then
			break;
		end;

		local index = getXMLInt(xmlFile, greenhouseKey .. "#index");
		local indexName = Utils.getNoNil(getXMLString(xmlFile, greenhouseKey .. "#indexName"), "");
		if index ~= nil then
			if self.greenhouses[index] ~= nil then
				if not self.greenhouses[index]:loadFromXMLFile(xmlFile, greenhouseKey) then
					return false;
				end;
			else
				g_company.debug:writeWarning(self.debugData, "Could not load greenhouse '%s'. Given 'index' '%d' is not defined!", indexName, index);
			end;
		end;
		
		i = i + 1;
	end;

	return true;
end;

function GC_GreenhousePlaceable:saveToXMLFile(xmlFile, key, usedModNames)
	GC_GreenhousePlaceable:superClass().saveToXMLFile(self, xmlFile, key, usedModNames);

	for index, greenhouse in ipairs(self.greenhouses) do
		local keyId = index - 1;
		local greenhouseKey = string.format("%s.greenhouse(%d)", key, keyId);
		setXMLInt(xmlFile, greenhouseKey .. "#index", index);
		setXMLString(xmlFile, greenhouseKey .. "#saveId", greenhouse.saveId);
		greenhouse:saveToXMLFile(xmlFile, greenhouseKey, usedModNames);
	end;
end;

-- We need to update the 'OwnerFarmId' here so that sub-objects can also be updated and for land sales.
function GC_GreenhousePlaceable:setOwnerFarmId(ownerFarmId, noEventSend)
    GC_GreenhousePlaceable:superClass().setOwnerFarmId(self, ownerFarmId, noEventSend);

	for index, greenhouse in ipairs(self.greenhouses) do
		greenhouse:setOwnerFarmId(ownerFarmId, noEventSend);
	end;
end;
--
-- GlobalCompany - Placeables - GC_ProductionFactoryPlaceable
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
-- 	v1.1.0.0 (21.02.2019):
-- 		- Add multi factory support for one placeable.
--		- Add GC Placeable registration method instead of script specific.
--
-- 	v1.0.0.0 (06.02.2019):
-- 		- initial fs19 (GtX)
--
--
-- Notes:
--	Registration is completed in the GlobalCompany.lua as part of 'loadPlaceables' function.
--	
--
-- ToDo:
--
--

GC_ProductionFactoryPlaceable = {};

local GC_ProductionFactoryPlaceable_mt = Class(GC_ProductionFactoryPlaceable, Placeable);
InitObjectClass(GC_ProductionFactoryPlaceable, "GC_ProductionFactoryPlaceable");

GC_ProductionFactoryPlaceable.debugIndex = g_company.debug:registerScriptName("ProductionFactoryPlaceable");

getfenv(0)["GC_ProductionFactoryPlaceable"] = GC_ProductionFactoryPlaceable;

function GC_ProductionFactoryPlaceable:new(isServer, isClient, customMt)
	local self = Placeable:new(isServer, isClient, customMt or GC_ProductionFactoryPlaceable_mt);
	
	self.debugData = nil;
	self.productionFactories = {};

	registerObjectClassName(self, "GC_ProductionFactoryPlaceable");	
	return self;
end;

function GC_ProductionFactoryPlaceable:load(xmlFilename, x,y,z, rx,ry,rz, initRandom)
	if not GC_ProductionFactoryPlaceable:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, initRandom) then
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_ProductionFactoryPlaceable.debugIndex, nil, self.customEnvironment);

	local filenameToUse = xmlFilename;
	local xmlFile = loadXMLFile("TempPlaceableXML", xmlFilename);
	local canLoad = xmlFile ~= nil and xmlFile ~= 0;
	
	if canLoad then
		local placeableKey = "placeable.productionFactories";
		local externalXML = getXMLString(xmlFile, placeableKey .. "#xmlFilename");
		if externalXML ~= nil then
			externalXML = Utils.getFilename(externalXML, self.baseDirectory);
			filenameToUse = externalXML;
			if fileExists(filenameToUse) then
				delete(xmlFile); -- delete the 'Placeable.xml' first as we no longer needed it. ;-)
				
				placeableKey = "globalCompany.productionFactories";
				xmlFile = loadXMLFile("TempExternalXML", filenameToUse);
				canLoad = xmlFile ~= nil and xmlFile ~= 0;
			else
				canLoad = false;
			end;
		end;

		if canLoad then
			local i = 0;
			while true do
				local key = string.format("%s.productionFactory(%d)", placeableKey, i);
				if not hasXMLProperty(xmlFile, key) then
					break;
				end;

				local indexName = getXMLString(xmlFile, key .. "#indexName");
				if indexName ~= nil then
					local factory = ProductionFactory:new(self.isServer, self.isClient, nil, filenameToUse, self.baseDirectory, self.customEnvironment);
					if factory:load(self.nodeId, xmlFile, key, indexName, true) then
						table.insert(self.productionFactories, factory);
					else
						factory:delete();
						factory = nil;
						canLoad = false;

						g_company.debug:writeError(self.debugData, "Can not load factory '%s' from XML file '%s'!", indexName, filenameToUse);
						break;
					end;
				end;

				i = i + 1;
			end;
		else
			g_company.debug:writeError(self.debugData, "Cannot load placeable type [GC_ProductionFactoryPlaceable]! Unable to load XML file '%s'.", filenameToUse);
		end;

		delete(xmlFile);
	end;

	return canLoad;
end;

function GC_ProductionFactoryPlaceable:finalizePlacement()
	GC_ProductionFactoryPlaceable:superClass().finalizePlacement(self)

	-- Only register each factory if they have all loaded correctly.
	for _, factory in ipairs(self.productionFactories) do
		factory:register(true);
	end;
end;

function GC_ProductionFactoryPlaceable:delete()
	for id, factory in ipairs(self.productionFactories) do
		factory:delete();
	end;

	unregisterObjectClassName(self);
	GC_ProductionFactoryPlaceable:superClass().delete(self);
end;

function GC_ProductionFactoryPlaceable:readStream(streamId, connection)
    GC_ProductionFactoryPlaceable:superClass().readStream(self, streamId, connection);
    
	if connection:getIsServer() then
        for _, factory in ipairs(self.productionFactories) do
            local factoryId = NetworkUtil.readNodeObjectId(streamId);
            factory:readStream(streamId, connection);
            g_client:finishRegisterObject(factory, factoryId);
        end;
    end;
end;

function GC_ProductionFactoryPlaceable:writeStream(streamId, connection)
    GC_ProductionFactoryPlaceable:superClass().writeStream(self, streamId, connection);
    
	if not connection:getIsServer() then
        for _, factory in ipairs(self.productionFactories) do
            NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(factory));
            factory:writeStream(streamId, connection);
            g_server:registerObjectInStream(connection, factory);
        end;
    end;
end;

function GC_ProductionFactoryPlaceable:collectPickObjects(node)
	-- We only want to add node once. This should be a simple check in the Placeable.lua be standard I think. ;-)
	if g_currentMission.nodeToObject[node] == nil then
		GC_ProductionFactoryPlaceable:superClass().collectPickObjects(self, node);
	end;
end;

function GC_ProductionFactoryPlaceable:loadFromXMLFile(xmlFile, key, resetVehicles)
	if not GC_ProductionFactoryPlaceable:superClass().loadFromXMLFile(self, xmlFile, key, resetVehicles) then
		return false;
	end;

	local i = 0;
	while true do
		local factoryKey = string.format("%s.productionFactory(%d)", key, i);
		if not hasXMLProperty(xmlFile, factoryKey) then
			break;
		end;

		local index = getXMLInt(xmlFile, factoryKey .. "#index");
		local indexName = Utils.getNoNil(getXMLString(xmlFile, factoryKey .. "#indexName"), "NAME ERROR");
		if index ~= nil then
			if self.productionFactories[index] ~= nil then
				if not self.productionFactories[index]:loadFromXMLFile(xmlFile, factoryKey) then
					return false;
				end;
			else
				g_company.debug:writeWarning(self.debugData, "Could not load bunkersilo. Given 'index' '%d' for '%s' is not defined!", index, indexName);
			end;
		end;
		
		i = i + 1;
	end;

	return true;
end;

function GC_ProductionFactoryPlaceable:saveToXMLFile(xmlFile, key, usedModNames)
	GC_ProductionFactoryPlaceable:superClass().saveToXMLFile(self, xmlFile, key, usedModNames);

	for index, factory in ipairs(self.productionFactories) do
		local keyId = index - 1;
		local factoryKey = string.format("%s.productionFactory(%d)", key, keyId);
		setXMLInt(xmlFile, factoryKey .. "#index", index);
		setXMLString(xmlFile, factoryKey .. "#saveId", factory.saveId);
		factory:saveToXMLFile(xmlFile, factoryKey, usedModNames);
	end;
end;






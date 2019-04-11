--
-- GlobalCompany - Placeables - GC_BaleShreaderPlaceable
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98 / GtX
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
--	Registration is completed in the GlobalCompany.lua as part of 'loadPlaceables' function.
--	
--
-- ToDo:
--
--

GC_BaleShreaderPlaceable = {};

local GC_BaleShreaderPlaceable_mt = Class(GC_BaleShreaderPlaceable, Placeable);
InitObjectClass(GC_BaleShreaderPlaceable, "GC_BaleShreaderPlaceable");

GC_BaleShreaderPlaceable.debugIndex = g_company.debug:registerScriptName("BaleShreaderPlaceable");

getfenv(0)["GC_BaleShreaderPlaceable"] = GC_BaleShreaderPlaceable;

function GC_BaleShreaderPlaceable:new(isServer, isClient, customMt)
	local self = Placeable:new(isServer, isClient, customMt or GC_BaleShreaderPlaceable_mt);
	
	self.debugData = nil;
	self.baleShreaders = {};

	registerObjectClassName(self, "GC_BaleShreaderPlaceable");	
	return self;
end;

function GC_BaleShreaderPlaceable:load(xmlFilename, x,y,z, rx,ry,rz, initRandom)
	if not GC_BaleShreaderPlaceable:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, initRandom) then
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_BaleShreaderPlaceable.debugIndex, nil, self.customEnvironment);

	local filenameToUse = xmlFilename;
	local xmlFile = loadXMLFile("TempPlaceableXML", xmlFilename);
	local canLoad = xmlFile ~= nil and xmlFile ~= 0;
	
	if canLoad then
		local placeableKey = "placeable.globalCompany.baleShreaders";
		local externalXML = getXMLString(xmlFile, placeableKey .. "#xmlFilename");
		if externalXML ~= nil then
			externalXML = Utils.getFilename(externalXML, self.baseDirectory);
			filenameToUse = externalXML;
			if fileExists(filenameToUse) then
				delete(xmlFile);
				
				placeableKey = "globalCompany.baleShreaders";
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
				local key = string.format("%s.baleShreader(%d)", placeableKey, i);
				if not hasXMLProperty(xmlFile, key) then
					break;
				end;

				local indexName = getXMLString(xmlFile, key .. "#indexName");
				if indexName ~= nil and usedIndexNames[indexName] == nil then
					usedIndexNames[indexName] = key;
					local baleShreader = BaleShreader:new(self.isServer, self.isClient, nil, filenameToUse, self.baseDirectory, self.customEnvironment);
					if baleShreader:load(self.nodeId, xmlFile, key, indexName, true) then
						table.insert(self.baleShreaders, baleShreader);
					else
						baleShreader:delete();
						baleShreader = nil;
						canLoad = false;

						g_company.debug:writeError(self.debugData, "Can not load baleshreader '%s' from XML file '%s'!", indexName, filenameToUse);
						break;
					end;
				else
					if indexName == nil then
						g_company.debug:writeError(self.debugData, "Can not load baleshreader. 'indexName' is missing. From XML file '%s'!", filenameToUse);
					else
						local usedKey = usedIndexNames[indexName];
						g_company.debug:writeError(self.debugData, "Duplicate indexName '%s' found! indexName is used at '%s' in XML file '%s'!", indexName, usedKey, filenameToUse);
					end;
				end;

				i = i + 1;
			end;
		else
			g_company.debug:writeError(self.debugData, "Cannot load placeable type [GC_BaleShreaderPlaceable]! Unable to load XML file '%s'.", filenameToUse);
		end;

		delete(xmlFile);
	end;

	return canLoad;
end;

function GC_BaleShreaderPlaceable:finalizePlacement()
	GC_BaleShreaderPlaceable:superClass().finalizePlacement(self)

	for _, shreader in ipairs(self.baleShreaders) do
		shreader:register(true);
	end;
end;

function GC_BaleShreaderPlaceable:delete()
	for id, shreader in ipairs(self.baleShreaders) do
		shreader:delete();
	end;

	unregisterObjectClassName(self);
	GC_BaleShreaderPlaceable:superClass().delete(self);
end;

function GC_BaleShreaderPlaceable:readStream(streamId, connection)
    GC_BaleShreaderPlaceable:superClass().readStream(self, streamId, connection);
    
	if connection:getIsServer() then
        for _, shreader in ipairs(self.baleShreaders) do
            local shreaderId = NetworkUtil.readNodeObjectId(streamId);
            shreader:readStream(streamId, connection);
            g_client:finishRegisterObject(shreader, shreaderId);
        end;
    end;
end;

function GC_BaleShreaderPlaceable:writeStream(streamId, connection)
    GC_BaleShreaderPlaceable:superClass().writeStream(self, streamId, connection);
    
	if not connection:getIsServer() then
        for _, shreader in ipairs(self.baleShreaders) do
            NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(shreader));
            shreader:writeStream(streamId, connection);
            g_server:registerObjectInStream(connection, shreader);
        end;
    end;
end;

function GC_BaleShreaderPlaceable:collectPickObjects(node)
	if g_currentMission.nodeToObject[node] == nil then
		GC_BaleShreaderPlaceable:superClass().collectPickObjects(self, node);
	end;
end;

function GC_BaleShreaderPlaceable:loadFromXMLFile(xmlFile, key, resetVehicles)
	if not GC_BaleShreaderPlaceable:superClass().loadFromXMLFile(self, xmlFile, key, resetVehicles) then
		return false;
	end;

	local i = 0;
	while true do
		local shreaderKey = string.format("%s.baleShreader(%d)", key, i);
		if not hasXMLProperty(xmlFile, shreaderKey) then
			break;
		end;

		local index = getXMLInt(xmlFile, shreaderKey .. "#index");
		local indexName = Utils.getNoNil(getXMLString(xmlFile, shreaderKey .. "#indexName"), "NAME ERROR");
		if index ~= nil then
			if self.baleShreaders[index] ~= nil then
				if not self.baleShreaders[index]:loadFromXMLFile(xmlFile, shreaderKey) then
					return false;
				end;
			else
				g_company.debug:writeWarning(self.debugData, "Could not load shreader. Given 'index' '%d' for '%s' is not defined!", index, indexName);
			end;
		end;
		
		i = i + 1;
	end;

	return true;
end;

function GC_BaleShreaderPlaceable:saveToXMLFile(xmlFile, key, usedModNames)
	GC_BaleShreaderPlaceable:superClass().saveToXMLFile(self, xmlFile, key, usedModNames);

	for index, shreader in ipairs(self.baleShreaders) do
		local keyId = index - 1;
		local shreaderKey = string.format("%s.baleShreader(%d)", key, keyId);
		setXMLInt(xmlFile, shreaderKey .. "#index", index);
		setXMLString(xmlFile, shreaderKey .. "#saveId", shreader.saveId);
		shreader:saveToXMLFile(xmlFile, shreaderKey, usedModNames);
	end;
end;






--
-- GlobalCompany - Placeables - GC_BalerPlaceable
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98 / GtX
-- @Date: 02.03.2019
-- @Version: 1.0.1.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (02.03.2019):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--
--
--
-- ToDo:
--
--

GC_BalerPlaceable = {};

local GC_BalerPlaceable_mt = Class(GC_BalerPlaceable, Placeable);
InitObjectClass(GC_BalerPlaceable, "GC_BalerPlaceable");

GC_BalerPlaceable.debugIndex = g_company.debug:registerScriptName("BalerPlaceable");

getfenv(0)["GC_BalerPlaceable"] = GC_BalerPlaceable;

function GC_BalerPlaceable:new(isServer, isClient, customMt)
	local self = Placeable:new(isServer, isClient, customMt or GC_BalerPlaceable_mt);

	self.debugData = nil;
	self.balers = {};

	registerObjectClassName(self, "GC_BalerPlaceable");
	return self;
end;

function GC_BalerPlaceable:load(xmlFilename, x,y,z, rx,ry,rz, initRandom)
	if not GC_BalerPlaceable:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, initRandom) then
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_BalerPlaceable.debugIndex, nil, self.customEnvironment);

	local filenameToUse = xmlFilename;
	local xmlFile = loadXMLFile("TempPlaceableXML", xmlFilename);
	local canLoad = xmlFile ~= nil and xmlFile ~= 0;

	if canLoad then
		local placeableKey = "placeable.globalCompany.balers";
		local externalXML = getXMLString(xmlFile, placeableKey .. "#xmlFilename");
		if externalXML ~= nil then
			externalXML = Utils.getFilename(externalXML, self.baseDirectory);
			filenameToUse = externalXML;
			if fileExists(filenameToUse) then
				delete(xmlFile);

				placeableKey = "globalCompany.balers";
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
				local key = string.format("%s.baler(%d)", placeableKey, i);
				if not hasXMLProperty(xmlFile, key) then
					break;
				end;

				local indexName = getXMLString(xmlFile, key .. "#indexName");
				if indexName ~= nil and usedIndexNames[indexName] == nil then
					usedIndexNames[indexName] = key;
					local baler = GC_Baler:new(self.isServer, self.isClient, nil, filenameToUse, self.baseDirectory, self.customEnvironment);
					baler:setOwnerFarmId(self:getOwnerFarmId(), false); -- Set the ownership here. All other updates will use 'setOwnerFarmId' function.
					if baler:load(self.nodeId, xmlFile, key, indexName, true) then
						table.insert(self.balers, baler);
					else
						baler:delete();
						baler = nil;
						canLoad = false;

						g_company.debug:writeError(self.debugData, "Can not load baler '%s' from XML file '%s'!", indexName, filenameToUse);
						break;
					end;
				else
					if indexName == nil then
						g_company.debug:writeError(self.debugData, "Can not load baler. 'indexName' is missing. From XML file '%s'!", filenameToUse);
					else
						local usedKey = usedIndexNames[indexName];
						g_company.debug:writeError(self.debugData, "Duplicate indexName '%s' found! indexName is used at '%s' in XML file '%s'!", indexName, usedKey, filenameToUse);
					end;
				end;

				i = i + 1;
			end;
		else
			g_company.debug:writeError(self.debugData, "Cannot load placeable type [GC_BalerPlaceable]! Unable to load XML file '%s'.", filenameToUse);
		end;

		delete(xmlFile);
	end;

	return canLoad;
end;

function GC_BalerPlaceable:finalizePlacement()
	GC_BalerPlaceable:superClass().finalizePlacement(self)

	for _, baler in ipairs(self.balers) do
		baler:register(true);
		baler:finalizePlacement();
	end;
end;

function GC_BalerPlaceable:delete()
	for id, baler in ipairs(self.balers) do
		baler:delete();
	end;

	unregisterObjectClassName(self);
	GC_BalerPlaceable:superClass().delete(self);
end;

function GC_BalerPlaceable:readStream(streamId, connection)
	GC_BalerPlaceable:superClass().readStream(self, streamId, connection);

	if connection:getIsServer() then
		for _, baler in ipairs(self.balers) do
			local balerId = NetworkUtil.readNodeObjectId(streamId);
			baler:readStream(streamId, connection);
			g_client:finishRegisterObject(baler, balerId);
		end;
	end;
end;

function GC_BalerPlaceable:writeStream(streamId, connection)
	GC_BalerPlaceable:superClass().writeStream(self, streamId, connection);

	if not connection:getIsServer() then
		for _, baler in ipairs(self.balers) do
			NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(baler));
			baler:writeStream(streamId, connection);
			g_server:registerObjectInStream(connection, baler);
		end;
	end;
end;

function GC_BalerPlaceable:collectPickObjects(node)
	if g_currentMission.nodeToObject[node] == nil then
		GC_BalerPlaceable:superClass().collectPickObjects(self, node);
	end;
end;

function GC_BalerPlaceable:loadFromXMLFile(xmlFile, key, resetVehicles)
	if not GC_BalerPlaceable:superClass().loadFromXMLFile(self, xmlFile, key, resetVehicles) then
		return false;
	end;

	local i = 0;
	while true do
		local balerKey = string.format("%s.baler(%d)", key, i);
		if not hasXMLProperty(xmlFile, balerKey) then
			break;
		end;

		local index = getXMLInt(xmlFile, balerKey .. "#index");
		local indexName = Utils.getNoNil(getXMLString(xmlFile, balerKey .. "#indexName"), "NAME ERROR");
		if index ~= nil then
			if self.balers[index] ~= nil then
				if not self.balers[index]:loadFromXMLFile(xmlFile, balerKey) then
					return false;
				end;
			else
				g_company.debug:writeWarning(self.debugData, "Could not load baler. Given 'index' '%d' for '%s' is not defined!", index, indexName);
			end;
		end;

		i = i + 1;
	end;

	return true;
end;

function GC_BalerPlaceable:saveToXMLFile(xmlFile, key, usedModNames)
	GC_BalerPlaceable:superClass().saveToXMLFile(self, xmlFile, key, usedModNames);

	for index, baler in ipairs(self.balers) do
		local keyId = index - 1;
		local balerKey = string.format("%s.baler(%d)", key, keyId);
		setXMLInt(xmlFile, balerKey .. "#index", index);
		setXMLString(xmlFile, balerKey .. "#saveId", baler.saveId);
		baler:saveToXMLFile(xmlFile, balerKey, usedModNames);
	end;
end;

-- We need to update the 'OwnerFarmId' here so that sub-objects can also be updated on saveGame load, and for land sales if 'boughtWithFarmland'.
function GC_BalerPlaceable:setOwnerFarmId(ownerFarmId, noEventSend)
	GC_BalerPlaceable:superClass().setOwnerFarmId(self, ownerFarmId, noEventSend);

	for _, baler in ipairs(self.balers) do
		baler:setOwnerFarmId(ownerFarmId, noEventSend);
	end;
end;




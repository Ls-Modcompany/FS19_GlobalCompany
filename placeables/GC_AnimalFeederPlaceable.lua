--
-- GlobalCompany - Placeables - GC_AnimalFeederPlaceable
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany / kevink98
-- @Date: ..
-- @Version: 1.0.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
-- 	v1.0.0.0 (..):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--		- Registration is completed in the GlobalCompany.lua as part of 'loadPlaceables' function.
--
--
-- ToDo:
--
--

GC_AnimalFeederPlaceable = {}

GC_AnimalFeederPlaceable.PLACEABLE_KEY = "placeable.animalFeeders";
GC_AnimalFeederPlaceable.GC_KEY = "globalCompany.animalFeeders";
GC_AnimalFeederPlaceable.ITEM_KEY = "animalFeeder";

local GC_AnimalFeederPlaceable_mt = Class(GC_AnimalFeederPlaceable, Placeable)
InitObjectClass(GC_AnimalFeederPlaceable, "GC_AnimalFeederPlaceable")

GC_AnimalFeederPlaceable.debugIndex = g_company.debug:registerScriptName("AnimalFeederPlaceable")

getfenv(0)["GC_AnimalFeederPlaceable"] = GC_AnimalFeederPlaceable

function GC_AnimalFeederPlaceable:new(isServer, isClient, customMt)
	local self = Placeable:new(isServer, isClient, customMt or GC_AnimalFeederPlaceable_mt)

	self.debugData = nil
	self.list = {}

	registerObjectClassName(self, "GC_AnimalFeederPlaceable")
	return self
end

function GC_AnimalFeederPlaceable:load(xmlFilename, x,y,z, rx,ry,rz, initRandom)
	if not GC_AnimalFeederPlaceable:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, initRandom) then
		return false
	end

	self.debugData = g_company.debug:getDebugData(GC_AnimalFeederPlaceable.debugIndex, nil, self.customEnvironment)

	local filenameToUse = xmlFilename
	local xmlFile = loadXMLFile("TempPlaceableXML", xmlFilename)
	local canLoad = xmlFile ~= nil and xmlFile ~= 0

	if canLoad then
		local placeableKey = GC_AnimalFeederPlaceable.PLACEABLE_KEY;
		local externalXML = getXMLString(xmlFile, placeableKey .. "#xmlFilename")
		if externalXML ~= nil then
			externalXML = Utils.getFilename(externalXML, self.baseDirectory)
			filenameToUse = externalXML
			if fileExists(filenameToUse) then
				delete(xmlFile)

				placeableKey = GC_AnimalFeederPlaceable.GC_KEY
				xmlFile = loadXMLFile("TempExternalXML", filenameToUse)
				canLoad = xmlFile ~= nil and xmlFile ~= 0
			else
				canLoad = false
			end
		end

		if canLoad then
			local usedIndexNames = {}

			local i = 0
			while true do
				local key = string.format("%s.%s(%d)", placeableKey, GC_AnimalFeederPlaceable.ITEM_KEY, i)
				if not hasXMLProperty(xmlFile, key) then
					break
				end

				local indexName = getXMLString(xmlFile, key .. "#indexName")
				if indexName ~= nil and usedIndexNames[indexName] == nil then
					usedIndexNames[indexName] = key
					local object = GC_AnimalFeeder:new(self.isServer, g_dedicatedServerInfo == nil, nil, filenameToUse, self.baseDirectory, self.customEnvironment)
					if object:load(self.nodeId, xmlFile, key, indexName, true) then
						object.owningPlaceable = self
						object:setOwnerFarmId(self:getOwnerFarmId(), false)
						table.insert(self.list, object)
					else
						object:delete()
						object = nil
						canLoad = false

						g_company.debug:writeError(self.debugData, "Can not load %s '%s' from XML file '%s'!", GC_AnimalFeederPlaceable.ITEM_KEY, indexName, filenameToUse)
						break
					end
				else
					if indexName == nil then
						g_company.debug:writeError(self.debugData, "Can not load %s. 'indexName' is missing. From XML file '%s'!", GC_AnimalFeederPlaceable.ITEM_KEY, filenameToUse)
					else
						local usedKey = usedIndexNames[indexName]
						g_company.debug:writeError(self.debugData, "Duplicate indexName '%s' found! indexName is used at '%s' in XML file '%s'!", indexName, usedKey, filenameToUse)
					end
				end

				i = i + 1
			end
		else
			g_company.debug:writeError(self.debugData, "Cannot load placeable type [GC_AnimalFeederPlaceable]! Unable to load XML file '%s'.", filenameToUse)
		end

		delete(xmlFile)
	else
		g_company.debug:writeError(self.debugData, "Cannot load placeable type [GC_AnimalFeederPlaceable]! Unable to load XML file '%s'.", filenameToUse)
	end

	return canLoad
end

function GC_AnimalFeederPlaceable:finalizePlacement()
	GC_AnimalFeederPlaceable:superClass().finalizePlacement(self)

	for _, object in ipairs(self.list) do
		object:finalizePlacement();
		object:register(true)
	end
end

function GC_AnimalFeederPlaceable:delete()
	for id, object in ipairs(self.list) do
		object:delete()
	end

	unregisterObjectClassName(self)
	GC_AnimalFeederPlaceable:superClass().delete(self)
end

function GC_AnimalFeederPlaceable:readStream(streamId, connection)
	GC_AnimalFeederPlaceable:superClass().readStream(self, streamId, connection)

	if connection:getIsServer() then
		for _, object in ipairs(self.list) do
			local objectId = NetworkUtil.readNodeObjectId(streamId)
			object:readStream(streamId, connection)
			g_client:finishRegisterObject(object, objectId)
		end
	end
end

function GC_AnimalFeederPlaceable:writeStream(streamId, connection)
	GC_AnimalFeederPlaceable:superClass().writeStream(self, streamId, connection)

	if not connection:getIsServer() then
		for _, object in ipairs(self.list) do
			NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(object))
			object:writeStream(streamId, connection)
			g_server:registerObjectInStream(connection, object)
		end
	end
end

function GC_AnimalFeederPlaceable:collectPickObjects(node)
	if g_currentMission.nodeToObject[node] == nil then
		GC_AnimalFeederPlaceable:superClass().collectPickObjects(self, node)
	end
end

function GC_AnimalFeederPlaceable:loadFromXMLFile(xmlFile, key, resetVehicles)
	if not GC_AnimalFeederPlaceable:superClass().loadFromXMLFile(self, xmlFile, key, resetVehicles) then
		return false
	end

	local i = 0
	while true do
		local objectKey = string.format("%s.%s(%d)", key, GC_AnimalFeederPlaceable.ITEM_KEY, i)
		if not hasXMLProperty(xmlFile, objectKey) then
			break
		end

		local index = getXMLInt(xmlFile, objectKey .. "#index")
		local indexName = Utils.getNoNil(getXMLString(xmlFile, objectKey .. "#indexName"), "")
		if index ~= nil then
			if self.list[index] ~= nil then
				if not self.list[index]:loadFromXMLFile(xmlFile, objectKey) then
					return false
				end
			else
				g_company.debug:writeWarning(self.debugData, "Could not load %s '%s'. Given 'index' '%d' is not defined!", GC_AnimalFeederPlaceable.ITEM_KEY, indexName, index)
			end
		end

		i = i + 1
	end

	return true
end

function GC_AnimalFeederPlaceable:saveToXMLFile(xmlFile, key, usedModNames)
	GC_AnimalFeederPlaceable:superClass().saveToXMLFile(self, xmlFile, key, usedModNames)

	for index, object in ipairs(self.list) do
		local keyId = index - 1
		local objectKey = string.format("%s.%s(%d)", key, GC_AnimalFeederPlaceable.ITEM_KEY, keyId)
		setXMLInt(xmlFile, objectKey .. "#index", index)
		setXMLString(xmlFile, objectKey .. "#saveId", object.saveId)
		object:saveToXMLFile(xmlFile, objectKey, usedModNames)
	end
end

function GC_AnimalFeederPlaceable:setOwnerFarmId(ownerFarmId, noEventSend)
	GC_AnimalFeederPlaceable:superClass().setOwnerFarmId(self, ownerFarmId, noEventSend)

	for _, object in ipairs(self.list) do
		object:setOwnerFarmId(ownerFarmId, noEventSend)
	end
end

function GC_AnimalFeederPlaceable:canBeSold()
	return true, nil
end

function GC_AnimalFeederPlaceable:onSell()
	GC_AnimalFeederPlaceable:superClass().onSell(self)
end
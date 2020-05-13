--
-- GlobalCompany - Placeables - GC_PlaceableDigitalDisplayPlaceable
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany / kevink98
-- @Date: 17.10.2019
-- @Version: 1.0.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
-- 	v1.0.0.0 (17.10.2019):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--		- Registration is completed in the GlobalCompany.lua as part of 'loadPlaceables' function.
--
-- ToDo:
--

GC_PlaceableDigitalDisplayPlaceable = {}

GC_PlaceableDigitalDisplayPlaceable.PLACEABLE_KEY = "placeable.digitalDisplays";
GC_PlaceableDigitalDisplayPlaceable.GC_KEY = "globalCompany.digitalDisplays";
GC_PlaceableDigitalDisplayPlaceable.ITEM_KEY = "digitalDisplay";

local GC_PlaceableDigitalDisplayPlaceable_mt = Class(GC_PlaceableDigitalDisplayPlaceable, Placeable)
InitObjectClass(GC_PlaceableDigitalDisplayPlaceable, "GC_PlaceableDigitalDisplayPlaceable")

GC_PlaceableDigitalDisplayPlaceable.debugIndex = g_company.debug:registerScriptName("PlaceableDigitalDisplayPlaceable")

getfenv(0)["GC_PlaceableDigitalDisplayPlaceable"] = GC_PlaceableDigitalDisplayPlaceable

function GC_PlaceableDigitalDisplayPlaceable:new(isServer, isClient, customMt)
	local self = Placeable:new(isServer, isClient, customMt or GC_PlaceableDigitalDisplayPlaceable_mt)

	self.debugData = nil
	self.list = {}

	self.totalSellPrice = 0

	registerObjectClassName(self, "GC_PlaceableDigitalDisplayPlaceable")
	return self
end

function GC_PlaceableDigitalDisplayPlaceable:load(xmlFilename, x,y,z, rx,ry,rz, initRandom)
	if not GC_PlaceableDigitalDisplayPlaceable:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, initRandom) then
		return false
	end

	self.debugData = g_company.debug:getDebugData(GC_PlaceableDigitalDisplayPlaceable.debugIndex, nil, self.customEnvironment)

	local filenameToUse = xmlFilename
	local xmlFile = loadXMLFile("TempPlaceableXML", xmlFilename)
	local canLoad = xmlFile ~= nil and xmlFile ~= 0

	if canLoad then
		local placeableKey = GC_PlaceableDigitalDisplayPlaceable.PLACEABLE_KEY;
		local externalXML = getXMLString(xmlFile, placeableKey .. "#xmlFilename")
		if externalXML ~= nil then
			externalXML = Utils.getFilename(externalXML, self.baseDirectory)
			filenameToUse = externalXML
			if fileExists(filenameToUse) then
				delete(xmlFile)

				placeableKey = GC_PlaceableDigitalDisplayPlaceable.GC_KEY
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
				local key = string.format("%s.%s(%d)", placeableKey, GC_PlaceableDigitalDisplayPlaceable.ITEM_KEY, i)
				if not hasXMLProperty(xmlFile, key) then
					break
				end

				local indexName = getXMLString(xmlFile, key .. "#indexName")
				if indexName ~= nil and usedIndexNames[indexName] == nil then
					usedIndexNames[indexName] = key
					local object = GC_PlaceableDigitalDisplay:new(self.isServer, g_dedicatedServerInfo == nil, nil, filenameToUse, self.baseDirectory, self.customEnvironment)
					if object:load(self.nodeId, xmlFile, key, indexName, true) then
						object.owningPlaceable = self
						object:setOwnerFarmId(self:getOwnerFarmId(), false)
						table.insert(self.list, object)
					else
						object:delete()
						object = nil
						canLoad = false

						g_company.debug:writeError(self.debugData, "Can not load %s '%s' from XML file '%s'!", GC_PlaceableDigitalDisplayPlaceable.ITEM_KEY, indexName, filenameToUse)
						break
					end
				else
					if indexName == nil then
						g_company.debug:writeError(self.debugData, "Can not load %s. 'indexName' is missing. From XML file '%s'!", GC_PlaceableDigitalDisplayPlaceable.ITEM_KEY, filenameToUse)
					else
						local usedKey = usedIndexNames[indexName]
						g_company.debug:writeError(self.debugData, "Duplicate indexName '%s' found! indexName is used at '%s' in XML file '%s'!", indexName, usedKey, filenameToUse)
					end
				end

				i = i + 1
			end
		else
			g_company.debug:writeError(self.debugData, "Cannot load placeable type [GC_PlaceableDigitalDisplayPlaceable]! Unable to load XML file '%s'.", filenameToUse)
		end

		delete(xmlFile)
	else
		g_company.debug:writeError(self.debugData, "Cannot load placeable type [GC_PlaceableDigitalDisplayPlaceable]! Unable to load XML file '%s'.", filenameToUse)
	end

	return canLoad
end

function GC_PlaceableDigitalDisplayPlaceable:finalizePlacement()
	GC_PlaceableDigitalDisplayPlaceable:superClass().finalizePlacement(self)

	for _, object in ipairs(self.list) do
		object:finalizePlacement();
		object:register(true)
	end
end

function GC_PlaceableDigitalDisplayPlaceable:delete()
	for id, object in ipairs(self.list) do
		object:delete()
	end

	unregisterObjectClassName(self)
	GC_PlaceableDigitalDisplayPlaceable:superClass().delete(self)
end

function GC_PlaceableDigitalDisplayPlaceable:readStream(streamId, connection)
	GC_PlaceableDigitalDisplayPlaceable:superClass().readStream(self, streamId, connection)

	if connection:getIsServer() then
		for _, object in ipairs(self.list) do
			local objectId = NetworkUtil.readNodeObjectId(streamId)
			object:readStream(streamId, connection)
			g_client:finishRegisterObject(object, objectId)
		end
	end
end

function GC_PlaceableDigitalDisplayPlaceable:writeStream(streamId, connection)
	GC_PlaceableDigitalDisplayPlaceable:superClass().writeStream(self, streamId, connection)

	if not connection:getIsServer() then
		for _, object in ipairs(self.list) do
			NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(object))
			object:writeStream(streamId, connection)
			g_server:registerObjectInStream(connection, object)
		end
	end
end

function GC_PlaceableDigitalDisplayPlaceable:collectPickObjects(node)
	if g_currentMission.nodeToObject[node] == nil then
		GC_PlaceableDigitalDisplayPlaceable:superClass().collectPickObjects(self, node)
	end
end

function GC_PlaceableDigitalDisplayPlaceable:loadFromXMLFile(xmlFile, key, resetVehicles)
	if not GC_PlaceableDigitalDisplayPlaceable:superClass().loadFromXMLFile(self, xmlFile, key, resetVehicles) then
		return false
	end

	local i = 0
	while true do
		local objectKey = string.format("%s.%s(%d)", key, GC_PlaceableDigitalDisplayPlaceable.ITEM_KEY, i)
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
				g_company.debug:writeWarning(self.debugData, "Could not load %s '%s'. Given 'index' '%d' is not defined!", GC_PlaceableDigitalDisplayPlaceable.ITEM_KEY, indexName, index)
			end
		end

		i = i + 1
	end

	return true
end

function GC_PlaceableDigitalDisplayPlaceable:saveToXMLFile(xmlFile, key, usedModNames)
	GC_PlaceableDigitalDisplayPlaceable:superClass().saveToXMLFile(self, xmlFile, key, usedModNames)

	for index, object in ipairs(self.list) do
		local keyId = index - 1
		local objectKey = string.format("%s.%s(%d)", key, GC_PlaceableDigitalDisplayPlaceable.ITEM_KEY, keyId)
		setXMLInt(xmlFile, objectKey .. "#index", index)
		setXMLString(xmlFile, objectKey .. "#saveId", object.saveId)
		object:saveToXMLFile(xmlFile, objectKey, usedModNames)
	end
end

function GC_PlaceableDigitalDisplayPlaceable:setOwnerFarmId(ownerFarmId, noEventSend)
	GC_PlaceableDigitalDisplayPlaceable:superClass().setOwnerFarmId(self, ownerFarmId, noEventSend)

	for _, object in ipairs(self.list) do
		object:setOwnerFarmId(ownerFarmId, noEventSend)
	end
end

function GC_PlaceableDigitalDisplayPlaceable:canBeSold()
	return true
end

function GC_PlaceableDigitalDisplayPlaceable:onSell()
	GC_PlaceableDigitalDisplayPlaceable:superClass().onSell(self)
end